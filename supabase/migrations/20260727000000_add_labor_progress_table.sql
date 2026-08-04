-- ============================================
-- Add labor_progress table for VK (Kamar Bersalin)
-- ============================================

CREATE TABLE IF NOT EXISTS public.labor_progress (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  patient_id TEXT NOT NULL REFERENCES public.patients(patient_id),
  admission_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  gestational_age INTEGER,
  presentation TEXT DEFAULT 'kepala',
  membrane_status TEXT DEFAULT 'intact' CHECK (membrane_status IN ('intact','ruptured','artificial')),
  cervix_dilation NUMERIC(4,1),
  contraction_freq TEXT,
  doctor_id TEXT REFERENCES public.employees(employee_id),
  status TEXT DEFAULT 'admission' CHECK (status IN ('admission','latent','active','transition','pushing','delivery','placenta','postpartum','completed')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add status column to beds table (for compatibility with VK page)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'beds' AND column_name = 'status') THEN
    ALTER TABLE public.beds ADD COLUMN status TEXT DEFAULT 'empty' CHECK (status IN ('empty','occupied'));
  END IF;
END $$;

-- Update existing beds status based on is_occupied
UPDATE public.beds SET status = CASE WHEN is_occupied THEN 'occupied' ELSE 'empty' END WHERE status IS NULL;

-- Add VK room class if not exists
INSERT INTO public.room_classes (class_id, name, base_price, description)
VALUES ('CLS-VK', 'VK', 300000, 'Verloskamer / Kamar Bersalin')
ON CONFLICT (class_id) DO NOTHING;

-- Add VK rooms and beds if not exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE room_id = 'RM-VK-01') THEN
    INSERT INTO public.rooms (room_id, class_id, clinic_id, room_number, floor) VALUES
    ('RM-VK-01', 'CLS-VK', 'POL-VK', 'VK-01', '1'),
    ('RM-VK-02', 'CLS-VK', 'POL-VK', 'VK-02', '1'),
    ('RM-VK-03', 'CLS-VK', 'POL-VK', 'VK-03', '1');
  END IF;
END $$;

INSERT INTO public.beds (bed_id, room_id, bed_number, status)
SELECT 'BD-VK-01', 'RM-VK-01', 'VK-01A', 'empty'
WHERE NOT EXISTS (SELECT 1 FROM public.beds WHERE bed_id = 'BD-VK-01');

INSERT INTO public.beds (bed_id, room_id, bed_number, status)
SELECT 'BD-VK-02', 'RM-VK-01', 'VK-01B', 'empty'
WHERE NOT EXISTS (SELECT 1 FROM public.beds WHERE bed_id = 'BD-VK-02');

INSERT INTO public.beds (bed_id, room_id, bed_number, status)
SELECT 'BD-VK-03', 'RM-VK-02', 'VK-02A', 'empty'
WHERE NOT EXISTS (SELECT 1 FROM public.beds WHERE bed_id = 'BD-VK-03');

INSERT INTO public.beds (bed_id, room_id, bed_number, status)
SELECT 'BD-VK-04', 'RM-VK-02', 'VK-02B', 'empty'
WHERE NOT EXISTS (SELECT 1 FROM public.beds WHERE bed_id = 'BD-VK-04');

INSERT INTO public.beds (bed_id, room_id, bed_number, status)
SELECT 'BD-VK-05', 'RM-VK-03', 'VK-03A', 'empty'
WHERE NOT EXISTS (SELECT 1 FROM public.beds WHERE bed_id = 'BD-VK-05');

INSERT INTO public.beds (bed_id, room_id, bed_number, status)
SELECT 'BD-VK-06', 'RM-VK-03', 'VK-03B', 'empty'
WHERE NOT EXISTS (SELECT 1 FROM public.beds WHERE bed_id = 'BD-VK-06');

-- Indexes
CREATE INDEX IF NOT EXISTS idx_labor_progress_visit ON public.labor_progress(visit_id);
CREATE INDEX IF NOT EXISTS idx_labor_progress_patient ON public.labor_progress(patient_id);
CREATE INDEX IF NOT EXISTS idx_labor_progress_status ON public.labor_progress(status);

-- RLS
ALTER TABLE public.labor_progress ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'labor_progress' AND policyname = 'labor_progress_all') THEN
    CREATE POLICY "labor_progress_all" ON public.labor_progress FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';