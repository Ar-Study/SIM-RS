const fs = require('fs');
const { Client } = require('pg');
const env = fs.readFileSync('D:/Pribadi/SIM-RS/.env', 'utf8');
const pw = encodeURIComponent(env.match(/^SUPABASE_PASSWORD=(.*)$/m)[1].trim());
const c = new Client({ connectionString: 'postgresql://postgres:' + pw + '@db.iwqgnjxskbhmhmojhifr.supabase.co:5432/postgres', ssl: { rejectUnauthorized: false } });

(async () => {
  await c.connect();
  const q = await c.query(`
    SELECT t.category, COUNT(*) AS lines, COALESCE(SUM(t.price),0) AS total
    FROM tariffs t GROUP BY t.category ORDER BY t.category`);
  console.log('tariffs by category:');
  console.table(q.rows);

  const q2 = await c.query(`
    SELECT COUNT(*) AS total,
           COUNT(DISTINCT visit_id) AS visits,
           SUM(CASE WHEN amount > 0 THEN 1 ELSE 0 END) AS nonzero
    FROM treatment_bills`);
  console.log('treatment_bills overall:', JSON.stringify(q2.rows));

  const q3 = await c.query(`
    SELECT tb.tariff_id, t.category, COUNT(*) c, SUM(tb.amount) tot
    FROM treatment_bills tb LEFT JOIN tariffs t ON t.tariff_id = tb.tariff_id
    GROUP BY tb.tariff_id, t.category ORDER BY c DESC LIMIT 15`);
  console.log('top tariff_ids used in bills:');
  console.table(q3.rows);

  await c.end();
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
