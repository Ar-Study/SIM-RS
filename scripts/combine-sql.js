import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const migrationsDir = join(__dirname, '..', 'supabase', 'migrations');
const files = ['001_initial_schema.sql', '002_seed_data.sql', '003_rls_policies.sql'];

let fullSQL = `-- =============================================
-- SIMRS FULL MIGRATION
-- Jalankan ini di Supabase Dashboard > SQL Editor
-- =============================================

`;

for (const file of files) {
  const sql = readFileSync(join(migrationsDir, file), 'utf-8');
  fullSQL += `\n-- ============================================\n-- ${file}\n-- ============================================\n${sql}\n`;
}

// Add auth user creation via RPC
fullSQL += `
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
`;

const outPath = join(__dirname, '..', 'supabase', 'migrations', 'full_migration.sql');
writeFileSync(outPath, fullSQL);
console.log(`✓ Full migration written to: ${outPath}`);
console.log(`  Size: ${(fullSQL.length / 1024).toFixed(1)} KB`);
