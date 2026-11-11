// Edge Function: laporan harian ke Telegram (jam 20.00 WITA dijadwalkan lewat pg_cron).
import { createClient } from 'npm:@supabase/supabase-js@2';

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const TG_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const TG_CHAT = Deno.env.get('TELEGRAM_CHAT_ID')!;

// tanggal hari ini di WITA (UTC+8)
const hariWita = () => new Date(Date.now() + 8 * 3600e3).toISOString().slice(0, 10);

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

async function ambil(tabel: string) {
  const { data, error } = await sb.from(tabel).select('id,data');
  if (error) throw new Error(`${tabel}: ${error.message}`);
  return (data ?? []).map((r: any) => ({ id: r.id, ...r.data }));
}
const n = (x: unknown) => Number(x) || 0;
const fmt = (x: number) => x.toLocaleString('id-ID', { maximumFractionDigits: 0 });
const catatLog = async (tanggal: string, status: string, pesan: string) => {
  try { await sb.from('laporan_harian_log').insert({ tanggal, status, pesan: pesan.slice(0, 500) }); } catch (_) { /* log best-effort */ }
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const tgl = hariWita();
  try {
    const [karyawan, produksi, dus, muatan, penjualan, absensi] = await Promise.all(
      ['karyawan', 'produksi', 'dus', 'muatan', 'penjualan', 'absensi'].map(ambil));

    // --- ringkasan angka (berdasarkan jumlah muatan dan nota) ---
    const prod = produksi.filter((r: any) => r.tanggal === tgl);
    const aktual = prod.reduce((a: number, r: any) => a + n(r.aktual), 0);
    const reject = prod.reduce((a: number, r: any) => a + n(r.reject), 0);
    const muatHari = muatan.filter((m: any) => m.tanggal === tgl);
    const selisih = muatan.filter((m: any) => m.status === 'Selesai' && n(m.selisih) > 0 && (m.tanggal === tgl || m.kembali_tgl === tgl)).length;

    const langsung = penjualan.filter((p: any) => p.dari_gudang).reduce((a: number, p: any) => a + n(p.dus) + n(p.bonus), 0);
    const dicetak = dus.filter((d: any) => d.status === 'Diproduksi').length;
    const dimuatSemua = muatan.reduce((a: number, m: any) => a + n(m.jumlah), 0);
    const kembaliSemua = muatan.reduce((a: number, m: any) => a + n(m.kembali), 0);
    const diGudang = Math.max(0, dicetak - dimuatSemua + kembaliSemua - langsung);
    const notaQty = (id: string) => penjualan.filter((p: any) => p.muatan_id === id).reduce((a: number, p: any) => a + n(p.dus) + n(p.bonus), 0);
    const diMobil = muatan.filter((m: any) => m.status !== 'Selesai')
      .reduce((a: number, m: any) => a + Math.max(0, n(m.jumlah) - notaQty(m.id)), 0);
    const terjualHari = penjualan.filter((p: any) => p.tanggal === tgl).reduce((a: number, p: any) => a + n(p.dus) + n(p.bonus), 0);

    // --- aktivitas per karyawan (nama dari kolom pencatat) ---
    const aktif = new Map<string, string[]>();
    const catat = (nama: string, teks: string) => {
      if (!nama) return;
      const k = nama.toUpperCase();
      aktif.set(k, [...(aktif.get(k) ?? []), teks]);
    };
    // absensi: kolom tanggal, nama, masuk (jam masuk), pulang (jam pulang)
    absensi.filter((a: any) => a.tanggal === tgl).forEach((a: any) =>
      catat(a.nama, `absen masuk ${a.masuk ?? '-'}${a.pulang ? ', pulang ' + a.pulang : ''}`));
    prod.forEach((r: any) => catat(r.dibuat_oleh, `produksi ${fmt(n(r.aktual))} dus`));
    prod.filter((r: any) => r.tds !== undefined && r.tds !== '').forEach((r: any) => catat(r.diubah_oleh || r.dibuat_oleh, 'uji QC'));
    muatHari.forEach((m: any) => catat(m.dibuat_oleh, `muatan ${m.kendaraan ?? ''}`));
    penjualan.filter((p: any) => p.tanggal === tgl).forEach((p: any) => catat(p.dibuat_oleh, 'penjualan'));

    // --- susun pesan (teks biasa) ---
    const baris: string[] = [];
    baris.push('LAPORAN HARIAN CN AIR MINERAL');
    baris.push(`Tanggal: ${tgl} (WITA)`);
    baris.push('');
    baris.push(`Produksi: ${fmt(aktual)} dus (reject ${fmt(reject)})`);
    baris.push(`Dus di gudang: ${fmt(diGudang)}`);
    baris.push(`Dus di mobil: ${fmt(diMobil)}`);
    baris.push(`Terjual hari ini: ${fmt(terjualHari)} dus`);
    baris.push(`Muatan dengan selisih: ${fmt(selisih)}`);
    baris.push('');
    baris.push('AKTIVITAS PER KARYAWAN');
    for (const k of karyawan) {
      const nama = String(k.nama ?? '').toUpperCase();
      const list = aktif.get(nama);
      baris.push(list ? `- ${k.nama}: ${[...new Set(list)].join(', ')}` : `- ${k.nama}: tidak ada aktivitas hari ini`);
    }

    const r = await fetch(`https://api.telegram.org/bot${TG_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: TG_CHAT, text: baris.join('\n') }),
    });
    const hasil = await r.json();
    if (!r.ok) throw new Error(`Telegram: ${JSON.stringify(hasil)}`);
    await catatLog(tgl, 'Terkirim', '');
    return new Response(JSON.stringify({ ok: true, tanggal: tgl }), { headers: { 'Content-Type': 'application/json', ...CORS } });
  } catch (e) {
    await catatLog(tgl, 'Gagal', String(e));
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json', ...CORS } });
  }
});
