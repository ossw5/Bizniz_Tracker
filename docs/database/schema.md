# Proposed local database schema

**Status:** partially implemented. Products and sales are active in Drift schema
version 1; the remaining tables below are the approved migration target and are
not yet active app storage.  
**Target:** SQLite accessed through Drift, with offline storage on each device.

This schema normalizes the current app's persisted data into related tables.
Reports, low-stock alerts, and expiration status should be calculated from
these records rather than stored as duplicate summary tables.

## Tables

`id` columns below are text IDs unless stated otherwise. Dates/times should be
stored in a consistent ISO-8601 representation (UTC for timestamps; date-only
values for calendar dates).

### Inventory

#### `products`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | Existing product ID |
| `name` | TEXT, not null | |
| `quantity` | INTEGER, not null | On-hand stock |
| `cost_price_minor` | INTEGER, not null | Cost per unit in the currency's minor unit |
| `selling_price_minor` | INTEGER, not null | Selling price per unit in the currency's minor unit |
| `category` | TEXT, not null, default `''` | |
| `min_stock` | INTEGER, not null, default `0` | Low-stock threshold |
| `barcode` | TEXT, not null, default `''` | Add a unique index when non-empty barcodes are enforced as unique |

#### `expiration_batches`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | Existing expiration-record ID |
| `product_id` | TEXT, not null, foreign key | References `products.id` |
| `batch_identifier` | TEXT, not null | |
| `initial_quantity` | INTEGER, not null | |
| `remaining_quantity` | INTEGER, not null | |
| `expiration_date` | TEXT, not null | Calendar date |
| `created_at` | TEXT, not null | Timestamp |
| `notes` | TEXT, nullable | |

#### `stock_movements`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | |
| `batch_id` | TEXT, nullable, foreign key | References `expiration_batches.id`; nullable to support movements without a tracked batch |
| `product_id` | TEXT, not null, foreign key | References `products.id` |
| `product_name_snapshot` | TEXT, not null | Historical display value |
| `batch_identifier_snapshot` | TEXT, not null | |
| `movement_type` | TEXT, not null | `sold`, `removed`, or `discarded` |
| `previous_quantity` | INTEGER, not null | |
| `updated_quantity` | INTEGER, not null | |
| `movement_at` | TEXT, not null | Timestamp |
| `expiration_date` | TEXT, not null | Calendar date snapshot |
| `remarks` | TEXT, nullable | |

### Sales

#### `sales_transactions`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | Transaction ID |
| `receipt_number` | TEXT, not null | |
| `sold_at` | TEXT, not null | Timestamp |
| `subtotal_minor` | INTEGER, not null | |
| `discount_minor` | INTEGER, not null, default `0` | |
| `total_minor` | INTEGER, not null | |
| `amount_paid_minor` | INTEGER, not null | |
| `change_due_minor` | INTEGER, not null, default `0` | |
| `payment_method` | TEXT, not null | |

#### `sale_items`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | Existing sale-item ID |
| `transaction_id` | TEXT, not null, foreign key | References `sales_transactions.id` |
| `product_id` | TEXT, nullable, foreign key | References `products.id`; nullable so history survives product removal |
| `product_id_snapshot` | TEXT, not null | Preserve the original product ID if the referenced product is removed |
| `product_name_snapshot` | TEXT, not null | Preserve the name shown at time of sale |
| `quantity` | INTEGER, not null | |
| `unit_price_minor` | INTEGER, not null | Price at time of sale |
| `unit_cost_minor` | INTEGER, nullable | Cost snapshot, if known |
| `line_total_minor` | INTEGER, not null | |

One transaction has one or more sale items. Keep price and name snapshots on
each item so historical receipts and profit reports do not change when a
product is edited.

### Customers and credit

#### `customers`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | |
| `full_name` | TEXT, not null | |
| `phone` | TEXT, not null, default `''` | |
| `address` | TEXT, not null, default `''` | |
| `notes` | TEXT, not null, default `''` | |
| `created_at` | TEXT, not null | Timestamp |

#### `credit_accounts`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | |
| `customer_id` | TEXT, not null, foreign key | References `customers.id` |
| `sale_id` | TEXT, nullable, foreign key | References `sales_transactions.id` when linked to a recorded sale |
| `item_name` | TEXT, not null | Snapshot for statements |
| `quantity` | INTEGER, not null | |
| `unit_price_minor` | INTEGER, not null | |
| `original_amount_minor` | INTEGER, not null | |
| `outstanding_balance_minor` | INTEGER, not null | |
| `credit_date` | TEXT, not null | Calendar date |
| `due_date` | TEXT, not null | Calendar date |

#### `credit_payments`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | |
| `credit_id` | TEXT, not null, foreign key | References `credit_accounts.id` |
| `customer_id` | TEXT, not null, foreign key | References `customers.id` |
| `amount_minor` | INTEGER, not null | |
| `payment_method` | TEXT, not null | |
| `paid_at` | TEXT, not null | Timestamp |

#### `credit_balance_corrections`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | |
| `credit_id` | TEXT, not null, foreign key | References `credit_accounts.id` |
| `original_balance_minor` | INTEGER, not null | |
| `corrected_balance_minor` | INTEGER, not null | |
| `reason` | TEXT, not null | |
| `details` | TEXT, not null | |
| `authorized_by` | TEXT, not null | |
| `changed_at` | TEXT, not null | Timestamp |

### Expenses and audit history

#### `expenses`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | |
| `category` | TEXT, not null | |
| `description` | TEXT, not null | |
| `amount_minor` | INTEGER, not null | |
| `expense_date` | TEXT, not null | Calendar date |
| `created_at` | TEXT, not null | Timestamp |

#### `expense_corrections`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | |
| `expense_id` | TEXT, not null | Original expense ID; retain even after deletion |
| `action` | TEXT, not null | `Added`, `Edited`, or `Deleted` |
| `reason` | TEXT, not null | |
| `changed_at` | TEXT, not null | Timestamp |
| `previous_record_json` | TEXT, nullable | Previous expense snapshot |
| `updated_record_json` | TEXT, nullable | Updated expense snapshot |

#### `business_activity_log`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT, primary key | |
| `description` | TEXT, not null | |
| `category` | TEXT, not null | |
| `occurred_at` | TEXT, not null | Timestamp |

### Configuration

#### `store_profile`

One row for the local store profile: `store_name`, `owner_name`, `address`, and
`contact_number`. Use a fixed singleton primary key so only one profile exists
per local database.

#### `app_preferences`

One row for app-wide preferences: `theme_mode`, `currency_code`,
`date_pattern`, and the four notification preferences (`low_stock`,
`expiration`, `sales`, and `expense_reminders`).

Technical migration/backup timestamps can remain in a key-value settings table
or be added to a dedicated settings table when implementation requirements
are known.

## Storage and relationship rules

- Store money as integer minor units rather than floating-point values. Convert
  to/from the app's `double` model values at the repository boundary, using the
  configured currency's fraction digits.
- Enable SQLite foreign-key enforcement. Define deletion behavior explicitly;
  preserve sales, corrections, and movement snapshots even if related display
  records are removed.
- Write a completed sale, its items, and associated stock changes in one
  database transaction.
- Index foreign-key columns and common filters such as sale date, expense date,
  credit due date, and expiration date.
- Derive summaries and statuses from persisted records; do not persist
  redundant dashboard totals.
- Let Drift's schema version and migration strategy own database upgrades.

## Migration notes

The existing Hive backup contains boxes corresponding to the entities above.
Migration must map Hive keys and values, preserve IDs and historical snapshots,
and verify row counts and representative totals before Hive data is retired.
Legacy sale records without transaction metadata need a defined import rule:
create one transaction per legacy sale record unless the data provides a
reliable grouping key.

Products and sales are imported from their existing Hive boxes once, in a
database transaction. The import preserves product and sale-item IDs, keeps
sale-time snapshots, groups records only when a legacy transaction ID exists,
and creates one transaction per ungrouped legacy sale. Monetary values are
stored in cents to match the app's current two-decimal currency handling. The
Hive boxes are retained. The other domains and complete backup/restore cutover
remain pending.
