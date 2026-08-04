const sql = require('mssql');
(async () => {
  const pool = await sql.connect({
    server: 'localhost',
    options: { trustServerCertificate: true, encrypt: true },
    database: 'rsud',
    authentication: { type: 'ntlm', options: { userName: 'BSI Farrel', domain: 'DESKTOP-QPBVQ0J', password: '' } }
  });
  const r = await pool.request().query('SELECT COUNT(*) c FROM CLINIC');
  console.log('mssql ok, clinics =', r.recordset[0].c);
  const t = await pool.request().query('SELECT TOP 2 AMOUNT, QUANTITY FROM TREATMENT_BILL');
  console.log('amount sample:', JSON.stringify(t.recordset));
  await pool.close();
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
