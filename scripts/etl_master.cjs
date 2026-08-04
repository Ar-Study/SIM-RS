const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const BCP = 'C:\\Program Files\\Microsoft SQL Server\\Client SDK\\ODBC\\180\\Tools\\Binn\\bcp.exe';
const SERVER = 'localhost';
const DB = 'rsud';
const TMP = path.join(process.env.TEMP || '.', 'opencode', 'etl_rsud');
const DELIM = '|~|';

const env = fs.readFileSync('D:/Pribadi/SIM-RS/.env', 'utf8');
function getEnv(k) { const m = env.match(new RegExp('^' + k + '=(.*)$', 'm')); return m ? m[1].trim() : undefined; }
const pw = encodeURIComponent(getEnv('SUPABASE_PASSWORD') || '');
const connStr = 'postgresql://postgres:' + pw + '@db.iwqgnjxskbhmhmojhifr.supabase.co:5432/postgres';

fs.mkdirSync(TMP, { recursive: true });

function dump(name, query) {
  const file = path.join(TMP, name + '.tsv');
  const q = query.replace(/\n/g, ' ');
  execFileSync(BCP, [q, 'queryout', file, '-T', '-u', '-S', SERVER, '-d', DB, '-c', '-t', DELIM, '-r', '\n'], { stdio: ['ignore', 'ignore', 'pipe'] });
  const raw = fs.readFileSync(file, 'utf8');
  return raw.split('\n').filter(l => l.length > 0).map(l => l.split(DELIM));
}

async function bulkInsert(client, table, columns, rows, batch = 400) {
  if (rows.length === 0) return;
  const colSql = columns.map(c => '"' + c + '"').join(', ');
  for (let i = 0; i < rows.length; i += batch) {
    const chunk = rows.slice(i, i + batch);
    const params = [];
    const values = chunk.map((r, ri) => '(' + r.map((v, ci) => {
      params.push(v);
      return '$' + (ri * r.length + ci + 1);
    }).join(', ') + ')').join(', ');
    await client.query('INSERT INTO public.' + table + ' (' + colSql + ') VALUES ' + values + ' ON CONFLICT DO NOTHING', params);
  }
}

const S = (v) => (v === null || v === undefined || v === '') ? null : String(v).replace(/\u0000/g, '').trim() || null;
const N = (v) => { if (v === null || v === undefined || String(v).trim() === '') return null; const n = Number(v); return isNaN(n) ? null : n; };
const D = (v) => { if (v === null || v === undefined || String(v).trim() === '') return null; return String(v).trim().replace('T', ' '); };
const GENDER = (v) => (String(v || '').trim() === '1') ? 'L' : (String(v || '').trim() === '2') ? 'P' : null;

(async () => {
  const pg = new Client({ connectionString: connStr, ssl: { rejectUnauthorized: false } });
  await pg.connect();
  console.log('PG connected');

  // ---------- clear existing app tables in FK-safe order ----------
  const clearOrder = [
    'free_drug_sale_items','free_drug_sales','drug_stock_logs','surgery_bookings','surgery_requests',
    'room_transfers','discharge_summaries','assessments','consultations','doctor_visits','tindakan',
    'triages','assessment_poli','assessment_igd','labor_progress','integrasi_satusehat','online_registrations',
    'lab_analysis','lab_orders','radiology_orders','prescription_items','prescriptions','billing_invoices',
    'treatment_bills','patient_diagnoses','cppt','comorbidities','patient_visitations','patients',
    'tariffs','beds','rooms','room_classes','diagnoses','drugs','payors','employees','clinics'
  ];
  for (const t of clearOrder) {
    await pg.query('DELETE FROM public.' + t);
    console.log('cleared', t);
  }

  // ---------- 1. clinics ----------
  {
    const rows = dump('clinics', 'SELECT CLINIC_ID, NAME_OF_CLINIC, ISNULL(PROFILES,\'\') FROM CLINIC');
    const out = rows.map(r => [S(r[0]), S(r[1]), S(r[2])]).filter(r => r[0]);
    await bulkInsert(pg, 'clinics', ['clinic_id', 'name', 'description'], out);
    console.log('clinics:', out.length);
  }

  // ---------- 2. room_classes ----------
  {
    const rows = dump('room_classes', 'SELECT CAST(CLASS_ID AS varchar(5)), NAME_OF_CLASS FROM CLASS');
    const out = rows.map(r => [S(r[0]), S(r[1])]).filter(r => r[0]);
    await bulkInsert(pg, 'room_classes', ['class_id', 'name'], out);
    console.log('room_classes:', out.length);
  }

  // ---------- 3. rooms (CLASS_ROOM) ----------
  {
    const rows = dump('rooms', "SELECT CLASS_ROOM_ID, CAST(CLASS_ID AS varchar(5)), CLINIC_ID, NAME_OF_CLASS FROM CLASS_ROOM WHERE ISACTIVE='1' OR ISACTIVE IS NULL");
    const validClasses = new Set(dump('room_classes_check', 'SELECT CAST(CLASS_ID AS varchar(5)) FROM CLASS').map(r => S(r[0])).filter(Boolean));
    const validClinics = new Set(dump('clinics_check', 'SELECT CLINIC_ID FROM CLINIC').map(r => S(r[0])).filter(Boolean));
    const out = rows.map(r => {
      const cls = validClasses.has(S(r[1])) ? S(r[1]) : null;
      const cli = validClinics.has(S(r[2])) ? S(r[2]) : null;
      return [S(r[0]), cls, cli, S(r[3])];
    }).filter(r => r[0]);
    await bulkInsert(pg, 'rooms', ['room_id', 'class_id', 'clinic_id', 'room_number'], out);
    globalThis.__rooms = new Set(out.map(o => o[0]));
    console.log('rooms:', out.length);
  }

  // ---------- 4. beds ----------
  {
    const rows = dump('beds', 'SELECT CAST(BED_ID AS varchar(10)), CLASS_ROOM_ID, DISPLAY FROM BEDS');
    const validRooms = globalThis.__rooms || new Set();
    let bedSeq = 1;
    const out = rows.map(r => {
      const room = validRooms.has(S(r[1])) ? S(r[1]) : null;
      const bedId = 'BD-' + (bedSeq++);
      const bedNumber = S(r[2]) || S(r[0]) || 'Bed ' + S(r[0]);
      return [bedId, room, bedNumber];
    }).filter(r => r[0]);
    await bulkInsert(pg, 'beds', ['bed_id', 'room_id', 'bed_number'], out);
    console.log('beds:', out.length);
  }

  // ---------- 5. payors ----------
  {
    const rows = dump('payors', 'SELECT PAYOR_ID, PAYOR, PAYOR_TYPE, ADDRESS, PHONE FROM PAYOR_INFO');
    const typeMap = { '1': 'personal', '2': 'bpjs', '3': 'corporate', '4': 'insurance', '5': 'corporate' };
    const out = rows.map(r => [S(r[0]), S(r[1]), typeMap[String(r[2] || '').trim()] || null, S(r[3]), S(r[4])]).filter(r => r[0]);
    await bulkInsert(pg, 'payors', ['payor_id', 'name', 'type', 'address', 'phone'], out);
    console.log('payors:', out.length);
  }

  // ---------- 6. employees ----------
  {
    const rows = dump('employees', 'SELECT EMPLOYEE_ID, FULLNAME, GENDER, HANDPHONE, EMAIL, DPJP, SPECIALIST_TYPE_ID FROM EMPLOYEE_ALL');
    const out = rows.map(r => {
      const empId = S(r[0]); if (!empId) return null;
      const fullName = S(r[1]) || '';
      const dpjp = S(r[5]);
      const spec = dpjp || S(r[6]);
      const isDoctor = dpjp !== null || /^dr\./i.test(fullName) || / dr\./i.test(fullName);
      return [empId, fullName, isDoctor ? 'doctor' : 'nurse', GENDER(r[2]), S(r[3]), S(r[4]), spec, dpjp !== null];
    }).filter(Boolean);
    await bulkInsert(pg, 'employees', ['employee_id', 'full_name', 'role', 'gender', 'phone', 'email', 'specialization', 'is_dpjp'], out);
    console.log('employees:', out.length);
  }

  // ---------- 7. diagnoses (merge ICD10 + DIAGNOSA by code) ----------
  {
    const icd = dump('diagnoses_icd', 'SELECT DIAGNOSA_ID, NAME_OF_DIAGNOSA FROM ICD10');
    const diag = dump('diagnoses_diag', 'SELECT DIAGNOSA_ID, NAME_OF_DIAGNOSA FROM DIAGNOSA');
    const map = new Map();
    for (const r of icd) { const code = S(r[0]); if (code) map.set(code, S(r[1])); }
    for (const r of diag) { const code = S(r[0]); if (code && !map.has(code)) map.set(code, S(r[1])); }
    const out = [...map.entries()].map(([code, name]) => [code, code, name]);
    await bulkInsert(pg, 'diagnoses', ['diagnosis_id', 'code', 'name'], out);
    console.log('diagnoses:', out.length);
  }

  // ---------- 8. tariffs ----------
  {
    const rows = dump('tariffs', 'SELECT CAST(TARIF_ID AS varchar(12)), TARIF_NAME, AMOUNT_PAID, ISNULL(TARIF_TYPE,\'\'), CLASS_ID FROM TREAT_TARIF');
    const catMap = { '1': 'Tindakan', '2': 'Konsultasi', '10': 'Laboratorium', '11': 'Radiologi', '12': 'Obat', '802': 'Akomodasi' };
    const out = rows.map(r => {
      const id = S(r[0]); if (!id) return null;
      const name = S(r[1]) || '';
      let cat = catMap[String(r[3] || '').trim()] || 'Tindakan';
      if (/laboratorium|lab\.|lab /i.test(name)) cat = 'Laboratorium';
      else if (/radiologi|rontgen|usg|ct ?scan|mri|foto/i.test(name)) cat = 'Radiologi';
      else if (/obat|ampul|kapsul|sirup|infus|cairan/i.test(name)) cat = 'Obat';
      else if (/konsul|visite/i.test(name)) cat = 'Konsultasi';
      else if (/kamar|akomodasi|rawat/i.test(name)) cat = 'Akomodasi';
      else if (/tindakan|operasi|incisi|jahit|spalk|bebat/i.test(name)) cat = 'Tindakan';
      return [id, cat, name, N(r[2])];
    }).filter(Boolean);
    await bulkInsert(pg, 'tariffs', ['tariff_id', 'category', 'name', 'price'], out);
    console.log('tariffs:', out.length);
  }

  // ---------- 9. drugs (dedupe by name, sum stock) ----------
  {
    const rows = dump('drugs', 'SELECT ID, NAMA_OBAT, SATUAN, STOK_AKHIR, EXPDATE FROM STOK_OBAT');
    const map = new Map();
    for (const r of rows) {
      const name = S(r[1]); if (!name) continue;
      const key = name.toLowerCase();
      const cur = map.get(key);
      const stock = N(r[3]) || 0;
      if (!cur) map.set(key, { name, unit: S(r[2]) || 'tablet', stock, expiry: D(r[4]) });
      else { cur.stock += stock; if (!cur.expiry && r[4]) cur.expiry = D(r[4]); }
    }
    let i = 0;
    const out = [...map.values()].map(d => [String(++i), d.name, null, d.unit, null, null, d.stock, 10, d.expiry, null]);
    await bulkInsert(pg, 'drugs', ['drug_id', 'name', 'generic_name', 'unit', 'buy_price', 'sell_price', 'stock', 'min_stock', 'expiry_date', 'manufacturer'], out);
    console.log('drugs:', out.length);
  }

  console.log('MASTER DONE');
  await pg.end();
})().catch(e => { console.error('ERR', e); process.exit(1); });
