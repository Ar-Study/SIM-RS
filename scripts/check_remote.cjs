const { Client } = require('pg');
const fs = require('fs');

const env = fs.readFileSync('D:/Pribadi/SIM-RS/.env', 'utf8');
function getEnv(key) {
  const m = env.match(new RegExp('^' + key + '=(.*)$', 'm'));
  return m ? m[1].trim() : undefined;
}

(async () => {
  const connStr = process.env.SUPABASE_CONNECTION_STRING || 'postgresql://postgres.iwqgnjxskbhmhmojhifr@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';
  const pw = encodeURIComponent(getEnv('SUPABASE_PASSWORD') || '');
  const c = new Client({
    connectionString: connStr.replace('postgres.iwqgnjxskbhmhmojhifr@', 'postgres.iwqgnjxskbhmhmojhifr:' + pw + '@'),
    ssl: { rejectUnauthorized: false }
  });
  await c.connect();
  const r = await c.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name");
  console.log('Total tables:', r.rows.length);
  for (const t of r.rows) console.log(t.table_name);
  await c.end();
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
