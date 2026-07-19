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
