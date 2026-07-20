-- 1. Hapus constraint lama yang membatasi huruf kecil saja
ALTER TABLE public.patient_diagnoses 
DROP CONSTRAINT IF EXISTS patient_diagnoses_diagnosis_type_check;

-- 2. Buat aturan baru yang mendukung huruf kapital/toleransi input data Anda
ALTER TABLE public.patient_diagnoses 
ADD CONSTRAINT patient_diagnoses_diagnosis_type_check 
CHECK (diagnosis_type IN ('primer', 'sekunder', 'komplikasi', 'Primer', 'Sekunder'));