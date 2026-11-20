import 'dart:convert';
import 'dart:io';

import 'package:bizniz_tracker/core/app_database.dart';
import 'package:bizniz_tracker/features/expense_tracking/services/expense_service.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/settings/models/app_settings.dart';
import 'package:bizniz_tracker/features/settings/screens/data_backup_transfer_screen.dart';
import 'package:bizniz_tracker/features/settings/services/data_transfer_service.dart';
import 'package:bizniz_tracker/features/settings/services/local_backup_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;
  late AppDatabase sourceDatabase;
  late AppDatabase targetDatabase;
  late DataTransferService sourceTransfer;
  late DataTransferService targetTransfer;
  late LocalBackupService targetBackupService;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    hiveDirectory = await Directory.systemTemp.createTemp(
      'data_backup_transfer_',
    );
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(SaleAdapter());
  });

  setUp(() async {
    sourceDatabase = AppDatabase(executor: NativeDatabase.memory());
    targetDatabase = AppDatabase(executor: NativeDatabase.memory());
    targetBackupService = LocalBackupService(database: targetDatabase);
    sourceTransfer = DataTransferService(
      database: sourceDatabase,
      backupService: LocalBackupService(database: sourceDatabase),
    );
    targetTransfer = DataTransferService(
      database: targetDatabase,
      backupService: targetBackupService,
    );
    final expenses = Hive.isBoxOpen(ExpenseService.recordsBoxName)
        ? Hive.box<dynamic>(ExpenseService.recordsBoxName)
        : await Hive.openBox<dynamic>(ExpenseService.recordsBoxName);
    await expenses.clear();
  });

  tearDown(() async {
    await sourceDatabase.close();
    await targetDatabase.close();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'product-only encrypted import preserves stock and financial records',
    () async {
      const password = 'a sufficiently long backup password';
      await sourceDatabase.putProduct(
        ProductModel(
          id: 'remote-bread',
          name: 'Wholegrain Bread',
          quantity: 75,
          costPrice: 3,
          sellingPrice: 6,
          category: 'Bakery',
          minStock: 5,
          barcode: 'bread-001',
        ),
      );
      await sourceDatabase.putProduct(
        ProductModel(
          id: 'remote-milk',
          name: 'Milk',
          quantity: 24,
          costPrice: 2,
          sellingPrice: 4,
          category: 'Dairy',
          barcode: 'milk-001',
        ),
      );

      await targetDatabase.putProduct(
        ProductModel(
          id: 'local-bread',
          name: 'Local Bread',
          quantity: 23,
          costPrice: 2.5,
          sellingPrice: 5,
          category: 'Old category',
          minStock: 3,
          barcode: 'bread-001',
        ),
      );
      await targetDatabase.putSale(
        Sale(
          id: 'local-sale-item',
          transactionId: 'local-transaction',
          productId: 'local-bread',
          productNameAtSale: 'Local Bread',
          quantitySold: 1,
          sellingPrice: 5,
          saleDate: DateTime(2026, 11, 8),
          totalRevenue: 5,
        ),
      );
      final expenses = Hive.box<dynamic>(ExpenseService.recordsBoxName);
      await expenses.put('expense-1', {'description': 'Keep this expense'});

      final encrypted = await sourceTransfer.exportProductsOnly(password);
      expect(utf8.decode(encrypted), isNot(contains('Wholegrain Bread')));
      final prepared = await targetTransfer.decryptAndValidate(
        encrypted,
        password: password,
        expectedKind: DataTransferKind.productsOnly,
      );
      expect(prepared.products, hasLength(2));
      expect(prepared.existingProductConflicts, 1);
      expect(
        prepared.products.every((product) => product.quantity == 0),
        isTrue,
      );
      for (final record in prepared.payload['products'] as List) {
        expect(
          Map<String, dynamic>.from(record as Map).containsKey('quantity'),
          isFalse,
        );
      }

      final skipped = await targetTransfer.importProducts(
        prepared,
        updateExisting: false,
      );
      expect(skipped.added, 1);
      expect(skipped.skipped, 1);
      expect((await targetDatabase.getProduct('local-bread'))?.quantity, 23);
      expect((await targetDatabase.getProduct('remote-milk'))?.quantity, 0);

      final updated = await targetTransfer.importProducts(
        prepared,
        updateExisting: true,
      );
      expect(updated.updated, 2);
      final bread = await targetDatabase.getProduct('local-bread');
      expect(bread?.name, 'Wholegrain Bread');
      expect(bread?.sellingPrice, 6);
      expect(bread?.quantity, 23);
      expect(bread?.minStock, 3);
      expect(await targetDatabase.getSales(), hasLength(1));
      expect(expenses.get('expense-1'), {'description': 'Keep this expense'});
    },
  );

  test('wrong passwords and corrupted encrypted data are rejected', () async {
    const password = 'another long backup password';
    await sourceDatabase.putProduct(
      ProductModel(
        id: 'remote-product',
        name: 'Private product name',
        quantity: 4,
        costPrice: 2,
        sellingPrice: 3,
      ),
    );
    await targetDatabase.putProduct(
      ProductModel(
        id: 'existing',
        name: 'Existing product',
        quantity: 12,
        costPrice: 1,
        sellingPrice: 2,
      ),
    );
    final encrypted = await sourceTransfer.exportProductsOnly(password);

    await expectLater(
      targetTransfer.decryptAndValidate(
        encrypted,
        password: 'incorrect password',
        expectedKind: DataTransferKind.productsOnly,
      ),
      throwsA(isA<DataTransferException>()),
    );
    await expectLater(
      targetTransfer.decryptAndValidate(
        utf8.encode('{}'),
        password: password,
        expectedKind: DataTransferKind.productsOnly,
      ),
      throwsFormatException,
    );

    final envelope = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(encrypted)) as Map,
    );
    final ciphertext = base64Decode(envelope['ciphertext'] as String);
    ciphertext[0] ^= 1;
    envelope['ciphertext'] = base64Encode(ciphertext);
    await expectLater(
      targetTransfer.decryptAndValidate(
        utf8.encode(jsonEncode(envelope)),
        password: password,
        expectedKind: DataTransferKind.productsOnly,
      ),
      throwsA(isA<DataTransferException>()),
    );
    expect(
      (await targetDatabase.getProducts()).single.name,
      'Existing product',
    );
  });

  test(
    'full restore recovers database relationships and rolls back failed imports',
    () async {
      final product = ProductModel(
        id: 'bread',
        name: 'Bread',
        quantity: 8,
        costPrice: 10,
        sellingPrice: 15,
        category: 'Bakery',
      );
      await targetDatabase.putProduct(product);
      await targetDatabase.putSale(
        Sale(
          id: 'sale-item-1',
          transactionId: 'sale-1',
          productId: product.id,
          productNameAtSale: product.name,
          quantitySold: 2,
          sellingPrice: 15,
          saleDate: DateTime(2026, 11, 8),
          totalRevenue: 30,
        ),
      );
      await targetDatabase.customStatement(
        'INSERT INTO customers '
        '(id, full_name, phone, address, notes, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        ['customer-1', 'A. Customer', '', '', '', '2026-11-08T00:00:00'],
      );
      await targetDatabase.customStatement(
        'INSERT INTO credit_accounts '
        '(id, customer_id, sale_id, item_name, quantity, unit_price_minor, '
        'original_amount_minor, outstanding_balance_minor, credit_date, due_date, '
        'customer_name_snapshot) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'credit-1',
          'customer-1',
          'sale-1',
          'Bread',
          2,
          1500,
          3000,
          2000,
          '2026-11-08',
          '2026-12-08',
          'A. Customer',
        ],
      );
      await targetDatabase.customStatement(
        'INSERT INTO credit_payments '
        '(id, credit_id, customer_id, amount_minor, payment_method, paid_at, '
        'customer_name_snapshot) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          'payment-1',
          'credit-1',
          'customer-1',
          1000,
          'Cash',
          '2026-11-09',
          'A. Customer',
        ],
      );
      await targetDatabase.saveStoreProfile(
        const StoreProfile(storeName: 'Original Store'),
      );
      final expenses = Hive.box<dynamic>(ExpenseService.recordsBoxName);
      await expenses.put('expense-1', {
        'description': 'Original expense',
        'amount': 12.5,
      });

      const password = 'full restore backup password';
      final encryptedBackup = await targetTransfer.exportAllData(password);
      final prepared = await targetTransfer.decryptAndValidate(
        encryptedBackup,
        password: password,
        expectedKind: DataTransferKind.allData,
      );
      expect(prepared.summaryLines, contains('Sales transactions: 1'));
      final backup = prepared.payload;
      await targetDatabase.putProduct(product.copyWith(quantity: 1));
      await targetDatabase.saveStoreProfile(
        const StoreProfile(storeName: 'Current Store'),
      );
      await expenses.put('expense-1', {'description': 'Current expense'});

      final invalidBackup = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(backup)) as Map,
      );
      final databaseSnapshot = Map<String, dynamic>.from(
        invalidBackup['databaseSnapshot'] as Map,
      );
      final tables = Map<String, dynamic>.from(
        databaseSnapshot['tables'] as Map,
      );
      final payments = List<dynamic>.from(tables['credit_payments'] as List);
      final payment = Map<String, dynamic>.from(payments.single as Map)
        ..['credit_id'] = 'missing-credit';
      tables['credit_payments'] = [payment];
      databaseSnapshot['tables'] = tables;
      invalidBackup['databaseSnapshot'] = databaseSnapshot;

      await expectLater(
        targetBackupService.restoreBackup(invalidBackup),
        throwsA(anything),
      );
      expect((await targetDatabase.getProduct('bread'))?.quantity, 1);
      expect(
        (await targetDatabase.getStoreProfile())?.storeName,
        'Current Store',
      );
      expect(expenses.get('expense-1'), {'description': 'Current expense'});

      await targetBackupService.restoreBackup(backup);
      expect((await targetDatabase.getProduct('bread'))?.quantity, 8);
      expect((await targetDatabase.getSales()).single.transactionId, 'sale-1');
      expect(
        (await targetDatabase.getStoreProfile())?.storeName,
        'Original Store',
      );
      expect(
        (await targetDatabase
                .customSelect('SELECT * FROM credit_accounts')
                .get())
            .single
            .read<String>('customer_id'),
        'customer-1',
      );
      expect(
        (await targetDatabase
                .customSelect('SELECT * FROM credit_payments')
                .get())
            .single
            .read<String>('credit_id'),
        'credit-1',
      );
      expect(expenses.get('expense-1'), {
        'description': 'Original expense',
        'amount': 12.5,
      });
    },
  );

  testWidgets('Data Backup & Transfer screen shows both workflows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DataBackupTransferScreen(transferService: targetTransfer),
      ),
    );
    await tester.pump();

    expect(find.text('EXPORT DATA'), findsOneWidget);
    expect(find.text('IMPORT DATA'), findsOneWidget);
    expect(find.text('Export All Data'), findsOneWidget);
    expect(find.text('Import Products Only'), findsOneWidget);
  });

  testWidgets('failed import closes password dialog and reports the error', (
    tester,
  ) async {
    final previousPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _MemoryFilePickerPlatform(const <int>[
      123,
      125,
    ]);
    addTearDown(() => FilePickerPlatform.instance = previousPicker);

    await tester.pumpWidget(
      MaterialApp(
        home: DataBackupTransferScreen(transferService: targetTransfer),
      ),
    );
    await tester.tap(find.text('Import Products Only'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Unlock backup'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'test password');
    await tester.tap(find.text('Unlock'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Unlock backup'), findsNothing);
    expect(tester.takeException(), equals(null));
  });

  testWidgets('catalog import failure dismisses its confirmation cleanly', (
    tester,
  ) async {
    final failingTransfer = _FailingDataTransferService(
      database: targetDatabase,
      backupService: targetBackupService,
      prepared: PreparedDataTransfer(
        kind: DataTransferKind.productsOnly,
        payload: const {},
        products: [
          ProductModel(
            id: 'conflict-id',
            name: 'Incoming product',
            quantity: 0,
            costPrice: 1,
            sellingPrice: 2,
          ),
        ],
        summaryLines: const ['Products in catalog: 1'],
      ),
    );
    final previousPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _MemoryFilePickerPlatform(const [1]);
    addTearDown(() => FilePickerPlatform.instance = previousPicker);
    var importNotified = false;

    await tester.pumpWidget(
      MaterialApp(
        home: DataBackupTransferScreen(
          transferService: failingTransfer,
          onDataImported: () async {
            importNotified = true;
          },
        ),
      ),
    );
    await tester.tap(find.text('Import Products Only'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextFormField).first, 'test password');
    await tester.tap(find.text('Unlock'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Import product catalog?').evaluate().isNotEmpty) break;
    }

    expect(find.text('Import product catalog?'), findsOneWidget);
    await tester.tap(find.text('Update catalog fields'));
    await tester.pump();
    await tester.tap(find.text('Import Catalog'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import product catalog?'), findsNothing);
    expect(importNotified, isFalse);
    expect(tester.takeException(), equals(null));
  });
}

final class _MemoryFilePickerPlatform extends FilePickerPlatform {
  final List<int> _bytes;

  _MemoryFilePickerPlatform(this._bytes);

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => [_MemoryPlatformFile(_bytes)];
}

final class _MemoryPlatformFile extends PlatformFile {
  final List<int> _bytes;

  _MemoryPlatformFile(this._bytes);

  @override
  String get name => 'invalid.bztbackup';

  @override
  int? lengthSync() => _bytes.length;

  @override
  Stream<Uint8List> readAsByteStream() async* {
    yield Uint8List.fromList(_bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FailingDataTransferService extends DataTransferService {
  final PreparedDataTransfer prepared;

  _FailingDataTransferService({
    required super.database,
    required super.backupService,
    required this.prepared,
  });

  @override
  Future<PreparedDataTransfer> decryptAndValidate(
    List<int> fileBytes, {
    required String password,
    required DataTransferKind expectedKind,
  }) async => prepared;

  @override
  Future<({int added, int updated, int skipped})> importProducts(
    PreparedDataTransfer prepared, {
    required bool updateExisting,
  }) async {
    throw StateError('Conflicting products');
  }
}
