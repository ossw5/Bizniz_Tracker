# Database documentation

This folder is the reference point for the app's local database design and
schema history.

## Status

- SQLite with Drift is now the active store for products and sales
  (schema version 1). Existing Hive products and sales are imported once at
  startup and retained; a verification failure prevents startup from silently
  continuing with an incomplete import.
- Expenses, credit records, expiration batches, activity history, and settings
  still use Hive. The migration is therefore partial; do not remove Hive or
  treat every table in `schema.md` as active. Explicit local backups are JSON
  exports of the Hive boxes and active product/sales store.
- Expense records are read from and written to the Hive
  `business_expenses_box`; corrections use `expense_corrections_box`.
  The SQLite `expenses` table is schema-only in this version and has no
  application CRUD or migration path. Do not treat it as an expense source or
  move records to it without a verified backup and migration.
- Native platforms use Drift's local SQLite database. Web uses Drift's WASM
  runtime and worker, with IndexedDB-backed persistence where supported by the
  browser. Browsers without a persistent Drift storage implementation need
  separate validation before they can be considered supported.
- Native Hive storage is initialized by `Hive.initFlutter()` in the platform's
  application documents directory; the web implementation uses browser
  storage. There is no online expense synchronization in the current app.

## Documents

- [schema.md](./schema.md) describes the proposed tables, relationships, and
  storage conventions.
- [CHANGELOG.md](./CHANGELOG.md) tracks approved and implemented schema changes.

## Change process

1. Update `schema.md` when a schema change is approved.
2. Add a dated entry to `CHANGELOG.md`, identifying whether the change is
   proposed or implemented and any data migration required.
3. When Drift is implemented, keep its `schemaVersion` and migration steps in
   sync with these documents.
4. Never alter a released schema without a migration and a backup/restore test.

Backups and any Hive-to-SQLite migration must preserve existing user data.
Keep the remaining Hive-backed features intact until their migration and
backup/restore verification are complete.
