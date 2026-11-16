# Testing

```bash
flutter analyze
```

```bash
flutter test
```

Result at last run: **analyzer – no issues; 105 tests passed** (the payload-dump tool test is skipped unless
`PAYLOAD_OUT` is set).

## Unit tests

| File | Covers |
|---|---|
| `test/financial_analysis/formulas_test.dart` | YoY, CAGR (elapsed periods, zero/negative/missing), vertical %, current & quick ratio, margins, ROE (closing vs average), D/E, interest coverage (bracketed costs, zero), normalization bands |
| `test/financial_analysis/engines_test.dart` | Analysis engine (sign normalization, derived GP, missing data, non-consecutive years), least squares, weighted growth (re-normalized weights, negative base), margin stability, insufficient history, scoring (weights sum, full/partial/incomplete, points ≤ max), verdict bands (10/5 boundaries), unsupported industry, insufficient data, integrity checks (currency mismatch, invalid values), RPC payload shape |
| `test/extraction/statement_parser_test.dart` | Synonym mapping, look-alike rejection (other income, deferred tax, NCI, EPS), confidence ordering, user mappings, bracket negatives, note/year column skipping, unit detection, full sample statement, empty/scanned text |
| `test/extraction/extraction_service_test.dart` | Generated PDF through Syncfusion (units, brackets, note column), blank PDF → scanned warning, XLSX with small values in millions, corrupt file |
| `test/widget/screens_test.dart` | Login validation, register, dashboard, new analysis, analysis hub, validation grid + edit dialog, all 7 results tabs, unsupported-industry results – each at 375 px and 1280 px with long company names (fails on any overflow) |
| `test/reports/report_exporter_test.dart` | PDF renders; Excel has the 7 required worksheets and score totals equal the engine; missing values not exported as 0; upload validation (xls, type, size, empty) |

Sample data in `test/fixtures/sample_financials.dart` is synthetic and labelled as such.

## Database / integration checks (performed against the live project, rolled back)

| Check | Expected | Result |
|---|---|---|
| User B lists companies of user A | 0 rows | 0 rows |
| User B creates analysis referencing user A's companies | rejected | FK violation (`analyses_company_a_id_user_id_fkey`) |
| Profile trigger on new auth user | 1 profile row | 1 |
| `save_analysis_results` with engine-generated payload (incl. null values / failed statuses) | rows inserted, verdict saved, status `completed` | as expected |
| Supabase security advisor | no findings | none |

## Manual UI checks (Chrome, release web build against the live project)

| Flow | Result |
|---|---|
| First launch → onboarding → register screen | Renders; routing correct |
| Sign-up request reaches Supabase and errors are surfaced | Supabase rejected the `.test` address; message shown in a snackbar |

### Not yet exercised end-to-end

Authenticated flows (company CRUD, upload, extraction from a real annual report, validation, results,
exports) have not been clicked through in the browser, because creating a confirmed test account requires
either custom SMTP / disabling email confirmation, or a manually confirmed user. Steps once an account exists:

1. Add two companies → create analysis → upload one PDF/XLSX per company-year.
2. Check extraction messages; open Review, correct values, confirm dataset.
3. Results: verify each tab, then export PDF and Excel and compare totals with the Scoring tab.
4. Sign in as a second user and confirm none of the first user's data is visible.

Automated Supabase integration tests are pending (see IMPLEMENTATION_PLAN.md).
