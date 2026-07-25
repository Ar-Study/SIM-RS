-- ============================================
-- Add missing tables used by rawat-inap pages
-- ============================================

-- doctor_visits: for doctor visit notes
CREATE TABLE IF NOT EXISTS public.doctor_visits (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  doctor_name TEXT,
  notes TEXT,
  visit_type TEXT DEFAULT 'visite',
  visit_date TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- consultations: for specialist consultation requests
CREATE TABLE IF NOT EXISTS public.consultations (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  specialist TEXT NOT NULL,
  reason TEXT,
  urgency TEXT DEFAULT 'normal',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','in_progress','completed','cancelled')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- room_transfers: for room transfer history
CREATE TABLE IF NOT EXISTS public.room_transfers (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  from_room_id TEXT REFERENCES public.rooms(room_id),
  from_bed_id TEXT REFERENCES public.beds(bed_id),
  to_room_id TEXT REFERENCES public.rooms(room_id),
  to_bed_id TEXT REFERENCES public.beds(bed_id),
  reason TEXT,
  transfer_date TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- tindakan: for emergency procedures (IGD)
CREATE TABLE IF NOT EXISTS public.tindakan (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  procedure_name TEXT NOT NULL,
  notes TEXT,
  operator TEXT,
  performed_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS policies for new tables
ALTER TABLE public.doctor_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tindakan ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'doctor_visits' AND policyname = 'doctor_visits_all') THEN
    CREATE POLICY "doctor_visits_all" ON public.doctor_visits FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'consultations' AND policyname = 'consultations_all') THEN
    CREATE POLICY "consultations_all" ON public.consultations FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'room_transfers' AND policyname = 'room_transfers_all') THEN
    CREATE POLICY "room_transfers_all" ON public.room_transfers FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tindakan' AND policyname = 'tindakan_all') THEN
    CREATE POLICY "tindakan_all" ON public.tindakan FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

-- ============================================
-- Add IGD-related columns to patient_visitations
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patient_visitations' AND column_name = 'triage_level') THEN
    ALTER TABLE public.patient_visitations ADD COLUMN triage_level TEXT CHECK (triage_level IN ('resuscitation','emergency','urgent','less_urgent','non_urgent'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patient_visitations' AND column_name = 'triage_score') THEN
    ALTER TABLE public.patient_visitations ADD COLUMN triage_score INTEGER;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patient_visitations' AND column_name = 'triage_notes') THEN
    ALTER TABLE public.patient_visitations ADD COLUMN triage_notes TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patient_visitations' AND column_name = 'chief_complaint') THEN
    ALTER TABLE public.patient_visitations ADD COLUMN chief_complaint TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patient_visitations' AND column_name = 'assessment_id') THEN
    ALTER TABLE public.patient_visitations ADD COLUMN assessment_id UUID REFERENCES public.assessments(assessment_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patient_visitations' AND column_name = 'disposition_type') THEN
    ALTER TABLE public.patient_visitations ADD COLUMN disposition_type TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patient_visitations' AND column_name = 'disposition_target_room') THEN
    ALTER TABLE public.patient_visitations ADD COLUMN disposition_target_room TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patient_visitations' AND column_name = 'disposition_target_bed') THEN
    ALTER TABLE public.patient_visitations ADD COLUMN disposition_target_bed TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patient_visitations' AND column_name = 'disposition_referral_hospital') THEN
    ALTER TABLE public.patient_visitations ADD COLUMN disposition_referral_hospital TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patient_visitations' AND column_name = 'disposition_referral_notes') THEN
    ALTER TABLE public.patient_visitations ADD COLUMN disposition_referral_notes TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patient_visitations' AND column_name = 'disposition_discharge_notes') THEN
    ALTER TABLE public.patient_visitations ADD COLUMN disposition_discharge_notes TEXT;
  END IF;
END $$;

-- Add chief_complaint, anamnesis, physical_exam to assessments table
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'assessments' AND column_name = 'chief_complaint') THEN
    ALTER TABLE public.assessments ADD COLUMN chief_complaint TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'assessments' AND column_name = 'anamnesis') THEN
    ALTER TABLE public.assessments ADD COLUMN anamnesis TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'assessments' AND column_name = 'physical_exam') THEN
    ALTER TABLE public.assessments ADD COLUMN physical_exam TEXT;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
