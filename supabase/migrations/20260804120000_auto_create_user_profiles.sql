-- Auto-populate profiles for existing auth.users that don't have one
-- and create a trigger to auto-create profiles for new users
-- This fixes the RLS issue where get_user_role() returns NULL because profiles is empty

-- 1. Populate profiles for existing users
INSERT INTO public.profiles (id, full_name, role)
SELECT
  u.id,
  COALESCE(u.raw_user_meta_data->>'full_name', u.email, '-'),
  'registration'
FROM auth.users u
WHERE u.id NOT IN (SELECT id FROM public.profiles)
ON CONFLICT (id) DO NOTHING;

-- 2. Create trigger function to auto-create profile on new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    'registration'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
