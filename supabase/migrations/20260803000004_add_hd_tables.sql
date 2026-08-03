-- Tabel untuk unit Hemodialisis (hd)
CREATE TABLE IF NOT EXISTS public.hd_machines (
  machine_id TEXT PRIMARY KEY,
  machine_no TEXT NOT NULL,
  brand TEXT,
  model TEXT,
  status TEXT DEFAULT 'available' CHECK (status IN ('available','in_use','maintenance')),
  last_maintenance_date DATE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hd_sessions (
  session_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES public.patients(patient_id) ON DELETE CASCADE,
  scheduled_time TIMESTAMPTZ,
  duration_minutes INTEGER DEFAULT 240,
  machine_id TEXT REFERENCES public.hd_machines(machine_id),
  nurse_id TEXT REFERENCES public.employees(employee_id),
  notes TEXT,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled','in_progress','completed','cancelled')),
  pre_weight NUMERIC,
  post_weight NUMERIC,
  ultrafiltration NUMERIC,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hd_sessions_patient ON public.hd_sessions(patient_id);
CREATE INDEX IF NOT EXISTS idx_hd_sessions_status ON public.hd_sessions(status);
CREATE INDEX IF NOT EXISTS idx_hd_sessions_schedule ON public.hd_sessions(scheduled_time);

-- Seed mesin HD contoh
INSERT INTO public.hd_machines (machine_id, machine_no, brand, status) VALUES
  ('HDM-001', 'HD-01', 'Fresenius 4008S', 'available'),
  ('HDM-002', 'HD-02', 'Fresenius 4008S', 'available'),
  ('HDM-003', 'HD-03', 'Nipro Surdial', 'available'),
  ('HDM-004', 'HD-04', 'Nipro Surdial', 'available'),
  ('HDM-005', 'HD-05', 'Fresenius 5008', 'available')
ON CONFLICT (machine_id) DO NOTHING;

ALTER TABLE public.hd_machines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hd_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated full access" ON public.hd_machines;
CREATE POLICY "Allow authenticated full access" ON public.hd_machines
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow anon read access" ON public.hd_machines;
CREATE POLICY "Allow anon read access" ON public.hd_machines
  FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "Allow authenticated full access" ON public.hd_sessions;
CREATE POLICY "Allow authenticated full access" ON public.hd_sessions
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow anon read access" ON public.hd_sessions;
CREATE POLICY "Allow anon read access" ON public.hd_sessions
  FOR SELECT TO anon USING (true);

NOTIFY pgrst, 'reload schema';
