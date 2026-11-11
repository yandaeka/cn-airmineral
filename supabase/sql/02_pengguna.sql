-- =====================================================================
-- CN Air Mineral — daftarkan peran setiap pengguna (langkah 2)
-- 1) Buat dulu akunnya di Supabase → Authentication → Users → Add user
--    → "Create new user": isi email & password, CENTANG "Auto Confirm User".
--    Sales/gudang tidak perlu email asli; pakai pola  namapanggilan@cn.local
--    (mis. abdul@cn.local). Di aplikasi nanti cukup ketik "abdul" + password.
-- 2) Ubah daftar di bawah (email | nama | peran), lalu Run.
--    Nama sales HARUS sama persis dengan nama di Master Data → Karyawan.
--    Peran: owner, sales, gudang, produksi
-- Bisa dijalankan ulang kapan saja untuk menambah/mengubah pengguna.
-- =====================================================================
with daftar(email, nama, role) as (values
  ('owner@cn.local',      'OWNER',       'owner'),
  ('herman@cn.local',     'HERMAN',      'sales'),
  ('sukri@cn.local',      'SUKRI',       'sales'),
  ('badaruddin@cn.local', 'BADARUDDIN',  'sales'),
  ('gudang@cn.local',     'GUDANG',      'gudang'),
  ('produksi@cn.local',   'BADRUS ALI',  'produksi')
)
insert into public.profiles (id, nama, role, aktif)
select u.id, d.nama, d.role, true
from daftar d join auth.users u on lower(u.email) = lower(d.email)
on conflict (id) do update set nama = excluded.nama, role = excluded.role, aktif = true;

-- Cek hasil: semua akun & perannya (akun tanpa peran belum bisa membuka data)
select u.email, p.nama, p.role, p.aktif
from auth.users u left join public.profiles p on p.id = u.id
order by p.role nulls first, p.nama;

-- Menonaktifkan karyawan yang keluar (akses langsung tertutup):
-- update public.profiles set aktif = false where nama = 'NAMA KARYAWAN';
