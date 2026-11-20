# Database change log

Record proposed and implemented database changes here. For implemented
changes, include the Drift schema version, migration behavior, and validation
performed.

## 2026-11-09 — Initial database reference

- Status: proposed; no SQLite/Drift schema or Hive migration implemented.
- Documented the current app's business data as a normalized offline schema
  proposal in [schema.md](./schema.md).
- Migration from Hive and a verified offline web backend remain prerequisites
  before replacing the current storage.

## 2026-11-09 — Drift schema version 1

- Status: partially implemented; products and sales use Drift. Expense,
  credit, expiration, settings, and activity-log persistence remain on Hive.
- Added normalized SQLite tables, indexes, foreign-key enforcement, and native
  and web database initialization.
- Added a one-time transactional import of products and sales from Hive. The
  source boxes are retained; standalone legacy sales become their own
  transaction. Startup checks imported record counts.
- Validation: database schema, CRUD, legacy sales, import idempotence, and
  failed-import retry tests pass. Sales workflow and Hive backup tests pass.
- The full multi-domain migration and web-browser persistence matrix remain
  outstanding; do not remove Hive.
