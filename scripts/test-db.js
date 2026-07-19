import pg from 'pg';
import dns from 'dns';

const password = 'S1mrs.S1mrs';

// Try IPv6 direct connection
const ipv6 = '2406:da14:1d4f:7402:3cbf:1cc4:df2f:9169';

async function test() {
  const configs = [
    { host: ipv6, port: 5432, user: 'postgres', label: 'IPv6:5432/postgres' },
    { host: ipv6, port: 5432, user: 'postgres.xfxdehqkdhmavgvaarwz', label: 'IPv6:5432/postgres.ref' },
    { host: ipv6, port: 6543, user: 'postgres', label: 'IPv6:6543/postgres' },
    { host: ipv6, port: 6543, user: 'postgres.xfxdehqkdhmavgvaarwz', label: 'IPv6:6543/postgres.ref' },
  ];

  for (const cfg of configs) {
    process.stdout.write(`${cfg.label} ... `);
    try {
      const pool = new pg.Pool({
        host: cfg.host, port: cfg.port, database: 'postgres',
        user: cfg.user, password,
        ssl: { rejectUnauthorized: false },
        connectionTimeoutMillis: 8000,
        family: 6
      });
      const client = await pool.connect();
      const res = await client.query('SELECT current_database(), current_user');
      console.log(`✓ OK! DB=${res.rows[0].current_database} User=${res.rows[0].current_user}`);
      client.release();
      await pool.end();
      return { host: cfg.host, port: cfg.port, user: cfg.user };
    } catch (err) {
      console.log(`✗ ${err.message.split('\n')[0]}`);
    }
  }
  return null;
}

const result = await test();
if (result) {
  console.log('\n✅ Working config:', JSON.stringify(result));
} else {
  console.log('\n❌ None worked. Silakan reset DB password di Supabase Dashboard > Settings > Database > Reset password');
}
