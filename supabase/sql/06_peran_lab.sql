-- =====================================================================
-- CN Air Mineral — Tambah peran "lab" (Penjamin Mutu, Lab)
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- =====================================================================
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('owner','sales','gudang','produksi','lab'));

-- daftar peran yang diizinkan di fungsi pengguna
do $$
declare f text;
begin
  select pg_get_functiondef('public.cn_buat_pengguna(text,text,text,text)'::regprocedure) into f;
  f := replace(f, $q$('owner','sales','gudang','produksi')$q$, $q$('owner','sales','gudang','produksi','lab')$q$);
  execute f;
  select pg_get_functiondef('public.cn_atur_pengguna(uuid,text,text,boolean)'::regprocedure) into f;
  f := replace(f, $q$('owner','sales','gudang','produksi')$q$, $q$('owner','sales','gudang','produksi','lab')$q$);
  execute f;
end $$;

-- hak baca & tulis peran lab
update public.cn_akses set baca = array_append(baca,'lab') where nama in ('pengaturan','produk','karyawan','bahan','produksi','pemakaian','absensi') and not ('lab' = any(baca));
update public.cn_akses set tulis = array_append(tulis,'lab') where nama = 'absensi' and not ('lab' = any(tulis));

-- terapkan ulang kebijakan akses untuk semua tabel dari cn_akses
do $$
declare t record;
begin
  for t in select * from public.cn_akses where nama <> 'absensi' loop
    execute format('drop policy if exists baca on public.%I', t.nama);
    execute format('drop policy if exists tambah on public.%I', t.nama);
    execute format('drop policy if exists ubah on public.%I', t.nama);
    execute format('drop policy if exists hapus on public.%I', t.nama);
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

select 'Peran lab siap' as hasil;
