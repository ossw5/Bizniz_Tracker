import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:hive/hive.dart';

import '../../customer_credit_and_debit_tracking/services/credit_tracking_service.dart';
import '../../expense_tracking/services/expense_service.dart';
import '../../product_and_inventory_management/services/expiration_service.dart';
import '../../products/domain/product.dart';
import '../../sales/domain/sale.dart';
import 'activity_log_service.dart';
import 'settings_service.dart';

class LocalBackupService {
  static const formatVersion = 1;
  static const filePrefix = 'bizniz_tracker_backup';
  static const _dynamicBoxNames = [
    SettingsService.boxName,
    ActivityLogService.boxName,
    ExpenseService.recordsBoxName,
    ExpenseService.correctionsBoxName,
    CreditTrackingService.customersBoxName,
    CreditTrackingService.creditsBoxName,
    CreditTrackingService.paymentsBoxName,
    CreditTrackingService.correctionsBoxName,
    ExpirationService.recordsBoxName,
    ExpirationService.historyBoxName,
  ];

  const LocalBackupService();

  Future<String?> exportBackup() async {
    await _openAllBoxes();
    final payload = await createBackup();
    final now = DateTime.now();
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
    );
    return FileSaver.instance.saveAs(
      name: '${filePrefix}_${_timestamp(now)}',
      bytes: bytes,
      fileExtension: 'json',
      mimeType: MimeType.json,
    );
  }

  Future<Map<String, Object?>> createBackup() async {
    await _openAllBoxes();
    final dynamicBoxes = <String, Object?>{};
    for (final name in _dynamicBoxNames) {
      final box = await _openDynamicBox(name);
      dynamicBoxes[name] = [
        for (final key in box.keys)
          {'key': _jsonSafe(key), 'value': _jsonSafe(box.get(key))},
      ];
    }

    final productsBox = Hive.box<ProductModel>('products_box');
    final salesBox = Hive.box<Sale>('sales_box');
    return {
      'format': 'bizniz_tracker_backup',
      'formatVersion': formatVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'boxes': {
        ...dynamicBoxes,
        'products_box': [
          for (final key in productsBox.keys)
            {
              'key': _jsonSafe(key),
              'value': _productToMap(productsBox.get(key as dynamic)!),
            },
        ],
        'sales_box': [
          for (final key in salesBox.keys)
            {
              'key': _jsonSafe(key),
              'value': _saleToMap(salesBox.get(key as dynamic)!),
            },
        ],
        'app_settings_box': [
          for (final key in Hive.box<bool>('app_settings_box').keys)
            {
              'key': _jsonSafe(key),
              'value': _jsonSafe(
                Hive.box<bool>('app_settings_box').get(key as dynamic),
              ),
            },
        ],
      },
    };
  }

  Future<Map<String, dynamic>?> pickAndValidateBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (result.isEmpty) return null;
    final bytes = await result.single.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('The selected backup file is empty.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException(
        'The selected file is not a Bizniz Tracker backup.',
      );
    }
    final backup = Map<String, dynamic>.from(decoded);
    validateBackup(backup);
    return backup;
  }

  void validateBackup(Map<String, dynamic> backup) {
    if (backup['format'] != 'bizniz_tracker_backup' ||
        backup['formatVersion'] != formatVersion) {
      throw const FormatException(
        'This is not a supported Bizniz Tracker backup file.',
      );
    }
    final rawBoxes = backup['boxes'];
    if (rawBoxes is! Map) {
      throw const FormatException(
        'The backup does not contain a data section.',
      );
    }
    final boxes = Map<String, dynamic>.from(rawBoxes);
    final knownNames = {
      'products_box',
      'sales_box',
      'app_settings_box',
      ..._dynamicBoxNames,
    };
    if (boxes.keys.any((name) => !knownNames.contains(name))) {
      throw const FormatException(
        'The backup contains unsupported data sections.',
      );
    }
    for (final name in knownNames) {
      final records = boxes[name];
      if (records is! List) {
        throw FormatException(
          'The $name backup section is missing or invalid.',
        );
      }
      for (final record in records) {
        if (record is! Map ||
            !record.containsKey('key') ||
            !record.containsKey('value')) {
          throw FormatException('A record in $name is invalid.');
        }
        _decodeJson(record['key']);
        _decodeJson(record['value']);
      }
    }
  }

  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    validateBackup(backup);
    final boxes = Map<String, dynamic>.from(backup['boxes'] as Map);
    final knownNames = {
      'products_box',
      'sales_box',
      'app_settings_box',
      ..._dynamicBoxNames,
    };
    await _openAllBoxes();
    final rollback = <String, List<MapEntry<dynamic, dynamic>>>{};
    for (final name in knownNames) {
      rollback[name] = await _readEntries(name);
    }
    try {
      for (final name in knownNames) {
        await _writeEntries(name, boxes[name] as List? ?? const []);
      }
    } catch (error) {
      final rollbackErrors = <String>[];
      for (final entry in rollback.entries) {
        try {
          await _replaceEntries(entry.key, entry.value);
        } catch (rollbackError) {
          rollbackErrors.add('${entry.key}: $rollbackError');
        }
      }
      if (rollbackErrors.isNotEmpty) {
        throw StateError(
          'Restore failed ($error), and some previous data could not be restored: '
          '${rollbackErrors.join('; ')}',
        );
      }
      rethrow;
    }
  }

  Future<List<MapEntry<dynamic, dynamic>>> _readEntries(String name) async {
    if (name == 'products_box') {
      final box = Hive.box<ProductModel>('products_box');
      return [
        for (final key in box.keys) MapEntry(key, box.get(key as dynamic)),
      ];
    }
    if (name == 'sales_box') {
      final box = Hive.box<Sale>('sales_box');
      return [
        for (final key in box.keys) MapEntry(key, box.get(key as dynamic)),
      ];
    }
    if (name == 'app_settings_box') {
      final box = Hive.box<bool>('app_settings_box');
      return [
        for (final key in box.keys) MapEntry(key, box.get(key as dynamic)),
      ];
    }
    final box = await _openDynamicBox(name);
    return [for (final key in box.keys) MapEntry(key, box.get(key))];
  }

  Future<void> _writeEntries(String name, List records) async {
    final entries = <MapEntry<dynamic, dynamic>>[];
    for (final record in records) {
      if (record is! Map) {
        throw FormatException('A record in $name is invalid.');
      }
      final key = _decodeJson(record['key']);
      final rawValue = record['value'];
      final value = switch (name) {
        'products_box' => _productFromMap(rawValue as Map),
        'sales_box' => _saleFromMap(rawValue as Map),
        _ => _decodeJson(rawValue),
      };
      if (name == 'app_settings_box' && value is! bool) {
        throw const FormatException('Application seed settings are invalid.');
      }
      entries.add(MapEntry(key, value));
    }
    await _replaceEntries(name, entries);
  }

  Future<void> _replaceEntries(
    String name,
    List<MapEntry<dynamic, dynamic>> entries,
  ) async {
    if (name == 'products_box') {
      final box = Hive.box<ProductModel>('products_box');
      await box.clear();
      for (final entry in entries) {
        await box.put(entry.key as dynamic, entry.value as ProductModel);
      }
      return;
    }
    if (name == 'sales_box') {
      final box = Hive.box<Sale>('sales_box');
      await box.clear();
      for (final entry in entries) {
        await box.put(entry.key as dynamic, entry.value as Sale);
      }
      return;
    }
    if (name == 'app_settings_box') {
      final box = Hive.box<bool>('app_settings_box');
      await box.clear();
      for (final entry in entries) {
        await box.put(entry.key as dynamic, entry.value as bool);
      }
      return;
    }
    final box = await _openDynamicBox(name);
    await box.clear();
    for (final entry in entries) {
      await box.put(entry.key, entry.value);
    }
  }

  Future<void> _openAllBoxes() async {
    for (final name in _dynamicBoxNames) {
      await _openDynamicBox(name);
    }
    if (!Hive.isBoxOpen('products_box')) {
      await Hive.openBox<ProductModel>('products_box');
    }
    if (!Hive.isBoxOpen('sales_box')) await Hive.openBox<Sale>('sales_box');
    if (!Hive.isBoxOpen('app_settings_box')) {
      await Hive.openBox<bool>('app_settings_box');
    }
  }

  Future<Box<dynamic>> _openDynamicBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<dynamic>(name);
    return Hive.openBox<dynamic>(name);
  }

  Map<String, Object?> _productToMap(ProductModel product) => {
    'id': product.id,
    'name': product.name,
    'quantity': product.quantity,
    'costPrice': product.costPrice,
    'sellingPrice': product.sellingPrice,
    'category': product.category,
    'minStock': product.minStock,
    'barcode': product.barcode,
  };

  ProductModel _productFromMap(Map map) => ProductModel(
    id: map['id'] as String,
    name: map['name'] as String,
    quantity: map['quantity'] as int,
    costPrice: (map['costPrice'] as num).toDouble(),
    sellingPrice: (map['sellingPrice'] as num).toDouble(),
    category: map['category'] as String? ?? '',
    minStock: map['minStock'] as int? ?? 0,
    barcode: map['barcode'] as String? ?? '',
  );

  Map<String, Object?> _saleToMap(Sale sale) => {
    'id': sale.id,
    'productId': sale.productId,
    'quantitySold': sale.quantitySold,
    'sellingPrice': sale.sellingPrice,
    'saleDate': sale.saleDate.toIso8601String(),
    'totalRevenue': sale.totalRevenue,
    'transactionId': sale.transactionId,
    'receiptNumber': sale.receiptNumber,
    'productNameAtSale': sale.productNameAtSale,
    'subtotal': sale.subtotal,
    'discount': sale.discount,
    'transactionTotal': sale.transactionTotal,
    'amountPaid': sale.amountPaid,
    'changeDue': sale.changeDue,
    'paymentMethod': sale.paymentMethod,
    'productCostAtSale': sale.productCostAtSale,
  };

  Sale _saleFromMap(Map map) => Sale(
    id: map['id'] as String,
    productId: map['productId'] as String,
    quantitySold: map['quantitySold'] as int,
    sellingPrice: (map['sellingPrice'] as num).toDouble(),
    saleDate: DateTime.parse(map['saleDate'] as String),
    totalRevenue: (map['totalRevenue'] as num).toDouble(),
    transactionId: map['transactionId'] as String?,
    receiptNumber: map['receiptNumber'] as String?,
    productNameAtSale: map['productNameAtSale'] as String?,
    subtotal: (map['subtotal'] as num?)?.toDouble(),
    discount: (map['discount'] as num?)?.toDouble(),
    transactionTotal: (map['transactionTotal'] as num?)?.toDouble(),
    amountPaid: (map['amountPaid'] as num?)?.toDouble(),
    changeDue: (map['changeDue'] as num?)?.toDouble(),
    paymentMethod: map['paymentMethod'] as String?,
    productCostAtSale: (map['productCostAtSale'] as num?)?.toDouble(),
  );

  Object? _jsonSafe(Object? value) {
    if (value is DateTime) {
      return {'__bizniz_datetime__': value.toIso8601String()};
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _jsonSafe(entry.value),
      };
    }
    if (value is Iterable) return value.map(_jsonSafe).toList();
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    throw FormatException('Unsupported backup value: ${value.runtimeType}.');
  }

  Object? _decodeJson(Object? value) {
    if (value is Map) {
      if (value.length == 1 && value['__bizniz_datetime__'] is String) {
        final date = DateTime.tryParse(value['__bizniz_datetime__'] as String);
        if (date == null) {
          throw const FormatException('Invalid date in backup.');
        }
        return date;
      }
      return {
        for (final entry in value.entries)
          entry.key.toString(): _decodeJson(entry.value),
      };
    }
    if (value is List) return value.map(_decodeJson).toList();
    return value;
  }

  String _timestamp(DateTime value) =>
      '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}_'
      '${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}';
}
