-- =====================================================================
-- CN Air Mineral — (1) Riwayat perubahan untuk semua data
--                  (2) Akun Lab / Penjamin Mutu hanya Uji QC dan Absensi
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- =====================================================================

-- (2) Peralatan dan sanitasi dikelola Produksi (owner tetap bisa melihat semua)
update public.cn_akses set baca = '{produksi}', tulis = '{produksi}' where nama in ('peralatan','sanitasi');

do $$
declare t record;
begin
  for t in select * from public.cn_akses where nama in ('peralatan','sanitasi') loop
    execute format('drop policy if exists baca on public.%I', t.nama);
    execute format('drop policy if exists tambah on public.%I', t.nama);
    execute format('drop policy if exists ubah on public.%I', t.nama);
    execute format('create policy baca on public.%I for select to authenticated using (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.baca);
    execute format('create policy tambah on public.%I for insert to authenticated with check (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.tulis);
    execute format('create policy ubah on public.%I for update to authenticated using (public.is_owner() or public.my_role() = any(%L::text[])) with check (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.tulis, t.tulis);
  end loop;
end $$;

-- (1) Catatan perubahan: setiap tambah, ubah, dan hapus di tabel data
create table if not exists public.cn_log (
  id        bigint generated always as identity primary key,
  tabel     text not null,
  rec_id    text,
  aksi      text not null,
  oleh_id   uuid,
  oleh_nama text,
  waktu     timestamptz not null default now(),
  sebelum   jsonb,
  sesudah   jsonb
);
alter table public.cn_log enable row level security;
drop policy if exists owner_baca on public.cn_log;
create policy owner_baca on public.cn_log for select to authenticated using (public.is_owner());
revoke all on public.cn_log from anon, authenticated;
grant select on public.cn_log to authenticated;
create index if not exists cn_log_waktu on public.cn_log(waktu desc);
create index if not exists cn_log_tabel on public.cn_log(tabel, waktu desc);

create or replace function public.cn_catat() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.cn_log(tabel, rec_id, aksi, oleh_id, oleh_nama, sebelum, sesudah)
  values (tg_table_name, coalesce(new.id, old.id), tg_op, auth.uid(),
          (select p.nama from public.profiles p where p.id = auth.uid()),
          case when tg_op <> 'INSERT' then old.data end,
          case when tg_op <> 'DELETE' then new.data end);
  return null;
end $$;

do $$
declare t record;
begin
  for t in select nama from public.cn_akses where nama <> 'keamanan' loop
    execute format('drop trigger if exists cn_catat_trg on public.%I', t.nama);
    execute format('create trigger cn_catat_trg after insert or update or delete on public.%I for each row execute function public.cn_catat()', t.nama);
  end loop;
end $$;

select 'Riwayat perubahan dan akses lab siap' as hasil;
