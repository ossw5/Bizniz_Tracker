# Bizniz Tracker

Bizniz Tracker is an offline-first Flutter app for small business inventory
and sales management. Product inventory and completed sales are stored locally
with Hive. Dashboard overview figures and recent transactions still include
sample data.

## Run the prototype

```powershell
flutter pub get
flutter run -d chrome
```

You can also run it on an available mobile device with `flutter run`.

## Dashboard and navigation

The dashboard previews business summaries, quick actions, a sales overview,
inventory alerts, product performance, smart suggestions, and recent
transactions. The five bottom destinations are Home, Inventory, Sales, Reports,
and More. Reports contains the daily/weekly/monthly sales summary and links to
expense tracking. Expense tracking supports offline expense records, category
totals, correction history, estimated profit, and CSV/PDF export. Sales opens
**Sales in One**, which supports inventory-based product selection, barcode
scanning/manual barcode entry, cart and payment, digital receipts, and saved
sales history. Reports also opens customer credit tracking for customer
registration, inventory-linked credit sales, partial/full payments, outstanding
balances, due-date monitoring, customer statements, and authorized balance
corrections.

On Android, iOS, macOS, and web, barcode scanning uses the device camera where
available. Windows and Linux use manual barcode entry or a connected
keyboard-wedge scanner. Assign barcodes to products in Inventory before
scanning them for a sale. Sales transactions and stock updates use the existing
local Hive stores.

## Feature modules

Sales in One is implemented in `lib/features/sales_management/` and integrated
with the existing dashboard and Hive-backed product and sales repositories.
Product/inventory, inventory-alert/smart-suggestion, expense-tracking, and
customer credit/debit modules are integrated with the existing app.

```text
lib/features/
├── product_and_inventory_management/
│   ├── screens/
│   ├── widgets/
│   ├── models/
│   └── services/
├── sales_management/
│   ├── screens/
│   ├── widgets/
│   ├── models/
│   └── services/
├── expense_tracking/
│   ├── screens/
│   ├── widgets/
│   ├── models/
│   └── services/
├── inventory_alerts_and_smart_suggestions/
│   ├── screens/
│   ├── widgets/
│   ├── models/
│   └── services/
└── customer_credit_and_debit_tracking/
    ├── screens/
    ├── widgets/
    ├── models/
    └── services/
```

Other team directories currently contain only `.gitkeep` files so Git preserves
their empty structure.

## Project notes

- App startup is in `lib/main.dart`; the prior sales/inventory app entrypoint
  has been preserved in `lib/legacy_main.dart`.
- Shared app setup and theme are in `lib/app.dart` and
  `lib/core/theme/app_theme.dart`.
- The dashboard and reusable dashboard widgets are under
  `lib/features/dashboard/`.
- Product and sale models and repositories are under `lib/features/products/`
  and `lib/features/sales/`.
- The integrated Sales in One workflow is under
  `lib/features/sales_management/`.

The app uses Flutter Material 3 and the project targets Dart 3.8.1 or later.
