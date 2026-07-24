CREATE POLICY "Enable insert for authenticated users only"
ON public.drug_stock_logs
FOR INSERT
TO authenticated
WITH CHECK (true);