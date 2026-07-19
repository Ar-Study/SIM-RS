import { supabase } from './supabase';

export async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

export async function getCurrentUser() {
  try {
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return null;

    let profile = null;
    try {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single();
      profile = data;
    } catch (e) {
      // profiles table may not exist yet - that's OK
      console.warn('Profile fetch failed (table may not exist):', e.message);
    }

    // If no profile exists, create a basic one from auth user
    if (!profile) {
      profile = {
        id: user.id,
        full_name: user.email?.split('@')[0] || 'User',
        role: 'admin',
        employee_id: null,
        is_active: true
      };
    }

    return { ...user, profile };
  } catch (e) {
    console.error('getCurrentUser error:', e);
    return null;
  }
}

export async function getProfile(userId) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();
  if (error) throw error;
  return data;
}

export function hasPermission(profile, permission) {
  if (!profile) return false;
  if (profile.role === 'admin') return true;
  const perms = {
    registration: ['patients', 'visitations', 'online_reg'],
    doctor: ['cppt', 'diagnoses', 'prescriptions', 'lab_orders', 'radiology_orders', 'tariffs', 'treatment_bills'],
    nurse: ['assessments', 'triages', 'cppt'],
    pharmacist: ['prescriptions_dispense', 'drugs', 'drug_stock_logs', 'free_drug_sales'],
    lab_tech: ['lab_orders', 'lab_analysis'],
    radiology_tech: ['radiology_orders'],
    cashier: ['billing_invoices', 'treatment_bills'],
    warehouse: ['drugs', 'drug_stock_logs'],
    igd: ['assessment_igd', 'triages', 'cppt']
  };
  return perms[profile.role]?.includes(permission) ?? false;
}
