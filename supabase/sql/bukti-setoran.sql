insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bukti-setoran', 'bukti-setoran', false, 10485760, array['application/pdf','image/jpeg']);

create policy "bukti_setoran_baca" on storage.objects for select to authenticated
using (bucket_id = 'bukti-setoran' and (public.is_owner() or public.my_role() in ('manager','komisaris')));

create policy "bukti_setoran_tambah" on storage.objects for insert to authenticated
with check (bucket_id = 'bukti-setoran' and (public.is_owner() or public.my_role() = 'manager'));
