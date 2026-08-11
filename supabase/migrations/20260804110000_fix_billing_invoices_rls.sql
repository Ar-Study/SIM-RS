-- Allow registration and igd roles to insert/update billing_invoices
-- (original policies only allowed admin and cashier)

DROP POLICY IF EXISTS "invoices_insert" ON public.billing_invoices;
CREATE POLICY "invoices_insert" ON public.billing_invoices
  FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','cashier','registration','igd'));

DROP POLICY IF EXISTS "invoices_update" ON public.billing_invoices;
CREATE POLICY "invoices_update" ON public.billing_invoices
  FOR UPDATE USING (public.get_user_role() IN ('admin','cashier','registration','igd'));

NOTIFY pgrst, 'reload schema';
