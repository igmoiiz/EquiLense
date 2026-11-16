-- Private bucket for original financial statements.
-- Object paths: {auth.uid()}/{analysis_id}/{company_id}/{year}_{uuid}.{ext}

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'financial-documents',
  'financial-documents',
  false,
  26214400, -- 25 MB
  array[
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "financial docs owner select" on storage.objects
  for select to authenticated
  using (bucket_id = 'financial-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "financial docs owner insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'financial-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "financial docs owner update" on storage.objects
  for update to authenticated
  using (bucket_id = 'financial-documents' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'financial-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "financial docs owner delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'financial-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
