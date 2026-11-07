# Bizniz Tracker - MVP Development Roadmap

## Project Overview
A Flutter-based offline inventory and sales tracking app for small businesses. Track products, log sales, and view daily/weekly/monthly analytics with local Hive database storage.

---

## ✅ Completed Features

### 1. **Product Catalog / Inventory** (Core Feature)
- ✅ Add, edit, delete products
- ✅ Track quantity, cost price, selling price
- ✅ Categorize items
- ✅ Set minimum stock threshold
- ✅ Hive persistence layer with TypeAdapter
- ✅ Product Repository (add, update, delete, getAll, getById)
- ✅ Inventory List Screen with product display

### 2. **Sales Logging and Sales in One**
- ✅ Sale entity with Hive support (typeId: 1)
- ✅ Sale Repository with date range queries
- ✅ Sales data persistence in Hive
- ✅ Automatic calculation of revenue (qty × price)
- ✅ Query sales by date, date range, or product ID
- ✅ Product selection, search, barcode scanning/manual entry, and cart
- ✅ Payment validation, receipt generation, and inventory deduction
- ✅ Saved transaction history with search and daily/weekly/monthly summaries

### 3. **Home Screen / Dashboard**
- ✅ Daily summary cards: Total revenue, profit, sales count
- ✅ Low stock alerts highlighting items below minimum
- ✅ Quick navigation via bottom navigation bar (5 destinations)
- ✅ FutureBuilder for async data loading

### 4. **Architecture & Providers**
- ✅ Clean architecture (Domain, Data, Presentation layers)
- ✅ Riverpod providers for dependency injection
- ✅ Hive boxes registered and accessible via providers
- ✅ Both products and sales boxes opened at app startup

---

## 🚧 In Progress / Next Steps

Sales in One is implemented in `lib/features/sales_management/`. Remaining
planned work includes CSV export and any future enhancements to the existing
inventory alert and suggestion experience.

### 5. **Low Stock Alerts** (Priority: MEDIUM)
**Location:** Currently partial in `HomeScreen` via `DailySummary`

**Requirements:**
- Already detects low stock in Home Screen
- Add optional: Pop-up alert when app starts if items are below minimum
- Show a dismissed/persistent banner on Home Screen

**Implementation Notes:**
- Check in `didChangeDependencies` or `initState`
- Trigger `showDialog()` if any `product.quantity < product.minStock`
- Allow user to dismiss or go to Inventory

---

### 6. **Enhance Inventory Screen** (Priority: MEDIUM)
**Location:** `lib/main.dart` - `ProductHomePage`

**Current State:** Basic list with add/edit/delete per product

**Improvements:**
- Add low stock indicator badge (red badge if qty < minStock)
- Show quick stats: quantity/minStock ratio
- Swipe-to-delete or context menu improvements
- Sort by: name, quantity, low stock first

---

### 7. **CSV Export Feature** (Priority: LOW)
**Location:** New file: `lib/features/core/csv_exporter.dart`

**Requirements:**
- Export inventory data (name, qty, cost, selling price, category)
- Export sales log (product, qty sold, price, date, revenue)
- Save to Downloads folder or share via email
- Use `csv` package from pub.dev

---

## 🏗️ Architecture Overview

```
lib/
├── core/
│   ├── failure.dart              # Error handling
│   ├── hive_registry.dart        # Hive adapter registration
│   └── csv_exporter.dart         # [TODO]
├── features/
│   ├── products/
│   │   ├── domain/
│   │   │   ├── product.dart      # ProductModel with @HiveType
│   │   │   └── repositories.dart
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── product_local_datasource_impl.dart
│   │   │   └── repositories/
│   │   │       └── product_repository_impl.dart
│   │   └── presentation/
│   │       ├── controllers.dart  # ProductController
│   │       └── providers.dart    # Riverpod providers
│   └── sales/
│       ├── domain/
│       │   ├── sale.dart         # Sale model with @HiveType
│       │   └── sale_repository.dart
│       ├── data/
│       │   └── sale_repository_impl.dart
│       └── presentation/
│           ├── sales_controller.dart     # DailySummary logic
│           ├── home_screen.dart         # Dashboard
│           ├── add_sale_screen.dart     # [WIP]
│           └── sales_summary_screen.dart # [WIP]
└── main.dart                    # App entry & navigation
```

---

## 📱 User Flow

1. **Home Screen (Dashboard)**
   - Opens on app launch
   - Shows today's totals + low stock alerts
   - Navigate to Inventory, Add Sale, or Sales Summary via bottom nav

2. **Inventory Screen**
   - View all products with stock indicators
   - Tap to edit, delete, or view product details
   - Add new product button

3. **Sales in One**
   - Search inventory and select products or scan registered barcodes
   - Manage cart quantities and validate payment at checkout
   - Save receipt and update stock only after completing a valid sale

4. **Sales Summary Screen**
   - Toggle: Daily / Weekly / Monthly
   - See revenue, profit, sales count, stock snapshot
   - Optional date range filter

---

## 🔧 Technical Stack

- **Frontend:** Flutter 3.x
- **State Management:** Riverpod + StateNotifier
- **Local Database:** Hive with code generation
- **Architecture:** Clean Architecture (Domain/Data/Presentation)
- **Dependencies:**
  - `flutter_riverpod` - state management
  - `hive` + `hive_flutter` - local storage
  - `dartz` - Either for error handling
  - `build_runner` + `hive_generator` - code generation
  - `intl` - date formatting
  - `csv` - CSV export (to add)

---

## 🚀 Next Immediate Steps

1. **CSV export** → Backup and external reporting

---

## 📝 Notes for Developers

- Always update `Hive.registerAdapter()` when adding new `@HiveType` models
- Run `flutter pub run build_runner build --delete-conflicting-outputs` after schema changes
- Use Riverpod providers for dependency injection; avoid direct instantiation
- Test with actual Hive persistence (not just in-memory mock)
- Consider adding unit tests for repository + controller logic

---

**Status:** Core inventory, sales workflow, local persistence, and sales summaries implemented
