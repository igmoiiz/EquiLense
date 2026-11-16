# EquiLense – PSX Financial Intelligence & Comparison System

Flutter application that compares the financial performance of two Pakistan Stock Exchange (PSX) listed
companies from three years of their own financial statements. Supabase is the only backend.

> The original product specification is preserved in [docs/SPEC.md](docs/SPEC.md).

## Features

- **Accounts** – registration, login, logout, password reset (email link), profile, settings (Supabase Auth).
- **Companies** – add, edit, search, delete and reuse companies (name, PSX ticker, industry, sector, exchange).
- **Analyses** – pick two companies, an industry and the first of three financial years; editable scoring weights.
- **Documents** – upload PDF/XLSX statements per company-year to a private Supabase Storage bucket; type and
  size validation, progress, preview, replace, delete. Legacy `.xls` is rejected with guidance.
- **Extraction** – on-device text extraction (PDF via Syncfusion, XLSX via `excel`) in a background isolate,
  mapped to a 24-field standardized taxonomy with synonyms, exclusion rules, confidence scores and unit
  detection ("Rupees in '000" etc.). Scanned PDFs are detected and routed to manual entry.
- **Validation** – review grid per company/year: edit, add, reject, remove, re-map (remembered per user),
  integrity checks, explicit dataset confirmation.
- **Analysis engine (pure Dart)** – horizontal (YoY, CAGR), vertical (% of revenue), 10 ratios,
  data-integrity checks; missing data is never treated as zero.
- **Forecasting** – least-squares trend, weighted moving growth, margin-stability projections for year 4.
- **Scoring & verdict** – transparent weighted 100-point model, industry weights, incomplete-data handling,
  decision rules (recommend / tie / inconclusive / insufficient data / unsupported industry) with explanations.
- **Dashboard** – overview, growth, ratios, cash flow, forecast, scoring and verdict tabs with fl_chart charts.
- **Reports** – PDF and Excel (7 worksheets) exports built from the same tables the dashboard shows.

## Technology

Flutter 3.47 / Dart 3.13 · Material 3 · Riverpod 3 · go_router · fl_chart · supabase_flutter ·
syncfusion_flutter_pdf · excel · pdf · file_picker · file_saver.

## Setup

1. Install Flutter (stable ≥ 3.47), then run `flutter pub get`.
2. Supabase project **EquiLense** (`oilfsgaelmnzdubiolgu`) is already provisioned with all migrations in
   [`supabase/migrations`](supabase/migrations) and is the default in `lib/app/env.dart`. To use another
   project, apply those SQL files in order and pass `--dart-define=SUPABASE_URL=…` and
   `--dart-define=SUPABASE_PUBLISHABLE_KEY=…`. Only the publishable key belongs in the app.
3. Supabase dashboard → Authentication → URL configuration: set the **Site URL** to where the web app is
   hosted and add redirect URLs `http://localhost:8080` and `com.equilense.equilense://auth-callback`.
4. Email: the built-in Supabase mailer only delivers to project team members and is rate-limited. Configure
   custom SMTP (Authentication → SMTP) before inviting users, or disable "Confirm email" during development.

## Run

```bash
flutter run -d chrome
```

Release web build: `flutter build web`, then serve `build/web` (a launch config for
`python -m http.server 8080` is in `.claude/launch.json`). iOS builds require macOS/Xcode.

## Tests

```bash
flutter analyze
```

```bash
flutter test
```

See [TESTING.md](TESTING.md).

## Documentation

[ARCHITECTURE](ARCHITECTURE.md) · [DATABASE](DATABASE.md) · [FINANCIAL_FORMULAS](FINANCIAL_FORMULAS.md) ·
[SECURITY](SECURITY.md) · [TESTING](TESTING.md) · [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md) · [CHANGELOG](CHANGELOG.md)

## Licensing note

`syncfusion_flutter_pdf` is distributed under the Syncfusion Community/Commercial licence: free under the
Community Licence thresholds, otherwise a commercial licence is required. It was chosen because it extracts
text in pure Dart on Android, iOS and Web. Alternatives (e.g. `pdfrx`, which wraps PDFium under a permissive
licence) avoid the licence condition but add native/WASM binaries; switching only affects
`lib/features/extraction/data/extraction_service.dart`. Confirm the licence fits before release.

> EquiLense compares reported financial fundamentals. It does not provide investment advice or valuations.
