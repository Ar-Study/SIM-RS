-- 1. Hapus constraint lama
ALTER TABLE radiology_orders 
DROP CONSTRAINT IF EXISTS radiology_orders_status_check;

-- 2. Normalisasi status legacy dan nilai kosong sebelum pasang constraint
UPDATE radiology_orders
SET status = CASE
	WHEN status = 'ordered' THEN 'pending'
	WHEN status = 'in_progress' THEN 'processing'
	WHEN status IN ('done', 'finished', 'selesai') THEN 'completed'
	WHEN status IN ('canceled', 'cancel') THEN 'cancelled'
	WHEN status IS NULL OR btrim(status) = '' THEN 'pending'
	ELSE status
END;

-- 3. Fallback terakhir: semua nilai yang masih tidak dikenal jadi pending
UPDATE radiology_orders
SET status = 'pending'
WHERE status NOT IN ('pending', 'processing', 'completed', 'cancelled');

-- 4. Buat constraint baru
ALTER TABLE radiology_orders 
ADD CONSTRAINT radiology_orders_status_check 
CHECK (status IN ('ordered', 'in_progress', 'pending', 'processing', 'completed', 'cancelled'));