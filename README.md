# ProsperFlow

A digital sales ledger for Nigerian market traders — record sales, track
stock, expenses, credits, and profit. Built with Flutter, designed
offline-first for low-end Android phones.

Implementation of the ProsperFlow design handoff. All 7 screens are built
(UI-only, on demo data); the offline-first local database and sync backend
come next:

1. **Login** ✅
2. **Dashboard** ✅
3. **Record Sale** ✅
4. **Products** ✅
5. **Expenses** ✅
6. **Reports** ✅
7. **Outstanding Credits** ✅

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
