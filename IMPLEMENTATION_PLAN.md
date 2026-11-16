# Implementation Plan & Status

"Implemented" = code written, analyzer clean, unit/widget tested with provider overrides.
"Verified live" = clicked through against the real Supabase project.

| Phase | Scope | Status |
|---|---|---|
| 1 Foundation | Flutter project (Android, iOS, Web), Material 3 theme, Riverpod, go_router with auth guards, env config, Supabase project + migrations, auth | Implemented; DB verified live; onboarding + sign-up request verified live |
| 2 Companies & documents | Company CRUD/search, analysis creation (periods auto-created), private storage uploads with validation, progress, replace, delete, preview | Implemented; not yet verified live |
| 3 Extraction & validation | PDF (Syncfusion) + XLSX extraction in isolate, taxonomy with synonyms/exclusions/confidence, unit detection, user-learned mappings, review grid with edit/add/reject/remove/remap, integrity checks, dataset confirmation | Implemented; extraction tested on generated PDF/XLSX; not yet verified live |
| 4 Calculation engine | Horizontal, vertical, ratios, integrity checks, unit tests | Done |
| 5 Forecasting | Linear regression, weighted growth, margin stability, charts, assumptions | Done (engine); charts widget-tested |
| 6 Scoring | Weighted model, normalization bands, industry weights, editable weights, verdict rules, explanations | Done (engine); UI widget-tested |
| 7 Dashboard | Overview, growth, ratios, cash flow, forecast, scoring, verdict tabs | Implemented; widget-tested at 375/1280 px |
| 8 Reporting | PDF and 7-sheet Excel export, saved analyses, result persistence via RPC | Exporters tested; RPC verified live; file saving not yet verified on device |
| 9 Testing & finalization | 105 unit/widget tests, DB/RLS checks, docs | Partially done |

## Pending

- End-to-end authenticated run in the browser/device (needs a confirmed account – see TESTING.md).
- Automated Supabase integration tests against a dedicated test project or branch.
- Syncfusion licence decision (see README).
- Custom SMTP, Site URL / redirect URLs in Supabase dashboard (manual dashboard settings).
- Android release signing and application id (`com.example.equilense` currently); iOS build on macOS.

## Known limitations

- **Scanned PDFs**: no on-device OCR; detected and routed to manual entry.
- **Extraction heuristics**: takes the first numeric column after optional note references as the current
  year; multi-statement annual reports may contain several matches (highest confidence, first occurrence wins).
  Every value must be reviewed before analysis.
- **XLSX formulas**: cached formula results are not read; workbooks with formula-only cells need values pasted.
- **`.xls`** not supported (re-save as `.xlsx`).
- Banking/insurance scoring requires specialized methodology (not implemented, explicitly flagged).
- Upload progress is indeterminate (the Supabase Storage SDK does not expose byte progress).
- The web build runs PDF parsing on the main thread (`compute` has no isolates on web); large PDFs may pause the UI briefly.
