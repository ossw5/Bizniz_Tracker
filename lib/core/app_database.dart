import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';

import '../features/products/domain/product.dart';
import '../features/sales/domain/sale.dart';
import '../features/settings/models/app_settings.dart';

class AppDatabase extends GeneratedDatabase {
  static const _backupTableOrder = [
    'products',
    'sales_transactions',
    'customers',
    'credit_accounts',
    'expiration_batches',
    'sale_items',
    'stock_movements',
    'credit_payments',
    'credit_balance_corrections',
    'expenses',
    'expense_corrections',
    'business_activity_log',
    'store_profile',
    'app_preferences',
    'migration_state',
  ];

  static const _backupTableColumns = <String, List<String>>{
    'products': [
      'id',
      'name',
      'quantity',
      'cost_price_minor',
      'selling_price_minor',
      'category',
      'min_stock',
      'barcode',
    ],
    'sales_transactions': [
      'id',
      'receipt_number',
      'sold_at',
      'subtotal_minor',
      'discount_minor',
      'total_minor',
      'amount_paid_minor',
      'change_due_minor',
      'payment_method',
    ],
    'customers': ['id', 'full_name', 'phone', 'address', 'notes', 'created_at'],
    'credit_accounts': [
      'id',
      'customer_id',
      'sale_id',
      'item_name',
      'quantity',
      'unit_price_minor',
      'original_amount_minor',
      'outstanding_balance_minor',
      'credit_date',
      'due_date',
      'customer_name_snapshot',
    ],
    'expiration_batches': [
      'id',
      'product_id',
      'batch_identifier',
      'initial_quantity',
      'remaining_quantity',
      'expiration_date',
      'created_at',
      'notes',
    ],
    'sale_items': [
      'id',
      'transaction_id',
      'product_id',
      'product_id_snapshot',
      'product_name_snapshot',
      'quantity',
      'unit_price_minor',
      'unit_cost_minor',
      'line_total_minor',
    ],
    'stock_movements': [
      'id',
      'batch_id',
      'product_id',
      'product_name_snapshot',
      'batch_identifier_snapshot',
      'movement_type',
      'previous_quantity',
      'updated_quantity',
      'movement_at',
      'expiration_date',
      'remarks',
    ],
    'credit_payments': [
      'id',
      'credit_id',
      'customer_id',
      'amount_minor',
      'payment_method',
      'paid_at',
      'customer_name_snapshot',
    ],
    'credit_balance_corrections': [
      'id',
      'credit_id',
      'original_balance_minor',
      'corrected_balance_minor',
      'reason',
      'details',
      'authorized_by',
      'changed_at',
      'customer_name_snapshot',
    ],
    'expenses': [
      'id',
      'category',
      'description',
      'amount_minor',
      'expense_date',
      'created_at',
    ],
    'expense_corrections': [
      'id',
      'expense_id',
      'action',
      'reason',
      'changed_at',
      'previous_record_json',
      'updated_record_json',
    ],
    'business_activity_log': ['id', 'description', 'category', 'occurred_at'],
    'store_profile': [
      'singleton_id',
      'store_name',
      'owner_name',
      'address',
      'contact_number',
    ],
    'app_preferences': [
      'singleton_id',
      'theme_mode',
      'currency_code',
      'date_pattern',
      'low_stock',
      'expiration',
      'sales',
      'expense_reminders',
    ],
    'migration_state': ['key', 'value'],
  };

  AppDatabase({QueryExecutor? executor})
    : super(
        executor ??
            driftDatabase(
              name: 'bizniz_tracker',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      for (final statement in _schema) {
        await customStatement(statement);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<List<ProductModel>> getProducts() async {
    final rows = await customSelect('SELECT * FROM products').get();
    return rows
        .map(
          (row) => ProductModel(
            id: row.read<String>('id'),
            name: row.read<String>('name'),
            quantity: row.read<int>('quantity'),
            costPrice: row.read<int>('cost_price_minor') / 100,
            sellingPrice: row.read<int>('selling_price_minor') / 100,
            category: row.read<String>('category'),
            minStock: row.read<int>('min_stock'),
            barcode: row.read<String>('barcode'),
          ),
        )
        .toList(growable: false);
  }

  Future<ProductModel?> getProduct(String id) async {
    final rows = await customSelect(
      'SELECT * FROM products WHERE id = ?',
      variables: [Variable.withString(id)],
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.single;
    return ProductModel(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      quantity: row.read<int>('quantity'),
      costPrice: row.read<int>('cost_price_minor') / 100,
      sellingPrice: row.read<int>('selling_price_minor') / 100,
      category: row.read<String>('category'),
      minStock: row.read<int>('min_stock'),
      barcode: row.read<String>('barcode'),
    );
  }

  Future<void> putProduct(ProductModel product) async {
    await customStatement(
      '''
      INSERT INTO products
        (id, name, quantity, cost_price_minor, selling_price_minor, category, min_stock, barcode)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        quantity = excluded.quantity,
        cost_price_minor = excluded.cost_price_minor,
        selling_price_minor = excluded.selling_price_minor,
        category = excluded.category,
        min_stock = excluded.min_stock,
        barcode = excluded.barcode
      ''',
      [
        product.id,
        product.name,
        product.quantity,
        _minorUnits(product.costPrice),
        _minorUnits(product.sellingPrice),
        product.category,
        product.minStock,
        product.barcode,
      ],
    );
  }

  Future<void> deleteProduct(String id) async {
    await customStatement('DELETE FROM products WHERE id = ?', [id]);
  }

  Future<StoreProfile?> getStoreProfile() async {
    final rows = await customSelect(
      'SELECT * FROM store_profile WHERE singleton_id = 1',
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.single;
    return StoreProfile(
      storeName: row.read<String>('store_name'),
      ownerName: row.read<String>('owner_name'),
      address: row.read<String>('address'),
      contactNumber: row.read<String>('contact_number'),
    );
  }

  Future<void> saveStoreProfile(StoreProfile profile) async {
    await customStatement(
      '''
      INSERT INTO store_profile
        (singleton_id, store_name, owner_name, address, contact_number)
      VALUES (1, ?, ?, ?, ?)
      ON CONFLICT(singleton_id) DO UPDATE SET
        store_name = excluded.store_name,
        owner_name = excluded.owner_name,
        address = excluded.address,
        contact_number = excluded.contact_number
      ''',
      [
        profile.storeName,
        profile.ownerName,
        profile.address,
        profile.contactNumber,
      ],
    );
  }

  Future<AppPreferences?> getAppPreferences() async {
    final rows = await customSelect(
      'SELECT * FROM app_preferences WHERE singleton_id = 1',
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.single;
    return AppPreferences(
      themeMode: ThemeMode.values.firstWhere(
        (theme) => theme.name == row.read<String>('theme_mode'),
        orElse: () => ThemeMode.light,
      ),
      currencyCode: row.read<String>('currency_code'),
      datePattern: row.read<String>('date_pattern'),
      notifications: NotificationPreferences(
        lowStock: row.read<int>('low_stock') != 0,
        expiration: row.read<int>('expiration') != 0,
        sales: row.read<int>('sales') != 0,
        expenseReminders: row.read<int>('expense_reminders') != 0,
      ),
    );
  }

  Future<void> saveAppPreferences(AppPreferences preferences) async {
    await customStatement(
      '''
      INSERT INTO app_preferences
        (singleton_id, theme_mode, currency_code, date_pattern, low_stock,
         expiration, sales, expense_reminders)
      VALUES (1, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(singleton_id) DO UPDATE SET
        theme_mode = excluded.theme_mode,
        currency_code = excluded.currency_code,
        date_pattern = excluded.date_pattern,
        low_stock = excluded.low_stock,
        expiration = excluded.expiration,
        sales = excluded.sales,
        expense_reminders = excluded.expense_reminders
      ''',
      [
        preferences.themeMode.name,
        preferences.currencyCode,
        preferences.datePattern,
        preferences.notifications.lowStock ? 1 : 0,
        preferences.notifications.expiration ? 1 : 0,
        preferences.notifications.sales ? 1 : 0,
        preferences.notifications.expenseReminders ? 1 : 0,
      ],
    );
  }

  Future<List<Sale>> getSales() async {
    final rows = await customSelect('''
      SELECT sale_items.*, sales_transactions.sold_at,
        sales_transactions.receipt_number AS txn_receipt_number,
        sales_transactions.subtotal_minor AS txn_subtotal_minor,
        sales_transactions.discount_minor AS txn_discount_minor,
        sales_transactions.total_minor AS txn_total_minor,
        sales_transactions.amount_paid_minor AS txn_amount_paid_minor,
        sales_transactions.change_due_minor AS txn_change_due_minor,
        sales_transactions.payment_method AS txn_payment_method
      FROM sale_items
      JOIN sales_transactions ON sales_transactions.id = sale_items.transaction_id
      ORDER BY sales_transactions.sold_at
      ''').get();
    return rows
        .map(
          (row) => Sale(
            id: row.read<String>('id'),
            transactionId: row.read<String>('transaction_id'),
            receiptNumber: row.read<String>('txn_receipt_number'),
            productId:
                row.read<String?>('product_id') ??
                row.read<String>('product_id_snapshot'),
            productNameAtSale: row.read<String>('product_name_snapshot'),
            productCostAtSale: row.read<int?>('unit_cost_minor') == null
                ? null
                : row.read<int>('unit_cost_minor') / 100,
            quantitySold: row.read<int>('quantity'),
            sellingPrice: row.read<int>('unit_price_minor') / 100,
            saleDate: DateTime.parse(row.read<String>('sold_at')),
            totalRevenue: row.read<int>('line_total_minor') / 100,
            subtotal: row.read<int>('txn_subtotal_minor') / 100,
            discount: row.read<int>('txn_discount_minor') / 100,
            transactionTotal: row.read<int>('txn_total_minor') / 100,
            amountPaid: row.read<int>('txn_amount_paid_minor') / 100,
            changeDue: row.read<int>('txn_change_due_minor') / 100,
            paymentMethod: row.read<String>('txn_payment_method'),
          ),
        )
        .toList(growable: false);
  }

  Future<void> putSale(Sale sale) async {
    final transactionId = sale.transactionId ?? sale.id;
    await transaction(() async {
      final existing = await customSelect(
        'SELECT id FROM sales_transactions WHERE id = ?',
        variables: [Variable.withString(transactionId)],
      ).get();
      if (existing.isEmpty) {
        final total = sale.transactionTotal ?? sale.totalRevenue;
        await customStatement(
          '''
          INSERT INTO sales_transactions
            (id, receipt_number, sold_at, subtotal_minor, discount_minor, total_minor,
             amount_paid_minor, change_due_minor, payment_method)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            transactionId,
            sale.receiptNumber ?? transactionId,
            sale.saleDate.toIso8601String(),
            _minorUnits(sale.subtotal ?? sale.totalRevenue),
            _minorUnits(sale.discount ?? 0),
            _minorUnits(total),
            _minorUnits(sale.amountPaid ?? total),
            _minorUnits(sale.changeDue ?? 0),
            sale.paymentMethod ?? 'Recorded sale',
          ],
        );
      }
      await customStatement('''
        INSERT INTO sale_items
          (id, transaction_id, product_id, product_id_snapshot,
           product_name_snapshot, quantity,
           unit_price_minor, unit_cost_minor, line_total_minor)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          transaction_id = excluded.transaction_id,
          product_id = excluded.product_id,
          product_id_snapshot = excluded.product_id_snapshot,
          product_name_snapshot = excluded.product_name_snapshot,
          quantity = excluded.quantity,
          unit_price_minor = excluded.unit_price_minor,
          unit_cost_minor = excluded.unit_cost_minor,
          line_total_minor = excluded.line_total_minor
        ''', await _saleItemValues(sale, transactionId));
    });
  }

  Future<List<Object?>> _saleItemValues(Sale sale, String transactionId) async {
    final product = sale.productId.isEmpty
        ? const <QueryRow>[]
        : await customSelect(
            'SELECT id, name, cost_price_minor FROM products WHERE id = ?',
            variables: [Variable.withString(sale.productId)],
          ).get();
    final storedProduct = product.isEmpty ? null : product.single;
    return [
      sale.id,
      transactionId,
      storedProduct?.read<String>('id'),
      sale.productId,
      sale.productNameAtSale ??
          (storedProduct == null ? '' : storedProduct.read<String>('name')),
      sale.quantitySold,
      _minorUnits(sale.sellingPrice),
      sale.productCostAtSale == null
          ? (storedProduct?.read<int>('cost_price_minor'))
          : _minorUnits(sale.productCostAtSale!),
      _minorUnits(sale.totalRevenue),
    ];
  }

  Future<void> deleteSale(String id) async {
    await transaction(() async {
      final rows = await customSelect(
        'SELECT transaction_id FROM sale_items WHERE id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (rows.isEmpty) return;
      final transactionId = rows.single.read<String>('transaction_id');
      await customStatement('DELETE FROM sale_items WHERE id = ?', [id]);
      await customStatement(
        'DELETE FROM sales_transactions WHERE id = ? AND NOT EXISTS '
        '(SELECT 1 FROM sale_items WHERE transaction_id = ?)',
        [transactionId, transactionId],
      );
    });
  }

  Future<void> importHiveInventory({
    required Iterable<ProductModel> products,
    required Iterable<Sale> sales,
  }) async {
    final productRecords = products.toList(growable: false);
    final saleRecords = sales.toList(growable: false);
    final imported = await transaction(() async {
      final previousImport = await customSelect(
        "SELECT value FROM migration_state WHERE key = 'hive_inventory_v1'",
      ).get();
      if (previousImport.isNotEmpty) return false;
      for (final product in productRecords) {
        await putProduct(product);
      }
      for (final sale in saleRecords) {
        await putSale(sale);
      }
      final migratedProducts = await customSelect(
        'SELECT COUNT(*) AS count FROM products',
      ).getSingle();
      final migratedSales = await customSelect(
        'SELECT COUNT(*) AS count FROM sale_items',
      ).getSingle();
      if (migratedProducts.read<int>('count') < productRecords.length ||
          migratedSales.read<int>('count') < saleRecords.length) {
        throw StateError('Hive inventory migration verification failed.');
      }
      await customStatement(
        "INSERT INTO migration_state (key, value) VALUES ('hive_inventory_v1', ?)",
        [DateTime.now().toUtc().toIso8601String()],
      );
      return true;
    });
    if (!imported) return;
  }

  Future<void> replaceInventory({
    required Iterable<ProductModel> products,
    required Iterable<Sale> sales,
  }) async {
    final productRecords = products.toList(growable: false);
    final saleRecords = sales.toList(growable: false);
    await transaction(() async {
      await customStatement('DELETE FROM sale_items');
      await customStatement('DELETE FROM sales_transactions');
      await customStatement('DELETE FROM products');
      for (final product in productRecords) {
        await putProduct(product);
      }
      for (final sale in saleRecords) {
        await putSale(sale);
      }
    });
  }

  Future<void> clearAllData() async {
    await transaction(() async {
      for (final table in _backupTableOrder.reversed) {
        await customStatement('DELETE FROM "$table"');
      }
    });
  }

  Future<void> clearApplicationConfiguration() async {
    await transaction(() async {
      await customStatement('DELETE FROM app_preferences');
      await customStatement('DELETE FROM store_profile');
    });
  }

  Future<Map<String, Object?>> exportDataSnapshot() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _backupTableOrder) {
      final rows = await customSelect('SELECT * FROM "$table"').get();
      tables[table] = [
        for (final row in rows) Map<String, Object?>.from(row.data),
      ];
    }
    return {'schemaVersion': schemaVersion, 'tables': tables};
  }

  void validateDataSnapshot(Object? snapshot) {
    if (snapshot is! Map ||
        snapshot['schemaVersion'] != schemaVersion ||
        snapshot['tables'] is! Map) {
      throw const FormatException(
        'The backup database section is invalid or incompatible.',
      );
    }
    final tables = Map<String, dynamic>.from(snapshot['tables'] as Map);
    if (tables.length != _backupTableOrder.length ||
        tables.keys.any((name) => !_backupTableColumns.containsKey(name))) {
      throw const FormatException(
        'The backup database tables are incomplete or unsupported.',
      );
    }
    for (final table in _backupTableOrder) {
      final rows = tables[table];
      if (rows is! List) {
        throw FormatException('The $table database section is invalid.');
      }
      for (final row in rows) {
        if (row is! Map) {
          throw FormatException(
            'A row in the $table database section is invalid.',
          );
        }
        final values = Map<String, dynamic>.from(row);
        final columns = _backupTableColumns[table]!;
        if (values.length != columns.length ||
            values.keys.any((column) => !columns.contains(column))) {
          throw FormatException(
            'A row in the $table database section has an unsupported shape.',
          );
        }
        for (final value in values.values) {
          if (value != null &&
              value is! String &&
              value is! int &&
              value is! double) {
            throw FormatException(
              'A row in the $table database section contains an invalid value.',
            );
          }
          if (value is double && !value.isFinite) {
            throw FormatException(
              'A row in the $table database section contains an invalid number.',
            );
          }
        }
      }
    }
  }

  Future<void> restoreDataSnapshot(Object? snapshot) async {
    validateDataSnapshot(snapshot);
    final tables = Map<String, dynamic>.from(
      (snapshot as Map)['tables'] as Map,
    );
    await transaction(() async {
      for (final table in _backupTableOrder.reversed) {
        await customStatement('DELETE FROM "$table"');
      }
      for (final table in _backupTableOrder) {
        final columns = _backupTableColumns[table]!;
        final quotedColumns = columns.map((column) => '"$column"').join(', ');
        final placeholders = List.filled(columns.length, '?').join(', ');
        final sql =
            'INSERT INTO "$table" ($quotedColumns) VALUES ($placeholders)';
        for (final row in tables[table] as List) {
          final values = Map<String, dynamic>.from(row as Map);
          await customStatement(sql, [
            for (final column in columns) values[column],
          ]);
        }
      }
    });
  }

  Future<({int added, int updated, int skipped})> importCatalogProducts(
    Iterable<ProductModel> incomingProducts, {
    required bool updateExisting,
  }) async {
    final products = incomingProducts.toList(growable: false);
    return transaction(() async {
      final rows = await customSelect('SELECT * FROM products').get();
      final existingById = <String, ProductModel>{};
      final existingByBarcode = <String, ProductModel>{};
      for (final product in rows.map(_productFromRow)) {
        existingById[product.id] = product;
        final barcode = _normalizedBarcode(product.barcode);
        if (barcode.isNotEmpty) {
          existingByBarcode.putIfAbsent(barcode, () => product);
        }
      }

      var added = 0;
      var updated = 0;
      var skipped = 0;
      for (final incoming in products) {
        final byId = existingById[incoming.id];
        final normalizedBarcode = _normalizedBarcode(incoming.barcode);
        final byBarcode = normalizedBarcode.isEmpty
            ? null
            : existingByBarcode[normalizedBarcode];
        if (updateExisting &&
            byId != null &&
            byBarcode != null &&
            byId.id != byBarcode.id) {
          throw StateError(
            'The catalog product conflicts with two existing products.',
          );
        }
        final existing = byId ?? byBarcode;
        if (existing != null) {
          if (!updateExisting) {
            skipped++;
            continue;
          }
          final updatedProduct = incoming.copyWith(
            id: existing.id,
            quantity: existing.quantity,
            minStock: existing.minStock,
          );
          await putProduct(updatedProduct);
          existingById[updatedProduct.id] = updatedProduct;
          final oldBarcode = _normalizedBarcode(existing.barcode);
          if (oldBarcode.isNotEmpty &&
              existingByBarcode[oldBarcode]?.id == existing.id) {
            existingByBarcode.remove(oldBarcode);
          }
          final barcode = _normalizedBarcode(updatedProduct.barcode);
          if (barcode.isNotEmpty) existingByBarcode[barcode] = updatedProduct;
          updated++;
          continue;
        }

        final catalogProduct = incoming.copyWith(quantity: 0);
        await putProduct(catalogProduct);
        existingById[catalogProduct.id] = catalogProduct;
        final barcode = _normalizedBarcode(catalogProduct.barcode);
        if (barcode.isNotEmpty) existingByBarcode[barcode] = catalogProduct;
        added++;
      }
      return (added: added, updated: updated, skipped: skipped);
    });
  }

  ProductModel _productFromRow(QueryRow row) => ProductModel(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    quantity: row.read<int>('quantity'),
    costPrice: row.read<int>('cost_price_minor') / 100,
    sellingPrice: row.read<int>('selling_price_minor') / 100,
    category: row.read<String>('category'),
    minStock: row.read<int>('min_stock'),
    barcode: row.read<String>('barcode'),
  );

  String _normalizedBarcode(String value) => value.trim().toLowerCase();

  int _minorUnits(double amount) {
    if (!amount.isFinite) {
      throw ArgumentError.value(amount, 'amount', 'Must be finite.');
    }
    return (amount * 100).round();
  }

  static const _schema = [
    '''
    CREATE TABLE products (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      cost_price_minor INTEGER NOT NULL,
      selling_price_minor INTEGER NOT NULL,
      category TEXT NOT NULL DEFAULT '',
      min_stock INTEGER NOT NULL DEFAULT 0,
      barcode TEXT NOT NULL DEFAULT ''
    )
    ''',
    '''
    CREATE TABLE sales_transactions (
      id TEXT PRIMARY KEY NOT NULL,
      receipt_number TEXT NOT NULL,
      sold_at TEXT NOT NULL,
      subtotal_minor INTEGER NOT NULL,
      discount_minor INTEGER NOT NULL DEFAULT 0,
      total_minor INTEGER NOT NULL,
      amount_paid_minor INTEGER NOT NULL,
      change_due_minor INTEGER NOT NULL DEFAULT 0,
      payment_method TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE sale_items (
      id TEXT PRIMARY KEY NOT NULL,
      transaction_id TEXT NOT NULL REFERENCES sales_transactions(id),
      product_id TEXT REFERENCES products(id) ON DELETE SET NULL,
    product_id_snapshot TEXT NOT NULL,
    product_name_snapshot TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price_minor INTEGER NOT NULL,
      unit_cost_minor INTEGER,
      line_total_minor INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE expiration_batches (
      id TEXT PRIMARY KEY NOT NULL,
      product_id TEXT NOT NULL REFERENCES products(id),
      batch_identifier TEXT NOT NULL,
      initial_quantity INTEGER NOT NULL,
      remaining_quantity INTEGER NOT NULL,
      expiration_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      notes TEXT
    )
    ''',
    '''
    CREATE TABLE stock_movements (
      id TEXT PRIMARY KEY NOT NULL,
      batch_id TEXT REFERENCES expiration_batches(id) ON DELETE SET NULL,
      product_id TEXT NOT NULL,
      product_name_snapshot TEXT NOT NULL,
      batch_identifier_snapshot TEXT NOT NULL,
      movement_type TEXT NOT NULL,
      previous_quantity INTEGER NOT NULL,
      updated_quantity INTEGER NOT NULL,
      movement_at TEXT NOT NULL,
      expiration_date TEXT NOT NULL,
      remarks TEXT
    )
    ''',
    '''
    CREATE TABLE customers (
      id TEXT PRIMARY KEY NOT NULL,
      full_name TEXT NOT NULL,
      phone TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE credit_accounts (
      id TEXT PRIMARY KEY NOT NULL,
      customer_id TEXT NOT NULL REFERENCES customers(id),
      sale_id TEXT REFERENCES sales_transactions(id) ON DELETE SET NULL,
      item_name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price_minor INTEGER NOT NULL,
      original_amount_minor INTEGER NOT NULL,
      outstanding_balance_minor INTEGER NOT NULL,
      credit_date TEXT NOT NULL,
      due_date TEXT NOT NULL,
      customer_name_snapshot TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE credit_payments (
      id TEXT PRIMARY KEY NOT NULL,
      credit_id TEXT NOT NULL REFERENCES credit_accounts(id),
      customer_id TEXT NOT NULL REFERENCES customers(id),
      amount_minor INTEGER NOT NULL,
      payment_method TEXT NOT NULL,
      paid_at TEXT NOT NULL,
      customer_name_snapshot TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE credit_balance_corrections (
      id TEXT PRIMARY KEY NOT NULL,
      credit_id TEXT NOT NULL REFERENCES credit_accounts(id),
      original_balance_minor INTEGER NOT NULL,
      corrected_balance_minor INTEGER NOT NULL,
      reason TEXT NOT NULL,
      details TEXT NOT NULL,
      authorized_by TEXT NOT NULL,
      changed_at TEXT NOT NULL,
      customer_name_snapshot TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE expenses (
      id TEXT PRIMARY KEY NOT NULL,
      category TEXT NOT NULL,
      description TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      expense_date TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE expense_corrections (
      id TEXT PRIMARY KEY NOT NULL,
      expense_id TEXT NOT NULL,
      action TEXT NOT NULL,
      reason TEXT NOT NULL,
      changed_at TEXT NOT NULL,
      previous_record_json TEXT,
      updated_record_json TEXT
    )
    ''',
    '''
    CREATE TABLE business_activity_log (
      id TEXT PRIMARY KEY NOT NULL,
      description TEXT NOT NULL,
      category TEXT NOT NULL,
      occurred_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE store_profile (
      singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
      store_name TEXT NOT NULL DEFAULT '',
      owner_name TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      contact_number TEXT NOT NULL DEFAULT ''
    )
    ''',
    '''
    CREATE TABLE app_preferences (
      singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
      theme_mode TEXT NOT NULL,
      currency_code TEXT NOT NULL,
      date_pattern TEXT NOT NULL,
      low_stock INTEGER NOT NULL,
      expiration INTEGER NOT NULL,
      sales INTEGER NOT NULL,
      expense_reminders INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE migration_state (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL
    )
    ''',
    'CREATE INDEX sale_items_transaction_idx ON sale_items(transaction_id)',
    'CREATE INDEX sale_items_product_idx ON sale_items(product_id)',
    'CREATE INDEX sales_transactions_sold_at_idx ON sales_transactions(sold_at)',
    'CREATE INDEX expiration_batches_product_idx ON expiration_batches(product_id)',
    'CREATE INDEX expiration_batches_expiration_idx ON expiration_batches(expiration_date)',
    'CREATE INDEX stock_movements_batch_idx ON stock_movements(batch_id)',
    'CREATE INDEX credit_accounts_customer_idx ON credit_accounts(customer_id)',
    'CREATE INDEX credit_accounts_due_date_idx ON credit_accounts(due_date)',
    'CREATE INDEX credit_payments_credit_idx ON credit_payments(credit_id)',
    'CREATE INDEX credit_corrections_credit_idx ON credit_balance_corrections(credit_id)',
    'CREATE INDEX expenses_expense_date_idx ON expenses(expense_date)',
    'CREATE INDEX expense_corrections_expense_idx ON expense_corrections(expense_id)',
    'CREATE INDEX activity_log_occurred_at_idx ON business_activity_log(occurred_at)',
  ];
}
