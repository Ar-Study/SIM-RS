-- Tabel untuk unit Kamar Bersalin (vk)
CREATE TABLE IF NOT EXISTS public.labor_progress (
  id SERIAL PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES public.patients(patient_id) ON DELETE CASCADE,
  visit_id TEXT REFERENCES public.patient_visitations(visit_id),
  admission_time TIMESTAMPTZ DEFAULT now(),
  gestational_age NUMERIC,
  presentation TEXT CHECK (presentation IN ('kepala','bokong','lilitan tali pusat','obliques','lainnya')),
  membrane_status TEXT CHECK (membrane_status IN ('intact','ruptured','artificial')),
  cervix_dilation NUMERIC,
  contraction_freq TEXT,
  doctor_id TEXT REFERENCES public.employees(employee_id),
  notes TEXT,
  status TEXT DEFAULT 'admission' CHECK (status IN ('admission','latent','active','transition','pushing','delivery','placenta','postpartum','completed')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_labor_progress_patient ON public.labor_progress(patient_id);
CREATE INDEX IF NOT EXISTS idx_labor_progress_status ON public.labor_progress(status);

-- Kelas, kamar, dan bed VK
INSERT INTO public.room_classes (class_id, name, base_price, description) VALUES
  ('CLS-VK', 'VK', 400000, 'Verloskamer / Kamar Bersalin')
ON CONFLICT (class_id) DO NOTHING;

INSERT INTO public.rooms (room_id, class_id, clinic_id, room_number, floor) VALUES
  ('RM-VK-01', 'CLS-VK', 'POL-VK', 'VK-01', '2')
ON CONFLICT (room_id) DO NOTHING;

INSERT INTO public.beds (bed_id, room_id, bed_number) VALUES
  ('BD-VK-01A', 'RM-VK-01', '1'),
  ('BD-VK-01B', 'RM-VK-01', '2'),
  ('BD-VK-01C', 'RM-VK-01', '3')
ON CONFLICT (bed_id) DO NOTHING;

ALTER TABLE public.labor_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated full access" ON public.labor_progress;
CREATE POLICY "Allow authenticated full access" ON public.labor_progress
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow anon read access" ON public.labor_progress;
CREATE POLICY "Allow anon read access" ON public.labor_progress
  FOR SELECT TO anon USING (true);

NOTIFY pgrst, 'reload schema';
