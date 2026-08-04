const fs = require('fs');
const { Client } = require('pg');
const env = fs.readFileSync('D:/Pribadi/SIM-RS/.env', 'utf8');
const pw = encodeURIComponent(env.match(/^SUPABASE_PASSWORD=(.*)$/m)[1].trim());
const c = new Client({ connectionString: 'postgresql://postgres:' + pw + '@db.iwqgnjxskbhmhmojhifr.supabase.co:5432/postgres', ssl: { rejectUnauthorized: false } });
(async () => {
  await c.connect();
  const r = await c.query("SELECT conrelid::regclass AS tbl, pg_get_constraintdef(oid) AS def FROM pg_constraint WHERE contype='f' AND connamespace='public'::regnamespace ORDER BY 1");
  console.log('FK count:', r.rows.length);
  for (const x of r.rows) console.log(x.tbl + ' | ' + x.def);
  const t = await c.query("SELECT count(*) c FROM patient_visitations WHERE ticket_no IS NULL");
  console.log('null ticket_no:', t.rows[0].c);
  await c.end();
})().catch(e => { console.error(e.message); process.exit(1); });
