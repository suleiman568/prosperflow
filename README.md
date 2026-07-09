# ProsperFlow

A digital sales ledger for Nigerian market traders — record sales, track
stock, expenses, credits, and profit. Built with Flutter, offline-first
for low-end Android phones.

All 7 design-handoff screens are implemented, backed by a local database,
Supabase auth, and a background sync engine:

1. **Login** — Supabase email/password, account creation, password reset
2. **Dashboard** — live stats, low-stock alert, sync status, quick actions
3. **Record Sale** — stock decrements, credits open, works fully offline
4. **Products** — inventory with LOW badges and add-product sheet
5. **Expenses** — weekly totals and categorized entries
6. **Reports** — profit, top products, payment breakdown per period
7. **Outstanding Credits** — mark-as-paid moves amounts into cash

## Architecture (per the Backend Plan)

- **Local-first**: Drift/SQLite (`lib/src/data/`) is the source of truth;
  every screen streams from it and every write lands instantly, offline.
- **Outbox sync**: each mutation appends to an outbox; `DriftSyncEngine`
  (`lib/src/sync/`) flushes it to Supabase in order with idempotent
  upserts on client-generated UUIDs — on reconnect, after each write,
  on manual sync, and with exponential backoff after failures.
- **Auth**: Supabase email/password behind `AuthService`
  (`lib/src/auth/`); sessions persist locally through offline stretches.
- **Server**: run `supabase/schema.sql` on the Supabase project to create
  the tables, indexes, and row-level-security policies.

The web build swaps in in-memory implementations (no SQLite/no network)
and is used for design previews only; Android is the production target.

## Design system

Tokens (colors, Inter typography, shape, spacing) live in
`lib/src/theme/tokens.dart`, taken from the Developer Handoff v1.0.
Inter is bundled in `assets/fonts/` so the app renders correctly offline.

## Running

```sh
flutter pub get
flutter run
```

## Tests

```sh
flutter test
```
