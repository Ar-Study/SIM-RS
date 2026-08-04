-- Mapping dokter ke poli/klinik (untuk dropdown dokter yang tergantung poli)
CREATE TABLE IF NOT EXISTS public.employee_clinics (
  id SERIAL PRIMARY KEY,
  employee_id TEXT NOT NULL REFERENCES public.employees(employee_id) ON DELETE CASCADE,
  clinic_id TEXT NOT NULL REFERENCES public.clinics(clinic_id) ON DELETE CASCADE,
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (employee_id, clinic_id)
);

-- Seed mapping berdasarkan spesialisasi dokter
INSERT INTO public.employee_clinics (employee_id, clinic_id, is_primary) VALUES
  ('DOC-001', 'POL-PERA', true),
  ('DOC-001', 'POL-UMUM', false),
  ('DOC-002', 'POL-ANAK', true),
  ('DOC-003', 'POL-OK', true),
  ('DOC-003', 'POL-IBS', true),
  ('DOC-003', 'POL-ORTH', false),
  ('DOC-004', 'POL-OBGYN', true),
  ('DOC-004', 'POL-VK', false),
  ('DOC-005', 'POL-MATA', true),
  ('DOC-006', 'POL-THT', true),
  ('DOC-007', 'POL-SYARAF', true),
  ('DOC-008', 'POL-KULIT', true)
ON CONFLICT (employee_id, clinic_id) DO NOTHING;

-- IGD: semua dokter DPJP dapat jaga di instalasi gawat darurat
INSERT INTO public.employee_clinics (employee_id, clinic_id, is_primary)
SELECT e.employee_id, 'POL-IGD', false
FROM public.employees e
WHERE e.role = 'doctor' AND e.is_dpjp = true
ON CONFLICT (employee_id, clinic_id) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_employee_clinics_clinic ON public.employee_clinics(clinic_id);
CREATE INDEX IF NOT EXISTS idx_employee_clinics_employee ON public.employee_clinics(employee_id);

ALTER TABLE public.employee_clinics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated full access" ON public.employee_clinics;
CREATE POLICY "Allow authenticated full access" ON public.employee_clinics
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon read access" ON public.employee_clinics;
CREATE POLICY "Allow anon read access" ON public.employee_clinics
  FOR SELECT TO anon USING (true);

NOTIFY pgrst, 'reload schema';
