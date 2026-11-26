import { supabase } from '$lib/supabase.js';

let _clinicMapPromise = null;

export async function getClinicMap() {
  if (!_clinicMapPromise) {
    _clinicMapPromise = Promise.all([
      supabase.from('clinics').select('clinic_id, name'),
      supabase.from('hospital_units').select('unit_id, name')
    ]).then(([cRes, uRes]) => {
      const map = {};
      for (const c of cRes.data || []) map[c.clinic_id] = c.name;
      for (const u of uRes.data || []) map[u.unit_id] = u.name;
      return map;
    }).catch(() => {
      _clinicMapPromise = null;
      return {};
    });
  }
  return _clinicMapPromise;
}

export function attachClinic(row, clinicMap) {
  if (!row) return row;
  const cid = row.clinic_id;
  if (!cid) return row;
  return {
    ...row,
    clinics: { clinic_id: cid, name: clinicMap[cid] || cid }
  };
}
