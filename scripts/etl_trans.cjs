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

  // valid reference sets from master data
  const validClinic = new Set((await pg.query('SELECT clinic_id FROM public.clinics')).rows.map(r => r.clinic_id));
  const validEmp = new Set((await pg.query('SELECT employee_id FROM public.employees')).rows.map(r => r.employee_id));
  const validRoom = new Set((await pg.query('SELECT room_id FROM public.rooms')).rows.map(r => r.room_id));
  const validPayor = new Set((await pg.query('SELECT payor_id FROM public.payors')).rows.map(r => r.payor_id));
  const validClass = new Set((await pg.query('SELECT class_id FROM public.room_classes')).rows.map(r => r.class_id));
  const validDiag = new Set((await pg.query('SELECT diagnosis_id FROM public.diagnoses')).rows.map(r => r.diagnosis_id));

  // ---------- patients (PASIEN keyed by NO_REGISTRATION) ----------
  {
    const rows = dump('pasien', "SELECT NO_REGISTRATION, NAME_OF_PASIEN, GENDER, DATE_OF_BIRTH, PHONE_NUMBER, MOBILE, CONTACT_ADDRESS, PAYOR_ID, REGISTRATION_DATE FROM PASIEN WHERE NO_REGISTRATION IS NOT NULL AND NAME_OF_PASIEN IS NOT NULL");
    const out = rows.map(r => {
      const reg = S(r[0]); if (!reg) return null;
      const payor = validPayor.has(S(r[7])) ? S(r[7]) : null;
      const dob = D(r[3]) || D(r[8]) || '1990-01-01';
      return [reg, reg, S(r[1]), GENDER(r[2]) || 'L', dob, null, S(r[5]) || S(r[4]), S(r[6]), payor];
    }).filter(Boolean);
    await bulkInsert(pg, 'patients', ['patient_id', 'no_registration', 'full_name', 'gender', 'date_of_birth', 'nik', 'phone', 'address', 'payor_id'], out);
    console.log('patients:', out.length);
  }
  const validPatient = new Set((await pg.query('SELECT patient_id FROM public.patients')).rows.map(r => r.patient_id));

  // ---------- patient_visitations (PASIEN_VISITATION) ----------
  {
    const rows = dump('visitations', "SELECT VISIT_ID, NO_REGISTRATION, CLINIC_ID, EMPLOYEE_ID, BOOKED_DATE, VISIT_DATE, TICKET_NO, CLASS_ROOM_ID, BED_ID, CLASS_ID, PAYOR_ID, IN_DATE, EXIT_DATE, CALL_TIMES, STATUS_PEMBAYARAN, STATUS_PERIKSA, REPLACE(REPLACE(ISNULL(DESCRIPTION,''),CHAR(13),' '),CHAR(10),' ') FROM PASIEN_VISITATION");
    let ticket = 1;
    const out = rows.map(r => {
      const visitId = S(r[0]); const reg = S(r[1]);
      if (!visitId || !reg || !validPatient.has(reg)) return null;
      const clinic = validClinic.has(S(r[2])) ? S(r[2]) : 'P004';
      const doc = validEmp.has(S(r[3])) ? S(r[3]) : null;
      const room = validRoom.has(S(r[7])) ? S(r[7]) : null;
      const cls = validClass.has(String(S(r[9]))) ? String(S(r[9])) : null;
      const payor = validPayor.has(S(r[10])) ? S(r[10]) : null;
      const booked = D(r[4]);
      const visitDate = D(r[5]) || booked;
      const sp = String(S(r[14]) || ''); // 1=Sudah Bayar
      const statusPembayaran = sp === '1' ? '1' : '0';
      const statusPeriksa = String(S(r[15]) || '') === '1' ? '1' : '0';
      const hasExit = D(r[12]) !== null;
      const statusKeluar = hasExit ? '1' : '0';
      const inDate = D(r[11]);
      const classRoomCode = S(r[7]);
      const classMap = { 'KL1': '2', 'KL2': '3', 'KL3': '1', 'VIP': '5', 'VIP B': '4', 'VVIP': null };
      const cls2 = cls || (classMap[classRoomCode] !== undefined ? classMap[classRoomCode] : null);
      let visitType = 'rawat_jalan';
      if (clinic === 'P012') visitType = 'igd';
      else if (classRoomCode || inDate) visitType = 'rawat_inap';
      return [visitId, reg, clinic, null, doc, booked, visitDate, S(r[6]) || ticket++, statusPembayaran, statusPeriksa, statusKeluar, S(r[16]), visitType, room, null, cls2, payor, inDate, D(r[12]), N(r[13])];
    }).filter(Boolean);
    await bulkInsert(pg, 'patient_visitations', ['visit_id', 'patient_id', 'clinic_id', 'clinic_id_from', 'doctor_id', 'booked_date', 'visit_date', 'ticket_no', 'status_pembayaran', 'status_periksa', 'status_keluar', 'description', 'visit_type', 'room_id', 'bed_id', 'class_id', 'payor_id', 'in_date', 'exit_date', 'call_times'], out);
    console.log('patient_visitations:', out.length);
  }
  const validVisit = new Set((await pg.query('SELECT visit_id FROM public.patient_visitations')).rows.map(r => r.visit_id));

  // ---------- cppt (CPPT) ----------
  {
    const rows = dump('cppt', "SELECT VISIT_ID, WAKTU_MASUK, REPLACE(REPLACE(SUBYEKTIF,CHAR(13),' '),CHAR(10),' '), REPLACE(REPLACE(OBYEKTIF,CHAR(13),' '),CHAR(10),' '), REPLACE(REPLACE(ASSESSMENT,CHAR(13),' '),CHAR(10),' '), REPLACE(REPLACE(PLANNING,CHAR(13),' '),CHAR(10),' '), REPLACE(REPLACE(INSTRUKSI,CHAR(13),' '),CHAR(10),' ') FROM CPPT WHERE VISIT_ID IS NOT NULL");
    const out = rows.map(r => {
      const visitId = S(r[0]); if (!visitId || !validVisit.has(visitId)) return null;
      return [visitId, D(r[1]), S(r[2]), S(r[3]), S(r[4]), S(r[5]), S(r[6])];
    }).filter(Boolean);
    await bulkInsert(pg, 'cppt', ['visit_id', 'waktu_masuk', 'subyektif', 'obyektif', 'assessment', 'planning', 'instruksi'], out);
    console.log('cppt:', out.length);
  }

  // ---------- patient_diagnoses (PASIEN_DIAGNOSA) ----------
  {
    const rows = dump('patient_diag', "SELECT VISIT_ID, DIAGNOSA_ID, ISNULL(DIAGNOSA_DESC,'') FROM PASIEN_DIAGNOSA WHERE VISIT_ID IS NOT NULL AND DIAGNOSA_ID IS NOT NULL");
    const out = rows.map(r => {
      const visitId = S(r[0]); const d = S(r[1]);
      if (!visitId || !validVisit.has(visitId) || !validDiag.has(d)) return null;
      return [visitId, d, 'primer'];
    }).filter(Boolean);
    await bulkInsert(pg, 'patient_diagnoses', ['visit_id', 'diagnosis_id', 'diagnosis_type'], out);
    console.log('patient_diagnoses:', out.length);
  }

  console.log('TRANSACTIONAL DONE');
  await pg.end();
})().catch(e => { console.error('ERR', e); process.exit(1); });
