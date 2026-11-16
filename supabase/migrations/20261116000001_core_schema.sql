-- EquiLense core schema
-- All user-owned tables carry user_id and composite foreign keys (id, user_id)
-- so that a row can never reference another user's data, even before RLS.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reference data (shared, read-only for clients)
-- ---------------------------------------------------------------------------
create table public.industries (
  code            text primary key check (code ~ '^[a-z_]+$'),
  label           text not null,
  support_status  text not null default 'supported'
                  check (support_status in ('supported', 'specialized_unsupported')),
  notes           text
);

create table public.metric_definitions (
  code          text primary key check (code ~ '^[A-Z_]+$'),
  display_name  text not null,
  statement     text not null check (statement in ('income_statement', 'balance_sheet', 'cash_flow')),
  sort_order    int  not null
);

create table public.industry_weights (
  id          uuid primary key default gen_random_uuid(),
  industry    text not null references public.industries (code) on delete cascade,
  criterion   text not null check (criterion in (
                'revenue_growth', 'return_on_equity', 'overhead_efficiency',
                'balance_sheet_safety', 'cash_flow_quality', 'gross_margin', 'asset_turnover')),
  weight      numeric(5,2) not null check (weight >= 0 and weight <= 100),
  updated_at  timestamptz not null default now(),
  unique (industry, criterion)
);

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  full_name         text check (char_length(full_name) <= 120),
  email             text,
  default_currency  char(3) not null default 'PKR',
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, nullif(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Companies
-- ---------------------------------------------------------------------------
create table public.companies (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  company_name   text not null check (char_length(trim(company_name)) between 1 and 160),
  ticker_symbol  text check (ticker_symbol ~ '^[A-Z0-9.]{1,12}$'),
  sector         text check (char_length(sector) <= 120),
  industry       text not null default 'other' references public.industries (code),
  description    text check (char_length(description) <= 2000),
  exchange       text not null default 'PSX' check (char_length(exchange) <= 40),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (id, user_id)
);

create unique index companies_user_ticker_uniq on public.companies (user_id, ticker_symbol)
  where ticker_symbol is not null;
create index companies_user_name_idx on public.companies (user_id, lower(company_name));
create index companies_industry_idx on public.companies (industry);

create trigger companies_updated_at before update on public.companies
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Analyses
-- ---------------------------------------------------------------------------
create table public.analyses (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null default auth.uid() references auth.users (id) on delete cascade,
  company_a_id          uuid not null,
  company_b_id          uuid not null,
  analysis_name         text not null check (char_length(trim(analysis_name)) between 1 and 160),
  industry              text not null default 'other' references public.industries (code),
  first_financial_year  int  not null check (first_financial_year between 1990 and 2100),
  currency              char(3) not null default 'PKR',
  status                text not null default 'draft'
                        check (status in ('draft', 'data_validated', 'completed', 'archived')),
  scoring_weights       jsonb,           -- snapshot of weights applied at last calculation
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (id, user_id),
  check (company_a_id <> company_b_id),
  foreign key (company_a_id, user_id) references public.companies (id, user_id) on delete restrict,
  foreign key (company_b_id, user_id) references public.companies (id, user_id) on delete restrict
);

create index analyses_user_created_idx on public.analyses (user_id, created_at desc);
create index analyses_company_a_idx on public.analyses (company_a_id, user_id);
create index analyses_company_b_idx on public.analyses (company_b_id, user_id);
create index analyses_industry_idx on public.analyses (industry);

create trigger analyses_updated_at before update on public.analyses
  for each row execute function public.set_updated_at();

-- Ensures company_id on child rows is one of the two companies of the analysis.
create or replace function public.assert_company_in_analysis()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.analyses a
    where a.id = new.analysis_id
      and new.company_id in (a.company_a_id, a.company_b_id)
  ) then
    raise exception 'company % is not part of analysis %', new.company_id, new.analysis_id
      using errcode = '23514';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Documents (files live in Storage; only metadata here)
-- ---------------------------------------------------------------------------
create table public.documents (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null default auth.uid() references auth.users (id) on delete cascade,
  analysis_id         uuid not null,
  company_id          uuid not null,
  file_name           text not null check (char_length(file_name) between 1 and 255),
  storage_path        text not null unique,
  file_type           text not null check (file_type in ('pdf', 'xlsx')),
  file_size_bytes     bigint not null check (file_size_bytes > 0),
  financial_year      int not null check (financial_year between 1990 and 2100),
  document_type       text not null default 'annual_report'
                      check (document_type in ('annual_report', 'income_statement', 'balance_sheet', 'cash_flow', 'other')),
  upload_status       text not null default 'uploaded'
                      check (upload_status in ('uploaded', 'extracted', 'extraction_failed')),
  extraction_message  text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (id, user_id),
  foreign key (analysis_id, user_id) references public.analyses (id, user_id) on delete cascade,
  foreign key (company_id, user_id) references public.companies (id, user_id) on delete cascade
);

create index documents_analysis_idx on public.documents (analysis_id, user_id);
create index documents_company_idx on public.documents (company_id, user_id);
create index documents_user_idx on public.documents (user_id);

create trigger documents_company_check before insert or update of company_id, analysis_id on public.documents
  for each row execute function public.assert_company_in_analysis();
create trigger documents_updated_at before update on public.documents
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Financial periods and standardized metrics
-- ---------------------------------------------------------------------------
create table public.financial_periods (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users (id) on delete cascade,
  analysis_id     uuid not null,
  company_id      uuid not null,
  financial_year  int not null check (financial_year between 1990 and 2100),
  currency        char(3) not null default 'PKR',
  is_validated    boolean not null default false,
  validated_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (analysis_id, company_id, financial_year),
  unique (id, user_id),
  foreign key (analysis_id, user_id) references public.analyses (id, user_id) on delete cascade,
  foreign key (company_id, user_id) references public.companies (id, user_id) on delete cascade
);

create index financial_periods_company_idx on public.financial_periods (company_id, user_id);
create index financial_periods_user_idx on public.financial_periods (user_id);
create index financial_periods_analysis_user_idx on public.financial_periods (analysis_id, user_id);

create trigger financial_periods_company_check before insert or update of company_id, analysis_id on public.financial_periods
  for each row execute function public.assert_company_in_analysis();
create trigger financial_periods_updated_at before update on public.financial_periods
  for each row execute function public.set_updated_at();

create table public.financial_metrics (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null default auth.uid() references auth.users (id) on delete cascade,
  analysis_id            uuid not null,
  company_id             uuid not null,
  financial_period_id    uuid not null,
  metric_code            text not null references public.metric_definitions (code),
  original_label         text check (char_length(original_label) <= 500),
  original_value         text check (char_length(original_value) <= 100),
  standardized_value     numeric(20,2),
  source_document_id     uuid references public.documents (id) on delete set null,
  extraction_confidence  numeric(4,3) check (extraction_confidence between 0 and 1),
  entry_source           text not null default 'manual' check (entry_source in ('pdf', 'excel', 'manual')),
  validation_status      text not null default 'pending'
                         check (validation_status in ('pending', 'validated', 'rejected')),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  unique (financial_period_id, metric_code),
  foreign key (financial_period_id, user_id) references public.financial_periods (id, user_id) on delete cascade,
  foreign key (analysis_id, user_id) references public.analyses (id, user_id) on delete cascade,
  foreign key (company_id, user_id) references public.companies (id, user_id) on delete cascade
);

create index financial_metrics_analysis_idx on public.financial_metrics (analysis_id, user_id);
create index financial_metrics_company_idx on public.financial_metrics (company_id, user_id);
create index financial_metrics_period_user_idx on public.financial_metrics (financial_period_id, user_id);
create index financial_metrics_source_doc_idx on public.financial_metrics (source_document_id);
create index financial_metrics_code_idx on public.financial_metrics (metric_code);
create index financial_metrics_user_idx on public.financial_metrics (user_id);

-- Keep metric analysis/company consistent with its period.
create or replace function public.assert_metric_matches_period()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.financial_periods p
    where p.id = new.financial_period_id
      and p.analysis_id = new.analysis_id
      and p.company_id = new.company_id
  ) then
    raise exception 'metric analysis/company does not match its financial period' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger financial_metrics_period_check
  before insert or update of financial_period_id, analysis_id, company_id on public.financial_metrics
  for each row execute function public.assert_metric_matches_period();
create trigger financial_metrics_updated_at before update on public.financial_metrics
  for each row execute function public.set_updated_at();

-- User-learned label -> metric mappings (built-in synonyms ship with the app).
create table public.metric_mappings (
  id                        uuid primary key default gen_random_uuid(),
  user_id                   uuid not null default auth.uid() references auth.users (id) on delete cascade,
  original_label            text not null check (char_length(original_label) between 1 and 500),
  normalized_label          text generated always as (lower(regexp_replace(trim(original_label), '\s+', ' ', 'g'))) stored,
  standardized_metric_code  text not null references public.metric_definitions (code),
  created_at                timestamptz not null default now(),
  unique (user_id, normalized_label)
);

create index metric_mappings_code_idx on public.metric_mappings (standardized_metric_code);

-- ---------------------------------------------------------------------------
-- Calculated outputs
-- ---------------------------------------------------------------------------
create table public.financial_ratios (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null default auth.uid() references auth.users (id) on delete cascade,
  analysis_id         uuid not null,
  company_id          uuid not null,
  financial_year      int not null check (financial_year between 1990 and 2100),
  ratio_code          text not null check (ratio_code ~ '^[a-z_]+$'),
  ratio_value         numeric(24,6),
  calculation_status  text not null check (calculation_status in
                      ('ok', 'missing_input', 'zero_denominator', 'negative_denominator', 'not_meaningful')),
  note                text,
  created_at          timestamptz not null default now(),
  unique (analysis_id, company_id, financial_year, ratio_code),
  check ((calculation_status = 'ok') = (ratio_value is not null)),
  foreign key (analysis_id, user_id) references public.analyses (id, user_id) on delete cascade,
  foreign key (company_id, user_id) references public.companies (id, user_id) on delete cascade
);

create index financial_ratios_company_idx on public.financial_ratios (company_id, user_id);
create index financial_ratios_analysis_user_idx on public.financial_ratios (analysis_id, user_id);
create index financial_ratios_user_idx on public.financial_ratios (user_id);

create trigger financial_ratios_company_check before insert on public.financial_ratios
  for each row execute function public.assert_company_in_analysis();

create table public.forecasts (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null default auth.uid() references auth.users (id) on delete cascade,
  analysis_id         uuid not null,
  company_id          uuid not null,
  forecast_year       int not null check (forecast_year between 1990 and 2100),
  metric_code         text not null references public.metric_definitions (code),
  forecast_value      numeric(20,2),
  forecasting_method  text not null check (forecasting_method in ('linear_regression', 'weighted_growth', 'margin_stability')),
  forecast_status     text not null default 'ok' check (forecast_status in ('ok', 'insufficient_data', 'not_meaningful')),
  assumptions         jsonb not null default '{}'::jsonb,
  created_at          timestamptz not null default now(),
  unique (analysis_id, company_id, metric_code, forecasting_method),
  check ((forecast_status = 'ok') = (forecast_value is not null)),
  foreign key (analysis_id, user_id) references public.analyses (id, user_id) on delete cascade,
  foreign key (company_id, user_id) references public.companies (id, user_id) on delete cascade
);

create index forecasts_company_idx on public.forecasts (company_id, user_id);
create index forecasts_analysis_user_idx on public.forecasts (analysis_id, user_id);
create index forecasts_metric_idx on public.forecasts (metric_code);
create index forecasts_user_idx on public.forecasts (user_id);

create trigger forecasts_company_check before insert on public.forecasts
  for each row execute function public.assert_company_in_analysis();

create table public.company_scores (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
  analysis_id       uuid not null,
  company_id        uuid not null,
  criterion         text not null,
  weight            numeric(5,2) not null check (weight between 0 and 100),
  raw_metric_value  numeric(24,6),
  awarded_points    numeric(6,2),
  maximum_points    numeric(6,2) not null check (maximum_points >= 0),
  score_status      text not null check (score_status in ('scored', 'incomplete')),
  explanation       text,
  created_at        timestamptz not null default now(),
  unique (analysis_id, company_id, criterion),
  check (awarded_points is null or awarded_points between 0 and maximum_points),
  check ((score_status = 'scored') = (awarded_points is not null)),
  foreign key (analysis_id, user_id) references public.analyses (id, user_id) on delete cascade,
  foreign key (company_id, user_id) references public.companies (id, user_id) on delete cascade
);

create index company_scores_company_idx on public.company_scores (company_id, user_id);
create index company_scores_analysis_user_idx on public.company_scores (analysis_id, user_id);
create index company_scores_user_idx on public.company_scores (user_id);

create trigger company_scores_company_check before insert on public.company_scores
  for each row execute function public.assert_company_in_analysis();

create table public.analysis_results (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
  analysis_id      uuid not null unique,
  company_a_score  numeric(6,2) check (company_a_score between 0 and 100),
  company_b_score  numeric(6,2) check (company_b_score between 0 and 100),
  verdict          text not null check (verdict in
                   ('recommend_a', 'recommend_b', 'tie_hold_both', 'inconclusive', 'insufficient_data', 'unsupported_industry')),
  explanation      text not null,
  details          jsonb not null default '{}'::jsonb,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  foreign key (analysis_id, user_id) references public.analyses (id, user_id) on delete cascade
);

create index analysis_results_analysis_user_idx on public.analysis_results (analysis_id, user_id);
create index analysis_results_user_idx on public.analysis_results (user_id, created_at desc);

create trigger analysis_results_updated_at before update on public.analysis_results
  for each row execute function public.set_updated_at();
