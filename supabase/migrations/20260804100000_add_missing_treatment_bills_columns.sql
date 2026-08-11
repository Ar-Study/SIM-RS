-- Add missing source_type and source_id columns to treatment_bills
-- These were intended to be added by 20260803000002 but were not actually applied to remote DB

ALTER TABLE public.treatment_bills
  ADD COLUMN IF NOT EXISTS source_type TEXT,
  ADD COLUMN IF NOT EXISTS source_id TEXT;

-- Ensure tariff_id is nullable for custom/system-generated bills
ALTER TABLE public.treatment_bills
  ALTER COLUMN tariff_id DROP NOT NULL;

-- Create index for efficient lookup
CREATE INDEX IF NOT EXISTS idx_treatment_bills_source
  ON public.treatment_bills (visit_id, source_type, source_id);

NOTIFY pgrst, 'reload schema';
