-- =====================================================================
-- CN Air Mineral — Checklist sanitasi ruang (pengisian & laboratorium)
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- Baca: owner, produksi (Kepala Produksi), lab. Catat/centang: produksi, lab, owner.
-- Acuan: PM.8.5 dan PK.8.5.01. Satu catatan per hari (id = tanggal).
-- =====================================================================
insert into public.cn_akses(nama, baca, tulis) values ('sanitasi', '{produksi,lab}', '{produksi,lab}')
on conflict (nama) do update set baca = excluded.baca, tulis = excluded.tulis;

do $$
declare t record;
begin
  for t in select * from public.cn_akses where nama = 'sanitasi' loop
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
    execute format('create index if not exists %1$s_tgl on public.%1$I ((data->>''tanggal''))', t.nama);

    execute format('drop policy if exists baca on public.%I',   t.nama);
    execute format('drop policy if exists tambah on public.%I', t.nama);
    execute format('drop policy if exists ubah on public.%I',   t.nama);
    execute format('drop policy if exists hapus on public.%I',  t.nama);

    execute format('create policy baca on public.%I for select to authenticated using (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.baca);
    execute format('create policy tambah on public.%I for insert to authenticated with check (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.tulis);
    execute format($p$create policy ubah on public.%I for update to authenticated
      using (public.is_owner() or public.my_role() = any(%L::text[]))
      with check (public.is_owner() or public.my_role() = any(%L::text[]))$p$, t.nama, t.tulis, t.tulis);
    execute format($p$create policy hapus on public.%I for delete to authenticated
      using (public.is_owner())$p$, t.nama);
  end loop;
end $$;

grant select, insert, update, delete on public.sanitasi to authenticated;
revoke all on public.sanitasi from anon;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='sanitasi') then
    alter publication supabase_realtime add table public.sanitasi;
  end if;
end $$;

select 'Checklist sanitasi siap' as hasil;
