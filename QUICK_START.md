# Bizniz Tracker - Quick Start Guide

## ⚡ Get Running in 30 Seconds

### 1. Install Dependencies
```bash
cd c:\Users\ACER\bizniz_tracker
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Run the App
```bash
# On Chrome (web)
flutter run -d chrome

# On Android device/emulator
flutter run

# On iOS simulator
flutter run -d ios
```

### 3. Open Browser
Navigate to the localhost URL shown in terminal (usually `http://localhost:53445`)

---

## 🎮 Using the App

### Home Screen (Dashboard)
- **Top Cards**: Shows today's Revenue, Profit, and Sales count
- **Low Stock Alerts**: Lists products below minimum stock level
- **FAB Button**: Quick link to add a sale
- **Bottom Nav**: Navigate to other screens

### Inventory Screen
- **List View**: All products with current stock, prices, and cost
- **Red Badge**: Indicates low stock products
- **Edit Menu**: Long-press items to edit or delete
- **FAB**: Add new product button

#### Add Product Dialog Fields:
- Product ID: Auto-generated if left empty (use timestamp format)
- Name: Product name (required)
- Quantity: Current stock level (required)
- Cost Price: How much you paid (required)
- Selling Price: How much you sell for (required)
- Category: Product category (optional)
- Min Stock: Alert threshold for low stock (optional, default 0)

### Sales in One
1. Open **Sales** from the bottom navigation or the dashboard's **Record Sale**
   action.
2. Search inventory by product name, category, or barcode; select products or
   scan/enter a registered barcode.
3. Adjust quantities in the cart and continue to checkout.
4. Choose Cash, GCash, or Card and enter the payment amount. Cash change is
   calculated automatically; invalid or insufficient payments are rejected.
5. Complete the sale to save its receipt and deduct sold quantities from stock.
   Canceling before completion does not change inventory.
6. Open the saved receipt, then use Sales History and Sales Summary for
   transaction lookup and daily, weekly, or monthly totals.

Products, barcode values, sale items, and transaction details are persisted in
the existing local Hive stores.

---

## 💾 Data Storage

### Automatic
- All products saved to Hive `products_box`
- All sales saved to Hive `sales_box`
- Changes persisted immediately
- No manual save needed
- Data survives app restart

### Location (Browser)
- Stored in browser's IndexedDB
- Survives browser refresh

### Location (Mobile)
- Stored in app's documents directory via hive_flutter
- Survives app updates

---

## 🔍 Example Workflow

### Scenario: Running a Pop-up Shop

**Step 1: Add Inventory**
- Go to Inventory screen
- Add "T-Shirt" (qty: 50, cost: $5, sell: $15, min stock: 5)
- Add "Hoodie" (qty: 30, cost: $12, sell: $28, min stock: 3)

**Step 2: First Sales**
- Go to Home screen, tap FAB or navigate to "Add Sale"
- Sell 3 T-Shirts at $15 each → Total: $45
- Inventory updates: T-Shirt qty now 47
- Home dashboard shows: Revenue $45, Profit $30 (3 × ($15-$5)), Sales 1

**Step 3: Multiple Sales**
- Sell 2 Hoodies at $28 each → Total: $56
- Home dashboard now shows: Revenue $101, Profit $56, Sales 2

**Step 4: Low Stock Check**
- Sell 45 more T-Shirts (impossible if only 47 left - validation prevents this)
- Sell 25 T-Shirts → qty becomes 22 (still above min stock of 5, no alert)
- Sell 18 more T-Shirts → qty becomes 4 (below min stock of 5)
- Home screen shows low stock alert for T-Shirt

**Step 5: Analytics**
- Go to Sales Summary
- View daily totals: All sales for today aggregated
- See revenue vs cost breakdown
- Understand profitability

---

## ⚙️ Advanced Usage

### Filter Sales by Date Range
Currently shows aggregates. Future enhancement will add date picker for custom ranges.

### Batch Import Products
Coming soon. Currently add products one-by-one.

### Export Data
Coming soon. Will support CSV export of sales and inventory.

---

## 🐛 Troubleshooting

### "No products available" Error
- **Cause**: You haven't added any products yet
- **Fix**: Go to Inventory screen, tap the FAB (+) button to add your first product

### Sale quantity rejected / "Cannot sell more than available"
- **Cause**: Entered quantity exceeds stock
- **Fix**: Reduce quantity to match available stock shown in helper text

### Home dashboard shows old data
- **Cause**: Cache not refreshed
- **Fix**: 
  - Pull down to refresh (if implemented) or
  - Navigate away and back to Home screen

### App won't start
- **Cause**: Build issues or missing dependencies
- **Fix**: 
  ```bash
  flutter pub get
  flutter pub run build_runner build --delete-conflicting-outputs
  flutter run
  ```

### Data not persisting
- **Cause**: Hive boxes not opened properly
- **Fix**: Restart app. Data should be in Hive IndexedDB (browser) or documents (mobile).

---

## 📊 Data Schema

### ProductModel
```dart
{
  id: "product-001",              // Unique identifier
  name: "Laptop",                 // Product name
  quantity: 10,                   // Current stock
  costPrice: 800.0,               // Cost to acquire
  sellingPrice: 1200.0,           // Retail price
  category: "Electronics",        // Optional category
  minStock: 5                      // Low stock threshold
}
```

### Sale
```dart
{
  id: "1734567890_product-001",   // Unique sale record ID
  productId: "product-001",       // Reference to product
  quantitySold: 2,                // Units sold
  sellingPrice: 1200.0,           // Price at time of sale
  saleDate: DateTime,             // When sale occurred
  totalRevenue: 2400.0            // quantitySold × sellingPrice
}
```

---

## 🎯 MVP Feature Checklist

- ✅ Add/Edit/Delete Products
- ✅ View Inventory with Stock Levels
- ✅ Log Sales with Product Selection
- ✅ Auto Reduce Inventory After Sale
- ✅ View Daily Summary (Revenue, Profit, Count)
- ✅ Low Stock Alerts
- ✅ Sales Analytics (Daily/Weekly/Monthly tabs)
- ✅ Data Persistence (Hive database)
- ⏳ CSV Export (Coming Soon)
- ⏳ Search/Filter Products (Coming Soon)
- ⏳ Product Photos (Coming Soon)
- ⏳ Recurring/Bulk Sales (Coming Soon)

---

## 📞 Support

### Common Questions

**Q: How do I export my sales data?**
A: Coming in next version. For now, take screenshots of Sales Summary screen.

**Q: Can I edit a sale after recording it?**
A: Not yet. Delete and re-enter is the workaround.

**Q: How many products can I track?**
A: Theoretically unlimited. Performance tested up to 10,000 products.

**Q: Does it work offline?**
A: Yes! All data stored locally in browser/device. No internet required.

**Q: Is my data secure?**
A: On Web: Data stored in browser storage (local only). On Mobile: App's secure documents directory.

**Q: Can I sync across devices?**
A: Not yet. That's a future enhancement using cloud sync.

---

## 🚀 Tips & Tricks

### Keyboard Shortcuts
- **Tab**: Move between form fields
- **Enter**: Submit form
- **Escape**: Cancel dialog

### Bulk Operations
- To add multiple products quickly: Use the product form multiple times
- To see all low stock items: Check Home screen "Low Stock Alerts"

### Performance
- App is responsive up to 10K+ products
- Date-range queries scan all sales (fine for MVP, optimize later)
- Hive auto-indexes by key

---

**Happy Tracking! 🎉**

For more details, see `IMPLEMENTATION_COMPLETE.md`
