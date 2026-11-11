/* =========================================================
   HALAMAN KHUSUS VERSI WEB: Pengguna & Laporan Otomatis (owner)
   ========================================================= */
(function(){ const o=NAV.owner, i=o.findIndex(n=>n[0]==='master'); o.splice(i,0,['pengguna','Pengguna'],['otomatis','Laporan Otomatis'],['riwayat','Riwayat perubahan']); })();
const RPC={};   // cache hasil panggilan server per halaman
async function rpcLoad(key,fn,args){ RPC[key]={busy:true,...(RPC[key]||{})}; try{ const {data,error}=await SB.rpc(fn,args||{}); if(error)throw error; RPC[key]={data,at:Date.now()} }catch(e){ RPC[key]={err:sbErr(e),data:RPC[key]?.data} } bump(); }
async function rpcDo(fn,args){ const {data,error}=await SB.rpc(fn,args||{}); if(error)throw error; return data; }
const ROLE_OPT=[['sales','Sales'],['gudang','Gudang'],['produksi','Produksi'],['lab','Lab / Penjamin Mutu'],['freelance','Freelance (bantu produksi)'],['driver','Driver'],['komisaris','Komisaris'],['manager','Manager Pabrik'],['owner','Owner']];
const namaKaryawan=()=>D.karyawan.filter(k=>k.aktif!==false).map(k=>String(k.nama).toUpperCase()).sort();

V.pengguna=()=>{
  if(!RPC.pg||(!RPC.pg.busy&&!RPC.pg.data&&!RPC.pg.err))rpcLoad('pg','cn_daftar_pengguna');
  const r=RPC.pg||{}; const rows=r.data||[]; const tanpa=rows.filter(x=>!x.role);
  return head('Pengguna','Akun untuk masuk ke aplikasi. Nama pengguna dipakai saat login (tanpa @cn.local). Kata sandi tidak bisa dilihat siapa pun — kalau lupa, buat password baru.',`<button class="btn pri" data-act="pgBaru">+ Pengguna baru</button>`)+
  (r.err?`<div class="note warn">Gagal memuat: ${esc(r.err)} Pastikan file 04_bulan1.sql sudah dijalankan di Supabase.</div>`:'')+
  (tanpa.length?`<div class="note warn">${tanpa.length} akun belum diberi peran sehingga belum bisa membuka data. Tekan “Atur” untuk memberi nama dan peran.</div>`:'')+
  `<div class="kpis">${kpi('Akun aktif',rows.filter(x=>x.aktif&&x.role).length,'','hl')}${ROLE_OPT.map(([k,l])=>kpi(l,rows.filter(x=>x.role===k&&x.aktif).length)).join('')}</div>`+
  (r.busy&&!r.data?'<div class="loading">Memuat…</div>':tbl([
    {h:'Nama',f:x=>`<b>${esc(x.nama||'—')}</b>${x.id===ME?.uid?'<span class="sub">akun Anda</span>':''}`},
    {h:'Nama pengguna',f:x=>`<span class="mono">${esc(x.username)}</span>`},
    {h:'Peran',f:x=>x.role?esc(ROLE_LBL[x.role]||x.role):chip('Belum diatur','warn')},
    {h:'Status',f:x=>x.role?(x.aktif?chip('Aktif','ok'):chip('Nonaktif','bad')):'–'},
    {h:'Terakhir masuk',f:x=>x.terakhir_login?esc(new Date(x.terakhir_login).toLocaleString('id-ID',{dateStyle:'medium',timeStyle:'short'})):'<span class="muted">belum pernah</span>'},
    {h:'',c:'act',f:x=>`<button class="btn sm ${x.role?'ghost':'pri'}" data-act="pgAtur" data-id="${x.id}">${x.role?'Ubah':'Atur'}</button> <button class="btn sm ghost" data-act="pgPw" data-id="${x.id}">Kata sandi baru</button>`}
  ],rows,{empty:'Belum ada akun.'}))+
  `<p class="muted" style="font-size:12.5px;margin-top:12px">Nama sales harus sama persis dengan nama di Master Data → Karyawan (${esc(namaKaryawan().join(', ')||'belum ada')}) agar nota dan piutangnya tampil di HP sales tersebut. Karyawan yang keluar cukup dinonaktifkan; datanya tetap tersimpan.</p>`;
};
function formPgBaru(){
  openForm({title:'Pengguna baru',values:{role:'sales'},
    fields:[{k:'nama',label:'Nama (sesuai data karyawan)',type:'text',req:1,full:1,hint:'Contoh: HERMAN. Untuk sales harus sama dengan nama di Karyawan.'},
      {k:'username',label:'Nama pengguna untuk login',type:'text',req:1,hint:'Huruf kecil tanpa spasi, mis. herman'},
      {k:'role',label:'Peran',type:'select',options:ROLE_OPT,ph:false},
      {k:'pw',label:'Kata sandi (min. 8 karakter)',type:'text',req:1,hint:'Catat dan berikan langsung ke orangnya.'}],
    onChange(v,api,ch){ if(ch==='nama'&&!v.username){} },
    async onSubmit(v){ try{ await rpcDo('cn_buat_pengguna',{p_username:v.username,p_nama:v.nama,p_role:v.role,p_password:v.pw}); }catch(e){ return 'Gagal: '+sbErr(e); }
      RPC.pg=null; bump(); },okMsg:'Pengguna dibuat — bisa langsung login'});
}
function formPgAtur(x){
  openForm({title:x.role?'Ubah pengguna '+x.username:'Atur akun '+x.username,values:{nama:x.nama||x.username.toUpperCase(),role:x.role||'sales',aktif:x.role?x.aktif:true},
    fields:[{k:'nama',label:'Nama',type:'text',req:1,full:1,hint:'Untuk sales harus sama dengan nama di Karyawan.'},{k:'role',label:'Peran',type:'select',options:ROLE_OPT,ph:false},
      {k:'aktif',type:'check',text:'Aktif (boleh masuk aplikasi)',full:1}],
    async onSubmit(v){ try{ await rpcDo('cn_atur_pengguna',{p_id:x.id,p_nama:v.nama,p_role:v.role,p_aktif:!!v.aktif}); }catch(e){ return 'Gagal: '+sbErr(e); } RPC.pg=null; bump(); },okMsg:'Pengguna diperbarui'});
}
function formPgPw(x){
  openForm({title:'Kata sandi baru untuk '+(x.nama||x.username),fields:[{k:'pw',label:'Kata sandi baru (min. 8 karakter)',type:'text',req:1,full:1,hint:'Berlaku langsung. Berikan ke orangnya secara pribadi, jangan lewat grup.'}],
    async onSubmit(v){ if(String(v.pw).length<8)return 'Kata sandi minimal 8 karakter.'; try{ await rpcDo('cn_reset_password',{p_id:x.id,p_password:v.pw}); }catch(e){ return 'Gagal: '+sbErr(e); } },okMsg:'Kata sandi baru tersimpan'});
}

V.otomatis=()=>{
  if(!RPC.tg||(!RPC.tg.busy&&!RPC.tg.data&&!RPC.tg.err))rpcLoad('tg','cn_status_telegram');
  if(!RPC.cd||(!RPC.cd.busy&&!RPC.cd.data&&!RPC.cd.err))rpcLoad('cd','cn_daftar_cadangan');
  if(!RPC.hr||(!RPC.hr.busy&&!RPC.hr.data&&!RPC.hr.err))rpcLoad('hr','cn_status_harian');
  const h=RPC.hr?.data||{}; const ter=h.terakhir; const fmtW=w=>new Date(w).toLocaleString('id-ID',{dateStyle:'medium',timeStyle:'short'});
  const stH=ter?(ter.status==='Terkirim'?chip('Terkirim','ok'):chip('Gagal','bad')):chip('Belum pernah','warn');
  const kartuHarian=`<div class="card"><h2>Laporan harian</h2>
    <div class="kpis" style="margin-bottom:10px">${kpi('Jadwal','20.00 WITA','','hl')}${kpi('Kiriman terakhir',ter?esc(fmtW(ter.waktu)):'–',stH)}</div>
    ${RPC.hr?.err?`<div class="note warn">Gagal memuat status: ${esc(RPC.hr.err)} Pastikan 20_laporan_harian_status.sql sudah dijalankan.</div>`:''}
    ${ter&&ter.status!=='Terkirim'?`<div class="note warn">Gagal kirim: <b>${esc(ter.pesan||'')}</b></div>`:''}
    <div class="acts"><button class="btn" data-act="hrUji">Kirim laporan uji</button></div>
    <p class="muted" style="font-size:13px;margin-bottom:0">Dikirim ke Telegram owner setiap hari jam 20.00 WITA. Tombol uji mengirim laporan hari ini sekarang.</p></div>`;
  const t=(RPC.tg?.data||[])[0]||{}; const cd=RPC.cd?.data||[];
  const st=t.kirim_terakhir?(t.status_terakhir===200?chip('Terkirim','ok'):t.status_terakhir?chip('Gagal ('+t.status_terakhir+')','bad'):chip('Menunggu jawaban','info')):chip('Belum pernah','warn');
  const errTg=t.status_terakhir&&t.status_terakhir!==200?(()=>{try{return JSON.parse(t.pesan_terakhir).description}catch(e){return t.pesan_terakhir}})():'';
  return head('Laporan Otomatis','Ringkasan mingguan dikirim ke Telegram setiap Senin 07.00 WITA, dan cadangan data dibuat otomatis setiap Senin 06.00 WITA.')+
  ((RPC.tg?.err||RPC.cd?.err)?`<div class="note warn">Gagal memuat: ${esc(RPC.tg?.err||RPC.cd?.err)} Pastikan file 04_bulan1.sql sudah dijalankan di Supabase.</div>`:'')+
  `<div class="grid g2"><div class="card"><h2>Telegram</h2>
    <div class="kpis" style="margin-bottom:10px">${kpi('Status',t.ada_token&&t.chat_id?(t.aktif?'Aktif':'Dimatikan'):'Belum diatur','',t.ada_token&&t.chat_id&&t.aktif?'hl':'')}${kpi('Kiriman terakhir',t.kirim_terakhir?esc(new Date(t.kirim_terakhir).toLocaleString('id-ID',{dateStyle:'medium',timeStyle:'short'})):'–',st)}</div>
    ${errTg?`<div class="note warn">Telegram menolak: <b>${esc(errTg)}</b>. ${/chat not found/i.test(errTg)?'Buka bot Anda di Telegram dan tekan Start, lalu periksa chat ID.':/unauthorized|not found/i.test(errTg)?'Periksa token bot.':''}</div>`:''}
    <div class="acts"><button class="btn pri" data-act="tgAtur">${t.ada_token?'Ubah pengaturan':'Atur Telegram'}</button><button class="btn" data-act="tgUji" ${t.ada_token&&t.chat_id?'':'disabled'}>Kirim laporan uji</button><button class="btn ghost" data-act="tgLihat">Lihat isi laporan</button></div>
    <details style="margin-top:12px"><summary style="cursor:pointer;font-weight:600">Cara mendapatkan token & chat ID</summary><ol style="font-size:13px;line-height:1.6;padding-left:18px">
      <li>Di Telegram, cari <b>@BotFather</b> → kirim <span class="mono">/newbot</span> → beri nama (mis. <i>CN Laporan</i>) dan username yang berakhiran <i>bot</i> (mis. <i>cnqqeka_bot</i>).</li>
      <li>BotFather membalas dengan <b>token</b> (panjang, ada tanda titik dua). Salin ke kolom Token.</li>
      <li>Cari bot baru Anda di Telegram, buka, tekan <b>Start</b>. Tanpa ini bot tidak boleh mengirim pesan ke Anda.</li>
      <li>Cari <b>@userinfobot</b> → tekan Start → salin angka <b>Id</b> ke kolom Chat ID.</li>
      <li>Simpan, lalu tekan <b>Kirim laporan uji</b>. Laporan harus masuk dalam beberapa detik.</li>
      <li>Ingin dikirim ke grup (mis. owner + manajer)? Masukkan bot ke grup, kirim satu pesan di grup, lalu minta bantuan untuk mengambil chat ID grup (diawali tanda minus).</li></ol></details>
  </div>
  ${kartuHarian}
  <div class="card"><h2>Cadangan otomatis</h2><p class="muted" style="font-size:13px;margin-top:0">Salinan seluruh data disimpan di database setiap minggu (8 minggu terakhir). Bila ada data terhapus tidak sengaja, data bisa dipulihkan dari salinan ini. Untuk salinan di luar server, unduh juga Excel secara berkala.</p>
    ${tbl([{h:'Waktu',f:r=>esc(new Date(r.waktu).toLocaleString('id-ID',{dateStyle:'medium',timeStyle:'short'}))},{h:'Tabel',c:'num',f:r=>r.jumlah_tabel},{h:'Baris data',c:'num',f:r=>nf(r.jumlah_baris,0)}],cd.slice(0,8),{empty:'Belum ada cadangan.'})}
    <div class="acts" style="margin-top:10px"><button class="btn" data-act="cdBuat">Buat cadangan sekarang</button><button class="btn ghost" data-act="backup">Unduh Excel</button></div></div></div>
  `;
};
function formTgAtur(){
  const t=(RPC.tg?.data||[])[0]||{};
  openForm({title:'Pengaturan Telegram',values:{token:'',chat:t.chat_id||'',url:t.app_url||location.origin,aktif:t.aktif!==false},
    fields:[{k:'token',label:'Token bot',type:'password',req:!t.ada_token,full:1,ph:t.ada_token?'tersimpan (…'+t.token_akhir+') — kosongkan bila tidak diganti':'123456789:AA…',hint:t.ada_token?'Kosongkan bila tidak ingin mengganti token.':''},
      {k:'chat',label:'Chat ID',type:'text',req:1,hint:'Angka dari @userinfobot, atau ID grup (diawali minus).'},
      {k:'url',label:'Alamat aplikasi (untuk link di laporan)',type:'text',full:1},
      {k:'aktif',type:'check',text:'Kirim otomatis setiap Senin 07.00 WITA',full:1}],
    async onSubmit(v){ try{ await rpcDo('cn_atur_telegram',{p_token:v.token||'',p_chat_id:v.chat,p_app_url:v.url,p_aktif:!!v.aktif}); }catch(e){ return 'Gagal: '+sbErr(e); } RPC.tg=null; bump(); },okMsg:'Pengaturan Telegram tersimpan'});
}
Object.assign(ACT,{
  pgBaru:()=>formPgBaru(),
  pgAtur:d=>{const x=(RPC.pg?.data||[]).find(r=>r.id===d.id);if(x)formPgAtur(x)},
  pgPw:d=>{const x=(RPC.pg?.data||[]).find(r=>r.id===d.id);if(x)formPgPw(x)},
  tgAtur:()=>formTgAtur(),
  tgUji:async()=>{ try{ await rpcDo('cn_kirim_laporan',{}); toast('Laporan dikirim — cek Telegram'); setTimeout(()=>{RPC.tg=null;bump()},4000); }catch(e){ toast('Gagal: '+sbErr(e),'bad'); } },
  hrUji:async()=>{ try{ const {data,error}=await SB.functions.invoke('laporan-harian',{body:{uji:true}}); if(error)throw error; if(data&&data.ok===false)throw new Error(data.error||'gagal'); toast('Laporan harian dikirim — cek Telegram'); setTimeout(()=>{RPC.hr=null;bump()},3000); }catch(e){ toast('Gagal: '+sbErr(e),'bad'); } },
  tgLihat:async()=>{ try{ const t=await rpcDo('cn_pratinjau_laporan',{});
      openModal(`<div class="mh"><h3>Isi laporan minggu lalu</h3><button class="btn sm ghost" data-act="close" aria-label="Tutup">✕</button></div><div class="mb"><div class="full"><div style="white-space:pre-wrap;font-size:13.5px;line-height:1.5">${String(t||'').replace(/<(?!\/?b>)/g,'&lt;')}</div></div></div><div class="mf"><button class="btn" data-act="close">Tutup</button></div>`);
    }catch(e){ toast('Gagal: '+sbErr(e),'bad'); } },
  cdBuat:async()=>{ try{ const n=await rpcDo('cn_buat_cadangan_sekarang',{}); toast(`Cadangan dibuat (${nf(n,0)} baris)`); RPC.cd=null; bump(); }catch(e){ toast('Gagal: '+sbErr(e),'bad'); } },
  gantiPwSaya:()=>formGantiPwSB()
});

/* ---------- Riwayat perubahan (log tiap tambah, ubah, hapus) — owner ---------- */
let LOG={};
async function loadLog(){
  const tab=F.log_tab||''; LOG={busy:true,tab}; bump();
  try{
    let q=SB.from('cn_log').select('waktu,tabel,rec_id,aksi,oleh_nama,sebelum,sesudah').order('waktu',{ascending:false}).limit(300);
    if(tab) q=q.eq('tabel',tab);
    const {data,error}=await q; if(error) throw error;
    LOG={tab,data:data||[]};
  }catch(e){ LOG={tab,err:sbErr(e)}; }
  bump();
}
const LOG_ABAIKAN=['dibuat_pada','dibuat_oleh','diubah_pada','diubah_oleh'];
const logNilai=v=>{ if(v==null||v==='') return '–'; const t=typeof v==='object'?JSON.stringify(v):String(v); return t.length>60?t.slice(0,57)+'…':t; };
function logPerubahan(r){
  if(r.aksi==='INSERT'){ const d=r.sesudah||{}; return Object.keys(d).filter(k=>!LOG_ABAIKAN.includes(k)).slice(0,6).map(k=>`${esc(k)}: ${esc(logNilai(d[k]))}`).join(' · ')||'data baru'; }
  if(r.aksi==='DELETE') return 'data dihapus';
  const a=r.sebelum||{}, b=r.sesudah||{}; const ks=[...new Set([...Object.keys(a),...Object.keys(b)])].filter(k=>!LOG_ABAIKAN.includes(k));
  const ch=ks.filter(k=>JSON.stringify(a[k]??null)!==JSON.stringify(b[k]??null));
  return ch.length? ch.slice(0,8).map(k=>`${esc(k)}: ${esc(logNilai(a[k]))} → <b>${esc(logNilai(b[k]))}</b>`).join('<br>') : 'tidak ada isi yang berubah';
}
V.riwayat=()=>{
  if(!LOG.busy && (LOG.tab!==(F.log_tab||'') || (!LOG.data && !LOG.err))) loadLog();
  let body;
  if(LOG.err) body=`<div class="note warn">Gagal memuat riwayat: ${esc(LOG.err)} Pastikan 12_audit_dan_lab.sql sudah dijalankan di Supabase.</div>`;
  else if(LOG.busy||!LOG.data) body='<p class="muted">Memuat riwayat…</p>';
  else body=tbl([
      {h:'Waktu',f:r=>`${tgl(String(r.waktu).slice(0,10))}<span class="sub">${lvJam(r.waktu)}</span>`},
      {h:'Data',f:r=>esc((TBL[r.tabel]||r.tabel))},
      {h:'Aksi',f:r=>r.aksi==='INSERT'?chip('Tambah','ok'):r.aksi==='DELETE'?chip('Hapus','bad'):chip('Ubah','info')},
      {h:'Oleh',f:r=>esc(r.oleh_nama||'–')},
      {h:'Perubahan',f:r=>`<span style="font-size:12.5px">${logPerubahan(r)}</span>`}
    ], LOG.data, {empty:'Belum ada perubahan tercatat.'});
  return head('Riwayat perubahan','Setiap tambah, ubah, dan hapus tercatat: siapa, kapan, dan apa yang berubah. Menampilkan 300 perubahan terakhir sesuai filter.',
    selF('log_tab','Data',[['','Semua data'],...Object.entries(TBL).filter(([k])=>k!=='keamanan')])+`<button class="btn ghost" data-act="logMuat">Muat ulang</button>`)+
    `<div class="card">${body}</div>`;
};
ACT.logMuat=()=>loadLog();
