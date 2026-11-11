-- =====================================================================
-- CN Air Mineral — Daftar peralatan, kalibrasi, dan catatan perawatan mesin
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- peralatan : owner, produksi, lab bisa baca; produksi & lab bisa mencatat/ubah
-- perawatan : owner, produksi, lab bisa baca; produksi bisa mencatat/ubah
-- Data awal: Daftar Peralatan Proses Produksi (14 jenis).
-- =====================================================================
insert into public.cn_akses(nama, baca, tulis) values
  ('peralatan', '{produksi,lab}', '{produksi,lab}'),
  ('perawatan', '{produksi,lab}', '{produksi}')
on conflict (nama) do update set baca = excluded.baca, tulis = excluded.tulis;

do $$
declare t record;
begin
  for t in select * from public.cn_akses where nama in ('peralatan','perawatan') loop
    execute format($f$
      create table if not exists public.%1$I (
        id         text primary key,
        data       jsonb not null default '{}'::jsonb,
        created_by uuid references auth.users(id) on delete set null,
        created_at timestamptz not null default now(),
        updated_by uuid references auth.users(id) on delete set null,
        updated_at timestamptz not null default now()
      )$f$, t.nama);
    execute format('alter table public.%I enable row level security', t.nama);
    execute format('drop trigger if exists cn_audit on public.%I', t.nama);
    execute format('create trigger cn_audit before insert or update on public.%I for each row execute function public.cn_audit()', t.nama);

    execute format('drop policy if exists baca on public.%I',   t.nama);
    execute format('drop policy if exists tambah on public.%I', t.nama);
    execute format('drop policy if exists ubah on public.%I',   t.nama);
    execute format('drop policy if exists hapus on public.%I',  t.nama);
    execute format('create policy baca on public.%I for select to authenticated using (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.baca);
    execute format('create policy tambah on public.%I for insert to authenticated with check (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.tulis);
    execute format('create policy ubah on public.%I for update to authenticated using (public.is_owner() or public.my_role() = any(%L::text[])) with check (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.tulis, t.tulis);
    execute format('create policy hapus on public.%I for delete to authenticated using (public.is_owner())', t.nama);
  end loop;
end $$;

grant select, insert, update, delete on public.peralatan, public.perawatan to authenticated;
revoke all on public.peralatan, public.perawatan from anon;

-- Data awal (aman dijalankan ulang: id tetap, tidak menimpa data yang sudah diubah)
insert into public.peralatan(id, data) values
 ('alat-01', '{"nama":"Tandon Air Jadi","jenis":"Proses","jumlah":6,"spesifikasi":"Covina","kondisi":"Baik"}'),
 ('alat-02', '{"nama":"Tandon Setengah Jadi","jenis":"Proses","jumlah":5,"spesifikasi":"Hydro Fill Tank","kondisi":"Baik"}'),
 ('alat-03', '{"nama":"Tandon Air Baku","jenis":"Proses","jumlah":3,"spesifikasi":"Hydro Fill Tank","kondisi":"Baik"}'),
 ('alat-04', '{"nama":"Mesin Cup Sealer","jenis":"Proses","jumlah":1,"spesifikasi":"Tongda","kondisi":"Baik"}'),
 ('alat-05', '{"nama":"Mesin RO","jenis":"Proses","jumlah":1,"spesifikasi":"Y2-112M-2 NFD","kondisi":"Baik","keterangan":"Spesifikasi perlu dicek ulang (terbaca seperti motor)"}'),
 ('alat-06', '{"nama":"Mesin UV","jenis":"Proses","jumlah":1,"spesifikasi":"ZWX-Q","kondisi":"Baik"}'),
 ('alat-07', '{"nama":"Pompa Air","jenis":"Proses","jumlah":1,"spesifikasi":"Shimizu","kondisi":"Baik"}'),
 ('alat-08', '{"nama":"Sand Filter","jenis":"Proses","jumlah":2,"spesifikasi":"","kondisi":"Baik"}'),
 ('alat-09', '{"nama":"Carbon Filter","jenis":"Proses","jumlah":2,"spesifikasi":"","kondisi":"Baik"}'),
 ('alat-10', '{"nama":"Carton Sealer","jenis":"Proses","jumlah":1,"spesifikasi":"Powerpack FXJ5050","kondisi":"Baik"}'),
 ('alat-11', '{"nama":"Compressor","jenis":"Proses","jumlah":1,"spesifikasi":"RYU","kondisi":"Baik"}'),
 ('alat-12', '{"nama":"Conveyor Belt","jenis":"Proses","jumlah":1,"spesifikasi":"HOULE 5GU25K-C12","kondisi":"Baik"}'),
 ('alat-13', '{"nama":"AC","jenis":"Proses","jumlah":1,"spesifikasi":"Panasonic","kondisi":"Baik"}'),
 ('alat-14', '{"nama":"Ozon Generator","jenis":"Proses","jumlah":1,"spesifikasi":"0Z-10G","kondisi":"Baik"}')
on conflict (id) do nothing;

select 'Peralatan dan perawatan siap' as hasil;
