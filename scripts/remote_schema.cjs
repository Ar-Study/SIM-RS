const fs = require('fs');
const { Client } = require('pg');
const env = fs.readFileSync('D:/Pribadi/SIM-RS/.env', 'utf8');
function getEnv(k) {
  const m = env.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : undefined;
}
const pw = encodeURIComponent(getEnv('SUPABASE_PASSWORD') || '');
const connStr = 'postgresql://postgres:' + pw + '@db.iwqgnjxskbhmhmojhifr.supabase.co:5432/postgres';

(async () => {
  const c = new Client({ connectionString: connStr, ssl: { rejectUnauthorized: false } });
  await c.connect();
  const tables = await c.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name");
  console.log('=== TABLES (' + tables.rows.length + ') ===');
  for (const t of tables.rows) console.log(t.table_name);

  console.log('\n=== ROW COUNTS ===');
  for (const t of tables.rows) {
    try {
      const r = await c.query('SELECT count(*)::int c FROM public.' + t.table_name);
      console.log(t.table_name + ': ' + r.rows[0].c);
    } catch (e) {
      console.log(t.table_name + ': ERR ' + e.message);
    }
  }
  await c.end();
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
