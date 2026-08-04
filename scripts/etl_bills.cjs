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

(async () => {
  const pg = new Client({ connectionString: connStr, ssl: { rejectUnauthorized: false } });
  await pg.connect();
  console.log('PG connected');

  const validVisit = new Set((await pg.query('SELECT visit_id FROM public.patient_visitations')).rows.map(r => r.visit_id));
  const validClinic = new Set((await pg.query('SELECT clinic_id FROM public.clinics')).rows.map(r => r.clinic_id));
  const validTariff = new Set((await pg.query('SELECT tariff_id FROM public.tariffs')).rows.map(r => r.tariff_id));

  const rows = dump('bills', "SELECT VISIT_ID, TARIF_ID, QUANTITY, AMOUNT, CLINIC_ID, REPLACE(REPLACE(ISNULL(TREATMENT,''),CHAR(13),' '),CHAR(10),' '), TREAT_DATE, ISNULL(TARIF_TYPE,'') FROM TREATMENT_BILL");
  let n = 0, skipped = 0;
  const out = rows.map(r => {
    const visitId = S(r[0]);
    if (!visitId || !validVisit.has(visitId)) { skipped++; return null; }
    const tarifId = validTariff.has(S(r[1])) ? S(r[1]) : null;
    const clinic = validClinic.has(S(r[4])) ? S(r[4]) : null;
    const qty = N(r[2]) || 1;
    const amount = N(r[3]) || 0;
    const unitPrice = amount / qty;
    const tariffType = S(r[7]) || null;
    n++;
    return [visitId, tarifId, Math.round(qty), unitPrice, amount, 0, 0, clinic, S(r[5]), D(r[6]), tariffType];
  }).filter(Boolean);
  console.log('bill rows total:', out.length, 'skipped (no visit):', skipped);
  await bulkInsert(pg, 'treatment_bills', ['visit_id', 'tariff_id', 'quantity', 'unit_price', 'amount', 'nominal_rs', 'nominal_nakes', 'clinic_id', 'description', 'created_at', 'tariff_type'], out);
  console.log('treatment_bills loaded');

  console.log('BILLS DONE');
  await pg.end();
})().catch(e => { console.error('ERR', e); process.exit(1); });
