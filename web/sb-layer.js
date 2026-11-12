const APP_VER = '2.77 · 12 Nov 2026';
/* =========================================================
   LAPISAN SUPABASE — login per pengguna, sinkron realtime,
   simpan offline (antrean) & cache lokal per pengguna
   ========================================================= */
const SB_URL='https://sybpqbtptschsszpmenv.supabase.co';
const SB_KEY='sb_publishable_eBKdzT6b7o9A3DDYst3P3Q_xWvRiGxD';
const SB_COLS=COLS.filter(c=>c!=='keamanan');
let RT_DOWN=false, SB=null, PROFILE=null, SBSTATE='connecting', LOGIN_ERR='', LOGIN_BUSY=false;
const QKEY='cn_queue_v1', CKEY='cn_cache_v1', PKEY='cn_profile_v1';
let Q=[]; try{Q=JSON.parse(localStorage.getItem(QKEY)||'[]')}catch(e){Q=[]}
const saveQ=()=>{try{localStorage.setItem(QKEY,JSON.stringify(Q))}catch(e){}};
let _ct=null; function saveCache(){ if(!PROFILE)return; clearTimeout(_ct); _ct=setTimeout(()=>{try{const o={};SB_COLS.forEach(c=>o[c]=D[c]);localStorage.setItem(CKEY+':'+PROFILE.id,JSON.stringify(o))}catch(e){}},700); }
function loadCache(){ try{const o=JSON.parse(localStorage.getItem(CKEY+':'+PROFILE.id)||'null');if(!o)return false;SB_COLS.forEach(c=>{if(Array.isArray(o[c]))D[c]=o[c]});return true}catch(e){return false} }
function applyLocal(op){ const a=D[op.col]; if(!a)return; if(op.t==='put'){const row={id:op.id,...op.data};const i=a.findIndex(r=>r.id===op.id);if(i>=0)a[i]=row;else a.push(row)} else D[op.col]=a.filter(r=>r.id!==op.id); }
const isNetErr=e=>!navigator.onLine||(!e?.code&&/fetch|network|load failed|timeout/i.test(String(e?.message||e||'')));
async function sendOp(op){ const tb=SB.from(op.col); const {error}=op.t==='put'?await tb.upsert({id:op.id,data:op.data}):await tb.delete().eq('id',op.id); if(error)throw error;  if(op.col!=='log_aktivitas')catatLog(op.t==='put'?'Simpan':'Hapus', (typeof TBL!=='undefined'&&TBL[op.col])||op.col); }
function catatLog(aksi,detail){ try{ if(!SB||!PROFILE||!navigator.onLine)return; SB.from('log_aktivitas').insert({user_id:PROFILE.id,nama:PROFILE.nama,peran:PROFILE.role,aksi,detail:String(detail||'').slice(0,300)}).then(()=>{},()=>{}); }catch(e){} }
let _flushing=false;
async function flushQ(){ if(_flushing||!SB||!Q.length||!navigator.onLine)return; _flushing=true; let sent=0;
  try{ while(Q.length){ const op=Q[0]; try{await sendOp(op);Q.shift();saveQ();sent++}
      catch(e){ if(isNetErr(e))break; Q.shift();saveQ(); toast(`Data ${TBL[op.col]||op.col} tidak tersimpan di server: ${sbErr(e)}`,'bad'); reloadCol(op.col); } } }
  finally{ _flushing=false; if(sent)toast(`${sent} data offline sudah terkirim`); bump(); } }
function sbErr(e){ const c=e?.code||''; if(c==='42501'||/row-level security|permission/i.test(e?.message||''))return 'akun Anda tidak berhak mengubah data ini (atau data sudah lewat hari dan hanya bisa diubah owner).'; if(isNetErr(e))return 'tidak ada koneksi internet.'; return (e?.message||'kesalahan server')+(c?' ('+c+')':''); }
async function fetchCol(c){ const rows=[]; for(let from=0;;from+=1000){ const {data,error}=await SB.from(c).select('id,data').order('id').range(from,from+999); if(error)throw error; rows.push(...data); if(data.length<1000)break; } return rows.map(r=>({id:r.id,...(r.data||{})})); }
async function reloadCol(c){ try{ D[c]=await fetchCol(c); Q.filter(o=>o.col===c).forEach(applyLocal); bump(); saveCache(); }catch(e){} }
const KOM_COLS=['pengaturan','produk','bahan','wilayah','harga','pelanggan','penjualan','pembayaran','pengeluaran','produksi','pemakaian','mutasi','opname','inv_supplier','hutang_lain','bayar_hutang','transfer','kreditur'];
async function loadAll(){ let fail=0; const KOM=PROFILE?.role==='komisaris';
  if(KOM) SB_COLS.forEach(c=>{ if(!KOM_COLS.includes(c)){ D[c]=[]; loaded.add(c); } });
  await Promise.all(SB_COLS.filter(c=>!KOM||KOM_COLS.includes(c)).map(async c=>{ try{ D[c]=await fetchCol(c); }catch(e){ if(!['wajah','absen_tolak','dus','muatan'].includes(c))fail++; } loaded.add(c); }));
  if(PROFILE?.role==='komisaris'||PROFILE?.role==='manager'){ try{ const {data,error}=await SB.rpc('cn_total_gaji_harian',{}); if(error)throw error;
    D.gaji=(data||[]).map((r,i)=>({id:'tot-'+i,tanggal:r.tanggal,tanggal_bayar:r.tanggal_bayar||null,status:'Dibayar',nama:'Total gaji',gaji_pokok:Number(r.total)||0})); }catch(e){ D.gaji=[]; } }
  Q.forEach(applyLocal); SBSTATE=fail?'offline':'online'; bump(); saveCache();
  if(fail&&!navigator.onLine)toast('Offline — menampilkan data terakhir di HP ini','warn'); }
function subscribe(){
  SB.channel('cn-db').on('postgres_changes',{event:'*',schema:'public'},p=>{ const c=p.table; if(!D[c]||c==='profiles')return;
      if(p.eventType==='DELETE'){const id=p.old?.id;if(id&&!Q.some(o=>o.col===c&&o.id===id))D[c]=D[c].filter(r=>r.id!==id)}
      else{ const r=p.new; if(!r||Q.some(o=>o.col===c&&o.id===r.id))return; const row={id:r.id,...(r.data||{})}; const i=D[c].findIndex(x=>x.id===r.id); if(i>=0)D[c][i]=row; else D[c].push(row); }
      bump(); saveCache(); })
    .subscribe(st=>{ if(st==='SUBSCRIBED'){ if(RT_DOWN){RT_DOWN=false;loadAll()} } if(st==='CHANNEL_ERROR'||st==='TIMED_OUT'||st==='CLOSED')RT_DOWN=true; });
  // cadangan bila koneksi realtime terputus: muat ulang berkala
  setInterval(()=>{ if(RT_DOWN&&navigator.onLine&&!document.hidden)loadAll() },60000);
}
async function afterLogin(user){
  let prof=null;
  try{ const {data,error}=await SB.from('profiles').select('id,nama,role,aktif').eq('id',user.id).maybeSingle(); if(error)throw error; prof=data; if(prof)localStorage.setItem(PKEY,JSON.stringify(prof)); }
  catch(e){ try{prof=JSON.parse(localStorage.getItem(PKEY)||'null')}catch(_){} if(prof&&prof.id!==user.id)prof=null; }
  if(!prof||!prof.aktif||!NAV[prof.role]){ LOGIN_ERR='Akun ini belum diberi peran atau sudah dinonaktifkan. Minta owner mendaftarkannya (file 02_pengguna.sql).'; await SB.auth.signOut(); setMe(null); MODE='login'; render(); return; }
  PROFILE=prof; setMe({role:prof.role,name:prof.nama,uid:prof.id}); MODE='cloud';
  if(loadCache()){ SB_COLS.forEach(c=>loaded.add(c)); Q.forEach(applyLocal); }
  bump(); await loadAll(); subscribe(); flushQ();
}
async function init(){
  render(); loaded.add('keamanan');
  if(!window.supabase){ document.getElementById('app').innerHTML='<div class="loading" style="padding:24px;text-align:center">Komponen koneksi gagal dimuat.<br>Periksa internet lalu <a href="javascript:location.reload()">muat ulang</a>.</div>'; return; }
  SB=window.supabase.createClient(SB_URL,SB_KEY,{auth:{persistSession:true,autoRefreshToken:true,storageKey:'cn-auth'}});
  const {data:{session}}=await SB.auth.getSession();
  if(session?.user) await afterLogin(session.user); else { setMe(null); MODE='login'; render(); }
  window.addEventListener('online',()=>{SBSTATE='online';flushQ();loadAll()});
  window.addEventListener('offline',()=>{SBSTATE='offline';bump()});
  setInterval(flushQ,20000);
}
async function sbLogin(form){
  if(LOGIN_BUSY)return; let u=form.querySelector('#lu').value.trim().toLowerCase(); const p=form.querySelector('#lp').value;
  if(!u||!p){LOGIN_ERR='Isi nama pengguna dan password.';render();return}
  if(!u.includes('@'))u=u.replace(/\s+/g,'')+'@cn.local';
  LOGIN_BUSY=true; LOGIN_ERR=''; render();
  const {data,error}=await SB.auth.signInWithPassword({email:u,password:p});
  LOGIN_BUSY=false;
  if(error){ LOGIN_ERR=isNetErr(error)?'Tidak ada koneksi internet. Login pertama kali harus online.':'Nama pengguna atau password salah.'; render(); return; }
  ROUTE=null; await afterLogin(data.user);
}
async function sbLogout(){
  if(Q.length&&!confirm(`Masih ada ${Q.length} data yang belum terkirim ke server. Kalau keluar sekarang, data itu hilang. Tetap keluar?`))return;
  try{await SB.auth.signOut()}catch(e){}
  try{ if(PROFILE)localStorage.removeItem(CKEY+':'+PROFILE.id); localStorage.removeItem(PKEY); }catch(e){}
  Q=[]; saveQ(); PROFILE=null; setMe(null); COLS.forEach(c=>D[c]=[]); loaded.clear(); MODE='login'; ROUTE=null; render();
}
function loginViewSB(){
  return `<div class="login"><div class="lbox"><div class="lhead">${LOGO}<div><h1>CN Air Mineral</h1><p>Sistem Informasi CV QQ Eka Putra</p></div></div>
  <div class="card" style="box-shadow:var(--shadow)"><h2>Masuk</h2>
  <form id="lform" style="display:grid;gap:10px;margin-top:6px">
    <label style="display:grid;gap:4px;font-size:13px">Nama pengguna<input id="lu" autocomplete="username" autocapitalize="none" spellcheck="false" placeholder="mis. abdul" ${LOGIN_BUSY?'disabled':''}></label>
    <label style="display:grid;gap:4px;font-size:13px">Kata sandi<input id="lp" type="password" autocomplete="current-password" ${LOGIN_BUSY?'disabled':''}></label>
    ${LOGIN_ERR?`<span class="badt" role="alert">${esc(LOGIN_ERR)}</span>`:''}
    <button class="btn pri" type="submit" ${LOGIN_BUSY?'disabled':''}>${LOGIN_BUSY?'Memeriksa…':'Masuk'}</button>
  </form>
  <p class="muted" style="font-size:12.5px;margin:14px 0 0">Akun dibuat oleh owner. Setelah masuk sekali, aplikasi tetap bisa dibuka dan dipakai mencatat walau sinyal hilang; data terkirim otomatis saat online.</p></div></div></div>`;
}
async function nomorNota(t){
  if(SB&&navigator.onLine){ try{ const {data,error}=await SB.rpc('nomor_nota',{tgl:t}); if(!error&&data)return data; }catch(e){} }
  const base=nextInvoice(t); const ini=String(meName()).split(/\s+/).map(w=>w[0]||'').join('').slice(0,2).toUpperCase()||'X';
  return base+'-'+ini; // nomor sementara saat offline, tetap unik per sales
}
function formGantiPwSB(){
  openForm({title:'Ganti password saya',fields:[{k:'baru',label:'Kata sandi baru (min. 8 karakter)',type:'password',req:1},{k:'ulang',label:'Ulangi password baru',type:'password',req:1}],
    async onSubmit(v){ if(v.baru.length<8)return 'Kata sandi minimal 8 karakter.'; if(v.baru!==v.ulang)return 'Ulangan password tidak sama.';
      const {error}=await SB.auth.updateUser({password:v.baru}); if(error)return 'Gagal: '+sbErr(error); },okMsg:'Kata sandi diganti'});
}
async function saveFile(name,bytes,mime){ const b=new Blob([bytes],{type:mime||'application/octet-stream'}); const a=document.createElement('a'); a.href=URL.createObjectURL(b); a.download=name; document.body.appendChild(a); a.click(); setTimeout(()=>{URL.revokeObjectURL(a.href);a.remove()},1500); }
async function backupXlsx(){ try{ const X=await loadXLSX(); const wb=X.utils.book_new();
    SB_COLS.forEach(c=>{ if(!D[c].length)return; const keys=[...new Set(D[c].flatMap(r=>Object.keys(r)))]; const rows=D[c].map(r=>keys.map(k=>typeof r[k]==='object'&&r[k]!==null?JSON.stringify(r[k]):r[k]));
      X.utils.book_append_sheet(wb,X.utils.aoa_to_sheet([keys,...rows]),c.slice(0,31)); });
    if(!wb.SheetNames.length){toast('Belum ada data untuk dicadangkan','warn');return}
    await saveFile(`cadangan-cn-${TODAY}.xlsx`,X.write(wb,{bookType:'xlsx',type:'array'}),'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'); toast('Cadangan diunduh');
  }catch(e){toast(e?.message||'Cadangan gagal dibuat','bad')} }
