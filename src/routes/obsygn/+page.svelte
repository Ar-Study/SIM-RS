<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate } from '$lib/utils/helpers.js';

  let loading = $state(true);
  let activeTab = $state('pasien');

  let patients = $state([]);
  let patientList = $state([]);
  let ancVisits = $state([]);
  let visits = $state([]);
  let doctors = $state([]);
  let searchQuery = $state('');

  let showForm = $state(false);
  let saving = $state(false);

  let newANC = $state({
    patient_id: '',
    visit_date: '',
    gestational_age: '',
    blood_pressure: '',
    weight: '',
    fundal_height: '',
    fetal_heart_rate: '',
    notes: '',
    doctor_id: ''
  });

  const stats = $derived({
    total: patients.length,
    prenatal: patients.filter(p => p.patient_type === 'prenatal').length,
    postpartum: patients.filter(p => p.patient_type === 'postpartum').length,
    labor: patients.filter(p => p.patient_type === 'labor').length,
    gynecology: patients.filter(p => p.patient_type === 'gynecology').length
  });

  const filteredPatients = $derived.by(() => {
    let result = patients;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(p =>
        p.patient_name.toLowerCase().includes(q) ||
        p.patient_no?.toLowerCase().includes(q)
      );
    }
    return result;
  });

  function getTypeBadge(type) {
    switch (type) {
      case 'prenatal': return { label: 'ANC', class: 'badge-info' };
      case 'postpartum': return { label: 'Post Partum', class: 'badge-warning' };
      case 'labor': return { label: 'Persalinan', class: 'badge-danger' };
      case 'gynecology': return { label: 'Ginekologi', class: 'badge-gray' };
      default: return { label: '-', class: 'badge-gray' };
    }
  }

  function getANCStatus(trimester) {
    if (trimester === 'T1') return { label: 'T1 (≤12 mgg)', class: 'bg-blue-100 text-blue-800' };
    if (trimester === 'T2') return { label: 'T2 (13-27 mgg)', class: 'bg-emerald-100 text-emerald-800' };
    if (trimester === 'T3') return { label: 'T3 (≥28 mgg)', class: 'bg-amber-100 text-amber-800' };
    return { label: '-', class: 'bg-gray-100 text-gray-800' };
  }

  function getLaborStatus(status) {
    switch (status) {
      case 'early': return { label: 'Awal', class: 'badge-info' };
      case 'active': return { label: 'Aktif', class: 'badge-warning' };
      case 'transition': return { label: 'Transisi', class: 'badge-danger' };
      case 'pushing': return { label: 'Mengejan', class: 'badge-danger' };
      case 'delivery': return { label: 'Persalinan', class: 'badge-danger' };
      case 'placenta': return { label: 'Plasenta', class: 'badge-warning' };
      default: return { label: '-', class: 'badge-gray' };
    }
  }

  async function submitANC() {
    if (!newANC.patient_id || !newANC.visit_date) return;
    saving = true;
    try {
      const { error } = await supabase.from('anc_visits').insert({
        ...newANC,
        created_at: new Date().toISOString()
      });
      if (error) throw error;
      showForm = false;
      newANC = { patient_id: '', visit_date: '', gestational_age: '', blood_pressure: '', weight: '', fundal_height: '', fetal_heart_rate: '', notes: '', doctor_id: '' };
      await Promise.all([fetchPatients(), fetchAncVisits()]);
    } catch (err) {
      console.error('Submit ANC error:', err);
    } finally {
      saving = false;
    }
  }

  async function fetchPatients() {
    try {
      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          visit_id,
          visit_date,
          patient_id,
          doctor_id,
          patients:patient_id ( full_name, no_registration, date_of_birth, gender ),
          doctors:doctor_id ( full_name )
        `)
        .eq('visit_type', 'rawat_jalan')
        .is('exit_date', null)
        .order('visit_date', { ascending: false });
      if (error) throw error;

      const raw = (data || []).map(v => ({
        ...v,
        patient_name: v.patients?.full_name || '-',
        patient_no: v.patients?.no_registration || '-',
        doctor_name: v.doctors?.full_name || '-',
        patient_type: 'prenatal',
        gestational_age: null,
        trimester: null,
        labor_status: null
      }));

      patients = raw;
    } catch (err) {
      console.error('Fetch OBS/GYN patients error:', err);
    }
  }

  async function fetchPatientList() {
    try {
      const { data, error } = await supabase
        .from('patients')
        .select('patient_id, full_name, no_registration')
        .order('full_name');
      if (error) throw error;
      patientList = data || [];
    } catch (err) {
      console.error('Fetch patient list error:', err);
    }
  }

  async function fetchDoctors() {
    try {
      const { data, error } = await supabase
        .from('employees')
        .select('employee_id, full_name, specialization')
        .eq('role', 'doctor')
        .eq('is_active', true)
        .order('full_name');
      if (error) throw error;
      doctors = data || [];
    } catch (err) {
      console.error('Fetch doctors error:', err);
    }
  }

  async function fetchAncVisits() {
    try {
      const { data, error } = await supabase
        .from('anc_visits')
        .select(`
          *,
          patients:patient_id ( full_name, no_registration ),
          employees:doctor_id ( full_name )
        `)
        .order('visit_date', { ascending: false });
      if (error) throw error;
      ancVisits = (data || []).map(a => ({
        ...a,
        patient_name: a.patients?.full_name || '-',
        patient_no: a.patients?.no_registration || '-',
        doctor_name: a.employees?.full_name || '-'
      }));
    } catch (err) {
      console.error('Fetch ANC visits error:', err);
    }
  }

  async function refreshAll() {
    loading = true;
    await Promise.all([fetchPatients(), fetchPatientList(), fetchDoctors(), fetchAncVisits()]);
    loading = false;
  }

  onMount(async () => {
    await refreshAll();
  });
</script>

<svelte:head>
  <title>Obstetri & Ginekologi - SIMRS</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div class="flex items-center gap-3">
      <div class="w-10 h-10 rounded-lg bg-rose-600 flex items-center justify-center">
        <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
        </svg>
      </div>
      <div>
        <h1 class="text-2xl font-bold text-rose-700">Obstetri & Ginekologi</h1>
        <p class="text-sm text-gray-500 mt-0.5">Pemantauan kehamilan, persalinan, dan ginekologi</p>
      </div>
    </div>
    <button class="btn-secondary btn-sm" onclick={refreshAll}>
      <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182" />
      </svg>
      Refresh
    </button>
  </div>

  <div class="grid grid-cols-2 lg:grid-cols-5 gap-3">
    <div class="card p-4">
      <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Total</p>
      <p class="text-2xl font-bold text-gray-900 mt-1">{stats.total}</p>
    </div>
    <div class="card p-4 border-blue-200 bg-blue-50">
      <p class="text-xs text-blue-700 uppercase tracking-wide font-medium">ANC</p>
      <p class="text-2xl font-bold text-blue-700 mt-1">{stats.prenatal}</p>
    </div>
    <div class="card p-4 border-amber-200 bg-amber-50">
      <p class="text-xs text-amber-700 uppercase tracking-wide font-medium">Post Partum</p>
      <p class="text-2xl font-bold text-amber-700 mt-1">{stats.postpartum}</p>
    </div>
    <div class="card p-4 border-red-200 bg-red-50">
      <p class="text-xs text-red-700 uppercase tracking-wide font-medium">Persalinan</p>
      <p class="text-2xl font-bold text-red-700 mt-1">{stats.labor}</p>
    </div>
    <div class="card p-4 border-gray-200 bg-gray-50">
      <p class="text-xs text-gray-700 uppercase tracking-wide font-medium">Ginekologi</p>
      <p class="text-2xl font-bold text-gray-700 mt-1">{stats.gynecology}</p>
    </div>
  </div>

  <div class="card">
    <div class="flex items-center gap-2 mb-4">
      <svg class="w-5 h-5 text-rose-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 0 1 0 3.75H5.625a1.875 1.875 0 0 1 0-3.75Z" />
      </svg>
      <h2 class="text-lg font-semibold text-gray-900">Alur Kehamilan</h2>
    </div>
    <div class="flex items-center gap-2 overflow-x-auto pb-2">
      {#each ['Konsultasi ANC', 'Pemantauan T1-T3', 'Persalinan', 'Post Partum', 'Kontrol'] as step, i}
        <div class="flex items-center gap-2 shrink-0">
          <div class="flex items-center justify-center w-8 h-8 rounded-full bg-rose-600 text-white text-xs font-bold">{i + 1}</div>
          <span class="text-sm font-medium text-gray-700">{step}</span>
          {#if i < 4}
            <svg class="w-5 h-5 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3" />
            </svg>
          {/if}
        </div>
      {/each}
    </div>
  </div>

  <div class="flex items-center gap-2 border-b border-gray-200">
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {activeTab === 'pasien' ? 'border-rose-600 text-rose-700 bg-rose-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'pasien'}
    >
      Daftar Pasien
    </button>
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {activeTab === 'anc' ? 'border-rose-600 text-rose-700 bg-rose-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'anc'}
    >
      Kunjungan ANC
    </button>
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {activeTab === 'labor' ? 'border-rose-600 text-rose-700 bg-rose-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'labor'}
    >
      Persalinan Aktif
    </button>
  </div>

  {#if activeTab === 'pasien'}
    <div class="card">
      <div class="flex items-center justify-between mb-4">
        <div class="relative w-64">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
          </svg>
          <input type="text" class="input-field pl-10" placeholder="Cari pasien..." bind:value={searchQuery} />
        </div>
      </div>

      <div class="overflow-x-auto">
        {#if loading}
          <div class="flex items-center justify-center py-16">
            <div class="w-10 h-10 border-4 border-rose-200 border-t-rose-600 rounded-full animate-spin"></div>
          </div>
        {:else if filteredPatients.length === 0}
          <div class="text-center py-16 text-gray-400">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
            </svg>
            <p class="text-lg font-medium">Tidak ada pasien OBS/GYN</p>
          </div>
        {:else}
          <table class="w-full">
            <thead>
              <tr class="table-header">
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No.RM</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Tipe</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Tgl Kunjung</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Trimester</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Dokter</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each filteredPatients as p, i}
                {@const typeBadge = getTypeBadge(p.patient_type)}
                {@const trimesterBadge = getANCStatus(p.trimester)}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                  <td class="table-cell">
                    <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">{p.patient_no}</span>
                  </td>
                  <td class="table-cell">
                    <p class="font-medium text-gray-900">{p.patient_name}</p>
                  </td>
                  <td class="table-cell hidden md:table-cell">
                    <span class="badge {typeBadge.class}">{typeBadge.label}</span>
                  </td>
                  <td class="table-cell text-gray-500 hidden sm:table-cell font-mono text-xs">{formatDate(p.visit_date)}</td>
                  <td class="table-cell hidden lg:table-cell">
                    {#if p.trimester}
                      <span class="badge {trimesterBadge.class}">{trimesterBadge.label}</span>
                    {:else}
                      <span class="text-gray-400">-</span>
                    {/if}
                  </td>
                  <td class="table-cell text-gray-600 hidden lg:table-cell">{p.doctor_name}</td>
                  <td class="table-cell text-right">
                    <a href="/rawat-jalan/{p.visit_id}" class="btn-primary btn-sm text-xs">Detail</a>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>
    </div>

  {:else if activeTab === 'anc'}
    <div class="flex items-center justify-between mb-4">
      <p class="text-sm text-gray-500">Kunjungan Antenatal Care</p>
      <button class="btn-primary btn-sm" onclick={() => showForm = !showForm}>
        <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        Kunjungan ANC Baru
      </button>
    </div>

    {#if showForm}
      <div class="card border-rose-200">
        <h3 class="font-semibold text-gray-900 mb-4">Kunjungan ANC Baru</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="label">Pasien *</label>
            <select class="select-field" bind:value={newANC.patient_id}>
              <option value="">Pilih Pasien</option>
              {#each patientList as p}
                <option value={p.patient_id}>{p.full_name} ({p.no_registration})</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Tanggal Kunjungan *</label>
            <input type="date" class="input-field" bind:value={newANC.visit_date} />
          </div>
          <div>
            <label class="label">Usia Kehamilan (minggu)</label>
            <input type="number" class="input-field" placeholder="contoh: 24" bind:value={newANC.gestational_age} min="1" max="45" />
          </div>
          <div>
            <label class="label">Tekanan Darah</label>
            <input type="text" class="input-field" placeholder="contoh: 120/80" bind:value={newANC.blood_pressure} />
          </div>
          <div>
            <label class="label">BB Ibu (kg)</label>
            <input type="number" class="input-field" placeholder="Berat badan" bind:value={newANC.weight} step="0.1" />
          </div>
          <div>
            <label class="label">Tinggi Fundus (cm)</label>
            <input type="number" class="input-field" placeholder="TFU" bind:value={newANC.fundal_height} step="0.5" />
          </div>
          <div>
            <label class="label">DJJ (x/menit)</label>
            <input type="number" class="input-field" placeholder="Detak Jantung Janin" bind:value={newANC.fetal_heart_rate} />
          </div>
          <div>
            <label class="label">Dokter</label>
            <select class="select-field" bind:value={newANC.doctor_id}>
              <option value="">Pilih Dokter</option>
              {#each doctors as d}
                <option value={d.employee_id}>{d.full_name}</option>
              {/each}
            </select>
          </div>
          <div class="md:col-span-2">
            <label class="label">Catatan</label>
            <textarea class="input-field" rows="2" placeholder="Catatan kunjungan..." bind:value={newANC.notes}></textarea>
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-5">
          <button class="btn-secondary btn-sm" onclick={() => showForm = false}>Batal</button>
          <button class="btn-primary btn-sm" onclick={submitANC} disabled={saving}>
            {saving ? 'Menyimpan...' : 'Simpan'}
          </button>
        </div>
      </div>
    {/if}

    <div class="card">
      <div class="overflow-x-auto">
        {#if ancVisits.length === 0}
          <div class="text-center py-16 text-gray-400">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
            </svg>
            <p class="text-lg font-medium">Belum ada kunjungan ANC</p>
            <p class="text-sm mt-1">Klik "Kunjungan ANC Baru" untuk mencatat kunjungan pertama</p>
          </div>
        {:else}
          <table class="w-full">
            <thead>
              <tr class="table-header">
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No.RM</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Tgl</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Usia Hamil</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">TD</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">BB (kg)</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">TFU (cm)</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">DJJ</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden xl:table-cell">Dokter</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each ancVisits as a, i}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                  <td class="table-cell">
                    <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">{a.patient_no}</span>
                  </td>
                  <td class="table-cell">
                    <p class="font-medium text-gray-900">{a.patient_name}</p>
                  </td>
                  <td class="table-cell text-gray-500 hidden sm:table-cell font-mono text-xs">{formatDate(a.visit_date)}</td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{a.gestational_age ? `${a.gestational_age} mgg` : '-'}</td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{a.blood_pressure || '-'}</td>
                  <td class="table-cell text-gray-600 hidden lg:table-cell">{a.weight ?? '-'}</td>
                  <td class="table-cell text-gray-600 hidden lg:table-cell">{a.fundal_height ?? '-'}</td>
                  <td class="table-cell text-gray-600 hidden lg:table-cell">{a.fetal_heart_rate ?? '-'}</td>
                  <td class="table-cell text-gray-600 hidden xl:table-cell">{a.doctor_name}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>
    </div>

  {:else if activeTab === 'labor'}
    <div class="card">
      <div class="flex items-center gap-2 mb-4">
        <svg class="w-5 h-5 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        <h2 class="text-lg font-semibold text-gray-900">Persalinan Aktif</h2>
      </div>
      <div class="text-center py-16 text-gray-400">
        <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        <p class="text-lg font-medium">Tidak ada persalinan aktif</p>
        <p class="text-sm mt-1">Pasien yang sedang dalam proses persalinan akan muncul di sini</p>
      </div>
    </div>
  {/if}
</div>
