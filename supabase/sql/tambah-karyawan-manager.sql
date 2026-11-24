create policy "tambah_karyawan_manager" on public.karyawan
for insert to authenticated
with check (
  public.my_role() = 'manager'
  and (data - array['nama','jabatan','status_kerja','catatan','sales','aktif']) = '{}'::jsonb
);
