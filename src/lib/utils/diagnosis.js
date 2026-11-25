// Master Kategori Diagnosa (dari DIAGNOSA_CATEGORY.sql) & mapping ke sistem SIM-RS
export const DIAGNOSIS_CATEGORIES = [
  { diag_cat: 1, slug: 'primer', label: 'Diagnosa Utama (Primer)', shortLabel: 'Utama', badgeClass: 'badge-danger' },
  { diag_cat: 2, slug: 'sekunder', label: 'Diagnosa Penunjang (Sekunder)', shortLabel: 'Penunjang', badgeClass: 'badge-info' },
  { diag_cat: 3, slug: 'masuk', label: 'Diagnosa Masuk', shortLabel: 'Masuk', badgeClass: 'badge-warning' },
  { diag_cat: 4, slug: 'kerja', label: 'Diagnosa Harian / Kerja', shortLabel: 'Kerja', badgeClass: 'badge-gray' },
  { diag_cat: 5, slug: 'kecelakaan', label: 'Diagnosa Kecelakaan', shortLabel: 'Kecelakaan', badgeClass: 'badge-warning' },
  { diag_cat: 6, slug: 'kematian', label: 'Diagnosa Kematian', shortLabel: 'Kematian', badgeClass: 'badge-danger' }
];

export function getDiagnosisCategoryInfo(typeOrCat) {
  if (typeof typeOrCat === 'number') {
    const byCat = DIAGNOSIS_CATEGORIES.find(c => c.diag_cat === typeOrCat);
    if (byCat) return byCat;
  }
  const key = String(typeOrCat || 'primer').toLowerCase();
  if (key === 'utama') return DIAGNOSIS_CATEGORIES[0];
  if (key === 'penunjang') return DIAGNOSIS_CATEGORIES[1];
  const found = DIAGNOSIS_CATEGORIES.find(c => c.slug === key);
  return found || { diag_cat: 2, slug: key, label: typeOrCat || 'Sekunder', shortLabel: typeOrCat || 'Sekunder', badgeClass: 'badge-info' };
}

export function getDiagCatId(type) {
  return getDiagnosisCategoryInfo(type).diag_cat;
}
