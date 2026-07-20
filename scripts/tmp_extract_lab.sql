SET NOCOUNT ON;
SELECT
  'INSERT INTO public.lab_test_catalog (legacy_id, legacy_category_id, category, test_name, normal_value, method, unit, lab_code, price, is_active) VALUES (' +
  CAST(id AS varchar(20)) + ', ' +
  CASE WHEN id_kategori IS NULL THEN 'NULL' ELSE '''' + CAST(id_kategori AS varchar(20)) + '''' END + ', ' +
  '''' + REPLACE(COALESCE(NULLIF(LTRIM(RTRIM(CAST(kategori AS nvarchar(max)))), ''), 'Umum'), '''', '''''') + '''' + ', ' +
  CASE WHEN nama_pemeriksaan IS NULL OR LTRIM(RTRIM(nama_pemeriksaan)) = '' THEN 'NULL' ELSE '''' + REPLACE(CAST(nama_pemeriksaan AS nvarchar(max)), '''', '''''') + '''' END + ', ' +
  CASE WHEN NILAI_NORMAL IS NULL OR LTRIM(RTRIM(NILAI_NORMAL)) = '' THEN 'NULL' ELSE '''' + REPLACE(CAST(NILAI_NORMAL AS nvarchar(max)), '''', '''''') + '''' END + ', ' +
  CASE WHEN metode IS NULL OR LTRIM(RTRIM(metode)) = '' THEN 'NULL' ELSE '''' + REPLACE(CAST(metode AS nvarchar(max)), '''', '''''') + '''' END + ', ' +
  CASE WHEN satuan_lab IS NULL OR LTRIM(RTRIM(satuan_lab)) = '' THEN 'NULL' ELSE '''' + REPLACE(CAST(satuan_lab AS nvarchar(max)), '''', '''''') + '''' END + ', ' +
  CASE WHEN kode_lab IS NULL OR LTRIM(RTRIM(kode_lab)) = '' THEN 'NULL' ELSE '''' + REPLACE(CAST(kode_lab AS nvarchar(max)), '''', '''''') + '''' END + ', ' +
  CASE WHEN harga IS NULL THEN '0' ELSE CAST(CAST(harga AS decimal(18,2)) AS varchar(32)) END + ', ' +
  'true' +
  ') ON CONFLICT (legacy_id) DO UPDATE SET ' +
  'legacy_category_id = EXCLUDED.legacy_category_id, category = EXCLUDED.category, test_name = EXCLUDED.test_name, normal_value = EXCLUDED.normal_value, method = EXCLUDED.method, unit = EXCLUDED.unit, lab_code = EXCLUDED.lab_code, price = EXCLUDED.price, is_active = EXCLUDED.is_active;'
FROM dbo.pemeriksaan_laboratorium
ORDER BY id;
