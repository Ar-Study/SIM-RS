CREATE TABLE IF NOT EXISTS public.anc_visits (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id text NOT NULL,
    visit_date date NOT NULL DEFAULT CURRENT_DATE,
    gestational_age int,
    blood_pressure text,
    weight numeric(5,2),
    fundal_height numeric(5,2),
    fetal_heart_rate int,
    notes text,
    doctor_id text,
    created_by uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.anc_visits ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    EXECUTE format('DROP POLICY IF EXISTS "Allow authenticated full access" ON public.anc_visits;');
    EXECUTE format('CREATE POLICY "Allow authenticated full access" ON public.anc_visits FOR ALL TO authenticated USING (true) WITH CHECK (true);');
    EXECUTE format('DROP POLICY IF EXISTS "Allow anon read access" ON public.anc_visits;');
    EXECUTE format('CREATE POLICY "Allow anon read access" ON public.anc_visits FOR SELECT TO anon USING (true);');
END $$;
