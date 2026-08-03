<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDateTime } from '$lib/utils/helpers.js';
  import { toast } from '$lib/toast.svelte.js';

  let loading = $state(true);
  let activeTab = $state('aktif');

  let laborPatients = $state([]);
  let deliveries = $state([]);
  let patients = $state([]);
  let doctors = $state([]);
  let beds = $state([]);

  let showForm = $state(false);
  let saving = $state(false);

  let newDelivery = $state({
    patient_id: '',
    admission_time: '',
    gestational_age: '',
    presentation: 'kepala',
    membrane_status: 'intact',
    cervix_dilation: '',
    contraction_freq: '',
    doctor_id: '',
    notes: ''
  });

  const presentationTypes = ['kepala', 'bokong', 'lilitan tali pusat', 'obliques', 'lainnya'];

  const stats = $derived({
    active: laborPatients.length,
    delivered: deliveries.length,
    beds_total: beds.length,
    beds_available: beds.filter(b => b.status === 'empty').length
  });

  function getLaborStatus(status) {
    switch (status) {
      case 'admission': return { label: 'Masuk', class: 'badge-info' };
      case 'latent': return { label: 'Fase Laten', class: 'badge-info' };
      case 'active': return { label: 'Fase Aktif', class: 'badge-warning' };
      case 'transition': return { label: 'Transisi', class: 'badge-danger' };
      case 'pushing': return { label: 'Mengejan', class: 'badge-danger' };
      case 'delivery': return { label: 'Persalinan', class: 'badge-danger' };
      case 'placenta': return { label: 'Plasenta', class: 'badge-warning' };
      case 'postpartum': return { label: 'Post Partum', class: 'badge-success' };
      default: return { label: status || '-', class: 'badge-gray' };
    }
  }

  function getDilationColor(dilation) {
    if (!dilation) return 'text-gray-400';
    if (dilation < 4) return 'text-blue-600';
    if (dilation < 8) return 'text-amber-600';
    return 'text-red-600';
  }

  function getLaborDuration(admissionTime) {
    if (!admissionTime) return '-';
    const start = new Date(admissionTime);
    const now = new Date();
    const hours = Math.floor((now - start) / (1000 * 60 * 60));
    const mins = Math.floor(((now - start) % (1000 * 60 * 60)) / (1000 * 60));
    return `${hours}j ${mins}m`;
  }

  async function advanceLaborStatus(patientId, currentStatus) {
    const next = {
      admission: 'latent',
      latent: 'active',
      active: 'transition',
      transition: 'pushing',
      pushing: 'delivery',
      delivery: 'placenta',
      placenta: 'postpartum'
    };
    const nextStatus = next[currentStatus];
    if (!nextStatus) return;
    try {
      const { error } = await supabase
        .from('labor_progress')
        .update({ status: nextStatus, updated_at: new Date().toISOString() })
        .eq('patient_id', patientId);
      if (error) throw error;
      toast(`Status persalinan diperbarui ke fase "${getLaborStatus(nextStatus).label}"`, 'success');
      await fetchLaborPatients();
    } catch (err) {
      console.error('Advance labor error:', err);
      toast('Gagal memperbarui status persalinan', 'error');
    }
  }

  async function submitDelivery() {
    if (!newDelivery.patient_id) {
      toast('Silakan pilih pasien terlebih dahulu', 'error');
      return;
    }
    if (!newDelivery.admission_time) {
      toast('Silakan isi jam masuk persalinan', 'error');
      return;
    }
    saving = true;
    try {
      const { error } = await supabase.from('labor_progress').insert({
        patient_id: newDelivery.patient_id,
        admission_time: newDelivery.admission_time,
        gestational_age: newDelivery.gestational_age || null,
        presentation: newDelivery.presentation,
        membrane_status: newDelivery.membrane_status,
        cervix_dilation: newDelivery.cervix_dilation || null,
        contraction_freq: newDelivery.contraction_freq || null,
        doctor_id: newDelivery.doctor_id || null,
        notes: newDelivery.notes || null,
        status: 'admission',
        created_at: new Date().toISOString()
      });
      if (error) throw error;
      toast('Pasien persalinan berhasil diterima', 'success');
      showForm = false;
      newDelivery = { patient_id: '', admission_time: '', gestational_age: '', presentation: 'kepala', membrane_status: 'intact', cervix_dilation: '', contraction_freq: '', doctor_id: '', notes: '' };
      await fetchLaborPatients();
    } catch (err) {
      console.error('Submit delivery error:', err);
      toast('Gagal menyimpan pasien persalinan', 'error');
    } finally {
      saving = false;
    }
  }

  async function fetchLaborPatients() {
    try {
      const { data, error } = await supabase
        .from('labor_progress')
        .select(`
          *,
          patients:patient_id ( full_name, no_registration ),
          employees:doctor_id ( full_name )
        `)
        .neq('status', 'completed')
        .order('admission_time', { ascending: false });
      if (error) throw error;
      laborPatients = (data || []).map(p => ({
        ...p,
        patient_name: p.patients?.full_name || '-',
        patient_no: p.patients?.no_registration || '-',
        doctor_name: p.employees?.full_name || '-'
      }));
    } catch (err) {
      console.error('Fetch labor patients error:', err);
    }
  }

  async function fetchDeliveries() {
    try {
      const { data, error } = await supabase
        .from('labor_progress')
        .select(`
          *,
          patients:patient_id ( full_name, no_registration )
        `)
        .in('status', ['postpartum', 'completed'])
        .order('updated_at', { ascending: false })
        .limit(20);
      if (error) throw error;
      deliveries = (data || []).map(d => ({
        ...d,
        patient_name: d.patients?.full_name || '-',
        patient_no: d.patients?.no_registration || '-'
      }));
    } catch (err) {
      console.error('Fetch deliveries error:', err);
    }
  }

  async function fetchPatients() {
    try {
      const { data, error } = await supabase.from('patients').select('patient_id, full_name, no_registration').order('full_name');
      if (error) throw error;
      patients = data || [];
    } catch (err) {
      console.error('Fetch patients error:', err);
    }
  }

  async function fetchDoctors() {
    try {
      const { data, error } = await supabase
        .from('employees')
        .select('employee_id, full_name')
        .eq('role', 'doctor')
        .order('full_name');
      if (error) throw error;
      doctors = data || [];
    } catch (err) {
      console.error('Fetch doctors error:', err);
    }
  }

  async function fetchBeds() {
    try {
      const { data, error } = await supabase.from('beds').select('*, rooms:room_id (room_number, room_classes:class_id (name))').order('bed_number');
      if (error) throw error;
      beds = (data || []).map(b => {
        const room = Array.isArray(b.rooms) ? b.rooms[0] : b.rooms;
        const roomClass = Array.isArray(room?.room_classes) ? room.room_classes[0] : room?.room_classes;
        return {
          ...b,
          bed_no: b.bed_number,
          rooms: room
            ? { ...room, name: room.room_number, class: roomClass?.name || '-' }
            : room
        };
      }).filter(b => b.rooms?.class === 'VK');
    } catch (err) {
      console.error('Fetch VK beds error:', err);
    }
  }

  async function refreshAll() {
    loading = true;
    await Promise.all([fetchLaborPatients(), fetchDeliveries(), fetchPatients(), fetchDoctors(), fetchBeds()]);
    loading = false;
  }

  onMount(async () => {
    await refreshAll();
  });
</script>

<svelte:head>
  <title>VK - Kamar Bersalin</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div class="flex items-center gap-3">
      <div class="w-10 h-10 rounded-lg bg-violet-600 flex items-center justify-center">
        <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
        </svg>
      </div>
      <div>
        <h1 class="text-2xl font-bold text-violet-700">Kamar Bersalin (VK)</h1>
        <p class="text-sm text-gray-500 mt-0.5">Verloskamer &mdash; Manajemen persalinan aktif</p>
      </div>
    </div>
    <button class="btn-secondary btn-sm" onclick={refreshAll}>
      <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182" />
      </svg>
      Refresh
    </button>
  </div>

  <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
    <div class="card p-4 border-violet-200 bg-violet-50">
      <p class="text-xs text-violet-700 uppercase tracking-wide font-medium">Persalinan Aktif</p>
      <p class="text-2xl font-bold text-violet-700 mt-1">{stats.active}</p>
    </div>
    <div class="card p-4 border-emerald-200 bg-emerald-50">
      <p class="text-xs text-emerald-700 uppercase tracking-wide font-medium">Selesai Hari Ini</p>
      <p class="text-2xl font-bold text-emerald-700 mt-1">{stats.delivered}</p>
    </div>
    <div class="card p-4 border-gray-200 bg-gray-50">
      <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Bed VK Total</p>
      <p class="text-2xl font-bold text-gray-900 mt-1">{stats.beds_total}</p>
    </div>
    <div class="card p-4 border-emerald-200 bg-emerald-50">
      <p class="text-xs text-emerald-700 uppercase tracking-wide font-medium">Bed Tersedia</p>
      <p class="text-2xl font-bold text-emerald-700 mt-1">{stats.beds_available}</p>
    </div>
  </div>

  {#if beds.length > 0}
    <div class="card">
      <div class="flex items-center gap-2 mb-4">
        <svg class="w-5 h-5 text-violet-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25a2.25 2.25 0 0 1-2.25-2.25v-2.25Z" />
        </svg>
        <h2 class="text-lg font-semibold text-gray-900">Status Bed Kamar Bersalin</h2>
      </div>
      <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-3">
        {#each beds as bed}
          <div class="rounded-xl border-2 p-3 text-center transition-all
            {bed.status === 'occupied' ? 'border-violet-300 bg-violet-50' : 'border-emerald-300 bg-emerald-50'}">
            <p class="font-bold text-sm {bed.status === 'occupied' ? 'text-violet-700' : 'text-emerald-700'}">{bed.bed_no}</p>
            <p class="text-[10px] {bed.status === 'occupied' ? 'text-violet-500' : 'text-emerald-500'} mt-0.5">
              {bed.status === 'occupied' ? 'Terisi' : 'Kosong'}
            </p>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  <div class="flex items-center gap-2 border-b border-gray-200">
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {activeTab === 'aktif' ? 'border-violet-600 text-violet-700 bg-violet-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'aktif'}
    >
      Persalinan Aktif
    </button>
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {activeTab === 'riwayat' ? 'border-violet-600 text-violet-700 bg-violet-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'riwayat'}
    >
      Riwayat Persalinan
    </button>
  </div>

  {#if activeTab === 'aktif'}
    <div class="flex items-center justify-between mb-4">
      <p class="text-sm text-gray-500">{laborPatients.length} pasien sedang dalam proses persalinan</p>
      <button class="btn-primary btn-sm" onclick={() => showForm = !showForm}>
        <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        Pasien Baru
      </button>
    </div>

    {#if showForm}
      <div class="card border-violet-200">
        <h3 class="font-semibold text-gray-900 mb-4">Penerimaan Pasien Persalinan</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="label">Pasien *</label>
            <select class="select-field" bind:value={newDelivery.patient_id}>
              <option value="">Pilih Pasien</option>
              {#each patients as p}
                <option value={p.patient_id}>{p.full_name} ({p.no_registration})</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Jam Masuk *</label>
            <input type="datetime-local" class="input-field" bind:value={newDelivery.admission_time} />
          </div>
          <div>
            <label class="label">Usia Kehamilan (minggu)</label>
            <input type="number" class="input-field" placeholder="contoh: 39" bind:value={newDelivery.gestational_age} min="20" max="45" />
          </div>
          <div>
            <label class="label">Presentasi</label>
            <select class="select-field" bind:value={newDelivery.presentation}>
              {#each presentationTypes as pt}
                <option value={pt}>{pt.charAt(0).toUpperCase() + pt.slice(1)}</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Status Selaput Ketuban</label>
            <select class="select-field" bind:value={newDelivery.membrane_status}>
              <option value="intact">Utuh</option>
              <option value="ruptured">Pecah</option>
              <option value="artificial">Buatan</option>
            </select>
          </div>
          <div>
            <label class="label">Pembukaan Serviks (cm)</label>
            <input type="number" class="input-field" placeholder="0-10" bind:value={newDelivery.cervix_dilation} min="0" max="10" step="0.5" />
          </div>
          <div>
            <label class="label">Frekuensi Kontraksi</label>
            <input type="text" class="input-field" placeholder="contoh: setiap 3 menit" bind:value={newDelivery.contraction_freq} />
          </div>
          <div>
            <label class="label">Dokter</label>
            <select class="select-field" bind:value={newDelivery.doctor_id}>
              <option value="">Pilih Dokter</option>
              {#each doctors as d}
                <option value={d.employee_id}>{d.full_name}</option>
              {/each}
            </select>
          </div>
          <div class="md:col-span-2">
            <label class="label">Catatan</label>
            <textarea class="input-field" rows="2" placeholder="Catatan persalinan..." bind:value={newDelivery.notes}></textarea>
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-5">
          <button class="btn-secondary btn-sm" onclick={() => showForm = false}>Batal</button>
          <button class="btn-primary btn-sm" onclick={submitDelivery} disabled={saving}>
            {saving ? 'Menyimpan...' : 'Simpan'}
          </button>
        </div>
      </div>
    {/if}

    {#if loading}
      <div class="flex items-center justify-center py-16">
        <div class="w-10 h-10 border-4 border-violet-200 border-t-violet-600 rounded-full animate-spin"></div>
      </div>
    {:else if laborPatients.length === 0}
      <div class="card text-center py-16">
        <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
        </svg>
        <p class="text-lg font-medium text-gray-500">Tidak ada pasien persalinan aktif</p>
        <p class="text-sm text-gray-400 mt-1">Semua kamar bersalin dalam kondisi siap</p>
      </div>
    {:else}
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        {#each laborPatients as labor}
          {@const laborStatus = getLaborStatus(labor.status)}
          {@const duration = getLaborDuration(labor.admission_time)}
          <div class="card p-5 border-l-4
            {labor.status === 'pushing' || labor.status === 'delivery' ? 'border-l-red-500' : labor.status === 'active' ? 'border-l-amber-500' : 'border-l-violet-500'}">
            <div class="flex items-start justify-between mb-3">
              <div class="flex items-center gap-2">
                <div class="w-10 h-10 rounded-full bg-violet-100 flex items-center justify-center">
                  <svg class="w-5 h-5 text-violet-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
                  </svg>
                </div>
                <div>
                  <p class="font-semibold text-gray-900">{labor.patient_name}</p>
                  <p class="text-xs text-gray-400 font-mono">{labor.patient_no}</p>
                </div>
              </div>
              <span class="badge {laborStatus.class}">{laborStatus.label}</span>
            </div>

            <div class="grid grid-cols-3 gap-2 mb-3">
              <div class="bg-gray-50 rounded-lg p-2 text-center">
                <p class="text-[10px] text-gray-500 uppercase">Pembukaan</p>
                <p class="text-lg font-bold {getDilationColor(labor.cervix_dilation)}">{labor.cervix_dilation ?? '-'}cm</p>
              </div>
              <div class="bg-gray-50 rounded-lg p-2 text-center">
                <p class="text-[10px] text-gray-500 uppercase">Presentasi</p>
                <p class="text-xs font-medium text-gray-700 mt-1 capitalize">{labor.presentation || '-'}</p>
              </div>
              <div class="bg-gray-50 rounded-lg p-2 text-center">
                <p class="text-[10px] text-gray-500 uppercase">Lama</p>
                <p class="text-sm font-bold text-violet-700">{duration}</p>
              </div>
            </div>

            <div class="space-y-1.5 text-xs text-gray-600 mb-3">
              <div class="flex items-center gap-2">
                <svg class="w-3.5 h-3.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
                </svg>
                <span>Dokter: {labor.doctor_name}</span>
              </div>
              <div class="flex items-center gap-2">
                <svg class="w-3.5 h-3.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5" />
                </svg>
                <span>Ketuban: {labor.membrane_status === 'intact' ? 'Utuh' : labor.membrane_status === 'ruptured' ? 'Pecah' : 'Buatan'}</span>
              </div>
              {#if labor.contraction_freq}
                <div class="flex items-center gap-2">
                  <svg class="w-3.5 h-3.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
                  </svg>
                  <span>Kontraksi: {labor.contraction_freq}</span>
                </div>
              {/if}
            </div>

            <div class="flex gap-2">
              {#if labor.status !== 'postpartum'}
                <button class="btn-primary btn-sm text-xs flex-1" onclick={() => advanceLaborStatus(labor.patient_id, labor.status)}>
                  Lanjutkan ke Fase Berikutnya
                </button>
              {:else}
                <a href="/rawat-inap/{labor.visit_id || ''}" class="btn-primary btn-sm text-xs flex-1 text-center">Lihat Detail</a>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    {/if}

  {:else if activeTab === 'riwayat'}
    <div class="card">
      <div class="overflow-x-auto">
        {#if loading}
          <div class="flex items-center justify-center py-16">
            <div class="w-10 h-10 border-4 border-violet-200 border-t-violet-600 rounded-full animate-spin"></div>
          </div>
        {:else if deliveries.length === 0}
          <div class="text-center py-16 text-gray-400">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
            </svg>
            <p class="text-lg font-medium">Belum ada riwayat persalinan</p>
          </div>
        {:else}
          <table class="w-full">
            <thead>
              <tr class="table-header">
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Pasien</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Jam Masuk</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">GA</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Presentasi</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each deliveries as d, i}
                {@const dStatus = getLaborStatus(d.status)}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                  <td class="table-cell">
                    <p class="font-medium text-gray-900">{d.patient_name}</p>
                    <p class="text-xs text-gray-400 font-mono">{d.patient_no}</p>
                  </td>
                  <td class="table-cell text-gray-500 hidden md:table-cell font-mono text-xs">{formatDateTime(d.admission_time)}</td>
                  <td class="table-cell text-gray-600 hidden sm:table-cell">{d.gestational_age ?? '-'} mgg</td>
                  <td class="table-cell text-gray-600 hidden lg:table-cell capitalize">{d.presentation || '-'}</td>
                  <td class="table-cell">
                    <span class="badge {dStatus.class}">{dStatus.label}</span>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>
    </div>
  {/if}
</div>
