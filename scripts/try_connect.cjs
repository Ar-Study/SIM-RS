const fs = require('fs');
const { Client } = require('pg');

const env = fs.readFileSync('D:/Pribadi/SIM-RS/.env', 'utf8');
function getEnv(k) {
  const m = env.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : undefined;
}
const pw = encodeURIComponent(getEnv('SUPABASE_PASSWORD') || '');

(async () => {
  const hosts = [
    'postgresql://postgres.iwqgnjxskbhmhmojhifr@db.iwqgnjxskbhmhmojhifr.supabase.co:5432/postgres',
    'postgresql://postgres@db.iwqgnjxskbhmhmojhifr.supabase.co:5432/postgres'
  ];
  for (const base of hosts) {
    const connStr = base.replace('postgres@', 'postgres:' + pw + '@');
    try {
      const c = new Client({ connectionString: connStr, ssl: { rejectUnauthorized: false } });
      await c.connect();
      const r = await c.query('select current_database() as db, current_user as u');
      console.log('OK via', base, '->', r.rows[0].db, r.rows[0].u);
      await c.end();
      process.exit(0);
    } catch (e) {
      console.log('FAIL', base, '->', e.message);
    }
  }
  process.exit(1);
})();
