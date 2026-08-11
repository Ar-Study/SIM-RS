-- Clear all patient visitations and dependent data for fresh start

-- Delete from tables referencing patient_visitations WITHOUT ON DELETE CASCADE first
DELETE FROM public.billing_invoices;
DELETE FROM public.discharge_summaries;
DELETE FROM public.integrasi_satusehat;

-- Clear visitations (all other dependent tables have ON DELETE CASCADE)
DELETE FROM public.patient_visitations;
