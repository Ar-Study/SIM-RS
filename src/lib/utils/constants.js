export const ROLES = {
  admin: 'Administrator',
  registration: 'Registrasi',
  doctor: 'Dokter',
  nurse: 'Perawat',
  pharmacist: 'Farmasi',
  lab_tech: 'Lab Teknisi',
  radiology_tech: 'Radiologi Teknisi',
  cashier: 'Kasir',
  warehouse: 'Gudang',
  igd: 'IGD'
};

export const VISIT_TYPES = {
  rawat_jalan: 'Rawat Jalan',
  rawat_inap: 'Rawat Inap',
  igd: 'IGD/Rawat Darurat'
};

export const STATUS_PEMBAYARAN = {
  '0': 'Belum Bayar',
  '1': 'Sudah Bayar',
  '2': 'Gratis'
};

export const STATUS_PERIKSA = {
  '0': 'Belum Diperiksa',
  '1': 'Sudah Diperiksa'
};

export const STATUS_KELUAR = {
  '0': 'Masih di RS',
  '1': 'Sudah Keluar'
};

export const TRIAGE_LEVELS = {
  resuscitation: { name: 'Resusitasi', color: 'bg-red-600 text-white', priority: 1 },
  emergency: { name: 'Darurat', color: 'bg-red-500 text-white', priority: 2 },
  urgent: { name: 'Urgent', color: 'bg-orange-500 text-white', priority: 3 },
  less_urgent: { name: 'Kurang Urgent', color: 'bg-yellow-500 text-white', priority: 4 },
  non_urgent: { name: 'Tidak Urgent', color: 'bg-green-500 text-white', priority: 5 }
};

export const DISCHARGE_CONDITIONS = {
  semuh: 'Sembuh',
  berobat_jalan: 'Berobat Jalan',
  rujuk: 'Rujuk',
  meninggal: 'Meninggal',
  lainnya: 'Lainnya'
};

export const DRUG_CATEGORIES = [
  'Antibiotik', 'Analgesik', 'Antipiretik', 'Antihistamin',
  'Antasida', 'Vitamin', 'Suplemen', 'Dermatologi',
  'Kardiovaskular', 'Respirasi', 'Endokrin', 'Neurologi',
  'Gastrointestinal', 'Oftalmologi', 'THT', 'Lainnya'
];

export const TARIFF_TYPES = [
  'Konsultasi', 'Akomodasi', 'Laboratorium', 'Radiologi',
  'Obat', 'BMHP', 'Tindakan', 'Operator', 'Anestesi',
  'Ruang Operasi', 'Obat Operasi', 'Visite Dokter'
];

export const PAYOR_TYPES = {
  bpjs: 'BPJS',
  insurance: 'Asuransi',
  personal: 'Pribadi',
  corporate: 'Perusahaan'
};

export const LAB_CATEGORIES = [
  'Hematologi', 'Kimia Darah', 'Imunologi', 'Urinalisa',
  'Feses', 'Mikrobiologi', 'Histopatologi', 'Lainnya'
];

export const RADIOLOGY_TYPES = [
  'Rontgen', 'CT Scan', 'MRI', 'USG', 'Mammografi',
  'Fluoroscopy', 'DEXA', 'Intervensi', 'Lainnya'
];
