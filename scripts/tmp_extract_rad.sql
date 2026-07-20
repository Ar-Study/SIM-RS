SET NOCOUNT ON;
SELECT
  'INSERT INTO public.radiology_catalog (exam_type, description, class_name, facility, legacy_tariff_name, price, is_active) VALUES (' +
  CASE WHEN TARIF_NAME IS NULL OR LTRIM(RTRIM(TARIF_NAME)) = '' THEN 'NULL' ELSE '''' + REPLACE(CAST(TARIF_NAME AS nvarchar(max)), '''', '''''') + '''' END + ', ' +
  CASE WHEN [DESCRIPTION] IS NULL OR LTRIM(RTRIM([DESCRIPTION])) = '' THEN 'NULL' ELSE '''' + REPLACE(CAST([DESCRIPTION] AS nvarchar(max)), '''', '''''') + '''' END + ', ' +
  CASE WHEN KELAS IS NULL OR LTRIM(RTRIM(KELAS)) = '' THEN 'NULL' ELSE '''' + REPLACE(CAST(KELAS AS nvarchar(max)), '''', '''''') + '''' END + ', ' +
  CASE WHEN SARANA IS NULL OR LTRIM(RTRIM(SARANA)) = '' THEN 'NULL' ELSE '''' + REPLACE(CAST(SARANA AS nvarchar(max)), '''', '''''') + '''' END + ', ' +
  CASE WHEN TARIF_NAME IS NULL OR LTRIM(RTRIM(TARIF_NAME)) = '' THEN 'NULL' ELSE '''' + REPLACE(CAST(TARIF_NAME AS nvarchar(max)), '''', '''''') + '''' END + ', ' +
  CASE WHEN ISNUMERIC(NULLIF(TARIF_LAMA, '')) = 1 THEN CAST(CAST(TARIF_LAMA AS decimal(18,2)) AS varchar(32))
       WHEN ISNUMERIC(NULLIF(NOMINAL_RS, '')) = 1 THEN CAST(CAST(NOMINAL_RS AS decimal(18,2)) AS varchar(32))
       ELSE '0' END + ', ' +
  CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(IMPLEMENTED, '1')))) IN ('1','Y','YES','TRUE') THEN 'true' ELSE 'false' END +
  ');'
FROM dbo.RADIOLOGI
ORDER BY TARIF_NAME;
