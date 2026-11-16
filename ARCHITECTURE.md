# Architecture

```
Flutter app (all processing on device)
 ├─ presentation (screens, widgets)          ── Riverpod providers ──┐
 ├─ data (repositories, Supabase calls)      ◄──────────────────────┘
 └─ domain (pure Dart engines, no Flutter UI)
        │
        ▼
Supabase: Auth · PostgreSQL (RLS) · Storage (private bucket) · one RPC
```

No separate backend server and no Edge Functions: every calculation runs in Dart; Supabase stores data.

## Folder structure

```
lib/
  main.dart                     Supabase + SharedPreferences init, ProviderScope
  app/                          app.dart, router.dart (auth redirects), app_shell.dart (rail / bottom nav),
                                env.dart (client config), preferences.dart, theme/
  core/                         errors (AppException, describeError, guard), services (Supabase providers),
                                utils (formatters), widgets (AsyncView, cards, dialogs)
  shared/models/                metric_code.dart (taxonomy enum), models.dart (row models)
  features/
    authentication/             auth repository, login/register/forgot/reset, onboarding
    dashboard/                  home overview
    companies/                  repository + management screen
    analysis/                   analyses + reference data repositories, list, create, hub
    documents/                  storage upload/download + documents screen
    extraction/                 domain: taxonomy + statement parser; data: PDF/XLSX extraction (isolate)
    validation/                 metrics/periods repository + review grid
    financial_analysis/domain/  CalcResult, Formulas, CompanyFinancials, FinancialAnalysisEngine, IntegrityChecker
    forecasting/domain/         ForecastingEngine
    scoring/                    domain: ScoringEngine, VerdictEngine; presentation: weights editor
    comparison/                 domain: ComparisonEngine/Outcome; data: comparison provider; presentation: dashboard + charts
    reports/                    domain: ReportTables; data: PDF/XLSX exporter
    profile/                    profile & settings
```

## Data flow

1. **Auth** – `supabase_flutter` persists the session; `router.dart` redirects on auth changes and the
   `passwordRecovery` event.
2. **Create analysis** – inserts `analyses` + six `financial_periods` (2 companies × 3 years).
3. **Upload** – file bytes → Storage `financial-documents/{uid}/{analysis}/{company}/{year}_{uuid}.{ext}`;
   metadata row in `documents`. Orphaned objects are removed if the row insert fails.
4. **Extract** – `ExtractionService` runs in `compute()`; `StatementParser` maps rows to `MetricCode`s;
   results are upserted to `financial_metrics` as `pending` (validated values are never overwritten).
5. **Validate** – user edits/remaps/rejects; any change un-validates its period; “Confirm dataset” marks all
   pending values validated.
6. **Analyse** – `comparisonProvider` loads validated values → `ComparisonEngine.run` (analysis, forecasts,
   scores, verdict, integrity issues).
7. **Persist** – `save_analysis_results` RPC atomically replaces ratios, forecasts, scores and the result.
8. **Report** – `ReportTables` feed both the PDF and Excel exporters, so exports match the dashboard.

## Key decisions

- **State management:** Riverpod 3 (`Provider`, `FutureProvider(.family)`, `Notifier`). Invalidation after writes.
- **Engines are pure Dart** and independently tested; UI never computes figures.
- **Results are recomputed** from validated inputs rather than read back from result tables, which removes any
  chance of display/export drift; persisted results serve history, listing and audit.
- **Missing ≠ zero:** `CalcResult` carries a status (`ok`, `missing_input`, `zero_denominator`,
  `negative_denominator`, `not_meaningful`) through every layer, including the database.
