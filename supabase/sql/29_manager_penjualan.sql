-- =====================================================================
-- CN Air Mineral — Manager Pabrik boleh mencatat penjualan & penerimaan kas
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- =====================================================================

do $$
declare t text;
begin
  foreach t in array array['penjualan','pembayaran'] loop
    execute format('drop policy if exists baca_mgr on public.%I', t);
    execute format('create policy baca_mgr on public.%I for select to authenticated using (public.my_role() = ''manager'')', t);
    execute format('drop policy if exists tulis_mgr_ins on public.%I', t);
    execute format('drop policy if exists tulis_mgr_upd on public.%I', t);
    execute format('drop policy if exists tulis_mgr_del on public.%I', t);
    execute format('create policy tulis_mgr_ins on public.%I for insert to authenticated with check (public.my_role() = ''manager'')', t);
    execute format('create policy tulis_mgr_upd on public.%I for update to authenticated using (public.my_role() = ''manager'') with check (public.my_role() = ''manager'')', t);
    execute format('create policy tulis_mgr_del on public.%I for delete to authenticated using (public.my_role() = ''manager'')', t);
  end loop;
end $$;
