-- Add diagnostic catalog tables used by outpatient/inpatient/ER order search.
-- Legacy reference:
-- - dbo.pemeriksaan_laboratorium
-- - dbo.RADIOLOGI

CREATE TABLE IF NOT EXISTS public.lab_test_catalog (
  test_id TEXT PRIMARY KEY DEFAULT ('LAB-' || upper(substr(md5(random()::text), 1, 8))),
  legacy_id INTEGER UNIQUE,
  legacy_category_id TEXT,
  category TEXT NOT NULL,
  test_name TEXT NOT NULL,
  normal_value TEXT,
  method TEXT,
  unit TEXT,
  lab_code TEXT,
  price NUMERIC NOT NULL DEFAULT 0,
  sort_order INTEGER,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.radiology_catalog (
  exam_id TEXT PRIMARY KEY DEFAULT ('RAD-' || upper(substr(md5(random()::text), 1, 8))),
  exam_type TEXT NOT NULL,
  description TEXT,
  class_name TEXT,
  facility TEXT,
  legacy_tariff_name TEXT,
  price NUMERIC NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lab_test_catalog_name ON public.lab_test_catalog (test_name);
CREATE INDEX IF NOT EXISTS idx_lab_test_catalog_category ON public.lab_test_catalog (category);
CREATE INDEX IF NOT EXISTS idx_radiology_catalog_exam_type ON public.radiology_catalog (exam_type);

INSERT INTO public.lab_test_catalog (
  test_id,
  category,
  test_name,
  lab_code,
  price,
  is_active
)
SELECT
  'LAB-' || upper(substr(md5('tariff:' || tariff_id), 1, 8)),
  'Umum',
  name,
  tariff_id,
  COALESCE(price, 0),
  COALESCE(is_active, true)
FROM public.tariffs
WHERE category = 'Laboratorium'
ON CONFLICT (test_id) DO NOTHING;

INSERT INTO public.radiology_catalog (
  exam_id,
  exam_type,
  description,
  legacy_tariff_name,
  price,
  is_active
)
SELECT
  'RAD-' || upper(substr(md5('tariff:' || tariff_id), 1, 8)),
  name,
  description,
  name,
  COALESCE(price, 0),
  COALESCE(is_active, true)
FROM public.tariffs
WHERE category = 'Radiologi'
ON CONFLICT (exam_id) DO NOTHING;

ALTER TABLE public.lab_test_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.radiology_catalog ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'lab_test_catalog' AND policyname = 'lab_test_catalog_select'
  ) THEN
    CREATE POLICY "lab_test_catalog_select"
    ON public.lab_test_catalog
    FOR SELECT
    USING (auth.role() = 'authenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'lab_test_catalog' AND policyname = 'lab_test_catalog_insert'
  ) THEN
    CREATE POLICY "lab_test_catalog_insert"
    ON public.lab_test_catalog
    FOR INSERT
    WITH CHECK (public.get_user_role() IN ('admin', 'lab_tech'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'lab_test_catalog' AND policyname = 'lab_test_catalog_update'
  ) THEN
    CREATE POLICY "lab_test_catalog_update"
    ON public.lab_test_catalog
    FOR UPDATE
    USING (public.get_user_role() IN ('admin', 'lab_tech'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'radiology_catalog' AND policyname = 'radiology_catalog_select'
  ) THEN
    CREATE POLICY "radiology_catalog_select"
    ON public.radiology_catalog
    FOR SELECT
    USING (auth.role() = 'authenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'radiology_catalog' AND policyname = 'radiology_catalog_insert'
  ) THEN
    CREATE POLICY "radiology_catalog_insert"
    ON public.radiology_catalog
    FOR INSERT
    WITH CHECK (public.get_user_role() IN ('admin', 'radiology_tech'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'radiology_catalog' AND policyname = 'radiology_catalog_update'
  ) THEN
    CREATE POLICY "radiology_catalog_update"
    ON public.radiology_catalog
    FOR UPDATE
    USING (public.get_user_role() IN ('admin', 'radiology_tech'));
  END IF;
END $$;