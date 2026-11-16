# Database

Supabase project `EquiLense` (`oilfsgaelmnzdubiolgu`, ap-south-1, PostgreSQL 17).
Migrations (applied, in order): [`supabase/migrations`](supabase/migrations)

| File | Contents |
|---|---|
| `…0001_core_schema.sql` | Tables, constraints, indexes, triggers |
| `…0002_rls_policies.sql` | RLS on every table and owner-only policies |
| `…0003_storage.sql` | Private `financial-documents` bucket and storage policies |
| `…0004_seed_and_functions.sql` | Industries, industry weights, metric taxonomy, `save_analysis_results` RPC |

## Tables

| Table | Purpose | Key constraints |
|---|---|---|
| `industries` | Reference: industry code, label, `support_status` (`supported` / `specialized_unsupported`) | PK `code` |
| `metric_definitions` | Reference: 24 standardized metric codes (e.g. `TOTAL_REVENUE`, `NET_PROFIT`) | PK `code` |
| `industry_weights` | Reference: weight per (industry, criterion) | unique (industry, criterion) |
| `profiles` | One row per auth user (name, email, default currency), created by trigger | PK → `auth.users` |
| `companies` | User's companies | unique (user, ticker); unique (id, user_id) |
| `analyses` | Two companies, industry, first year, currency, status, weights snapshot | composite FKs to companies; `company_a ≠ company_b` |
| `documents` | Storage path + metadata per uploaded file | unique `storage_path`; file type/size checks |
| `financial_periods` | (analysis, company, year) with currency and validation flag | unique (analysis, company, year) |
| `financial_metrics` | Standardized value + original label/value, source document, confidence, entry source, validation status | unique (period, metric_code); `numeric(20,2)` |
| `metric_mappings` | User-learned label → metric mappings | unique (user, normalized_label) |
| `financial_ratios` | Calculated ratios with status | unique (analysis, company, year, ratio); `ok ⇔ value not null` |
| `forecasts` | Year-4 forecasts with method, status and assumptions (jsonb) | unique (analysis, company, metric, method) |
| `company_scores` | Per-criterion score with weight, raw value, points, status, explanation | unique (analysis, company, criterion); points ≤ max |
| `analysis_results` | Verdict, scores, explanation, details | unique (analysis) |

### Relationships and integrity

- Every user-owned table has `user_id default auth.uid()` and **composite foreign keys** `(x_id, user_id)` →
  `parent(id, user_id)`. A row can therefore never reference another user's company/analysis, independent of RLS.
- Triggers `assert_company_in_analysis` (documents, periods, ratios, forecasts, scores) ensure the company is
  one of the analysis's two companies; `assert_metric_matches_period` keeps metrics consistent with their period.
- Deleting an analysis cascades to all its rows; companies used by an analysis cannot be deleted (`restrict`).
- Every foreign key is indexed; `updated_at` maintained by trigger.

### RPC

`save_analysis_results(p_analysis_id uuid, p_payload jsonb)` – `SECURITY INVOKER` (RLS applies). In one
transaction it replaces ratios, forecasts and scores, upserts `analysis_results`, sets the analysis to
`completed` and stores the applied weights. Executable by `authenticated` only.

## Row Level Security

- RLS enabled on all 14 public tables.
- Reference tables: `select` for `authenticated` only; no write policies (changes via migrations).
- `profiles`: select/update own row (`id = auth.uid()`); inserts only via the `security definer` trigger.
- All other tables: separate select/insert/update/delete policies `(select auth.uid()) = user_id`.
- `anon` has no table privileges.
- Verified: a second user sees 0 of the first user's rows and cannot create an analysis referencing them
  (FK violation). Supabase security advisor: 0 findings.

## Storage

- Bucket `financial-documents`: private, 25 MB limit, MIME types `application/pdf` and XLSX only.
- Path: `{auth.uid()}/{analysis_id}/{company_id}/{year}_{uuid}.{ext}`.
- Policies (select/insert/update/delete) require `(storage.foldername(name))[1] = auth.uid()::text`.
- Files are accessed by authenticated download or 5-minute signed URLs; no public URLs.
