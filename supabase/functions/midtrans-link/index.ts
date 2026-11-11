import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (obj: any, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json', ...CORS } });
const N = (x: any) => Number(x) || 0;

// Membuat tautan pembayaran Midtrans untuk sisa tagihan satu invoice.
// Nominal default = sisa tagihan; boleh diisi lebih kecil (panjar), tidak boleh lebih besar.
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const auth = req.headers.get('Authorization') ?? '';
    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const sbUser = createClient(url, anon, { global: { headers: { Authorization: auth } } });
    const { data: ud } = await sbUser.auth.getUser();
    if (!ud?.user) return json({ error: 'Belum login' }, 401);
    const { data: prof } = await sbUser.from('profiles').select('role').eq('id', ud.user.id).single();
    if (!['owner', 'manager', 'sales'].includes(prof?.role)) return json({ error: 'Tidak punya izin' }, 403);

    const { no, nominal } = await req.json();
    const sb = createClient(url, service);
    const rows = async (t: string) => {
      const { data } = await sb.from(t).select('id,data');
      return (data ?? []).map((r: any) => ({ id: r.id, ...(r.data ?? {}) }));
    };
    const [pen, byr, pel] = await Promise.all([rows('penjualan'), rows('pembayaran'), rows('pelanggan')]);

    const inv: any = pen.find((p: any) => p.no === no);
    if (!inv) return json({ error: 'Invoice tidak ditemukan' }, 404);
    const bersih = N(inv.dus) * N(inv.harga) - N(inv.diskon) - N(inv.retur) * N(inv.harga);
    const dibayar = byr.filter((b: any) => b.ref === no).reduce((a: number, b: any) => a + N(b.nominal), 0);
    const sisa = bersih - dibayar;
    if (sisa <= 0) return json({ error: 'Invoice sudah lunas' }, 400);
    const nom = Math.round(Math.min(N(nominal) || sisa, sisa));
    if (nom <= 0) return json({ error: 'Nominal tidak valid' }, 400);

    const p: any = pel.find((x: any) => x.id === inv.pelanggan);
    let hp = String(p?.hp || '').replace(/\D/g, '');
    if (hp.startsWith('0')) hp = '62' + hp.slice(1);

    // pakai ulang tautan yang masih aktif (pending, nominal sama, belum 23 jam) supaya tidak ada banyak tautan untuk satu invoice
    const { data: aktif } = await sb.from('midtrans_order').select('*')
      .eq('no', no).eq('status', 'pending').eq('nominal', nom)
      .order('dibuat', { ascending: false }).limit(1);
    const lama: any = (aktif ?? [])[0];
    if (lama && lama.payment_url && Date.now() - new Date(lama.dibuat).getTime() < 23 * 3600e3) {
      return json({ url: lama.payment_url, order_id: lama.order_id, nominal: nom });
    }

    const orderId = String(no).replace(/[^A-Za-z0-9]/g, '').slice(0, 30) + '-' + Date.now().toString(36);
    const base = Deno.env.get('MIDTRANS_ENV') === 'production'
      ? 'https://api.midtrans.com' : 'https://api.sandbox.midtrans.com';

    const mt = await fetch(base + '/v1/payment-links', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        Authorization: 'Basic ' + btoa(Deno.env.get('MIDTRANS_SERVER_KEY') + ':'),
      },
      body: JSON.stringify({
        transaction_details: { order_id: orderId, gross_amount: nom },
        usage_limit: 1,
        expiry: { duration: 1, unit: 'days' },
        enabled_payments: ['qris', 'bank_transfer'],
        customer_details: {
          first_name: String(p?.nama || inv.pelNama || 'Pelanggan').slice(0, 40),
          email: 'cvqqekaputra@gmail.com',
          ...(hp ? { phone: '+' + hp } : {}),
        },
      }),
    });
    const j: any = await mt.json().catch(() => ({}));
    if (!mt.ok || !j.payment_url) {
      return json({ error: 'Midtrans: ' + (j.error_messages?.join(', ') || mt.status) }, 502);
    }

    await sb.from('midtrans_order').insert({ order_id: orderId, no, nominal: nom, payment_url: j.payment_url, status: 'pending' });
    return json({ url: j.payment_url, order_id: orderId, nominal: nom });
  } catch (e: any) {
    return json({ error: String(e?.message || e) }, 500);
  }
});
