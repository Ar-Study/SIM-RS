-- =========================================================================
-- 1. PERBAIKAN & STRUKTUR TABEL: assessments
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.assessments (
    assessment_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    visit_id TEXT NOT NULL, -- Menggunakan TEXT menyesuaikan format "VIS2026XXXX"
    subjective TEXT,
    objective TEXT,
    sistolik NUMERIC,
    diastolik NUMERIC,
    suhu NUMERIC,
    nadi NUMERIC,
    rr NUMERIC,
    gcs NUMERIC,
    tb NUMERIC,
    bb NUMERIC,
    spo2 NUMERIC,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Mengaktifkan RLS pada tabel assessments
ALTER TABLE public.assessments ENABLE ROW LEVEL SECURITY;

-- Membuat Kebijakan RLS untuk assessments (Akses Publik / Dev Mode)
DROP POLICY IF EXISTS "Allow public insert" ON public.assessments;
DROP POLICY IF EXISTS "Allow public select" ON public.assessments;

CREATE POLICY "Allow public insert" ON public.assessments FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "Allow public select" ON public.assessments FOR SELECT TO anon, authenticated USING (true);


-- =========================================================================
-- 2. PERBAIKAN & STRUKTUR TABEL: cppt
-- =========================================================================
-- Memastikan RLS aktif pada cppt
ALTER TABLE public.cppt ENABLE ROW LEVEL SECURITY;

-- Membuat Kebijakan RLS untuk cppt (Mengatasi error RLS Policy)
DROP POLICY IF EXISTS "Allow public insert" ON public.cppt;
DROP POLICY IF EXISTS "Allow public select" ON public.cppt;

CREATE POLICY "Allow public insert" ON public.cppt FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "Allow public select" ON public.cppt FOR SELECT TO anon, authenticated USING (true);


-- =========================================================================
-- 3. PERBAIKAN & STRUKTUR TABEL: prescriptions
-- =========================================================================
-- Menambahkan kolom yang hilang di tabel prescriptions jika belum ada
ALTER TABLE public.prescriptions ADD COLUMN IF NOT EXISTS drug_id TEXT;
ALTER TABLE public.prescriptions ADD COLUMN IF NOT EXISTS drug_name TEXT;
ALTER TABLE public.prescriptions ADD COLUMN IF NOT EXISTS qty INTEGER;
ALTER TABLE public.prescriptions ADD COLUMN IF NOT EXISTS dosage TEXT;
ALTER TABLE public.prescriptions ADD COLUMN IF NOT EXISTS frequency TEXT;
ALTER TABLE public.prescriptions ADD COLUMN IF NOT EXISTS instruction TEXT;

-- Memastikan tipe data drug_id di prescriptions adalah TEXT (menyamakan master drugs)
ALTER TABLE public.prescriptions ALTER COLUMN drug_id TYPE TEXT;

-- Memasang kembali Foreign Key Constraint ke tabel drugs
ALTER TABLE public.prescriptions DROP CONSTRAINT IF EXISTS fk_prescriptions_drugs;
ALTER TABLE public.prescriptions
ADD CONSTRAINT fk_prescriptions_drugs
FOREIGN KEY (drug_id) REFERENCES public.drugs(drug_id)
ON DELETE SET NULL;

-- Memastikan RLS aktif pada prescriptions
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;

-- Membuat Kebijakan RLS untuk prescriptions
DROP POLICY IF EXISTS "Allow public insert" ON public.prescriptions;
DROP POLICY IF EXISTS "Allow public select" ON public.prescriptions;

CREATE POLICY "Allow public insert" ON public.prescriptions FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "Allow public select" ON public.prescriptions FOR SELECT TO anon, authenticated USING (true);


-- =========================================================================
-- 4. REFRESH SCHEMA CACHE
-- =========================================================================
-- Memaksa PostgREST memuat ulang cache skema agar perubahan langsung dikenali client
NOTIFY pgrst, 'reload schema';