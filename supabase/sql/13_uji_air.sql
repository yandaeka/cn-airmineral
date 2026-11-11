-- =====================================================================
-- CN Air Mineral — Uji QC air baku dan air setengah jadi (PK.8.5.01)
-- Air baku  : diuji tiap hari sebelum produksi (visual + TDS + pH)
-- Air setengah jadi: diuji selama proses, setelah sand & carbon filter
-- Produk jadi tetap dicatat per batch di menu Produksi.
-- Lab mencatat; Produksi dan owner bisa melihat. Jalankan sekali. Aman diulang.
-- =====================================================================
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


insert into public.cn_akses(nama, baca, tulis) values ('uji_air', '{produksi,lab}', '{lab}')
on conflict (nama) do update set baca = excluded.baca, tulis = excluded.tulis;

do $$
declare t record;
begin
  for t in select * from public.cn_akses where nama = 'uji_air' loop
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
    execute format('drop trigger if exists cn_catat_trg on public.%I', t.nama);
    execute format('create trigger cn_catat_trg after insert or update or delete on public.%I for each row execute function public.cn_catat()', t.nama);
    execute format('drop policy if exists baca on public.%I', t.nama);
    execute format('drop policy if exists tambah on public.%I', t.nama);
    execute format('drop policy if exists ubah on public.%I', t.nama);
    execute format('drop policy if exists hapus on public.%I', t.nama);
    execute format('create policy baca on public.%I for select to authenticated using (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.baca);
    execute format('create policy tambah on public.%I for insert to authenticated with check (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.tulis);
    execute format('create policy ubah on public.%I for update to authenticated using (public.is_owner() or public.my_role() = any(%L::text[])) with check (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.tulis, t.tulis);
    execute format('create policy hapus on public.%I for delete to authenticated using (public.is_owner())', t.nama);
  end loop;
end $$;

grant select, insert, update, delete on public.uji_air to authenticated;
revoke all on public.uji_air from anon;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='uji_air') then
    alter publication supabase_realtime add table public.uji_air;
  end if;
end $$;

select 'Uji QC air siap' as hasil;
