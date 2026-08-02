-- 1. Berikan hak akses untuk SEMUA tabel yang ada saat ini di skema public
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;

-- 2. Berikan hak akses untuk SEMUA sequence/ID auto-increment di skema public
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- 3. (PENTING) Otomatiskan hak akses ini untuk tabel baru yang dibuat di masa depan
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT USAGE, SELECT ON SEQUENCES TO authenticated;