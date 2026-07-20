-- App now uses exam_type as primary field; keep legacy column optional.
ALTER TABLE public.radiology_orders
  ALTER COLUMN examination_type DROP NOT NULL;

-- Keep legacy column populated when possible for backward compatibility.
UPDATE public.radiology_orders
SET examination_type = COALESCE(examination_type, exam_type)
WHERE examination_type IS NULL;

NOTIFY pgrst, 'reload schema';