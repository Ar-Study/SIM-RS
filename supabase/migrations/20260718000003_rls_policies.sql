-- RLS Policies for SIMRS
-- ============================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_visitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cppt ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_analysis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.radiology_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.treatment_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drugs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drug_stock_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Helper: get current user role
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper: check if admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT public.get_user_role() = 'admin';
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Profiles: users can read all, update own
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_admin_all" ON public.profiles FOR ALL USING (public.is_admin());

-- Patients: authenticated users can read, registration+admin can modify
CREATE POLICY "patients_select" ON public.patients FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "patients_insert" ON public.patients FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','registration'));
CREATE POLICY "patients_update" ON public.patients FOR UPDATE USING (public.get_user_role() IN ('admin','registration'));
CREATE POLICY "patients_delete" ON public.patients FOR DELETE USING (public.is_admin());

-- Patient Visitations: authenticated read, registration/doctor/admin modify
CREATE POLICY "visitations_select" ON public.patient_visitations FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "visitations_insert" ON public.patient_visitations FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','registration'));
CREATE POLICY "visitations_update" ON public.patient_visitations FOR UPDATE USING (public.get_user_role() IN ('admin','registration','doctor','nurse','pharmacist','cashier','igd'));
CREATE POLICY "visitations_delete" ON public.patient_visitations FOR DELETE USING (public.is_admin());

-- CPPT: doctor/nurse can CRUD, all authenticated can read
CREATE POLICY "cppt_select" ON public.cppt FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "cppt_insert" ON public.cppt FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','doctor','nurse','igd'));
CREATE POLICY "cppt_update" ON public.cppt FOR UPDATE USING (public.get_user_role() IN ('admin','doctor','nurse','igd'));

-- Lab orders
CREATE POLICY "lab_orders_select" ON public.lab_orders FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "lab_orders_insert" ON public.lab_orders FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','doctor','nurse','igd'));
CREATE POLICY "lab_orders_update" ON public.lab_orders FOR UPDATE USING (public.get_user_role() IN ('admin','doctor','lab_tech'));

-- Lab analysis
CREATE POLICY "lab_analysis_select" ON public.lab_analysis FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "lab_analysis_insert" ON public.lab_analysis FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','lab_tech'));
CREATE POLICY "lab_analysis_update" ON public.lab_analysis FOR UPDATE USING (public.get_user_role() IN ('admin','lab_tech'));

-- Radiology orders
CREATE POLICY "radiology_select" ON public.radiology_orders FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "radiology_insert" ON public.radiology_orders FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','doctor','nurse','igd'));
CREATE POLICY "radiology_update" ON public.radiology_orders FOR UPDATE USING (public.get_user_role() IN ('admin','radiology_tech'));

-- Prescriptions
CREATE POLICY "prescriptions_select" ON public.prescriptions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "prescriptions_insert" ON public.prescriptions FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','doctor','nurse','igd'));
CREATE POLICY "prescriptions_update" ON public.prescriptions FOR UPDATE USING (public.get_user_role() IN ('admin','pharmacist'));

-- Prescription items
CREATE POLICY "prescription_items_select" ON public.prescription_items FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "prescription_items_insert" ON public.prescription_items FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','doctor','nurse'));
CREATE POLICY "prescription_items_update" ON public.prescription_items FOR UPDATE USING (public.get_user_role() IN ('admin','pharmacist'));

-- Treatment bills
CREATE POLICY "bills_select" ON public.treatment_bills FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "bills_insert" ON public.treatment_bills FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','doctor','nurse','cashier','igd'));
CREATE POLICY "bills_delete" ON public.treatment_bills FOR DELETE USING (public.is_admin());

-- Billing invoices
CREATE POLICY "invoices_select" ON public.billing_invoices FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "invoices_insert" ON public.billing_invoices FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','cashier'));
CREATE POLICY "invoices_update" ON public.billing_invoices FOR UPDATE USING (public.get_user_role() IN ('admin','cashier'));

-- Drugs: all authenticated read, pharmacist+warehouse+admin modify
CREATE POLICY "drugs_select" ON public.drugs FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "drugs_insert" ON public.drugs FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','pharmacist','warehouse'));
CREATE POLICY "drugs_update" ON public.drugs FOR UPDATE USING (public.get_user_role() IN ('admin','pharmacist','warehouse'));

-- Drug stock logs
CREATE POLICY "stock_logs_select" ON public.drug_stock_logs FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "stock_logs_insert" ON public.drug_stock_logs FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','pharmacist','warehouse'));

-- Audit logs: admin only
CREATE POLICY "audit_select" ON public.audit_logs FOR SELECT USING (public.is_admin());
CREATE POLICY "audit_insert" ON public.audit_logs FOR INSERT WITH CHECK (auth.role() = 'authenticated');
