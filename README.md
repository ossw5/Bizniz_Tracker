# Bizniz Tracker

Bizniz Tracker is a Flutter prototype for small business inventory and sales
management. The current milestone focuses on the Material 3 dashboard and
shared navigation. Dashboard figures and transactions are sample data; backend
storage, online backup, and transaction processing are not part of this
wireframe milestone.

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
and More. Inventory and Sales open clear placeholders for the assigned teams;
the other unfinished destinations are also identified as prototype work.

Quick actions navigate to the corresponding shared destination where one
exists. Barcode scanning shows an explicit not-yet-implemented notice. The
Daily, Weekly, and Monthly sales filters are interactive, but the chart and
figures remain sample data.

## Assigned module scaffolds

The five team modules contain only the requested directory structure. No
module screens, widgets, models, services, forms, or module-specific buttons
have been implemented.

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

Each team member can add their work under the matching folder in
`lib/features/`. The directories currently contain only `.gitkeep` files so
Git preserves the empty structure.

## Project notes

- App startup is in `lib/main.dart`; the prior sales/inventory app entrypoint
  has been preserved in `lib/legacy_main.dart`.
- Shared app setup and theme are in `lib/app.dart` and
  `lib/core/theme/app_theme.dart`.
- The dashboard and reusable dashboard widgets are under
  `lib/features/dashboard/`.
- The existing `products/` and `sales/` code is retained, but is not connected
  to the sample dashboard in this prototype milestone.

The app uses Flutter Material 3 and the project targets Dart 3.8.1 or later.
