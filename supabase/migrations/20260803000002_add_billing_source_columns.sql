-- ============================================
-- Auto-billing: lacak asal tagihan (konsultasi, lab, radiologi, resep)
-- supaya tidak ganda & mudah dihapus saat order dihapus
-- ============================================

ALTER TABLE public.treatment_bills
  ADD COLUMN IF NOT EXISTS source_type TEXT,
  ADD COLUMN IF NOT EXISTS source_id TEXT;

CREATE INDEX IF NOT EXISTS idx_treatment_bills_source
  ON public.treatment_bills (visit_id, source_type, source_id);

-- Registrasi juga perlu membuat tagihan konsultasi
DROP POLICY IF EXISTS "bills_insert" ON public.treatment_bills;
CREATE POLICY "bills_insert" ON public.treatment_bills
  FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','doctor','nurse','cashier','igd','registration'));

-- Hapus tagihan ketika source dihapus (diizinkan untuk dokter/perawat/cashier/registration)
DROP POLICY IF EXISTS "bills_delete" ON public.treatment_bills;
CREATE POLICY "bills_delete" ON public.treatment_bills
  FOR DELETE USING (public.get_user_role() IN ('admin','doctor','nurse','cashier','igd','registration'));

NOTIFY pgrst, 'reload schema';
