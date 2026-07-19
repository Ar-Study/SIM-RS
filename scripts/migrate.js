import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const pool = new pg.Pool({
  host: 'aws-0-ap-northeast-1.pooler.supabase.com',
  port: 6543,
  database: 'postgres',
  user: 'postgres.xfxdehqkdhmavgvaarwz',
  password: 'S1mrs.S1mrs',
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 15000
});

async function migrate() {
  console.log('Connecting to Supabase database...');
  const client = await pool.connect();

  const res = await client.query('SELECT current_database(), current_user');
  console.log(`✓ Connected! DB: ${res.rows[0].current_database}, User: ${res.rows[0].current_user}\n`);

  const migrationsDir = join(__dirname, '..', 'supabase', 'migrations');
  const files = ['001_initial_schema.sql', '002_seed_data.sql', '003_rls_policies.sql'];

  for (const file of files) {
    console.log(`▶ Running ${file}...`);
    const sql = readFileSync(join(migrationsDir, file), 'utf-8');
    try {
      await client.query(sql);
      console.log(`  ✓ ${file} selesai\n`);
    } catch (err) {
      console.error(`  ✗ Error: ${err.message}\n`);
    }
  }

  const tables = await client.query(`
    SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename
  `);
  console.log(`✅ Migrasi selesai! ${tables.rows.length} tabel:`);
  tables.rows.forEach(r => console.log(`  - ${r.tablename}`));

  client.release();
  await pool.end();
}

migrate().catch(err => {
  console.error('❌ Migration failed:', err.message);
  process.exit(1);
});
