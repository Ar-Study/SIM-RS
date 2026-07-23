-- ============================================
-- Fix treatment_bills: make tariff_id nullable and add tariff_type
-- ============================================

-- Make tariff_id nullable (allows custom bills without tariff reference)
ALTER TABLE public.treatment_bills
  ALTER COLUMN tariff_id DROP NOT NULL;

-- Add tariff_type column for display/categorization
ALTER TABLE public.treatment_bills
  ADD COLUMN IF NOT EXISTS tariff_type TEXT;