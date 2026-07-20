-- Align order table columns with current app usage.
-- App expects:
-- - lab_orders: test_name, category, results
-- - radiology_orders: exam_type, description, results

ALTER TABLE public.lab_orders
  ADD COLUMN IF NOT EXISTS test_name TEXT,
  ADD COLUMN IF NOT EXISTS category TEXT,
  ADD COLUMN IF NOT EXISTS results TEXT;

ALTER TABLE public.radiology_orders
  ADD COLUMN IF NOT EXISTS exam_type TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS results TEXT;

-- Backfill app-facing columns from legacy columns when possible.
UPDATE public.radiology_orders
SET
  exam_type = COALESCE(exam_type, examination_type),
  description = COALESCE(description, clinical_info),
  results = COALESCE(results, result)
WHERE
  exam_type IS NULL
  OR description IS NULL
  OR results IS NULL;

CREATE INDEX IF NOT EXISTS idx_lab_orders_category ON public.lab_orders (category);
CREATE INDEX IF NOT EXISTS idx_radiology_orders_exam_type ON public.radiology_orders (exam_type);

-- Refresh PostgREST schema cache so new columns are immediately discoverable.
NOTIFY pgrst, 'reload schema';