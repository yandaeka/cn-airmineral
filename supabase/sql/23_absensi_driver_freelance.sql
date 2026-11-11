-- =====================================================================
-- CN Air Mineral — Izinkan driver, freelance & lab mencatat absensi
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- =====================================================================

update public.cn_akses set
  baca  = (select array_agg(distinct x) from unnest(baca  || '{driver,freelance,lab}'::text[]) x),
  tulis = (select array_agg(distinct x) from unnest(tulis || '{driver,freelance,lab}'::text[]) x)
where nama = 'absensi';

do $$
declare t record;
begin
  for t in select * from public.cn_akses where nama = 'absensi' loop
    execute format('drop policy if exists baca on public.%I',   t.nama);
    execute format('drop policy if exists tambah on public.%I', t.nama);
    execute format('drop policy if exists ubah on public.%I',   t.nama);
    execute format('drop policy if exists hapus on public.%I',  t.nama);
    execute format('create policy baca on public.%I for select to authenticated using (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.baca);
    execute format('create policy tambah on public.%I for insert to authenticated with check (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.tulis);
    execute format($p$create policy ubah on public.%I for update to authenticated
      using (public.is_owner() or (public.my_role() = any(%L::text[]) and created_by = auth.uid()
             and (created_at at time zone 'Asia/Makassar')::date = (now() at time zone 'Asia/Makassar')::date))
      with check (public.is_owner() or public.my_role() = any(%L::text[]))$p$, t.nama, t.tulis, t.tulis);
    execute format($p$create policy hapus on public.%I for delete to authenticated
      using (public.is_owner() or (public.my_role() = any(%L::text[]) and created_by = auth.uid()
             and (created_at at time zone 'Asia/Makassar')::date = (now() at time zone 'Asia/Makassar')::date))$p$, t.nama, t.tulis);
  end loop;
end $$;
