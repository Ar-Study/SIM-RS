-- 1. Hapus constraint lama
ALTER TABLE radiology_orders 
DROP CONSTRAINT radiology_orders_status_check;

-- 2. Buat constraint baru dengan daftar nilai yang diperbarui
ALTER TABLE radiology_orders 
ADD CONSTRAINT radiology_orders_status_check 
CHECK (status IN ('pending', 'processing', 'completed', 'cancelled'));