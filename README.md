# Receipto

**Intelligent Personal Finance Management System** — a Final Year Project (UTAR FICT).

Receipto is a Flutter/Android personal-finance app that combines a full
transaction/budget/goals management system with on-device receipt scanning
and an optional LLM layer for smarter data entry and natural-language
spending queries. Everything runs locally on SQLite — there is no backend
server; the only network calls are to the receipt/chat AI provider (BYOK)
and, optionally, Google Drive for backup.

## Features

### Core finance management
- **Transactions** — add/edit/delete, with category + subcategory, account
  (payment method), date & time, notes, and OCR provenance.
- **Categories** — 11 preset categories with 45 subcategories, each with an
  SVG icon and a user-selectable colour (icon and colour are independently
  configurable); fully editable/extendable.
- **Budgets** — per-category monthly limits with progress tracking that rolls
  subcategory spending up into its parent category.
- **Savings goals** — target amount, saved amount, optional target date.
- **Recurring transactions** — weekly/monthly templates that post
  automatically when due.
- **Accounts & wallets** — multiple accounts (bank/cash/e-wallet), inter-account
  transfers, and a live net-worth view.
- **Analytics** — monthly income/expense/net, spending-by-category with a
  category → subcategory drill-down, a 6-month trend, and a ranked
  transaction list per (sub)category.
- **Bill splitting** — scan a receipt, mark which items were yours, and the
  app applies the printed service charge / SST to compute your share.
- **Backup & restore** — full JSON export/import, either to a local file or
  to Google Drive (with silent auto-backup on launch).

### Intelligence
- **On-device OCR** (Google ML Kit) reads receipt photos/gallery images and
  parses merchant, date, total, tax/service rates, and line items.
- **LLM receipt parsing (BYOK)** — when a Gemini / OpenAI / Groq API key is
  configured, receipts are parsed by an LLM for far more accurate
  field extraction across arbitrary layouts, including **automatic
  category/subcategory classification** (with a keyword-based fallback
  when no key is set).
- **Chatbot** — ask natural-language questions about your own spending
  (backed by the same BYOK LLM providers).
- **Smart Insights** — transparent, rule-based anomaly detection over local
  transaction history: category spending spikes, unusually large
  transactions, possible duplicate charges, and frequently repeated
  merchants.

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart) |
| State management | Provider |
| Persistence | SQLite (`sqflite`), no backend server |
| OCR | Google ML Kit Text Recognition (on-device) |
| AI (optional, BYOK) | Google Gemini, OpenAI, or Groq |
| Cloud backup (optional) | Google Drive API |
| Secure storage | `flutter_secure_storage` (API keys) |

## Getting started

```bash
flutter pub get
flutter run
```

Requires Flutter (Dart SDK `^3.8.1`) and an Android device/emulator
(`minSdk 23`). No `.env` or backend setup is needed to use the app —
AI features are opt-in via **Settings → AI Provider**, where you can paste
your own API key for Gemini, OpenAI, or Groq (Groq is free and works without
a card). Google Drive backup is likewise opt-in via **Settings → Backup**.

### Building

```bash
flutter build apk --profile   # release build currently fails R8/ML-Kit shrinking
```

### Tests

```bash
flutter test
```

## Project structure

```
lib/
  constants/   Theme, category icon/colour presets, app-wide constants
  models/      Transaction, Account, CategoryModel, Goal, RecurringTransaction
  providers/   ChangeNotifier state: transactions, accounts, categories,
               budgets, goals, recurring, settings
  screens/     One file per screen (Home, Analytics, Chat, Settings, ...)
  services/    Database, OCR, AI, backup/Drive, insights, secure storage
  widgets/     Shared UI: pickers, tiles, glass/pressable/route components
assets/icons/  SVG glyphs for the 11 categories and 45 subcategories
```

