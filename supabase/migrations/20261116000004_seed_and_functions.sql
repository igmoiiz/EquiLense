-- Reference data and transactional RPCs.

insert into public.industries (code, label, support_status, notes) values
  ('technology',        'Technology / SaaS',  'supported', 'Extra emphasis on gross margin and ROE.'),
  ('manufacturing',     'Manufacturing',      'supported', 'Extra emphasis on balance-sheet safety and asset turnover.'),
  ('capital_intensive', 'Capital Intensive',  'supported', 'Strongest emphasis on leverage and asset turnover.'),
  ('banking',           'Banking',            'specialized_unsupported',
     'Industrial ratios (current ratio, D/E, overhead) are not meaningful for banks. Specialised methodology pending.'),
  ('insurance',         'Insurance',          'specialized_unsupported',
     'Insurance requires combined-ratio / solvency-margin analysis. Specialised methodology pending.'),
  ('other',             'Other',              'supported', 'Base specification weights.')
on conflict (code) do nothing;

insert into public.industry_weights (industry, criterion, weight) values
  -- Base specification (section 8)
  ('other', 'revenue_growth', 25), ('other', 'return_on_equity', 25), ('other', 'overhead_efficiency', 20),
  ('other', 'balance_sheet_safety', 15), ('other', 'cash_flow_quality', 15),
  ('other', 'gross_margin', 0), ('other', 'asset_turnover', 0),
  -- Technology / SaaS
  ('technology', 'revenue_growth', 25), ('technology', 'return_on_equity', 25), ('technology', 'overhead_efficiency', 10),
  ('technology', 'balance_sheet_safety', 10), ('technology', 'cash_flow_quality', 15),
  ('technology', 'gross_margin', 15), ('technology', 'asset_turnover', 0),
  -- Manufacturing
  ('manufacturing', 'revenue_growth', 20), ('manufacturing', 'return_on_equity', 20), ('manufacturing', 'overhead_efficiency', 15),
  ('manufacturing', 'balance_sheet_safety', 20), ('manufacturing', 'cash_flow_quality', 15),
  ('manufacturing', 'gross_margin', 0), ('manufacturing', 'asset_turnover', 10),
  -- Capital intensive
  ('capital_intensive', 'revenue_growth', 15), ('capital_intensive', 'return_on_equity', 20), ('capital_intensive', 'overhead_efficiency', 10),
  ('capital_intensive', 'balance_sheet_safety', 25), ('capital_intensive', 'cash_flow_quality', 15),
  ('capital_intensive', 'gross_margin', 0), ('capital_intensive', 'asset_turnover', 15)
on conflict (industry, criterion) do nothing;

insert into public.metric_definitions (code, display_name, statement, sort_order) values
  ('TOTAL_REVENUE',          'Revenue',                          'income_statement', 10),
  ('COST_OF_SALES',          'Cost of Sales',                    'income_statement', 20),
  ('GROSS_PROFIT',           'Gross Profit',                     'income_statement', 30),
  ('ADMIN_EXPENSES',         'Administrative Expenses',          'income_statement', 40),
  ('SELLING_EXPENSES',       'Selling & Distribution Expenses',  'income_statement', 50),
  ('OPERATING_EXPENSES',     'Operating Expenses',               'income_statement', 60),
  ('OPERATING_PROFIT',       'Operating Profit',                 'income_statement', 70),
  ('FINANCE_COST',           'Finance Cost',                     'income_statement', 80),
  ('PROFIT_BEFORE_TAX',      'Profit Before Tax',                'income_statement', 90),
  ('TAX_EXPENSE',            'Tax Expense',                      'income_statement', 100),
  ('NET_PROFIT',             'Net Profit After Tax',             'income_statement', 110),
  ('CURRENT_ASSETS',         'Current Assets',                   'balance_sheet', 200),
  ('CASH_AND_EQUIVALENTS',   'Cash and Cash Equivalents',        'balance_sheet', 210),
  ('INVENTORY',              'Inventory',                        'balance_sheet', 220),
  ('TRADE_RECEIVABLES',      'Receivables',                      'balance_sheet', 230),
  ('TOTAL_ASSETS',           'Total Assets',                     'balance_sheet', 240),
  ('CURRENT_LIABILITIES',    'Current Liabilities',              'balance_sheet', 250),
  ('TOTAL_LIABILITIES',      'Total Liabilities',                'balance_sheet', 260),
  ('TOTAL_DEBT',             'Total Debt',                       'balance_sheet', 270),
  ('SHAREHOLDERS_EQUITY',    'Shareholders'' Equity',            'balance_sheet', 280),
  ('OPERATING_CASH_FLOW',    'Operating Cash Flow',              'cash_flow', 300),
  ('INVESTING_CASH_FLOW',    'Investing Cash Flow',              'cash_flow', 310),
  ('FINANCING_CASH_FLOW',    'Financing Cash Flow',              'cash_flow', 320),
  ('CAPITAL_EXPENDITURE',    'Capital Expenditure',              'cash_flow', 330)
on conflict (code) do nothing;

-- Atomically replaces all calculated outputs of one analysis.
-- SECURITY INVOKER: RLS still applies to every statement.
create or replace function public.save_analysis_results(p_analysis_id uuid, p_payload jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.analyses where id = p_analysis_id and user_id = (select auth.uid())
  ) then
    raise exception 'analysis not found' using errcode = 'P0002';
  end if;

  delete from public.financial_ratios where analysis_id = p_analysis_id;
  delete from public.forecasts        where analysis_id = p_analysis_id;
  delete from public.company_scores   where analysis_id = p_analysis_id;

  insert into public.financial_ratios
    (analysis_id, company_id, financial_year, ratio_code, ratio_value, calculation_status, note)
  select p_analysis_id, (r ->> 'company_id')::uuid, (r ->> 'financial_year')::int, r ->> 'ratio_code',
         (r ->> 'ratio_value')::numeric, r ->> 'calculation_status', r ->> 'note'
  from jsonb_array_elements(coalesce(p_payload -> 'ratios', '[]'::jsonb)) r;

  insert into public.forecasts
    (analysis_id, company_id, forecast_year, metric_code, forecast_value, forecasting_method, forecast_status, assumptions)
  select p_analysis_id, (f ->> 'company_id')::uuid, (f ->> 'forecast_year')::int, f ->> 'metric_code',
         (f ->> 'forecast_value')::numeric, f ->> 'forecasting_method', f ->> 'forecast_status',
         coalesce(f -> 'assumptions', '{}'::jsonb)
  from jsonb_array_elements(coalesce(p_payload -> 'forecasts', '[]'::jsonb)) f;

  insert into public.company_scores
    (analysis_id, company_id, criterion, weight, raw_metric_value, awarded_points, maximum_points, score_status, explanation)
  select p_analysis_id, (s ->> 'company_id')::uuid, s ->> 'criterion', (s ->> 'weight')::numeric,
         (s ->> 'raw_metric_value')::numeric, (s ->> 'awarded_points')::numeric, (s ->> 'maximum_points')::numeric,
         s ->> 'score_status', s ->> 'explanation'
  from jsonb_array_elements(coalesce(p_payload -> 'scores', '[]'::jsonb)) s;

  insert into public.analysis_results
    (analysis_id, company_a_score, company_b_score, verdict, explanation, details)
  values (
    p_analysis_id,
    (p_payload #>> '{result,company_a_score}')::numeric,
    (p_payload #>> '{result,company_b_score}')::numeric,
    p_payload #>> '{result,verdict}',
    p_payload #>> '{result,explanation}',
    coalesce(p_payload #> '{result,details}', '{}'::jsonb)
  )
  on conflict (analysis_id) do update set
    company_a_score = excluded.company_a_score,
    company_b_score = excluded.company_b_score,
    verdict         = excluded.verdict,
    explanation     = excluded.explanation,
    details         = excluded.details;

  update public.analyses
     set status = 'completed', scoring_weights = p_payload -> 'weights'
   where id = p_analysis_id;
end;
$$;

revoke execute on function public.save_analysis_results(uuid, jsonb) from public, anon;
grant execute on function public.save_analysis_results(uuid, jsonb) to authenticated;
