DO $$
DECLARE
    r RECORD;
BEGIN
    -- Loop untuk semua tabel yang ada di schema public
    FOR r IN (
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
          AND tablename NOT LIKE 'pg_%' 
          AND tablename NOT LIKE '_prisma%'
    ) LOOP
        -- 1. Aktifkan RLS pada tabel
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', r.tablename);

        -- 2. Hapus policy universal lama jika ada (agar tidak error duplicate)
        EXECUTE format('DROP POLICY IF EXISTS "Allow authenticated full access" ON public.%I;', r.tablename);
        EXECUTE format('DROP POLICY IF EXISTS "Allow anon read access" ON public.%I;', r.tablename);

        -- 3. Buat Policy Universal untuk user yang LOGIN (authenticated): Bebas CRUD
        EXECUTE format('
            CREATE POLICY "Allow authenticated full access" 
            ON public.%I 
            FOR ALL 
            TO authenticated 
            USING (true) 
            WITH CHECK (true);
        ', r.tablename);

        -- 4. (Opsional) Buat Policy untuk anon (akses tanpa login/public): Hanya SELECT/baca
        EXECUTE format('
            CREATE POLICY "Allow anon read access" 
            ON public.%I 
            FOR SELECT 
            TO anon 
            USING (true);
        ', r.tablename);
    END LOOP;
END $$;