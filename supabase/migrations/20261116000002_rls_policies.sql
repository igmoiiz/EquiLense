-- Row Level Security: every user-owned table is restricted to its owner.

alter table public.industries         enable row level security;
alter table public.metric_definitions enable row level security;
alter table public.industry_weights   enable row level security;
alter table public.profiles           enable row level security;
alter table public.companies          enable row level security;
alter table public.analyses           enable row level security;
alter table public.documents          enable row level security;
alter table public.financial_periods  enable row level security;
alter table public.financial_metrics  enable row level security;
alter table public.metric_mappings    enable row level security;
alter table public.financial_ratios   enable row level security;
alter table public.forecasts          enable row level security;
alter table public.company_scores     enable row level security;
alter table public.analysis_results   enable row level security;

-- Reference data: read-only for signed-in users. Writes only via migrations.
create policy "industries readable" on public.industries
  for select to authenticated using (true);
create policy "metric definitions readable" on public.metric_definitions
  for select to authenticated using (true);
create policy "industry weights readable" on public.industry_weights
  for select to authenticated using (true);

-- Profiles: a user sees and edits only their own row. Rows are created by trigger.
create policy "own profile select" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "own profile update" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- Owner-only access for all user data tables.
do $$
declare
  t text;
begin
  foreach t in array array[
    'companies', 'analyses', 'documents', 'financial_periods', 'financial_metrics',
    'metric_mappings', 'financial_ratios', 'forecasts', 'company_scores', 'analysis_results'
  ]
  loop
    execute format(
      'create policy "owner select" on public.%1$I for select to authenticated using ((select auth.uid()) = user_id);
       create policy "owner insert" on public.%1$I for insert to authenticated with check ((select auth.uid()) = user_id);
       create policy "owner update" on public.%1$I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
       create policy "owner delete" on public.%1$I for delete to authenticated using ((select auth.uid()) = user_id);',
      t);
  end loop;
end;
$$;

-- Anonymous users get nothing.
revoke all on all tables in schema public from anon;
