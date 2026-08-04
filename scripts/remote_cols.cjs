const fs = require('fs');
const { Client } = require('pg');
const env = fs.readFileSync('D:/Pribadi/SIM-RS/.env', 'utf8');
function getEnv(k) {
  const m = env.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : undefined;
}
const pw = encodeURIComponent(getEnv('SUPABASE_PASSWORD') || '');
const connStr = 'postgresql://postgres:' + pw + '@db.iwqgnjxskbhmhmojhifr.supabase.co:5432/postgres';

const tables = process.argv[2] ? process.argv[2].split(',') : ['clinics','employees','room_classes','rooms','beds','payors','diagnoses','tariffs','drugs','patients','patient_visitations','cppt','patient_diagnoses','lab_orders','lab_test_catalog','radiology_catalog','radiology_orders','prescriptions','prescription_items','treatment_bills','billing_invoices','surgery_requests','surgery_bookings','profiles','lab_analysis','drug_stock_logs','free_drug_sales','discharge_summaries','assessments','consultations','doctor_visits','room_transfers','tindakan','online_registrations','triages','assessment_poli','assessment_igd'];

(async () => {
  const c = new Client({ connectionString: connStr, ssl: { rejectUnauthorized: false } });
  await c.connect();
  for (const t of tables) {
    const r = await c.query(
      `SELECT column_name, data_type, is_nullable, column_default, udt_name
       FROM information_schema.columns WHERE table_schema='public' AND table_name=$1 ORDER BY ordinal_position`, [t]);
    console.log('### ' + t);
    for (const col of r.rows) {
      console.log(col.column_name + '|' + col.data_type + '|' + col.is_nullable + '|' + (col.column_default || '') + '|' + col.udt_name);
    }
  }
  await c.end();
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
