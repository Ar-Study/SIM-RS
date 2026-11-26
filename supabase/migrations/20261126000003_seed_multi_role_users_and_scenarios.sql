-- Migration: Seed 9 additional multi-role user accounts + realistic multi-scenario hospital operational data
-- All role accounts use password: password123 (email confirmed immediately)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- 1. CREATE MULTI-ROLE USER ACCOUNTS (auth.users + auth.identities + public.profiles)
-- ============================================================================
DO $$
DECLARE
  v_users JSONB := '[
    {"email":"registrasi@simrs.com", "name":"Rina Pendaftaran",             "role":"registration",   "phone":"081200000002"},
    {"email":"dokter@simrs.com",     "name":"dr. Ahmad Suharto, Sp.PD",     "role":"doctor",         "phone":"081200000003"},
    {"email":"perawat@simrs.com",    "name":"Andi Saputra, S.Kep",          "role":"nurse",          "phone":"081200000004"},
    {"email":"farmasi@simrs.com",    "name":"Fajar Nugroho, S.Farm, Apt",   "role":"pharmacist",     "phone":"081200000005"},
    {"email":"lab@simrs.com",        "name":"Danang Prasetyo, A.Md.AK",     "role":"lab_tech",       "phone":"081200000006"},
    {"email":"radiologi@simrs.com",  "name":"Eka Fitriani, A.Md.Rad",       "role":"radiology_tech", "phone":"081200000007"},
    {"email":"kasir@simrs.com",      "name":"Gita Sari, S.E.",              "role":"cashier",        "phone":"081200000008"},
    {"email":"gudang@simrs.com",     "name":"Hadi Wijaya (Gudang)",         "role":"warehouse",      "phone":"081200000009"},
    {"email":"igd@simrs.com",        "name":"dr. Sari Jaga IGD",            "role":"igd",            "phone":"081200000010"}
  ]'::jsonb;
  u JSONB;
  v_uid UUID;
  v_email TEXT;
  v_name TEXT;
  v_role TEXT;
  v_phone TEXT;
  v_pw_hash TEXT;
BEGIN
  v_pw_hash := crypt('password123', gen_salt('bf'));

  FOR u IN SELECT * FROM jsonb_array_elements(v_users)
  LOOP
    v_email := u->>'email';
    v_name  := u->>'name';
    v_role  := u->>'role';
    v_phone := u->>'phone';

    SELECT id INTO v_uid FROM auth.users WHERE email = v_email LIMIT 1;

    IF v_uid IS NULL THEN
      v_uid := gen_random_uuid();
      INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, recovery_token,
        email_change_token_new, email_change
      ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        v_uid, 'authenticated', 'authenticated', v_email, v_pw_hash,
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('full_name', v_name, 'role', v_role),
        now(), now(), '', '', '', ''
      );

      INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id,
        last_sign_in_at, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), v_uid,
        jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
        'email', v_uid::text, now(), now(), now()
      );
    END IF;

    INSERT INTO public.profiles (id, full_name, email, phone, role, is_active)
    VALUES (v_uid, v_name, v_email, v_phone, v_role, true)
    ON CONFLICT (id) DO UPDATE SET
      full_name = EXCLUDED.full_name,
      role = EXCLUDED.role,
      phone = EXCLUDED.phone,
      is_active = true;
  END LOOP;
END $$;

-- ============================================================================
-- 2. SEED MULTI-SCENARIO HOSPITAL VISITS (RAJAL, IGD, RANAP, ICU, VK)
-- ============================================================================
INSERT INTO public.patient_visitations (
  visit_id, patient_id, clinic_id, doctor_id, visit_type,
  status_periksa, status_pembayaran, status_keluar,
  room_id, bed_id, payor_id, description, visit_date, in_date
) VALUES
-- Skenario 1: Rawat Jalan Menunggu Periksa (Hari Ini)
('VST-SCN01', 'PAS-SEED01', 'POL-UMUM',  'DOC-001', 'rawat_jalan', '0', '0', '0', NULL, NULL, 'PAY-BPJS1',   'Keluhan demam & batuk 2 hari',             now() - interval '2 hours', now() - interval '2 hours'),
('VST-SCN02', 'PAS-SEED02', 'POL-OBGYN', 'DOC-004', 'rawat_jalan', '0', '0', '0', NULL, NULL, 'PAY-BPJS2',   'Kontrol kehamilan trimester 2 (ANC)',      now() - interval '90 minutes', now() - interval '90 minutes'),
('VST-SCN03', 'PAS-SEED18', 'POL-ANAK',  'DOC-002', 'rawat_jalan', '0', '0', '0', NULL, NULL, 'PAY-PRIBADI', 'Imunisasi & kontrol tumbuh kembang anak',  now() - interval '45 minutes', now() - interval '45 minutes'),

-- Skenario 2: Rawat Jalan Sudah Diperiksa + Resep Pending + Lab Ordered + Invoice Unpaid
('VST-SCN04', 'PAS-SEED03', 'POL-PERA',  'DOC-001', 'rawat_jalan', '1', '0', '0', NULL, NULL, 'PAY-BPJS1',   'Kontrol rutin DM Tipe 2 & Hipertensi',     now() - interval '3 hours', now() - interval '3 hours'),

-- Skenario 3: Rawat Jalan Selesai Total (Dispensed + Lab/Rad Completed + Lunas)
('VST-SCN05', 'PAS-SEED04', 'POL-UMUM',  'DOC-001', 'rawat_jalan', '1', '1', '1', NULL, NULL, 'PAY-PRIBADI', 'Diare akut & nyeri perut (Selesai Lunas)', now() - interval '5 hours', now() - interval '5 hours'),
('VST-SCN06', 'PAS-SEED06', 'POL-GIGI',  'DOC-006', 'rawat_jalan', '1', '1', '1', NULL, NULL, 'PAY-ASURANSI1','Pemeriksaan & tambal gigi (Selesai Lunas)',now() - interval '4 hours', now() - interval '4 hours'),

-- Skenario 4: IGD Gawat Darurat (Triase Merah & Urgent)
('VST-SCN07', 'PAS-SEED07', 'POL-IGD',   'DOC-001', 'igd',         '0', '0', '0', NULL, NULL, 'PAY-BPJS1',   'Nyeri dada akut menjalar ke lengan kiri',  now() - interval '1 hour', now() - interval '1 hour'),
('VST-SCN08', 'PAS-SEED08', 'POL-IGD',   'DOC-003', 'igd',         '1', '0', '0', NULL, NULL, 'PAY-PRIBADI', 'Luka robek lengan kanan akibat jatuh',     now() - interval '2 hours', now() - interval '2 hours'),

-- Skenario 5: Rawat Inap Aktif (Bangsal VIP & Kelas II)
('VST-SCN09', 'PAS-SEED09', 'POL-RANAP', 'DOC-001', 'rawat_inap',  '1', '0', '0', 'RM-VIP-01', 'BD-VIP-01A', 'PAY-BPJS1', 'Observasi Pneumonia & persiapan operasi', now() - interval '1 day', now() - interval '1 day'),
('VST-SCN10', 'PAS-SEED11', 'POL-RANAP', 'DOC-001', 'rawat_inap',  '1', '0', '0', 'RM-II-01',  'BD-II-01A',  'PAY-BPJS2', 'Demam tifoid hari ke-4, terapi IV',       now() - interval '2 days', now() - interval '2 days'),

-- Skenario 6: Unit Khusus (ICU & VK)
('VST-SCN11', 'PAS-SEED26', 'POL-ICU',   'DOC-007', 'rawat_inap',  '1', '0', '0', 'RM-ICU-01', 'BD-ICU-01A', 'PAY-BPJS1', 'Monitoring intensif pasca stroke akut',   now() - interval '1 day', now() - interval '1 day'),
('VST-SCN12', 'PAS-SEED12', 'POL-VK',    'DOC-004', 'rawat_inap',  '1', '0', '0', 'RM-VK-01',  NULL,         'PAY-BPJS2', 'Observasi inpartu kala I aktif',          now() - interval '6 hours', now() - interval '6 hours')
ON CONFLICT (visit_id) DO NOTHING;

-- Tandai bed yang sedang ditempati pasien Rawat Inap & ICU
UPDATE public.beds SET is_occupied = true WHERE bed_id IN ('BD-VIP-01A', 'BD-II-01A', 'BD-ICU-01A');

-- ============================================================================
-- 3. TRIASE IGD
-- ============================================================================
INSERT INTO public.triages (visit_id, level, score, notes, created_by)
SELECT v.visit_id, v.lvl, v.sc, v.nt, (SELECT id FROM public.profiles WHERE email = 'igd@simrs.com' LIMIT 1)
FROM (VALUES
  ('VST-SCN07', 'resuscitation', 1, 'Nyeri dada tipikal >30 menit, keringat dingin, TD 160/100, HR 112, SpO2 94% — segera EKG & Troponin'),
  ('VST-SCN08', 'urgent',        3, 'Vulnus laceratum regio antebrachii dekstra 4 cm, perdarahan terkontrol, TD 125/80, HR 88')
) AS v(visit_id, lvl, sc, nt)
WHERE NOT EXISTS (SELECT 1 FROM public.triages t WHERE t.visit_id = v.visit_id);

-- ============================================================================
-- 4. CPPT (SOAP) DOKTER & PERAWAT
-- ============================================================================
INSERT INTO public.cppt (visit_id, subyektif, obyektif, assessment, planning, instruksi, created_by)
SELECT v.visit_id, v.s, v.o, v.a, v.p, v.i, (SELECT id FROM public.profiles WHERE email = 'dokter@simrs.com' LIMIT 1)
FROM (VALUES
  ('VST-SCN04', 'Sering haus, kesemutan ujung jari, kontrol rutin bulanan', 'TD 150/90 mmHg, N 82x/m, GDS 248 mg/dL, BMI 26.4', 'Diabetes Mellitus Tipe 2 + Hipertensi Esensial', 'Lanjut Metformin + Amlodipine, cek GDP & HbA1c', 'Diet rendah gula & garam, kontrol 2 minggu'),
  ('VST-SCN05', 'BAB cair 6x sejak kemarin malam disertai mual', 'TD 110/70 mmHg, N 88x/m, S 37.8 C, bising usus meningkat', 'Gastroenteritis Akut (GEA) dehidrasi ringan', 'Rehidrasi oralit, terapi simptomatik', 'Banyak minum air putih, istirahat cukup'),
  ('VST-SCN06', 'Gigi geraham kanan bawah ngilu saat minum dingin', 'Karies profunda gigi 46, tes vitalitas (+), perkusi (-)', 'Karies Dentis (K02.9)', 'Penambalan komposit resin', 'Hindari makan keras 2 jam pasca tambal'),
  ('VST-SCN07', 'Nyeri dada kiri seperti tertindih benda berat sejak 1 jam lalu', 'TD 160/100 mmHg, HR 112x/m, RR 24x/m, SpO2 94%', 'Suspek Sindrom Koroner Akut (ACS)', 'O2 4 Lpm, ISDN 5mg SL, Aspilet 160mg, EKG 12 lead, cek Troponin I', 'Monitoring ketat di resusitasi IGD'),
  ('VST-SCN09', 'Sesak napas & batuk berdahak kuning sejak 4 hari', 'TD 130/80 mmHg, N 96x/m, RR 26x/m, S 38.6 C, ronki basah basal paru kanan', 'Pneumonia Komunitas (CAP)', 'IVFD RL 20 tpm, Antibiotik IV, Nebulizer, Foto Thorax evaluasi', 'Observasi TTV tiap 4 jam & balans cairan'),
  ('VST-SCN10', 'Demam naik turun terutama malam hari, nafsu makan turun', 'TD 115/75 mmHg, N 84x/m, S 38.9 C, lidah kotor (+)', 'Demam Tifoid', 'Tirah baring, diet lunak, Ceftriaxone IV, Paracetamol', 'Cek darah rutin ulang H+3'),
  ('VST-SCN11', 'Penurunan kesadaran mendadak + kelemahan sisi kanan', 'GCS E3V3M5, TD 185/105 mmHg, N 90x/m, SpO2 96%', 'Stroke Iskemik Akut', 'Head up 30 derajat, manajemen TD terkontrol, neuroprotektor IV', 'Monitoring neurologis & hemodinamik tiap jam di ICU')
) AS v(visit_id, s, o, a, p, i)
WHERE NOT EXISTS (SELECT 1 FROM public.cppt c WHERE c.visit_id = v.visit_id);

-- ============================================================================
-- 5. DIAGNOSIS PASIEN (ICD-10 RSUD + diag_cat)
-- ============================================================================
INSERT INTO public.patient_diagnoses (visit_id, diagnosis_id, diagnosis_type, diag_cat)
SELECT v.visit_id, v.diag_id, v.dtype, v.dcat
FROM (VALUES
  ('VST-SCN04', 'DX-E11',   'primer',   1),
  ('VST-SCN04', 'DX-I10',   'sekunder', 2),
  ('VST-SCN05', 'DX-A09',   'primer',   1),
  ('VST-SCN06', 'DX-K02.9', 'primer',   1),
  ('VST-SCN07', 'DX-I21.9', 'masuk',    3),
  ('VST-SCN08', 'DX-S00',   'kecelakaan', 5),
  ('VST-SCN09', 'DX-J18.9', 'primer',   1),
  ('VST-SCN10', 'DX-A01.0', 'primer',   1),
  ('VST-SCN11', 'DX-I64',   'primer',   1),
  ('VST-SCN12', 'DX-O80.0', 'primer',   1)
) AS v(visit_id, diag_id, dtype, dcat)
WHERE EXISTS (SELECT 1 FROM public.diagnoses d WHERE d.diagnosis_id = v.diag_id)
  AND NOT EXISTS (SELECT 1 FROM public.patient_diagnoses pd WHERE pd.visit_id = v.visit_id AND pd.diagnosis_id = v.diag_id);

-- ============================================================================
-- 6. RESEP OBAT (PENDING UNTUK FARMASI & DISPENSED)
-- ============================================================================
DO $$
DECLARE
  v_rx_id INTEGER;
  v_drug1 TEXT := 'OBT-11';
  v_price1 NUMERIC := 1110;
  v_drug2 TEXT := 'OBT-12';
  v_price2 NUMERIC := 839;
BEGIN
  SELECT sell_price INTO v_price1 FROM public.drugs WHERE drug_id = v_drug1;
  SELECT sell_price INTO v_price2 FROM public.drugs WHERE drug_id = v_drug2;
  v_price1 := COALESCE(v_price1, 1110);
  v_price2 := COALESCE(v_price2, 839);

  -- Resep Pending 1 (Rawat Jalan VST-SCN04 -> siap diserahkan di Farmasi)
  IF NOT EXISTS (SELECT 1 FROM public.prescriptions WHERE visit_id = 'VST-SCN04') THEN
    INSERT INTO public.prescriptions (visit_id, prescription_type, status)
    VALUES ('VST-SCN04', 'rajal', 'pending') RETURNING id INTO v_rx_id;
    INSERT INTO public.prescription_items (prescription_id, drug_id, quantity, dosage, frequency, duration, instruction, unit_price, total_price)
    VALUES
      (v_rx_id, v_drug1, 10, '1 kapsul', '3x1', '3 hari', 'Sesudah makan', v_price1, v_price1 * 10),
      (v_rx_id, v_drug2, 10, '1 tablet', '2x1', '5 hari', 'Sesudah makan', v_price2, v_price2 * 10);
  END IF;

  -- Resep Pending 2 (IGD VST-SCN07)
  IF NOT EXISTS (SELECT 1 FROM public.prescriptions WHERE visit_id = 'VST-SCN07') THEN
    INSERT INTO public.prescriptions (visit_id, prescription_type, status)
    VALUES ('VST-SCN07', 'rajal', 'pending') RETURNING id INTO v_rx_id;
    INSERT INTO public.prescription_items (prescription_id, drug_id, quantity, dosage, frequency, duration, instruction, unit_price, total_price)
    VALUES (v_rx_id, v_drug1, 6, '1 kapsul', '3x1', '2 hari', 'Segera diberikan', v_price1, v_price1 * 6);
  END IF;

  -- Resep Pending 3 (Rawat Inap VST-SCN09)
  IF NOT EXISTS (SELECT 1 FROM public.prescriptions WHERE visit_id = 'VST-SCN09') THEN
    INSERT INTO public.prescriptions (visit_id, prescription_type, status)
    VALUES ('VST-SCN09', 'ranap', 'pending') RETURNING id INTO v_rx_id;
    INSERT INTO public.prescription_items (prescription_id, drug_id, quantity, dosage, frequency, duration, instruction, unit_price, total_price)
    VALUES (v_rx_id, v_drug1, 15, '1 kapsul', '3x1', '5 hari', 'Terapi rawat inap', v_price1, v_price1 * 15);
  END IF;

  -- Resep Dispensed (VST-SCN05 Selesai)
  IF NOT EXISTS (SELECT 1 FROM public.prescriptions WHERE visit_id = 'VST-SCN05') THEN
    INSERT INTO public.prescriptions (visit_id, prescription_type, status)
    VALUES ('VST-SCN05', 'rajal', 'dispensed') RETURNING id INTO v_rx_id;
    INSERT INTO public.prescription_items (prescription_id, drug_id, quantity, dosage, frequency, duration, instruction, unit_price, total_price, is_dispensed)
    VALUES (v_rx_id, v_drug1, 10, '1 kapsul', '3x1', '3 hari', 'Sesudah makan', v_price1, v_price1 * 10, true);
  END IF;
END $$;

-- ============================================================================
-- 7. ORDER LABORATORIUM (ORDERED & COMPLETED + HASIL ANALISIS)
-- ============================================================================
DO $$
DECLARE
  v_lo_id INTEGER;
  v_doc UUID;
BEGIN
  SELECT id INTO v_doc FROM public.profiles WHERE email = 'dokter@simrs.com' LIMIT 1;

  -- Lab Ordered 1 (VST-SCN04 -> siap dikerjakan Analis Lab)
  IF NOT EXISTS (SELECT 1 FROM public.lab_orders WHERE visit_id = 'VST-SCN04') THEN
    INSERT INTO public.lab_orders (visit_id, status, notes, created_by)
    VALUES ('VST-SCN04', 'ordered', 'Cek Gula Darah Puasa & HbA1c', v_doc) RETURNING id INTO v_lo_id;
    INSERT INTO public.lab_analysis (lab_order_id, analysis_name, category, normal_value, unit)
    VALUES
      (v_lo_id, 'Gula Darah Puasa (GDP)', 'Kimia Darah', '70 - 100', 'mg/dL'),
      (v_lo_id, 'HbA1c', 'Kimia Darah', '< 5.7', '%');
  END IF;

  -- Lab Ordered 2 (IGD CITO VST-SCN07)
  IF NOT EXISTS (SELECT 1 FROM public.lab_orders WHERE visit_id = 'VST-SCN07') THEN
    INSERT INTO public.lab_orders (visit_id, status, notes, created_by)
    VALUES ('VST-SCN07', 'ordered', 'CITO IGD: Troponin I & Darah Lengkap', v_doc) RETURNING id INTO v_lo_id;
    INSERT INTO public.lab_analysis (lab_order_id, analysis_name, category, normal_value, unit)
    VALUES
      (v_lo_id, 'Troponin I', 'Imunologi', '< 0.04', 'ng/mL'),
      (v_lo_id, 'Hemoglobin (Hb)', 'Hematologi', '13.0 - 17.0', 'g/dL');
  END IF;

  -- Lab Completed (VST-SCN05)
  IF NOT EXISTS (SELECT 1 FROM public.lab_orders WHERE visit_id = 'VST-SCN05') THEN
    INSERT INTO public.lab_orders (visit_id, status, notes, created_by, completed_at)
    VALUES ('VST-SCN05', 'completed', 'Darah Lengkap Rutin', v_doc, now() - interval '4 hours') RETURNING id INTO v_lo_id;
    INSERT INTO public.lab_analysis (lab_order_id, analysis_name, category, normal_value, result, unit, flag)
    VALUES
      (v_lo_id, 'Hemoglobin (Hb)', 'Hematologi', '12.0 - 16.0', '12.8', 'g/dL', 'normal'),
      (v_lo_id, 'Leukosit', 'Hematologi', '4.000 - 10.000', '11.400', '/uL', 'high');
  END IF;
END $$;

-- ============================================================================
-- 8. ORDER RADIOLOGI (ORDERED & COMPLETED)
-- ============================================================================
INSERT INTO public.radiology_orders (visit_id, examination_type, body_part, clinical_info, status, result, impression, ordered_by, completed_at)
SELECT v.visit_id, v.etype, v.bp, v.ci, v.st, v.res, v.imp, (SELECT id FROM public.profiles WHERE email = 'dokter@simrs.com' LIMIT 1), v.comp
FROM (VALUES
  ('VST-SCN07', 'Rontgen', 'Thorax AP Bedside', 'CITO Nyeri dada suspek ACS', 'ordered',   NULL, NULL, NULL::timestamptz),
  ('VST-SCN09', 'Rontgen', 'Thorax PA',         'Evaluasi infiltrat pneumonia', 'ordered', NULL, NULL, NULL::timestamptz),
  ('VST-SCN05', 'USG',     'Abdomen',           'Nyeri abdomen akut',          'completed', 'Hepar, lien, ginjal bilateral dalam batas normal. Tidak tampak cairan bebas.', 'USG Abdomen Normal', now() - interval '4 hours')
) AS v(visit_id, etype, bp, ci, st, res, imp, comp)
WHERE NOT EXISTS (SELECT 1 FROM public.radiology_orders r WHERE r.visit_id = v.visit_id);

-- ============================================================================
-- 9. TAGIHAN TINDAKAN & INVOICE KASIR (UNPAID & PAID)
-- ============================================================================
INSERT INTO public.treatment_bills (visit_id, tariff_id, description, tariff_type, amount)
SELECT v.visit_id, v.tid, v.descr, v.ttype, v.amt
FROM (VALUES
  ('VST-SCN04', 'TRF-1', 'Administrasi Poli Premium',  'Administrasi', 62000),
  ('VST-SCN05', 'TRF-1', 'Administrasi Poli Premium',  'Administrasi', 62000),
  ('VST-SCN06', 'TRF-1', 'Administrasi Poli Gigi',     'Administrasi', 62000),
  ('VST-SCN08', 'TRF-6', 'Administrasi Tindakan Emergency', 'IGD',    720000)
) AS v(visit_id, tid, descr, ttype, amt)
WHERE EXISTS (SELECT 1 FROM public.tariffs t WHERE t.tariff_id = v.tid)
  AND NOT EXISTS (SELECT 1 FROM public.treatment_bills tb WHERE tb.visit_id = v.visit_id AND tb.tariff_id = v.tid);

INSERT INTO public.billing_invoices (invoice_id, visit_id, total_amount, discount, net_amount, status, paid_amount, payment_method, paid_at) VALUES
('INV-SCN04', 'VST-SCN04', 81490,  0, 81490,  'unpaid', 0,      NULL,      NULL),
('INV-SCN08', 'VST-SCN08', 720000, 0, 720000, 'unpaid', 0,      NULL,      NULL),
('INV-SCN05', 'VST-SCN05', 73100,  0, 73100,  'paid',   73100,  'tunai',   now() - interval '4 hours'),
('INV-SCN06', 'VST-SCN06', 62000,  0, 62000,  'paid',   62000,  'qris',    now() - interval '3 hours')
ON CONFLICT (invoice_id) DO NOTHING;

-- ============================================================================
-- 10. OPERASI / IBS, HEMODIALISIS (HD), & PENJUALAN OBAT BEBAS (OTC)
-- ============================================================================
DO $$
DECLARE
  v_sr_id INTEGER;
  v_sale_id INTEGER;
BEGIN
  -- Jadwal Operasi (IBS)
  IF NOT EXISTS (SELECT 1 FROM public.surgery_requests WHERE visit_id = 'VST-SCN09') THEN
    INSERT INTO public.surgery_requests (visit_id, procedure_name, description, requested_date, priority, status, surgeon_id, anesthesia_type, notes)
    VALUES ('VST-SCN09', 'Appendektomi Laparoskopi', 'Operasi elektif pasca stabilisasi', CURRENT_DATE + 1, 'elective', 'scheduled', 'DOC-003', 'General Anesthesia', 'Puasa 8 jam pre-op')
    RETURNING id INTO v_sr_id;

    INSERT INTO public.surgery_bookings (surgery_request_id, room_id, scheduled_date, status, notes)
    VALUES (v_sr_id, 'RM-VIP-01', now() + interval '1 day', 'scheduled', 'Tim OK 1 siap');
  END IF;

  -- Penjualan Obat Bebas (OTC)
  IF NOT EXISTS (SELECT 1 FROM public.free_drug_sales WHERE buyer_name = 'Bapak Andi (OTC)') THEN
    INSERT INTO public.free_drug_sales (buyer_name, total_amount, discount, net_amount, payment_method, sale_date)
    VALUES ('Bapak Andi (OTC)', 11100, 0, 11100, 'tunai', now() - interval '2 hours') RETURNING id INTO v_sale_id;
    INSERT INTO public.free_drug_sale_items (sale_id, drug_id, quantity, unit_price, total_price)
    VALUES (v_sale_id, 'OBT-11', 10, 1110, 11100);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.free_drug_sales WHERE buyer_name = 'Ibu Sinta (OTC)') THEN
    INSERT INTO public.free_drug_sales (buyer_name, total_amount, discount, net_amount, payment_method, sale_date)
    VALUES ('Ibu Sinta (OTC)', 8390, 0, 8390, 'qris', now() - interval '1 hour') RETURNING id INTO v_sale_id;
    INSERT INTO public.free_drug_sale_items (sale_id, drug_id, quantity, unit_price, total_price)
    VALUES (v_sale_id, 'OBT-12', 10, 839, 8390);
  END IF;
END $$;

-- Sesi Hemodialisis (HD)
INSERT INTO public.hd_sessions (session_id, patient_id, scheduled_time, duration_minutes, machine_id, nurse_id, notes, status, pre_weight, started_at) VALUES
('HDS-SCN01', 'PAS-SEED15', now() - interval '1 hour', 240, 'HDM-001', 'NRS-001', 'HD rutin 2x/minggu, akses AV shunt lengan kiri', 'in_progress', 64.5, now() - interval '1 hour'),
('HDS-SCN02', 'PAS-SEED16', now() + interval '2 hours', 240, 'HDM-002', 'NRS-002', 'HD rutin jadwal siang', 'scheduled', NULL, NULL)
ON CONFLICT (session_id) DO NOTHING;

UPDATE public.hd_machines SET status = 'in_use' WHERE machine_id = 'HDM-001';
