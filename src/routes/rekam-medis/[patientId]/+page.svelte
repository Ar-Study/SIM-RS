<script>
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime } from '$lib/utils/helpers.js';
  import { VISIT_TYPES, PAYOR_TYPES } from '$lib/utils/constants.js';

  let patientId = $derived(page.params.patientId);
  let loading = $state(true);
  let activeTab = $state('kunjungan');

  let patient = $state(null);
  let visits = $state([]);
  let allDiagnoses = $state([]);
  let allLabResults = $state([]);
  let allRadiologyResults = $state([]);
  let allPrescriptions = $state([]);
  let resumeData = $state(null);

  let printDropdownOpen = $state(false);

  const tabs = [
    { id: 'kunjungan', label: 'Riwayat Kunjungan', icon: 'calendar' },
    { id: 'diagnosis', label: 'Diagnosis', icon: 'activity' },
    { id: 'lab', label: 'Riwayat Lab', icon: 'flask' },
    { id: 'radiologi', label: 'Riwayat Radiologi', icon: 'scan' },
    { id: 'resep', label: 'Riwayat Resep/Obat', icon: 'pill' },
    { id: 'resume', label: 'Resume Medis', icon: 'file-text' },
    { id: 'cetak', label: 'Cetak', icon: 'printer' }
  ];

  function calculateAge(dob) {
    if (!dob) return '-';
    const birth = new Date(dob);
    const today = new Date();
    let years = today.getFullYear() - birth.getFullYear();
    let months = today.getMonth() - birth.getMonth();
    if (months < 0) {
      years--;
      months += 12;
    }
    if (today.getDate() < birth.getDate()) {
      months--;
      if (months < 0) {
        years--;
        months += 12;
      }
    }
    if (years > 0) return `${years} tahun`;
    return `${months} bulan`;
  }

  function getVisitTypeBadge(type) {
    switch (type) {
      case 'rawat_jalan': return 'badge-info';
      case 'rawat_inap': return 'badge-warning';
      case 'igd': return 'badge-danger';
      default: return 'badge-gray';
    }
  }

  function getVisitStatusLabel(visit) {
    if (visit.discharge_date) return { label: 'Selesai', class: 'badge-info' };
    if (visit.status_periksa === '1') return { label: 'Diperiksa', class: 'badge-success' };
    return { label: 'Proses', class: 'badge-warning' };
  }

  function getGenderLabel(g) {
    return g === 'L' ? 'Laki-laki' : g === 'P' ? 'Perempuan' : '-';
  }

  async function fetchPatientData() {
    try {
      const { data, error } = await supabase
        .from('patients')
        .select('*')
        .eq('patient_id', patientId)
        .single();

      if (error) throw error;
      patient = data;
    } catch (err) {
      console.error('Fetch patient error:', err);
    }
  }

  async function fetchVisits() {
    try {
      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          *,
          clinics:clinic_id ( name ),
          doctors:doctor_id ( full_name )
        `)
        .eq('patient_id', patientId)
        .order('visit_date', { ascending: false });

      if (error) throw error;

      visits = (data || []).map(v => ({
        ...v,
        clinic_name: v.clinics?.name || '-',
        doctor_name: v.doctors?.full_name || '-'
      }));
    } catch (err) {
      console.error('Fetch visits error:', err);
    }
  }

  async function fetchAllDiagnoses() {
    try {
      const visitIds = visits.map(v => v.visit_id);
      if (visitIds.length === 0) { allDiagnoses = []; return; }

      const { data, error } = await supabase
        .from('patient_diagnoses')
        .select('*')
        .in('visit_id', visitIds);

      if (error) throw error;

      const visitDateMap = {};
      visits.forEach(v => { visitDateMap[v.visit_id] = v.visit_date; });

      allDiagnoses = (data || [])
        .map(d => ({ ...d, visit_date: visitDateMap[d.visit_id] || null }))
        .sort((a, b) => new Date(b.visit_date || 0) - new Date(a.visit_date || 0));
    } catch (err) {
      console.error('Fetch diagnoses error:', err);
    }
  }

  async function fetchAllLabResults() {
    try {
      const visitIds = visits.map(v => v.visit_id);
      if (visitIds.length === 0) { allLabResults = []; return; }

      const { data, error } = await supabase
        .from('lab_orders')
        .select('*')
        .in('visit_id', visitIds)
        .order('created_at', { ascending: false });

      if (error) throw error;

      const visitDateMap = {};
      visits.forEach(v => { visitDateMap[v.visit_id] = v.visit_date; });

      allLabResults = (data || []).map(l => ({
        ...l,
        visit_date: visitDateMap[l.visit_id] || null
      }));
    } catch (err) {
      console.error('Fetch lab results error:', err);
    }
  }

  async function fetchAllRadiologyResults() {
    try {
      const visitIds = visits.map(v => v.visit_id);
      if (visitIds.length === 0) { allRadiologyResults = []; return; }

      const { data, error } = await supabase
        .from('radiology_orders')
        .select('*')
        .in('visit_id', visitIds)
        .order('created_at', { ascending: false });

      if (error) throw error;

      const visitDateMap = {};
      visits.forEach(v => { visitDateMap[v.visit_id] = v.visit_date; });

      allRadiologyResults = (data || []).map(r => ({
        ...r,
        visit_date: visitDateMap[r.visit_id] || null
      }));
    } catch (err) {
      console.error('Fetch radiology results error:', err);
    }
  }

  async function fetchAllPrescriptions() {
    try {
      const visitIds = visits.map(v => v.visit_id);
      if (visitIds.length === 0) { allPrescriptions = []; return; }

      const { data, error } = await supabase
        .from('prescriptions')
        .select('*')
        .in('visit_id', visitIds)
        .order('created_at', { ascending: false });

      if (error) throw error;

      const visitDateMap = {};
      visits.forEach(v => { visitDateMap[v.visit_id] = v.visit_date; });

      allPrescriptions = (data || []).map(p => ({
        ...p,
        visit_date: visitDateMap[p.visit_id] || null
      }));
    } catch (err) {
      console.error('Fetch prescriptions error:', err);
    }
  }

  function buildResume() {
    const totalVisits = visits.length;
    const totalRawatJalan = visits.filter(v => v.visit_type === 'rawat_jalan').length;
    const totalRawatInap = visits.filter(v => v.visit_type === 'rawat_inap').length;
    const totalIGD = visits.filter(v => v.visit_type === 'igd').length;
    const totalDiagnoses = allDiagnoses.length;
    const totalLab = allLabResults.length;
    const totalRadiology = allRadiologyResults.length;
    const totalPrescriptions = allPrescriptions.length;

    const primerDiagnoses = allDiagnoses
      .filter(d => d.diagnosis_type === 'primer')
      .reduce((acc, d) => {
        const existing = acc.find(a => a.icd_code === d.icd_code);
        if (existing) existing.count++;
        else acc.push({ icd_code: d.icd_code, icd_name: d.icd_name, count: 1 });
        return acc;
      }, [])
      .sort((a, b) => b.count - a.count);

    const firstVisit = visits.length > 0 ? visits[visits.length - 1] : null;
    const lastVisit = visits.length > 0 ? visits[0] : null;

    resumeData = {
      totalVisits,
      totalRawatJalan,
      totalRawatInap,
      totalIGD,
      totalDiagnoses,
      totalLab,
      totalRadiology,
      totalPrescriptions,
      primerDiagnoses,
      firstVisit,
      lastVisit
    };
  }

  function printPatientCard() {
    if (!patient) return;
    const content = `
      <html>
      <head>
        <title>Kartu Pasien</title>
        <style>
          body { font-family: monospace; width: 80mm; margin: 0; padding: 10mm; }
          h2 { text-align: center; font-size: 14pt; margin: 0 0 5px 0; }
          h3 { text-align: center; font-size: 10pt; margin: 0 0 10px 0; font-weight: normal; }
          .info { font-size: 9pt; line-height: 1.8; }
          .info td { padding: 0; }
          .info td:first-child { font-weight: bold; width: 100px; }
          .divider { border-top: 1px dashed #000; margin: 10px 0; }
        </style>
      </head>
      <body>
        <h2>SIMRS</h2>
        <h3>Kartu Pasien</h3>
        <div class="divider"></div>
        <table class="info">
          <tr><td>No. RM</td><td>: ${patient.no_registration || '-'}</td></tr>
          <tr><td>Nama</td><td>: ${patient.full_name || '-'}</td></tr>
          <tr><td>NIK</td><td>: ${patient.nik || '-'}</td></tr>
          <tr><td>Tgl Lahir</td><td>: ${formatDate(patient.date_of_birth)}</td></tr>
          <tr><td>Jenis Kelamin</td><td>: ${getGenderLabel(patient.gender)}</td></tr>
          <tr><td>Gol. Darah</td><td>: ${patient.blood_type || '-'}</td></tr>
          <tr><td>Telp</td><td>: ${patient.phone || '-'}</td></tr>
          <tr><td>Alamat</td><td>: ${patient.address || '-'}</td></tr>
        </table>
        <div class="divider"></div>
      </body>
      </html>
    `;
    const printWindow = window.open('', '_blank', 'width=400,height=600');
    if (printWindow) {
      printWindow.document.write(content);
      printWindow.document.close();
      printWindow.print();
    }
    printDropdownOpen = false;
  }

  function printFullHistory() {
    if (!patient) return;

    let visitRows = visits.map(v => `
      <tr>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${formatDate(v.visit_date)}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${VISIT_TYPES[v.visit_type] || v.visit_type}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${v.clinic_name}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${v.doctor_name}</td>
      </tr>
    `).join('');

    let diagnosisRows = allDiagnoses.map(d => `
      <tr>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${formatDate(d.visit_date)}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt"><strong>${d.icd_code}</strong></td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${d.icd_name}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${d.diagnosis_type === 'primer' ? 'Primer' : 'Sekunder'}</td>
      </tr>
    `).join('');

    let labRows = allLabResults.map(l => `
      <tr>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${formatDate(l.visit_date)}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${l.test_name}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${l.category || '-'}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${l.results || '-'}</td>
      </tr>
    `).join('');

    let radioRows = allRadiologyResults.map(r => `
      <tr>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${formatDate(r.visit_date)}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${r.exam_type}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${r.results || '-'}</td>
      </tr>
    `).join('');

    let rxRows = allPrescriptions.map(p => `
      <tr>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${formatDate(p.visit_date)}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${p.drug_name}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${p.qty}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${p.dosage || '-'}</td>
        <td style="padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:9pt">${p.frequency || '-'}</td>
      </tr>
    `).join('');

    const content = `
      <html>
      <head>
        <title>Riwayat Medis - ${patient.full_name}</title>
        <style>
          body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; font-size: 10pt; }
          h1 { font-size: 16pt; margin-bottom: 4px; }
          h2 { font-size: 12pt; margin: 20px 0 8px 0; color: #1e40af; border-bottom: 2px solid #1e40af; padding-bottom: 4px; }
          .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 4px 24px; margin: 10px 0; }
          .info-item { font-size: 9pt; }
          .info-label { font-weight: bold; color: #6b7280; }
          table { width: 100%; border-collapse: collapse; margin-bottom: 10px; }
          th { background: #f3f4f6; text-align: left; padding: 4px 8px; font-size: 9pt; border-bottom: 2px solid #d1d5db; }
          .no-data { color: #9ca3af; font-style: italic; text-align: center; padding: 10px; }
          @media print { body { margin: 10mm; } }
        </style>
      </head>
      <body>
        <h1>Riwayat Medis Pasien</h1>
        <p style="color:#6b7280;margin-top:0">Dicetak: ${new Date().toLocaleString('id-ID')}</p>

        <div class="info-grid">
          <div class="info-item"><span class="info-label">No. RM:</span> ${patient.no_registration || '-'}</div>
          <div class="info-item"><span class="info-label">Nama:</span> ${patient.full_name || '-'}</div>
          <div class="info-item"><span class="info-label">NIK:</span> ${patient.nik || '-'}</div>
          <div class="info-item"><span class="info-label">Tgl Lahir:</span> ${formatDate(patient.date_of_birth)}</div>
          <div class="info-item"><span class="info-label">Jenis Kelamin:</span> ${getGenderLabel(patient.gender)}</div>
          <div class="info-item"><span class="info-label">Golongan Darah:</span> ${patient.blood_type || '-'}</div>
          <div class="info-item"><span class="info-label">Telp:</span> ${patient.phone || '-'}</div>
          <div class="info-item"><span class="info-label">Alamat:</span> ${patient.address || '-'}</div>
        </div>

        <h2>Riwayat Kunjungan (${visits.length} kunjungan)</h2>
        ${visits.length > 0 ? `
        <table>
          <thead><tr><th>Tanggal</th><th>Tipe</th><th>Poli</th><th>Dokter</th></tr></thead>
          <tbody>${visitRows}</tbody>
        </table>` : '<p class="no-data">Tidak ada riwayat kunjungan</p>'}

        <h2>Diagnosis (${allDiagnoses.length} data)</h2>
        ${allDiagnoses.length > 0 ? `
        <table>
          <thead><tr><th>Tanggal</th><th>Kode</th><th>Diagnosis</th><th>Tipe</th></tr></thead>
          <tbody>${diagnosisRows}</tbody>
        </table>` : '<p class="no-data">Tidak ada diagnosis tercatat</p>'}

        <h2>Riwayat Laboratorium (${allLabResults.length} data)</h2>
        ${allLabResults.length > 0 ? `
        <table>
          <thead><tr><th>Tanggal</th><th>Tes</th><th>Kategori</th><th>Hasil</th></tr></thead>
          <tbody>${labRows}</tbody>
        </table>` : '<p class="no-data">Tidak ada riwayat lab</p>'}

        <h2>Riwayat Radiologi (${allRadiologyResults.length} data)</h2>
        ${allRadiologyResults.length > 0 ? `
        <table>
          <thead><tr><th>Tanggal</th><th>Jenis</th><th>Hasil</th></tr></thead>
          <tbody>${radioRows}</tbody>
        </table>` : '<p class="no-data">Tidak ada riwayat radiologi</p>'}

        <h2>Riwayat Resep/Obat (${allPrescriptions.length} data)</h2>
        ${allPrescriptions.length > 0 ? `
        <table>
          <thead><tr><th>Tanggal</th><th>Obat</th><th>Qty</th><th>Dosis</th><th>Frekuensi</th></tr></thead>
          <tbody>${rxRows}</tbody>
        </table>` : '<p class="no-data">Tidak ada riwayat resep</p>'}
      </body>
      </html>
    `;
    const printWindow = window.open('', '_blank', 'width=900,height=700');
    if (printWindow) {
      printWindow.document.write(content);
      printWindow.document.close();
      printWindow.print();
    }
    printDropdownOpen = false;
  }

  function goBack() {
    goto('/rekam-medis');
  }

  onMount(async () => {
    loading = true;
    await fetchPatientData();
    await fetchVisits();
    await Promise.all([
      fetchAllDiagnoses(),
      fetchAllLabResults(),
      fetchAllRadiologyResults(),
      fetchAllPrescriptions()
    ]);
    buildResume();
    loading = false;
  });

  $effect(() => {
    if (visits.length >= 0 && !loading) {
      buildResume();
    }
  });
</script>

<svelte:head>
  <title>{patient?.full_name || 'Pasien'} - Rekam Medis</title>
</svelte:head>

{#if loading}
  <div class="flex items-center justify-center py-24">
    <div class="flex flex-col items-center gap-4">
      <div class="w-12 h-12 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
      <p class="text-sm text-gray-500 font-medium">Memuat data rekam medis...</p>
    </div>
  </div>
{:else if !patient}
  <div class="card text-center py-16">
    <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
    </svg>
    <p class="text-lg font-medium text-gray-700">Pasien tidak ditemukan</p>
    <button class="btn-primary mt-4" onclick={goBack}>Kembali ke Pencarian</button>
  </div>
{:else}
  <div class="space-y-6">
    <div class="flex items-center gap-3">
      <button class="btn-secondary btn-sm" onclick={goBack}>
        <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
        </svg>
        Kembali
      </button>
      <h1 class="text-xl font-bold text-gray-900">Rekam Medis Pasien</h1>
    </div>

    <div class="card bg-gradient-to-r from-primary-50 to-blue-50 border-primary-200">
      <div class="flex flex-col md:flex-row md:items-start gap-5">
        <div class="shrink-0 w-16 h-16 rounded-full bg-primary-100 flex items-center justify-center">
          <svg class="w-8 h-8 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
          </svg>
        </div>
        <div class="flex-1">
          <h2 class="text-xl font-bold text-gray-900">{patient.full_name || '-'}</h2>
          <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-x-6 gap-y-2 mt-3 text-sm">
            <div>
              <p class="text-xs text-gray-500">No. RM</p>
              <p class="font-semibold text-gray-900 font-mono">{patient.no_registration || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">NIK</p>
              <p class="font-semibold text-gray-900 font-mono">{patient.nik || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Tgl Lahir</p>
              <p class="font-semibold text-gray-900">{formatDate(patient.date_of_birth)}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Umur</p>
              <p class="font-semibold text-gray-900">{calculateAge(patient.date_of_birth)}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Jenis Kelamin</p>
              <p class="font-semibold text-gray-900">{getGenderLabel(patient.gender)}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Telp</p>
              <p class="font-semibold text-gray-900">{patient.phone || '-'}</p>
            </div>
            <div class="sm:col-span-2 lg:col-span-2">
              <p class="text-xs text-gray-500">Alamat</p>
              <p class="font-semibold text-gray-900 text-xs leading-relaxed">{patient.address || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Gol. Darah</p>
              <p class="font-semibold text-gray-900">{patient.blood_type || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Penanggung Biaya</p>
              <p class="font-semibold text-gray-900">{PAYOR_TYPES[patient.payor_type] || patient.payor_type || '-'}</p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="card p-0">
      <div class="flex overflow-x-auto border-b border-gray-200 scrollbar-thin">
        {#each tabs as tab}
          <button
            class="flex items-center gap-2 px-4 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
              {activeTab === tab.id
                ? 'border-primary-600 text-primary-700 bg-primary-50'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
            onclick={() => activeTab = tab.id}
          >
            {#if tab.icon === 'calendar'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5" /></svg>
            {:else if tab.icon === 'activity'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 0 0 6 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0 1 18 16.5h-2.25m-7.5 0h7.5m-7.5 0-1 3m8.5-3 1 3m0 0 .5 1.5m-.5-1.5h-9.5m0 0-.5 1.5" /></svg>
            {:else if tab.icon === 'flask'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" /></svg>
            {:else if tab.icon === 'scan'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0 1 3.75 9.375v-4.5ZM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 0 1-1.125-1.125v-4.5ZM13.5 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0 1 13.5 9.375v-4.5Z" /><path stroke-linecap="round" stroke-linejoin="round" d="M6.75 6.75h.75v.75h-.75v-.75ZM6.75 16.5h.75v.75h-.75v-.75ZM16.5 6.75h.75v.75h-.75v-.75ZM13.5 13.5h.75v.75h-.75v-.75ZM13.5 19.5h.75v.75h-.75v-.75ZM19.5 13.5h.75v.75h-.75v-.75ZM19.5 19.5h.75v.75h-.75v-.75ZM16.5 16.5h.75v.75h-.75v-.75Z" /></svg>
            {:else if tab.icon === 'pill'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" /></svg>
            {:else if tab.icon === 'file-text'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" /></svg>
            {:else if tab.icon === 'printer'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0 1 10.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0 .229 2.523a1.125 1.125 0 0 1-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0 0 21 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 0 0-1.913-.247M6.34 18H5.25A2.25 2.25 0 0 1 3 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 0 1 1.913-.247m10.5 0a48.536 48.536 0 0 0-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659M18 10.5h.008v.008H18V10.5Zm-3 0h.008v.008H15V10.5Z" /></svg>
            {/if}
            <span class="hidden sm:inline">{tab.label}</span>
          </button>
        {/each}
      </div>

      <div class="p-6">
        {#if activeTab === 'kunjungan'}
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-semibold text-gray-900">Riwayat Kunjungan</h3>
              <span class="badge badge-gray">{visits.length} kunjungan</span>
            </div>

            {#if visits.length > 0}
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead>
                    <tr class="table-header">
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tanggal</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Poli</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Dokter</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tipe</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden xl:table-cell">Diagnosis</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    {#each visits as visit, i}
                      {@const status = getVisitStatusLabel(visit)}
                      <tr class="hover:bg-gray-50 transition-colors">
                        <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                        <td class="table-cell">
                          <p class="font-medium text-gray-900 text-sm">{formatDate(visit.visit_date)}</p>
                          <p class="text-xs text-gray-400 font-mono">{formatDateTime(visit.visit_date).split(',')[1]?.trim() || ''}</p>
                        </td>
                        <td class="table-cell text-gray-600 hidden md:table-cell">{visit.clinic_name}</td>
                        <td class="table-cell text-gray-600 hidden lg:table-cell">{visit.doctor_name}</td>
                        <td class="table-cell">
                          <span class="badge {getVisitTypeBadge(visit.visit_type)}">{VISIT_TYPES[visit.visit_type] || visit.visit_type}</span>
                        </td>
                        <td class="table-cell text-gray-600 hidden xl:table-cell text-xs max-w-[200px] truncate">{visit.diagnosis || '-'}</td>
                        <td class="table-cell">
                          <span class="badge {status.class}">{status.label}</span>
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            {:else}
              <div class="text-center py-12 text-gray-400">
                <svg class="w-14 h-14 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5" />
                </svg>
                <p class="text-sm font-medium">Belum ada riwayat kunjungan</p>
              </div>
            {/if}
          </div>

        {:else if activeTab === 'diagnosis'}
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-semibold text-gray-900">Riwayat Diagnosis</h3>
              <span class="badge badge-gray">{allDiagnoses.length} diagnosis</span>
            </div>

            {#if allDiagnoses.length > 0}
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead>
                    <tr class="table-header">
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tanggal</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Kode ICD</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Diagnosis</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tipe</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    {#each allDiagnoses as diag, i}
                      <tr class="hover:bg-gray-50 transition-colors">
                        <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                        <td class="table-cell text-gray-500 text-xs">{formatDate(diag.visit_date)}</td>
                        <td class="table-cell">
                          <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">{diag.icd_code}</span>
                        </td>
                        <td class="table-cell font-medium text-gray-900">{diag.icd_name}</td>
                        <td class="table-cell">
                          <span class="badge {diag.diagnosis_type === 'primer' ? 'badge-danger' : 'badge-info'}">
                            {diag.diagnosis_type === 'primer' ? 'Primer' : 'Sekunder'}
                          </span>
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            {:else}
              <div class="text-center py-12 text-gray-400">
                <svg class="w-14 h-14 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 0 0 6 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0 1 18 16.5h-2.25m-7.5 0h7.5m-7.5 0-1 3m8.5-3 1 3m0 0 .5 1.5m-.5-1.5h-9.5m0 0-.5 1.5" />
                </svg>
                <p class="text-sm font-medium">Belum ada riwayat diagnosis</p>
              </div>
            {/if}
          </div>

        {:else if activeTab === 'lab'}
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-semibold text-gray-900">Riwayat Laboratorium</h3>
              <span class="badge badge-gray">{allLabResults.length} data</span>
            </div>

            {#if allLabResults.length > 0}
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead>
                    <tr class="table-header">
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tanggal</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Tes</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Kategori</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Hasil</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    {#each allLabResults as lab, i}
                      <tr class="hover:bg-gray-50 transition-colors">
                        <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                        <td class="table-cell text-gray-500 text-xs">{formatDate(lab.visit_date)}</td>
                        <td class="table-cell font-medium text-gray-900">{lab.test_name}</td>
                        <td class="table-cell text-gray-600 hidden md:table-cell">
                          <span class="badge badge-gray">{lab.category || '-'}</span>
                        </td>
                        <td class="table-cell">
                          <span class="badge {lab.status === 'completed' ? 'badge-success' : lab.status === 'ordered' ? 'badge-warning' : 'badge-info'}">
                            {lab.status === 'completed' ? 'Selesai' : lab.status === 'ordered' ? 'Dipesan' : 'Proses'}
                          </span>
                        </td>
                        <td class="table-cell text-gray-600 hidden lg:table-cell text-xs max-w-[300px]">{lab.results || '-'}</td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            {:else}
              <div class="text-center py-12 text-gray-400">
                <svg class="w-14 h-14 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" />
                </svg>
                <p class="text-sm font-medium">Belum ada riwayat laboratorium</p>
              </div>
            {/if}
          </div>

        {:else if activeTab === 'radiologi'}
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-semibold text-gray-900">Riwayat Radiologi</h3>
              <span class="badge badge-gray">{allRadiologyResults.length} data</span>
            </div>

            {#if allRadiologyResults.length > 0}
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead>
                    <tr class="table-header">
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tanggal</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Jenis Pemeriksaan</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Deskripsi</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Hasil</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    {#each allRadiologyResults as radio, i}
                      <tr class="hover:bg-gray-50 transition-colors">
                        <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                        <td class="table-cell text-gray-500 text-xs">{formatDate(radio.visit_date)}</td>
                        <td class="table-cell font-medium text-gray-900">{radio.exam_type}</td>
                        <td class="table-cell text-gray-600 hidden md:table-cell">{radio.description || '-'}</td>
                        <td class="table-cell">
                          <span class="badge {radio.status === 'completed' ? 'badge-success' : radio.status === 'ordered' ? 'badge-warning' : 'badge-info'}">
                            {radio.status === 'completed' ? 'Selesai' : radio.status === 'ordered' ? 'Dipesan' : 'Proses'}
                          </span>
                        </td>
                        <td class="table-cell text-gray-600 hidden lg:table-cell text-xs max-w-[300px]">{radio.results || '-'}</td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            {:else}
              <div class="text-center py-12 text-gray-400">
                <svg class="w-14 h-14 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0 1 3.75 9.375v-4.5ZM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 0 1-1.125-1.125v-4.5ZM13.5 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0 1 13.5 9.375v-4.5Z" />
                </svg>
                <p class="text-sm font-medium">Belum ada riwayat radiologi</p>
              </div>
            {/if}
          </div>

        {:else if activeTab === 'resep'}
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-semibold text-gray-900">Riwayat Resep / Obat</h3>
              <span class="badge badge-gray">{allPrescriptions.length} data</span>
            </div>

            {#if allPrescriptions.length > 0}
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead>
                    <tr class="table-header">
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tanggal</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Obat</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Qty</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Dosis</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Frekuensi</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden xl:table-cell">Instruksi</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    {#each allPrescriptions as rx, i}
                      <tr class="hover:bg-gray-50 transition-colors">
                        <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                        <td class="table-cell text-gray-500 text-xs">{formatDate(rx.visit_date)}</td>
                        <td class="table-cell font-medium text-gray-900">{rx.drug_name}</td>
                        <td class="table-cell text-gray-600 hidden md:table-cell">{rx.qty}</td>
                        <td class="table-cell text-gray-600 hidden md:table-cell">{rx.dosage || '-'}</td>
                        <td class="table-cell text-gray-600 hidden lg:table-cell">{rx.frequency || '-'}</td>
                        <td class="table-cell text-gray-600 hidden xl:table-cell text-xs">{rx.instruction || '-'}</td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            {:else}
              <div class="text-center py-12 text-gray-400">
                <svg class="w-14 h-14 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" />
                </svg>
                <p class="text-sm font-medium">Belum ada riwayat resep obat</p>
              </div>
            {/if}
          </div>

        {:else if activeTab === 'resume'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Resume Medis</h3>

            {#if resumeData}
              <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
                <div class="bg-blue-50 rounded-xl p-4 text-center">
                  <p class="text-2xl font-bold text-blue-600">{resumeData.totalVisits}</p>
                  <p class="text-xs text-blue-500 font-medium mt-1">Total Kunjungan</p>
                </div>
                <div class="bg-emerald-50 rounded-xl p-4 text-center">
                  <p class="text-2xl font-bold text-emerald-600">{resumeData.totalDiagnoses}</p>
                  <p class="text-xs text-emerald-500 font-medium mt-1">Total Diagnosis</p>
                </div>
                <div class="bg-purple-50 rounded-xl p-4 text-center">
                  <p class="text-2xl font-bold text-purple-600">{resumeData.totalLab}</p>
                  <p class="text-xs text-purple-500 font-medium mt-1">Total Tes Lab</p>
                </div>
                <div class="bg-amber-50 rounded-xl p-4 text-center">
                  <p class="text-2xl font-bold text-amber-600">{resumeData.totalPrescriptions}</p>
                  <p class="text-xs text-amber-500 font-medium mt-1">Total Resep Obat</p>
                </div>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="rounded-xl border border-gray-200 overflow-hidden">
                  <div class="bg-gray-50 px-4 py-3 border-b border-gray-200">
                    <h4 class="text-sm font-semibold text-gray-700">Ringkasan Kunjungan</h4>
                  </div>
                  <div class="p-4 space-y-3">
                    <div class="flex justify-between text-sm">
                      <span class="text-gray-600">Rawat Jalan</span>
                      <span class="font-semibold text-gray-900">{resumeData.totalRawatJalan}</span>
                    </div>
                    <div class="flex justify-between text-sm">
                      <span class="text-gray-600">Rawat Inap</span>
                      <span class="font-semibold text-gray-900">{resumeData.totalRawatInap}</span>
                    </div>
                    <div class="flex justify-between text-sm">
                      <span class="text-gray-600">IGD</span>
                      <span class="font-semibold text-gray-900">{resumeData.totalIGD}</span>
                    </div>
                    <div class="border-t border-gray-100 pt-3">
                      <div class="flex justify-between text-sm">
                        <span class="text-gray-600">Radiologi</span>
                        <span class="font-semibold text-gray-900">{resumeData.totalRadiology}</span>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="rounded-xl border border-gray-200 overflow-hidden">
                  <div class="bg-gray-50 px-4 py-3 border-b border-gray-200">
                    <h4 class="text-sm font-semibold text-gray-700">Kunjungan Pertama & Terakhir</h4>
                  </div>
                  <div class="p-4 space-y-3">
                    {#if resumeData.firstVisit}
                      <div>
                        <p class="text-xs text-gray-500">Kunjungan Pertama</p>
                        <p class="text-sm font-medium text-gray-900">{formatDate(resumeData.firstVisit.visit_date)}</p>
                        <p class="text-xs text-gray-500">{resumeData.firstVisit.clinic_name} - {resumeData.firstVisit.doctor_name}</p>
                      </div>
                    {:else}
                      <p class="text-sm text-gray-400">-</p>
                    {/if}
                    {#if resumeData.lastVisit}
                      <div class="border-t border-gray-100 pt-3">
                        <p class="text-xs text-gray-500">Kunjungan Terakhir</p>
                        <p class="text-sm font-medium text-gray-900">{formatDate(resumeData.lastVisit.visit_date)}</p>
                        <p class="text-xs text-gray-500">{resumeData.lastVisit.clinic_name} - {resumeData.lastVisit.doctor_name}</p>
                      </div>
                    {/if}
                  </div>
                </div>
              </div>

              {#if resumeData.primerDiagnoses.length > 0}
                <div class="rounded-xl border border-gray-200 overflow-hidden">
                  <div class="bg-gray-50 px-4 py-3 border-b border-gray-200">
                    <h4 class="text-sm font-semibold text-gray-700">Diagnosis Primer Terbanyak</h4>
                  </div>
                  <div class="p-4">
                    <div class="space-y-2">
                      {#each resumeData.primerDiagnoses.slice(0, 5) as diag}
                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-3">
                            <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">{diag.icd_code}</span>
                            <span class="text-sm text-gray-700">{diag.icd_name}</span>
                          </div>
                          <span class="badge badge-gray">{diag.count}x</span>
                        </div>
                      {/each}
                    </div>
                  </div>
                </div>
              {/if}
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Data resume tidak tersedia</p>
            {/if}
          </div>

        {:else if activeTab === 'cetak'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Cetak Dokumen</h3>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <button
                class="flex items-center gap-4 p-5 rounded-xl border-2 border-gray-200 hover:border-primary-300 hover:bg-primary-50 transition-all text-left group"
                onclick={printPatientCard}
              >
                <div class="shrink-0 w-12 h-12 rounded-lg bg-blue-100 group-hover:bg-blue-200 flex items-center justify-center transition-colors">
                  <svg class="w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
                  </svg>
                </div>
                <div>
                  <p class="font-semibold text-gray-900">Cetak Kartu Pasien</p>
                  <p class="text-sm text-gray-500 mt-0.5">Cetak kartu identitas pasien</p>
                </div>
              </button>

              <button
                class="flex items-center gap-4 p-5 rounded-xl border-2 border-gray-200 hover:border-primary-300 hover:bg-primary-50 transition-all text-left group"
                onclick={printFullHistory}
              >
                <div class="shrink-0 w-12 h-12 rounded-lg bg-emerald-100 group-hover:bg-emerald-200 flex items-center justify-center transition-colors">
                  <svg class="w-6 h-6 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
                  </svg>
                </div>
                <div>
                  <p class="font-semibold text-gray-900">Cetak Riwayat Lengkap</p>
                  <p class="text-sm text-gray-500 mt-0.5">Riwayat kunjungan, diagnosis, lab, radiologi, dan resep</p>
                </div>
              </button>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}
