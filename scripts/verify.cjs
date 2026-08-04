const fs = require('fs');
const { Client } = require('pg');
const env = fs.readFileSync('D:/Pribadi/SIM-RS/.env', 'utf8');
const pw = encodeURIComponent(env.match(/^SUPABASE_PASSWORD=(.*)$/m)[1].trim());
const c = new Client({ connectionString: 'postgresql://postgres:' + pw + '@db.iwqgnjxskbhmhmojhifr.supabase.co:5432/postgres', ssl: { rejectUnauthorized: false } });
(async () => {
  await c.connect();
  const tables = ['clinics','employees','room_classes','rooms','beds','payors','diagnoses','tariffs','drugs','patients','patient_visitations','cppt','patient_diagnoses','treatment_bills','billing_invoices','lab_orders','radiology_orders','prescriptions','profiles','lab_test_catalog','radiology_catalog'];
  for (const t of tables) {
    const r = await c.query('SELECT count(*) c FROM public.' + t);
    console.log(t.padEnd(22), r.rows[0].c);
  }
  const q = await c.query(`SELECT v.visit_type, count(*) c FROM patient_visitations v GROUP BY v.visit_type ORDER BY 1`);
  console.log('visit_type dist:', JSON.stringify(q.rows));
  const q2 = await c.query(`SELECT count(*) c FROM patient_visitations v LEFT JOIN patients p ON v.patient_id=p.patient_id WHERE p.patient_id IS NULL`);
  console.log('orphan visits:', q2.rows[0].c);
  const q3 = await c.query(`SELECT count(*) c FROM patient_visitations v LEFT JOIN clinics c ON v.clinic_id=c.clinic_id WHERE c.clinic_id IS NULL`);
  console.log('visits no clinic:', q3.rows[0].c);
  await c.end();
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
