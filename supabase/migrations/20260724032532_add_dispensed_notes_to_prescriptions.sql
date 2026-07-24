-- Tambah kolom dispensed_notes ke tabel prescriptions
ALTER TABLE prescriptions 
ADD COLUMN IF NOT EXISTS dispensed_notes TEXT NULL;

-- Opsional: Beri komentar penjelasan kolom
COMMENT ON COLUMN prescriptions.dispensed_notes IS 'Catatan penyerahan/dispensing obat dari apotek';