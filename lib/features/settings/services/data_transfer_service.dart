import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

import '../../../core/app_database.dart';
import '../../customer_credit_and_debit_tracking/services/credit_tracking_service.dart';
import '../../expense_tracking/services/expense_service.dart';
import '../../product_and_inventory_management/services/expiration_service.dart';
import '../../products/domain/product.dart';
import 'local_backup_service.dart';

enum DataTransferKind { allData, productsOnly }

class PreparedDataTransfer {
  final DataTransferKind kind;
  final Map<String, dynamic> payload;
  final List<ProductModel> products;
  final List<String> summaryLines;
  final int existingProductConflicts;

  const PreparedDataTransfer({
    required this.kind,
    required this.payload,
    this.products = const [],
    required this.summaryLines,
    this.existingProductConflicts = 0,
  });
}

class DataTransferException implements Exception {
  final String message;

  const DataTransferException(this.message);

  @override
  String toString() => message;
}

class DataTransferService {
  static const fileFormat = 'bizniz_tracker_encrypted_backup';
  static const fileVersion = 1;
  static const backupVersion = 1;
  static const minimumPasswordLength = 12;
  static const maxBackupFileBytes = 128 * 1024 * 1024;
  static const _iterations = 600000;
  static const _maxPayloadBytes = 256 * 1024 * 1024;

  static const _aad =
      'bizniz_tracker_encrypted_backup|1|AES-256-GCM|PBKDF2-HMAC-SHA256|600000';

  final AppDatabase database;
  final LocalBackupService backupService;

  const DataTransferService({
    required this.database,
    required this.backupService,
  });

  Future<Uint8List> exportAllData(String password) async {
    _validateExportPassword(password);
    if (backupService.database == null) {
      throw const DataTransferException(
        'A complete backup requires the application database.',
      );
    }
    final backup = await backupService.createBackup();
    if (!backup.containsKey('databaseSnapshot')) {
      throw const DataTransferException(
        'The application database could not be included in the backup.',
      );
    }
    return encryptPayload({
      'format': fileFormat,
      'backupVersion': backupVersion,
      'kind': DataTransferKind.allData.name,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'data': backup,
    }, password);
  }

  Future<Uint8List> exportProductsOnly(String password) async {
    _validateExportPassword(password);
    final products = await database.getProducts();
    return encryptPayload({
      'format': fileFormat,
      'backupVersion': backupVersion,
      'kind': DataTransferKind.productsOnly.name,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'data': {
        'products': [
          for (final product in products) _productToCatalogMap(product),
        ],
      },
    }, password);
  }

  Future<Uint8List> encryptPayload(
    Map<String, Object?> payload,
    String password,
  ) async {
    _validateExportPassword(password);
    final plainBytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    if (plainBytes.length > _maxPayloadBytes) {
      throw const DataTransferException(
        'The backup is too large to export from this device.',
      );
    }
    final compressed = Uint8List.fromList(
      const GZipEncoder().encode(plainBytes),
    );
    final salt = _secureRandomBytes(16);
    final nonce = _secureRandomBytes(12);
    final key = await _deriveKey(password, salt);
    final secretBox = await AesGcm.with256bits().encrypt(
      compressed,
      secretKey: key,
      nonce: nonce,
      aad: utf8.encode(_aad),
    );
    final envelope = <String, Object?>{
      'format': fileFormat,
      'fileVersion': fileVersion,
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
    if (bytes.length > maxBackupFileBytes) {
      throw const DataTransferException(
        'The encrypted backup exceeds the supported file size.',
      );
    }
    return bytes;
  }

  Future<PreparedDataTransfer> decryptAndValidate(
    List<int> fileBytes, {
    required String password,
    required DataTransferKind expectedKind,
  }) async {
    if (fileBytes.isEmpty || fileBytes.length > maxBackupFileBytes) {
      throw const FormatException(
        'The selected backup file is empty or too large.',
      );
    }
    if (password.isEmpty) {
      throw const DataTransferException('Enter the backup password.');
    }

    final decodedEnvelope = jsonDecode(utf8.decode(fileBytes));
    if (decodedEnvelope is! Map) {
      throw const FormatException('The selected file is not a valid backup.');
    }
    final envelope = Map<String, dynamic>.from(decodedEnvelope);
    const expectedKeys = {
      'format',
      'fileVersion',
      'cipher',
      'kdf',
      'iterations',
      'salt',
      'nonce',
      'ciphertext',
      'mac',
    };
    if (envelope.keys.length != expectedKeys.length ||
        envelope.keys.any((key) => !expectedKeys.contains(key)) ||
        envelope['format'] != fileFormat ||
        envelope['fileVersion'] != fileVersion ||
        envelope['cipher'] != 'AES-256-GCM' ||
        envelope['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        envelope['iterations'] != _iterations) {
      throw const FormatException(
        'The selected file uses an unsupported backup format.',
      );
    }

    final salt = base64Decode(envelope['salt'] as String);
    final nonce = base64Decode(envelope['nonce'] as String);
    final ciphertext = base64Decode(envelope['ciphertext'] as String);
    final mac = base64Decode(envelope['mac'] as String);
    if (salt.length != 16 ||
        nonce.length != 12 ||
        ciphertext.isEmpty ||
        mac.length != 16) {
      throw const FormatException('The encrypted backup data is invalid.');
    }

    final key = await _deriveKey(password, salt);
    late final List<int> compressed;
    try {
      compressed = await AesGcm.with256bits().decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
        aad: utf8.encode(_aad),
      );
    } on SecretBoxAuthenticationError {
      throw const DataTransferException(
        'The password is incorrect or the backup file is damaged.',
      );
    }

    final plainBytes = const GZipDecoder().decodeBytes(
      compressed,
      verify: true,
      maxOutputSize: _maxPayloadBytes,
    );
    final decodedPayload = jsonDecode(utf8.decode(plainBytes));
    if (decodedPayload is! Map) {
      throw const FormatException('The decrypted backup data is invalid.');
    }
    final payload = Map<String, dynamic>.from(decodedPayload);
    if (payload['format'] != fileFormat ||
        payload['backupVersion'] != backupVersion ||
        payload['kind'] != expectedKind.name ||
        payload['data'] is! Map) {
      throw const FormatException(
        'The backup is incompatible with the selected import option.',
      );
    }

    final data = Map<String, dynamic>.from(payload['data'] as Map);
    if (expectedKind == DataTransferKind.allData) {
      final backup = data;
      if (backup['format'] != 'bizniz_tracker_backup' ||
          backup['formatVersion'] != LocalBackupService.formatVersion ||
          !backup.containsKey('databaseSnapshot')) {
        throw const FormatException(
          'The full backup is incomplete or incompatible.',
        );
      }
      backupService.validateBackup(backup);
      return PreparedDataTransfer(
        kind: expectedKind,
        payload: backup,
        summaryLines: _fullBackupSummary(backup),
      );
    }

    final products = _decodeProducts(data);
    final existing = await database.getProducts();
    final conflicts = _countProductConflicts(products, existing);
    return PreparedDataTransfer(
      kind: expectedKind,
      payload: data,
      products: products,
      summaryLines: [
        'Products in catalog: ${products.length}',
        'Products matching this store: $conflicts',
      ],
      existingProductConflicts: conflicts,
    );
  }

  Future<({int added, int updated, int skipped})> importProducts(
    PreparedDataTransfer prepared, {
    required bool updateExisting,
  }) {
    if (prepared.kind != DataTransferKind.productsOnly) {
      throw const FormatException(
        'The selected backup does not contain a product catalog.',
      );
    }
    return database.importCatalogProducts(
      prepared.products,
      updateExisting: updateExisting,
    );
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  void _validateExportPassword(String password) {
    if (password.length < minimumPasswordLength) {
      throw const DataTransferException(
        'Use a backup password with at least 12 characters.',
      );
    }
  }

  Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Map<String, Object?> _productToCatalogMap(ProductModel product) => {
    'id': product.id,
    'name': product.name,
    'category': product.category,
    'costPrice': product.costPrice,
    'sellingPrice': product.sellingPrice,
    'minStock': product.minStock,
    'barcode': product.barcode,
  };

  List<ProductModel> _decodeProducts(Map<String, dynamic> data) {
    final rawProducts = data['products'];
    if (data.keys.length != 1 || rawProducts is! List) {
      throw const FormatException(
        'The product catalog data is missing or invalid.',
      );
    }
    final products = <ProductModel>[];
    final seenIds = <String>{};
    final seenBarcodes = <String>{};
    const fields = {
      'id',
      'name',
      'category',
      'costPrice',
      'sellingPrice',
      'minStock',
      'barcode',
    };
    for (final rawProduct in rawProducts) {
      if (rawProduct is! Map) {
        throw const FormatException('A product in the catalog is invalid.');
      }
      final record = Map<String, dynamic>.from(rawProduct);
      if (record.keys.any((field) => !fields.contains(field)) ||
          !record.keys.toSet().containsAll({
            'id',
            'name',
            'category',
            'costPrice',
            'sellingPrice',
          })) {
        throw const FormatException(
          'A product in the catalog has an unsupported structure.',
        );
      }
      final id = record['id'];
      final name = record['name'];
      final category = record['category'];
      final costPrice = record['costPrice'];
      final sellingPrice = record['sellingPrice'];
      final minStock = record['minStock'] ?? 0;
      final barcode = record['barcode'] ?? '';
      if (id is! String ||
          id.trim().isEmpty ||
          name is! String ||
          name.trim().isEmpty ||
          category is! String ||
          costPrice is! num ||
          !costPrice.isFinite ||
          sellingPrice is! num ||
          !sellingPrice.isFinite ||
          minStock is! int ||
          minStock < 0 ||
          barcode is! String) {
        throw const FormatException(
          'A product in the catalog contains invalid values.',
        );
      }
      final normalizedBarcode = barcode.trim().toLowerCase();
      if (!seenIds.add(id) ||
          (normalizedBarcode.isNotEmpty &&
              !seenBarcodes.add(normalizedBarcode))) {
        throw const FormatException(
          'The product catalog contains duplicate product identifiers.',
        );
      }
      products.add(
        ProductModel(
          id: id,
          name: name,
          quantity: 0,
          costPrice: costPrice.toDouble(),
          sellingPrice: sellingPrice.toDouble(),
          category: category,
          minStock: minStock,
          barcode: barcode,
        ),
      );
    }
    return products;
  }

  int _countProductConflicts(
    List<ProductModel> incoming,
    List<ProductModel> existing,
  ) {
    final ids = existing.map((product) => product.id).toSet();
    final barcodes = existing
        .map((product) => product.barcode.trim().toLowerCase())
        .where((barcode) => barcode.isNotEmpty)
        .toSet();
    return incoming.where((product) {
      final barcode = product.barcode.trim().toLowerCase();
      return ids.contains(product.id) ||
          (barcode.isNotEmpty && barcodes.contains(barcode));
    }).length;
  }

  List<String> _fullBackupSummary(Map<String, dynamic> backup) {
    final boxes = Map<String, dynamic>.from(backup['boxes'] as Map);
    final tables = Map<String, dynamic>.from(
      (backup['databaseSnapshot'] as Map)['tables'] as Map,
    );
    int rows(String table) => (tables[table] as List).length;
    int boxRows(String name) => (boxes[name] as List? ?? const []).length;

    return [
      'Products: ${rows('products')}',
      'Sales transactions: ${rows('sales_transactions')}',
      'Expenses: ${boxRows(ExpenseService.recordsBoxName)}',
      'Customers: ${boxRows(CreditTrackingService.customersBoxName)}',
      'Customer credit records: ${boxRows(CreditTrackingService.creditsBoxName)}',
      'Expiration records: ${boxRows(ExpirationService.recordsBoxName)}',
    ];
  }
}
