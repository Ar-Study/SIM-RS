-- Migration: Clean public.clinics so it only contains outpatient clinics (Poli)
-- Move non-poli hospital units/installations to public.hospital_units and keep existing references intact

-- 1. Create public.hospital_units for non-poli units (IGD, Rawat Inap, ICU, NICU, VK, IBS, OK, HD, Lab, Radiologi, Farmasi)
CREATE TABLE IF NOT EXISTS public.hospital_units (
  unit_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.hospital_units ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'hospital_units' AND policyname = 'hospital_units_select_all'
  ) THEN
    CREATE POLICY hospital_units_select_all ON public.hospital_units FOR SELECT USING (true);
  END IF;
END $$;

INSERT INTO public.hospital_units (unit_id, name, description, is_active)
SELECT clinic_id, name, description, is_active
FROM public.clinics
WHERE clinic_id IN (
  'POL-FAR', 'POL-HD', 'POL-IBS', 'POL-ICU', 'POL-IGD',
  'POL-LAB', 'POL-NICU', 'POL-OK', 'POL-RAD', 'POL-RANAP', 'POL-VK'
)
ON CONFLICT (unit_id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active;

-- 2. Relax FK constraints on tables that reference either a clinic (poli) or a hospital unit (IGD, Ranap, ICU, VK, etc.)
DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT conname, conrelid::regclass AS table_name
    FROM pg_constraint
    WHERE contype = 'f'
      AND confrelid = 'public.clinics'::regclass
  LOOP
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT IF EXISTS %I', rec.table_name, rec.conname);
  END LOOP;
END $$;

-- 3. Remove non-poli units from public.clinics so public.clinics only contains actual Poli
DELETE FROM public.clinics
WHERE clinic_id IN (
  'POL-FAR', 'POL-HD', 'POL-IBS', 'POL-ICU', 'POL-IGD',
  'POL-LAB', 'POL-NICU', 'POL-OK', 'POL-RAD', 'POL-RANAP', 'POL-VK'
);
