-- =============================================
-- SIMRS FULL MIGRATION
-- Jalankan ini di Supabase Dashboard > SQL Editor
-- =============================================


-- ============================================
-- 001_initial_schema.sql
-- ============================================
-- SIMRS Database Schema for Supabase (PostgreSQL)
-- ================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. PROFILES (extends Supabase Auth)
-- ============================================
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  role TEXT NOT NULL CHECK (role IN ('admin','registration','doctor','nurse','pharmacist','lab_tech','radiology_tech','cashier','warehouse','igd')),
  employee_id TEXT,
  is_active BOOLEAN DEFAULT true,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 2. MASTER DATA
-- ============================================
CREATE TABLE public.employees (
  employee_id TEXT PRIMARY KEY DEFAULT ('EMP-' || upper(substr(md5(random()::text), 1, 6))),
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'doctor',
  gender TEXT CHECK (gender IN ('L','P')),
  phone TEXT,
  email TEXT,
  specialization TEXT,
  department TEXT,
  is_dpjp BOOLEAN DEFAULT false,
  satusehat_practitioner_id TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.clinics (
  clinic_id TEXT PRIMARY KEY DEFAULT ('POL-' || upper(substr(md5(random()::text), 1, 6))),
  name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.room_classes (
  class_id TEXT PRIMARY KEY DEFAULT ('CLS-' || upper(substr(md5(random()::text), 1, 6))),
  name TEXT NOT NULL,
  base_price NUMERIC DEFAULT 0,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.rooms (
  room_id TEXT PRIMARY KEY DEFAULT ('RM-' || upper(substr(md5(random()::text), 1, 6))),
  class_id TEXT REFERENCES public.room_classes(class_id),
  clinic_id TEXT REFERENCES public.clinics(clinic_id),
  room_number TEXT NOT NULL,
  floor TEXT DEFAULT '1',
  is_occupied BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.beds (
  bed_id TEXT PRIMARY KEY DEFAULT ('BD-' || upper(substr(md5(random()::text), 1, 6))),
  room_id TEXT REFERENCES public.rooms(room_id),
  bed_number TEXT NOT NULL,
  is_occupied BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.payors (
  payor_id TEXT PRIMARY KEY DEFAULT ('PAY-' || upper(substr(md5(random()::text), 1, 6))),
  name TEXT NOT NULL,
  type TEXT CHECK (type IN ('bpjs','insurance','personal','corporate')),
  bpjs_code TEXT,
  contact_person TEXT,
  phone TEXT,
  address TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.diagnoses (
  diagnosis_id TEXT PRIMARY KEY DEFAULT ('DX-' || upper(substr(md5(random()::text), 1, 6))),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.tariffs (
  tariff_id TEXT PRIMARY KEY DEFAULT ('TRF-' || upper(substr(md5(random()::text), 1, 6))),
  category TEXT NOT NULL DEFAULT 'Konsultasi',
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC DEFAULT 0,
  clinic_id TEXT REFERENCES public.clinics(clinic_id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.drugs (
  drug_id TEXT PRIMARY KEY DEFAULT ('DRG-' || upper(substr(md5(random()::text), 1, 6))),
  name TEXT NOT NULL,
  generic_name TEXT,
  category TEXT,
  unit TEXT NOT NULL DEFAULT 'tablet',
  buy_price NUMERIC DEFAULT 0,
  sell_price NUMERIC DEFAULT 0,
  stock INTEGER DEFAULT 0,
  min_stock INTEGER DEFAULT 10,
  expiry_date DATE,
  manufacturer TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 3. PATIENTS & REGISTRATION
-- ============================================
CREATE TABLE public.patients (
  patient_id TEXT PRIMARY KEY DEFAULT ('PAS-' || upper(substr(md5(random()::text), 1, 8))),
  no_registration TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  gender TEXT NOT NULL CHECK (gender IN ('L','P')),
  date_of_birth DATE NOT NULL,
  nik TEXT,
  phone TEXT,
  address TEXT,
  blood_type TEXT,
  religion TEXT,
  marital_status TEXT,
  occupation TEXT,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  insurance_number TEXT,
  payor_id TEXT REFERENCES public.payors(payor_id),
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.patient_visitations (
  visit_id TEXT PRIMARY KEY DEFAULT ('VST-' || upper(substr(md5(random()::text), 1, 8))),
  patient_id TEXT NOT NULL REFERENCES public.patients(patient_id),
  clinic_id TEXT NOT NULL REFERENCES public.clinics(clinic_id),
  clinic_id_from TEXT REFERENCES public.clinics(clinic_id),
  doctor_id TEXT REFERENCES public.employees(employee_id),
  booked_date DATE,
  visit_date TIMESTAMPTZ DEFAULT now(),
  ticket_no SERIAL,
  status_pembayaran TEXT DEFAULT '0' CHECK (status_pembayaran IN ('0','1','2')),
  status_periksa TEXT DEFAULT '0' CHECK (status_periksa IN ('0','1')),
  status_keluar TEXT DEFAULT '0' CHECK (status_keluar IN ('0','1')),
  description TEXT,
  visit_type TEXT NOT NULL CHECK (visit_type IN ('rawat_jalan','rawat_inap','igd')),
  room_id TEXT REFERENCES public.rooms(room_id),
  bed_id TEXT REFERENCES public.beds(bed_id),
  class_id TEXT REFERENCES public.room_classes(class_id),
  payor_id TEXT REFERENCES public.payors(payor_id),
  in_date TIMESTAMPTZ DEFAULT now(),
  exit_date TIMESTAMPTZ,
  call_times INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.online_registrations (
  id SERIAL PRIMARY KEY,
  patient_id TEXT REFERENCES public.patients(patient_id),
  clinic_id TEXT REFERENCES public.clinics(clinic_id),
  doctor_id TEXT REFERENCES public.employees(employee_id),
  booked_date DATE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','confirmed','cancelled')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 4. CLINICAL
-- ============================================
CREATE TABLE public.assessment_poli (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  subjective TEXT,
  objective TEXT,
  height NUMERIC,
  weight NUMERIC,
  blood_pressure_sistolik INTEGER,
  blood_pressure_diastolik INTEGER,
  heart_rate INTEGER,
  temperature NUMERIC,
  respiratory_rate INTEGER,
  gcs INTEGER,
  spo2 INTEGER,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.assessment_igd (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  triage_level TEXT CHECK (triage_level IN ('resuscitation','emergency','urgent','less_urgent','non_urgent')),
  chief_complaint TEXT,
  anamnesis TEXT,
  physical_exam TEXT,
  vital_signs JSONB,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.triages (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  level TEXT NOT NULL,
  score INTEGER,
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.cppt (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  waktu_masuk TIMESTAMPTZ DEFAULT now(),
  subyektif TEXT,
  obyektif TEXT,
  assessment TEXT,
  planning TEXT,
  instruksi TEXT,
  created_by UUID REFERENCES public.profiles(id),
  edited_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.patient_diagnoses (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  diagnosis_id TEXT NOT NULL REFERENCES public.diagnoses(diagnosis_id),
  diagnosis_type TEXT DEFAULT 'primer' CHECK (diagnosis_type IN ('primer','sekunder')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.comorbidities (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 5. LABORATORY
-- ============================================
CREATE TABLE public.lab_orders (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  order_date TIMESTAMPTZ DEFAULT now(),
  status TEXT DEFAULT 'ordered' CHECK (status IN ('ordered','in_progress','completed','cancelled')),
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  completed_at TIMESTAMPTZ
);

CREATE TABLE public.lab_analysis (
  id SERIAL PRIMARY KEY,
  lab_order_id INTEGER NOT NULL REFERENCES public.lab_orders(id) ON DELETE CASCADE,
  analysis_name TEXT NOT NULL,
  category TEXT,
  normal_value TEXT,
  result TEXT,
  unit TEXT,
  method TEXT,
  flag TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 6. RADIOLOGY
-- ============================================
CREATE TABLE public.radiology_orders (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  examination_type TEXT NOT NULL,
  body_part TEXT,
  clinical_info TEXT,
  status TEXT DEFAULT 'ordered' CHECK (status IN ('ordered','in_progress','completed','cancelled')),
  result TEXT,
  impression TEXT,
  image_url TEXT,
  ordered_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ
);

-- ============================================
-- 7. PHARMACY
-- ============================================
CREATE TABLE public.drug_stock_logs (
  id SERIAL PRIMARY KEY,
  drug_id TEXT NOT NULL REFERENCES public.drugs(drug_id),
  change_type TEXT CHECK (change_type IN ('in','out','adjustment')),
  quantity INTEGER NOT NULL,
  reference TEXT,
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.prescriptions (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  prescription_type TEXT CHECK (prescription_type IN ('rajal','ranap')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','dispensed','cancelled')),
  doctor_id TEXT REFERENCES public.employees(employee_id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  dispensed_at TIMESTAMPTZ
);

CREATE TABLE public.prescription_items (
  id SERIAL PRIMARY KEY,
  prescription_id INTEGER NOT NULL REFERENCES public.prescriptions(id) ON DELETE CASCADE,
  drug_id TEXT NOT NULL REFERENCES public.drugs(drug_id),
  quantity INTEGER NOT NULL,
  dosage TEXT,
  frequency TEXT,
  duration TEXT,
  instruction TEXT,
  unit_price NUMERIC DEFAULT 0,
  total_price NUMERIC DEFAULT 0,
  is_dispensed BOOLEAN DEFAULT false
);

CREATE TABLE public.free_drug_sales (
  id SERIAL PRIMARY KEY,
  buyer_name TEXT,
  buyer_phone TEXT,
  sale_date TIMESTAMPTZ DEFAULT now(),
  total_amount NUMERIC DEFAULT 0,
  discount NUMERIC DEFAULT 0,
  net_amount NUMERIC DEFAULT 0,
  payment_method TEXT DEFAULT 'cash',
  created_by UUID REFERENCES public.profiles(id)
);

CREATE TABLE public.free_drug_sale_items (
  id SERIAL PRIMARY KEY,
  sale_id INTEGER NOT NULL REFERENCES public.free_drug_sales(id) ON DELETE CASCADE,
  drug_id TEXT NOT NULL REFERENCES public.drugs(drug_id),
  quantity INTEGER NOT NULL,
  unit_price NUMERIC NOT NULL,
  total_price NUMERIC NOT NULL
);

-- ============================================
-- 8. BILLING
-- ============================================
CREATE TABLE public.treatment_bills (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  tariff_id TEXT NOT NULL REFERENCES public.tariffs(tariff_id),
  quantity INTEGER DEFAULT 1,
  unit_price NUMERIC DEFAULT 0,
  amount NUMERIC DEFAULT 0,
  nominal_rs NUMERIC DEFAULT 0,
  nominal_nakes NUMERIC DEFAULT 0,
  clinic_id TEXT REFERENCES public.clinics(clinic_id),
  description TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.billing_invoices (
  invoice_id TEXT PRIMARY KEY DEFAULT ('INV-' || upper(substr(md5(random()::text), 1, 8))),
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id),
  total_amount NUMERIC DEFAULT 0,
  discount NUMERIC DEFAULT 0,
  net_amount NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'unpaid' CHECK (status IN ('unpaid','paid','partial','cancelled')),
  paid_amount NUMERIC DEFAULT 0,
  payment_method TEXT,
  payment_note TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  paid_at TIMESTAMPTZ
);

-- ============================================
-- 9. SURGERY
-- ============================================
CREATE TABLE public.surgery_requests (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  procedure_name TEXT NOT NULL,
  description TEXT,
  requested_date DATE,
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('urgent','elective','normal')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','scheduled','in_progress','completed','cancelled')),
  surgeon_id TEXT REFERENCES public.employees(employee_id),
  assistant_surgeon_id TEXT REFERENCES public.employees(employee_id),
  anesthesia_type TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.surgery_bookings (
  id SERIAL PRIMARY KEY,
  surgery_request_id INTEGER NOT NULL REFERENCES public.surgery_requests(id) ON DELETE CASCADE,
  room_id TEXT REFERENCES public.rooms(room_id),
  scheduled_date TIMESTAMPTZ NOT NULL,
  actual_start TIMESTAMPTZ,
  actual_end TIMESTAMPTZ,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled','in_progress','completed','cancelled')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 10. INPATIENT DISCHARGE
-- ============================================
CREATE TABLE public.discharge_summaries (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE UNIQUE,
  discharge_date TIMESTAMPTZ NOT NULL,
  discharge_condition TEXT CHECK (discharge_condition IN ('sembuh','berobat_jalan','rujuk','meninggal','lainnya')),
  final_diagnosis TEXT,
  treatment_summary TEXT,
  medication_on_discharge TEXT,
  follow_up_notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 11. INTEGRATION
-- ============================================
CREATE TABLE public.satusehat_tokens (
  id SERIAL PRIMARY KEY,
  access_token TEXT NOT NULL,
  token_type TEXT DEFAULT 'Bearer',
  expires_at TIMESTAMPTZ NOT NULL,
  org_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.integrasi_satusehat (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id),
  patient_fhir_id TEXT,
  location_fhir_id TEXT,
  practitioner_fhir_id TEXT,
  encounter_fhir_id TEXT,
  condition_main_fhir_id TEXT,
  condition_comorbid_fhir_id TEXT,
  observation_sistolik NUMERIC,
  observation_diastolik NUMERIC,
  observation_suhu NUMERIC,
  observation_nadi INTEGER,
  observation_rr INTEGER,
  observation_gcs INTEGER,
  observation_tb NUMERIC,
  observation_bb NUMERIC,
  procedure_fhir_id TEXT,
  composition_fhir_id TEXT,
  allergy_fhir_id TEXT,
  status JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.bpjs_references (
  id SERIAL PRIMARY KEY,
  ref_type TEXT NOT NULL,
  bpjs_code TEXT NOT NULL,
  local_code TEXT,
  name TEXT NOT NULL,
  metadata JSONB,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 12. AUDIT LOG
-- ============================================
CREATE TABLE public.audit_logs (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id),
  action TEXT NOT NULL,
  table_name TEXT NOT NULL,
  record_id TEXT,
  old_data JSONB,
  new_data JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_visitations_patient ON public.patient_visitations(patient_id);
CREATE INDEX idx_visitations_clinic ON public.patient_visitations(clinic_id);
CREATE INDEX idx_visitations_date ON public.patient_visitations(visit_date);
CREATE INDEX idx_visitations_type ON public.patient_visitations(visit_type);
CREATE INDEX idx_visitations_status ON public.patient_visitations(status_periksa, status_pembayaran);
CREATE INDEX idx_cppt_visit ON public.cppt(visit_id);
CREATE INDEX idx_lab_orders_visit ON public.lab_orders(visit_id);
CREATE INDEX idx_lab_orders_status ON public.lab_orders(status);
CREATE INDEX idx_radiology_visit ON public.radiology_orders(visit_id);
CREATE INDEX idx_prescriptions_visit ON public.prescriptions(visit_id);
CREATE INDEX idx_prescriptions_status ON public.prescriptions(status);
CREATE INDEX idx_treatment_bills_visit ON public.treatment_bills(visit_id);
CREATE INDEX idx_billing_visit ON public.billing_invoices(visit_id);
CREATE INDEX idx_drugs_stock ON public.drugs(stock);
CREATE INDEX idx_drugs_category ON public.drugs(category);
CREATE INDEX idx_diagnoses_code ON public.diagnoses(code);
CREATE INDEX idx_patient_nik ON public.patients(nik);
CREATE INDEX idx_patient_name ON public.patients(full_name);
CREATE INDEX idx_tariffs_category ON public.tariffs(category);
CREATE INDEX idx_surgery_requests_status ON public.surgery_requests(status);


-- ============================================
-- 002_seed_data.sql
-- ============================================
-- Seed Data for SIMRS
-- ============================================

-- Room Classes
INSERT INTO public.room_classes (class_id, name, base_price, description) VALUES
('CLS-VIP', 'VIP', 500000, 'Kelas VIP'),
('CLS-II', 'Kelas II', 200000, 'Kelas II'),
('CLS-III', 'Kelas III', 100000, 'Kelas III'),
('CLS-ICU', 'ICU', 800000, 'Intensive Care Unit'),
('CLS-NICU', 'NICU', 900000, 'Neonatal Intensive Care Unit'),
('CLS-HD', 'Hemodialisis', 600000, 'Hemodialysis');

-- Clinics
INSERT INTO public.clinics (clinic_id, name, description) VALUES
('POL-UMUM', 'Poli Umum', 'Poli Umum / General Practice'),
('POL-IGD', 'IGD', 'Instalasi Gawat Darurat'),
('POL-ANAK', 'Poli Anak', 'Pediatri'),
('POL-OBGYN', 'Poli Kandungan', 'Obstetri dan Ginekologi'),
('POL-PERA', 'Poli Penyakit Dalam', 'Internal Medicine'),
('POL-MATA', 'Poli Mata', 'Oftalmologi'),
('POL-THT', 'Poli THT', 'Telinga Hidung Tenggorokan'),
('POL-KULIT', 'Poli Kulit', 'Dermatologi'),
('POL-JIWA', 'Poli Jiwa', 'Psikiatri'),
('POL-GIGI', 'Poli Gigi', 'Dokter Gigi'),
('POL-ORTH', 'Poli Orthopedi', 'Orthopedi'),
('POL-SYARAF', 'Poli Saraf', 'Neurologi'),
('POL-JANTUNG', 'Poli Jantung', 'Kardiologi'),
('POL-GIZI', 'Poli Gizi', 'Klinik Gizi'),
('POL-LAB', 'Laboratorium', 'Laboratorium Klinik'),
('POL-RAD', 'Radiologi', 'Radiologi'),
('POL-FAR', 'Farmasi', 'Farmasi / Apotik'),
('POL-OK', 'Kamar Operasi', 'Operating Theatre'),
('POL-VK', 'VK', 'Verloskamer / Kamar Bersalin'),
('POL-ICU', 'ICU', 'Intensive Care Unit'),
('POL-NICU', 'NICU', 'Neonatal Intensive Care Unit'),
('POL-HD', 'Hemodialisis', 'Hemodialysis Unit'),
('POL-IBS', 'IBS', 'Instalasi Bedah Sentra'),
('POL-RANAP', 'Rawat Inap', 'Rawat Inap / Inpatient');

-- Sample employees
INSERT INTO public.employees (employee_id, full_name, role, gender, specialization, department, is_dpjp) VALUES
('DOC-001', 'dr. Ahmad Suharto, Sp.PD', 'doctor', 'L', 'Penyakit Dalam', 'Poliklinik', true),
('DOC-002', 'dr. Siti Rahayu, Sp.A', 'doctor', 'P', 'Anak', 'Poliklinik', true),
('DOC-003', 'dr. Budi Prasetyo, Sp.B', 'doctor', 'L', 'Bedah Umum', 'Bedah', true),
('DOC-004', 'dr. Dewi Lestari, Sp.OG', 'doctor', 'P', 'Kandungan', 'Kandungan', true),
('DOC-005', 'dr. Eko Wijaya, Sp.M', 'doctor', 'L', 'Mata', 'Mata', true),
('DOC-006', 'dr. Fitri Handayani, Sp.THT', 'doctor', 'P', 'THT-KL', 'THT', true),
('DOC-007', 'dr. Gunawan Kurniawan, Sp.S', 'doctor', 'L', 'Saraf', 'Saraf', true),
('DOC-008', 'dr. Hana Permata, Sp.KK', 'doctor', 'P', 'Kulit dan Kelamin', 'Kulit', true),
('NRS-001', 'Andi Saputra', 'nurse', 'L', 'Perawat', 'IGD', false),
('NRS-002', 'Budi Santoso', 'nurse', 'L', 'Perawat', 'Rawat Inap', false),
('NRS-003', 'Citra Dewi', 'nurse', 'P', 'Perawat', 'Rawat Jalan', false),
('LAB-001', 'Danang Prasetyo', 'lab_tech', 'L', 'Laboratorium', 'Laboratorium', false),
('RAD-001', 'Eka Fitriani', 'radiology_tech', 'P', 'Radiologi', 'Radiologi', false),
('FRM-001', 'Fajar Nugroho', 'pharmacist', 'L', 'Farmasi', 'Farmasi', false),
('KSR-001', 'Gita Sari', 'cashier', 'P', 'Kasir', 'Keuangan', false);

-- Sample payors
INSERT INTO public.payors (payor_id, name, type, bpjs_code) VALUES
('PAY-BPJS1', 'BPJS Kesehatan Kelas 1', 'bpjs', '1'),
('PAY-BPJS2', 'BPJS Kesehatan Kelas 2', 'bpjs', '2'),
('PAY-BPJS3', 'BPJS Kesehatan Kelas 3', 'bpjs', '3'),
('PAY-PRIBADI', 'Umum / Pribadi', 'personal', NULL),
('PAY-ASURANSI1', 'Prudential Life Assurance', 'insurance', NULL),
('PAY-CORP1', 'PT. Maju Bersama', 'corporate', NULL);

-- Sample tariffs
INSERT INTO public.tariffs (tariff_id, category, name, price, clinic_id) VALUES
('TRF-KONS-UMUM', 'Konsultasi', 'Konsultasi Dokter Umum', 150000, 'POL-UMUM'),
('TRF-KONS-SP', 'Konsultasi', 'Konsultasi Dokter Spesialis', 250000, NULL),
('TRF-KONS-IGD', 'Konsultasi', 'Konsultasi IGD', 300000, 'POL-IGD'),
('TRF-AKO-VIP', 'Akomodasi', 'Akomodasi VIP', 500000, NULL),
('TRF-AKO-II', 'Akomodasi', 'Akomodasi Kelas II', 200000, NULL),
('TRF-AKO-III', 'Akomodasi', 'Akomodasi Kelas III', 100000, NULL),
('TRF-AKO-ICU', 'Akomodasi', 'Akomodasi ICU', 800000, NULL),
('TRF-LAB-DARAH', 'Laboratorium', 'Pemeriksaan Darah Lengkap', 75000, 'POL-LAB'),
('TRF-LAB-URIN', 'Laboratorium', 'Pemeriksaan Urine Lengkap', 50000, 'POL-LAB'),
('TRF-LAB-GDS', 'Laboratorium', 'Gula Darah Sewaktu', 35000, 'POL-LAB'),
('TRF-LAB-CHO', 'Laboratorium', 'Cholesterol Total', 45000, 'POL-LAB'),
('TRF-RAD-RONTGEN', 'Radiologi', 'Rontgen Thorax', 150000, 'POL-RAD'),
('TRF-RAD-USG', 'Radiologi', 'USG Abdomen', 200000, 'POL-RAD'),
('TRF-RAD-CT', 'Radiologi', 'CT Scan', 800000, 'POL-RAD'),
('TRF-TDK-INJEKSI', 'Tindakan', 'Injeksi/Intravena', 25000, NULL),
('TRF-TDK-NEBUL', 'Tindakan', 'Nebulisasi', 50000, NULL),
('TRF-TDK-INFUS', 'Tindakan', 'Pemasangan Infus', 75000, NULL),
('TRF-TDK-JAHIT', 'Tindakan', 'Penjahitan Luka', 150000, NULL),
('TRF-VIS-DOKTER', 'Visite Dokter', 'Visite Dokter', 100000, NULL);

-- Sample diagnoses
INSERT INTO public.diagnoses (diagnosis_id, code, name, category) VALUES
('DX-A09', 'A09', 'Diare dan gastroenteritis', 'Penyakit Infeksi'),
('DX-J06', 'J06', 'Infeksi saluran pernapasan akut', 'Respirasi'),
('DX-I10', 'I10', 'Hipertensi primer', 'Kardiovaskular'),
('DX-E11', 'E11', 'Diabetes mellitus tipe 2', 'Endokrin'),
('DX-K29', 'K29', 'Gastritis', 'Gastrointestinal'),
('DX-N39', 'N39', 'Infeksi saluran kemih', 'Urologi'),
('DX-M54', 'M54', 'Dorsalgia (nyeri punggung)', 'Muskuloskeletal'),
('DX-K80', 'K80', 'Batu kandung empedu', 'Gastrointestinal'),
('DX-J18', 'J18', 'Pneumonia', 'Respirasi'),
('DX-G40', 'G40', 'Epilepsi', 'Neurologi'),
('DX-O80', 'O80', 'Pengiriman spontan', 'Obstetri'),
('DX-L03', 'L03', 'Selulitis', 'Dermatologi'),
('DX-H65', 'H65', 'Otitis media', 'THT'),
('DX-S82', 'S82', 'Fraktur tungkai bawah', 'Orthopedi'),
('DX-F32', 'F32', 'Episode depresif Mayor', 'Psikiatri');

-- Sample drugs
INSERT INTO public.drugs (drug_id, name, generic_name, category, unit, buy_price, sell_price, stock, min_stock) VALUES
('DRG-001', 'Paracetamol 500mg', 'Paracetamol', 'Analgesik', 'tablet', 200, 500, 1000, 100),
('DRG-002', 'Amoxicillin 500mg', 'Amoxicillin', 'Antibiotik', 'kaplet', 800, 1500, 500, 50),
('DRG-003', 'Omeprazol 20mg', 'Omeprazol', 'Gastrointestinal', 'kaplet', 500, 1000, 300, 30),
('DRG-004', 'Metformin 500mg', 'Metformin', 'Endokrin', 'tablet', 300, 700, 400, 40),
('DRG-005', 'Amlodipine 5mg', 'Amlodipine', 'Kardiovaskular', 'tablet', 600, 1200, 350, 30),
('DRG-006', 'Cetirizine 10mg', 'Cetirizine', 'Antihistamin', 'tablet', 300, 700, 250, 25),
('DRG-007', 'Salbutamol Nebulizer', 'Salbutamol', 'Respirasi', 'kotak', 15000, 25000, 50, 10),
('DRG-008', 'Ringer Lactat 500ml', 'Ringer Lactat', 'Infus', 'botol', 8000, 15000, 200, 20),
('DRG-009', 'NaCl 0.9% 500ml', 'Natrium Klorida', 'Infus', 'botol', 6000, 12000, 300, 30),
('DRG-010', 'Diclofenac 50mg', 'Diclofenac', 'Analgesik', 'tablet', 250, 600, 400, 40),
('DRG-011', 'Ciprofloxacin 500mg', 'Ciprofloxacin', 'Antibiotik', 'tablet', 1000, 2000, 200, 20),
('DRG-012', 'Vitamin C 1000mg', 'Ascorbic Acid', 'Vitamin', 'tablet', 150, 400, 800, 50),
('DRG-013', 'Vitamin B Complex', 'Vitamin B Kompleks', 'Vitamin', 'tablet', 100, 300, 600, 50),
('DRG-014', 'Antangin JRG', 'Herbal', 'Lainnya', 'sachet', 500, 1000, 500, 50),
('DRG-015', 'Tromboflash', 'Heparin', 'Kardiovaskular', 'injeksi', 25000, 45000, 30, 5),
('DRG-016', 'Ranitidine 150mg', 'Ranitidine', 'Gastrointestinal', 'tablet', 200, 500, 300, 30),
('DRG-017', 'Dexamethasone 0.5mg', 'Dexamethasone', 'Kortikosteroid', 'tablet', 150, 400, 250, 25),
('DRG-018', 'Prednison 5mg', 'Prednison', 'Kortikosteroid', 'tablet', 200, 500, 200, 20),
('DRG-019', 'Ibuprofen 400mg', 'Ibuprofen', 'Analgesik', 'tablet', 250, 600, 500, 50),
('DRG-020', 'ORS Sachet', 'Oral Rehydration Salt', 'Lainnya', 'sachet', 300, 800, 1000, 100);

-- Sample rooms
INSERT INTO public.rooms (room_id, class_id, clinic_id, room_number, floor) VALUES
('RM-VIP-01', 'CLS-VIP', 'POL-RANAP', 'VIP-01', '3'),
('RM-VIP-02', 'CLS-VIP', 'POL-RANAP', 'VIP-02', '3'),
('RM-II-01', 'CLS-II', 'POL-RANAP', 'II-01', '2'),
('RM-II-02', 'CLS-II', 'POL-RANAP', 'II-02', '2'),
('RM-II-03', 'CLS-II', 'POL-RANAP', 'II-03', '2'),
('RM-III-01', 'CLS-III', 'POL-RANAP', 'III-01', '1'),
('RM-III-02', 'CLS-III', 'POL-RANAP', 'III-02', '1'),
('RM-III-03', 'CLS-III', 'POL-RANAP', 'III-03', '1'),
('RM-III-04', 'CLS-III', 'POL-RANAP', 'III-04', '1'),
('RM-ICU-01', 'CLS-ICU', 'POL-ICU', 'ICU-01', '3'),
('RM-ICU-02', 'CLS-ICU', 'POL-ICU', 'ICU-02', '3'),
('RM-NICU-01', 'CLS-NICU', 'POL-NICU', 'NICU-01', '3'),
('RM-HD-01', 'CLS-HD', 'POL-HD', 'HD-01', '2');

-- Sample beds
INSERT INTO public.beds (bed_id, room_id, bed_number) VALUES
('BD-VIP-01A', 'RM-VIP-01', '1'),
('BD-VIP-02A', 'RM-VIP-02', '1'),
('BD-II-01A', 'RM-II-01', '1'),
('BD-II-01B', 'RM-II-01', '2'),
('BD-II-02A', 'RM-II-02', '1'),
('BD-II-03A', 'RM-II-03', '1'),
('BD-III-01A', 'RM-III-01', '1'),
('BD-III-01B', 'RM-III-01', '2'),
('BD-III-02A', 'RM-III-02', '1'),
('BD-III-03A', 'RM-III-03', '1'),
('BD-III-04A', 'RM-III-04', '1'),
('BD-III-04B', 'RM-III-04', '2'),
('BD-ICU-01A', 'RM-ICU-01', '1'),
('BD-ICU-02A', 'RM-ICU-02', '1'),
('BD-NICU-01A', 'RM-NICU-01', '1'),
('BD-HD-01A', 'RM-HD-01', '1'),
('BD-HD-01B', 'RM-HD-01', '2');


-- ============================================
-- 003_rls_policies.sql
-- ============================================
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


-- ============================================
-- CREATE AUTH USER (admin)
-- ============================================
-- Jalankan ini SETELAH migration di atas berhasil.
-- Buka Supabase Dashboard > Authentication > Users > Add User
-- Email: admin@simrs.com
-- Password: password123
-- 
-- ATAU jalankan SQL ini di SQL Editor:
-- INSERT INTO auth.users (
--   instance_id, id, aud, role, email, encrypted_password,
--   email_confirmed_at, created_at, updated_at, confirmation_token,
--   recovery_token, email_change_token_new, email_change
-- ) VALUES (
--   '00000000-0000-0000-0000-000000000000',
--   gen_random_uuid(),
--   'authenticated',
--   'authenticated',
--   'admin@simrs.com',
--   crypt('password123', gen_salt('bf')),
--   now(), now(), now(),
--   '', '', '', ''
-- );
--
-- INSERT INTO auth.identities (id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
-- SELECT id, id, jsonb_build_object('sub', id, 'email', email), 'email', now(), now(), now()
-- FROM auth.users WHERE email = 'admin@simrs.com';
--
-- INSERT INTO auth.sessions (id, user_id, created_at, updated_at, factor_id, aal, not_after)
-- SELECT gen_random_uuid(), id, now(), now(), NULL, 'aal1', now() + interval '7 days'
-- FROM auth.users WHERE email = 'admin@simrs.com';
--
-- INSERT INTO public.profiles (id, full_name, role, is_active)
-- SELECT id, 'Administrator', 'admin', true
-- FROM auth.users WHERE email = 'admin@simrs.com';
