<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime, generateId } from '$lib/utils/helpers.js';

  let loading = $state(true);
  let activeTab = $state('jadwal');

  let surgeries = $state([]);
  let requests = $state([]);
  let patients = $state([]);
  let doctors = $state([]);
  let rooms = $state([]);

  let showForm = $state(false);
  let saving = $state(false);

  let newRequest = $state({
    patient_id: '',
    procedure_name: '',
    description: '',
    priority: 'normal',
    requested_date: '',
    surgeon_id: '',
    assistant: '',
    anesthesia_type: 'umum'
  });

  const anesthesiaTypes = ['umum', 'regional', 'spinal', 'epidural', 'lokal', 'sedasi'];

  const stats = $derived({
    total: surgeries.length,
    scheduled: surgeries.filter(s => s.status === 'scheduled').length,
    inProgress: surgeries.filter(s => s.status === 'in_progress').length,
    completed: surgeries.filter(s => s.status === 'completed').length,
    cancelled: surgeries.filter(s => s.status === 'cancelled').length
  });

  const todaySurgeries = $derived.by(() => {
    const today = new Date().toDateString();
    return surgeries.filter(s => {
      const schedDate = new Date(s.scheduled_time);
      return schedDate.toDateString() === today;
    }).sort((a, b) => new Date(a.scheduled_time) - new Date(b.scheduled_time));
  });

  const pendingRequests = $derived(requests.filter(r => r.status === 'pending'));

  const completedSurgeries = $derived(surgeries.filter(s => s.status === 'completed').sort((a, b) => new Date(b.completed_at || b.scheduled_time) - new Date(a.completed_at || a.scheduled_time)));

  function getStatusBadge(status) {
    switch (status) {
      case 'scheduled': return { label: 'Terjadwal', class: 'badge-info' };
      case 'in_progress': return { label: 'Sedang Berlangsung', class: 'badge-warning' };
      case 'completed': return { label: 'Selesai', class: 'badge-success' };
      case 'cancelled': return { label: 'Dibatalkan', class: 'badge-danger' };
      case 'pending': return { label: 'Menunggu', class: 'badge-warning' };
      case 'approved': return { label: 'Disetujui', class: 'badge-success' };
      case 'rejected': return { label: 'Ditolak', class: 'badge-danger' };
      default: return { label: status, class: 'badge-gray' };
    }
  }

  function getPriorityBadge(priority) {
    switch (priority) {
      case 'urgent': return { label: 'Urgent', class: 'bg-red-100 text-red-800' };
      case 'elective': return { label: 'Elektif', class: 'bg-blue-100 text-blue-800' };
      default: return { label: 'Normal', class: 'bg-gray-100 text-gray-800' };
    }
  }

  function getScheduleTime(timeStr) {
    if (!timeStr) return '-';
    return new Date(timeStr).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
  }

  async function startSurgery(surgeryId) {
    try {
      const { error } = await supabase
        .from('surgeries')
        .update({ status: 'in_progress', started_at: new Date().toISOString() })
        .eq('surgery_id', surgeryId);
      if (error) throw error;
      await fetchSurgeries();
    } catch (err) {
      console.error('Start surgery error:', err);
    }
  }

  async function completeSurgery(surgeryId) {
    try {
      const { error } = await supabase
        .from('surgeries')
        .update({ status: 'completed', completed_at: new Date().toISOString() })
        .eq('surgery_id', surgeryId);
      if (error) throw error;
      await fetchSurgeries();
    } catch (err) {
      console.error('Complete surgery error:', err);
    }
  }

  async function submitRequest() {
    if (!newRequest.patient_id || !newRequest.procedure_name || !newRequest.requested_date) return;
    saving = true;
    try {
      const { error } = await supabase.from('surgery_requests').insert({
        ...newRequest,
        request_id: generateId('SR'),
        status: 'pending',
        created_at: new Date().toISOString()
      });
      if (error) throw error;
      showForm = false;
      newRequest = { patient_id: '', procedure_name: '', description: '', priority: 'normal', requested_date: '', surgeon_id: '', assistant: '', anesthesia_type: 'umum' };
      await fetchRequests();
    } catch (err) {
      console.error('Submit request error:', err);
    } finally {
      saving = false;
    }
  }

  async function approveRequest(requestId) {
    try {
      const { error } = await supabase
        .from('surgery_requests')
        .update({ status: 'approved' })
        .eq('request_id', requestId);
      if (error) throw error;
      await fetchRequests();
    } catch (err) {
      console.error('Approve request error:', err);
    }
  }

  async function fetchSurgeries() {
    try {
      const { data, error } = await supabase
        .from('surgeries')
        .select(`
          *,
          patients:patient_id ( full_name, no_registration ),
          doctors:surgeon_id ( full_name )
        `)
        .order('scheduled_time', { ascending: false })
        .limit(100);
      if (error) throw error;
      surgeries = (data || []).map(s => ({
        ...s,
        patient_name: s.patients?.full_name || '-',
        patient_no: s.patients?.no_registration || '-',
        surgeon_name: s.doctors?.full_name || '-'
      }));
    } catch (err) {
      console.error('Fetch surgeries error:', err);
    }
  }

  async function fetchRequests() {
    try {
      const { data, error } = await supabase
        .from('surgery_requests')
        .select(`
          *,
          patients:patient_id ( full_name, no_registration ),
          doctors:surgeon_id ( full_name )
        `)
        .order('created_at', { ascending: false });
      if (error) throw error;
      requests = (data || []).map(r => ({
        ...r,
        patient_name: r.patients?.full_name || '-',
        patient_no: r.patients?.no_registration || '-',
        surgeon_name: r.doctors?.full_name || '-'
      }));
    } catch (err) {
      console.error('Fetch requests error:', err);
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
      const { data, error } = await supabase.from('doctors').select('doctor_id, full_name, specialization').order('full_name');
      if (error) throw error;
      doctors = data || [];
    } catch (err) {
      console.error('Fetch doctors error:', err);
    }
  }

  async function refreshAll() {
    loading = true;
    await Promise.all([fetchSurgeries(), fetchRequests(), fetchPatients(), fetchDoctors()]);
    loading = false;
  }

  onMount(async () => {
    await refreshAll();
  });
</script>

<svelte:head>
  <title>Kamar Operasi - SIMRS</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div class="flex items-center gap-3">
      <div class="w-10 h-10 rounded-lg bg-indigo-600 flex items-center justify-center">
        <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
      </div>
      <div>
        <h1 class="text-2xl font-bold text-indigo-700">Kamar Operasi</h1>
        <p class="text-sm text-gray-500 mt-0.5">Manajemen jadwal dan pelaksanaan operasi</p>
      </div>
    </div>
    <div class="flex items-center gap-3">
      <button class="btn-secondary btn-sm" onclick={refreshAll}>
        <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182" />
        </svg>
        Refresh
      </button>
    </div>
  </div>

  <div class="grid grid-cols-2 lg:grid-cols-5 gap-3">
    <div class="card p-4">
      <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Total</p>
      <p class="text-2xl font-bold text-gray-900 mt-1">{stats.total}</p>
    </div>
    <div class="card p-4 border-blue-200 bg-blue-50">
      <p class="text-xs text-blue-700 uppercase tracking-wide font-medium">Terjadwal</p>
      <p class="text-2xl font-bold text-blue-700 mt-1">{stats.scheduled}</p>
    </div>
    <div class="card p-4 border-amber-200 bg-amber-50">
      <p class="text-xs text-amber-700 uppercase tracking-wide font-medium">Berlangsung</p>
      <p class="text-2xl font-bold text-amber-700 mt-1">{stats.inProgress}</p>
    </div>
    <div class="card p-4 border-emerald-200 bg-emerald-50">
      <p class="text-xs text-emerald-700 uppercase tracking-wide font-medium">Selesai</p>
      <p class="text-2xl font-bold text-emerald-700 mt-1">{stats.completed}</p>
    </div>
    <div class="card p-4 border-red-200 bg-red-50">
      <p class="text-xs text-red-700 uppercase tracking-wide font-medium">Dibatalkan</p>
      <p class="text-2xl font-bold text-red-700 mt-1">{stats.cancelled}</p>
    </div>
  </div>

  <div class="flex items-center gap-2 border-b border-gray-200">
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {activeTab === 'jadwal' ? 'border-indigo-600 text-indigo-700 bg-indigo-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'jadwal'}
    >
      Jadwal Operasi
    </button>
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {activeTab === 'pengajuan' ? 'border-indigo-600 text-indigo-700 bg-indigo-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'pengajuan'}
    >
      Pengajuan Operasi
      {#if pendingRequests.length > 0}
        <span class="ml-1.5 bg-amber-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">{pendingRequests.length}</span>
      {/if}
    </button>
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {activeTab === 'riwayat' ? 'border-indigo-600 text-indigo-700 bg-indigo-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'riwayat'}
    >
      Riwayat
    </button>
  </div>

  {#if activeTab === 'jadwal'}
    {#if loading}
      <div class="flex items-center justify-center py-16">
        <div class="w-10 h-10 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"></div>
      </div>
    {:else if todaySurgeries.length === 0}
      <div class="card text-center py-16">
        <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        <p class="text-lg font-medium text-gray-500">Tidak ada jadwal operasi hari ini</p>
      </div>
    {:else}
      <div class="space-y-4">
        {#each todaySurgeries as surgery}
          {@const statusBadge = getStatusBadge(surgery.status)}
          <div class="card p-4">
            <div class="flex flex-col lg:flex-row lg:items-center gap-4">
              <div class="flex items-center gap-3 lg:w-48 shrink-0">
                <div class="text-center">
                  <p class="text-2xl font-bold text-indigo-700">{getScheduleTime(surgery.scheduled_time)}</p>
                  <p class="text-xs text-gray-500">{surgery.room_name || 'OK-'}</p>
                </div>
                <div class="w-px h-12 bg-gray-200 hidden lg:block"></div>
              </div>

              <div class="flex-1 min-w-0">
                <div class="flex items-start justify-between gap-2 mb-2">
                  <div>
                    <h3 class="font-semibold text-gray-900">{surgery.procedure_name}</h3>
                    <p class="text-sm text-gray-500">{surgery.patient_name} &middot; {surgery.patient_no}</p>
                  </div>
                  <span class="badge {statusBadge.class} shrink-0">{statusBadge.label}</span>
                </div>
                <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-500">
                  <span class="flex items-center gap-1">
                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
                    </svg>
                    {surgery.surgeon_name}
                  </span>
                  {#if s.room_name}
                    <span class="flex items-center gap-1">
                      <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21M3 3h12m-.75 4.5H21m-3.75 3h.008v.008h-.008v-.008Zm0 3h.008v.008h-.008v-.008Zm0 3h.008v.008h-.008v-.008Z" />
                      </svg>
                      {surgery.room_name || '-'}
                    </span>
                  {/if}
                  <span class="flex items-center gap-1">
                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5m14.8.8 1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0 1 12 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5" />
                    </svg>
                    Anestesi: {surgery.anesthesia_type || '-'}
                  </span>
                </div>
                {#if surgery.description}
                  <p class="text-xs text-gray-400 mt-2 italic">{surgery.description}</p>
                {/if}
              </div>

              <div class="flex gap-2 shrink-0">
                {#if surgery.status === 'scheduled'}
                  <button class="btn-success btn-sm text-xs" onclick={() => startSurgery(surgery.surgery_id)}>
                    <svg class="w-3.5 h-3.5 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 0 1 0 1.972l-11.54 6.347a1.125 1.125 0 0 1-1.667-.986V5.653Z" />
                    </svg>
                    Mulai Operasi
                  </button>
                {:else if surgery.status === 'in_progress'}
                  <button class="btn-primary btn-sm text-xs" onclick={() => completeSurgery(surgery.surgery_id)}>
                    <svg class="w-3.5 h-3.5 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                    </svg>
                    Selesai
                  </button>
                {/if}
              </div>
            </div>
          </div>
        {/each}
      </div>
    {/if}

  {:else if activeTab === 'pengajuan'}
    <div class="flex items-center justify-between mb-4">
      <p class="text-sm text-gray-500">{pendingRequests.length} pengajuan menunggu</p>
      <button class="btn-primary btn-sm" onclick={() => showForm = !showForm}>
        <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        Ajukan Operasi
      </button>
    </div>

    {#if showForm}
      <div class="card border-indigo-200">
        <h3 class="font-semibold text-gray-900 mb-4">Form Pengajuan Operasi</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="label">Pasien *</label>
            <select class="select-field" bind:value={newRequest.patient_id}>
              <option value="">Pilih Pasien</option>
              {#each patients as p}
                <option value={p.patient_id}>{p.full_name} ({p.no_registration})</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Prosedur *</label>
            <input type="text" class="input-field" placeholder="Nama prosedur operasi" bind:value={newRequest.procedure_name} />
          </div>
          <div class="md:col-span-2">
            <label class="label">Deskripsi</label>
            <textarea class="input-field" rows="2" placeholder="Deskripsi singkat..." bind:value={newRequest.description}></textarea>
          </div>
          <div>
            <label class="label">Prioritas</label>
            <select class="select-field" bind:value={newRequest.priority}>
              <option value="normal">Normal</option>
              <option value="elective">Elektif</option>
              <option value="urgent">Urgent</option>
            </select>
          </div>
          <div>
            <label class="label">Tanggal *</label>
            <input type="date" class="input-field" bind:value={newRequest.requested_date} />
          </div>
          <div>
            <label class="label">Dokter Bedah</label>
            <select class="select-field" bind:value={newRequest.surgeon_id}>
              <option value="">Pilih Dokter</option>
              {#each doctors as d}
                <option value={d.doctor_id}>{d.full_name} ({d.specialization || '-'})</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Asisten</label>
            <input type="text" class="input-field" placeholder="Nama asisten" bind:value={newRequest.assistant} />
          </div>
          <div>
            <label class="label">Jenis Anestesi</label>
            <select class="select-field" bind:value={newRequest.anesthesia_type}>
              {#each anesthesiaTypes as at}
                <option value={at}>{at.charAt(0).toUpperCase() + at.slice(1)}</option>
              {/each}
            </select>
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-5">
          <button class="btn-secondary btn-sm" onclick={() => showForm = false}>Batal</button>
          <button class="btn-primary btn-sm" onclick={submitRequest} disabled={saving}>
            {saving ? 'Menyimpan...' : 'Ajukan'}
          </button>
        </div>
      </div>
    {/if}

    <div class="card">
      <div class="overflow-x-auto">
        {#if loading}
          <div class="flex items-center justify-center py-16">
            <div class="w-10 h-10 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"></div>
          </div>
        {:else if requests.length === 0}
          <div class="text-center py-16 text-gray-400">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
            </svg>
            <p class="text-lg font-medium">Belum ada pengajuan operasi</p>
          </div>
        {:else}
          <table class="w-full">
            <thead>
              <tr class="table-header">
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Pasien</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Prosedur</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Prioritas</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Tgl Minta</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each requests as req, i}
                {@const priorityBadge = getPriorityBadge(req.priority)}
                {@const statusBadge = getStatusBadge(req.status)}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                  <td class="table-cell">
                    <p class="font-medium text-gray-900">{req.patient_name}</p>
                    <p class="text-xs text-gray-400 font-mono">{req.patient_no}</p>
                  </td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{req.procedure_name}</td>
                  <td class="table-cell hidden lg:table-cell">
                    <span class="badge {priorityBadge.class}">{priorityBadge.label}</span>
                  </td>
                  <td class="table-cell text-gray-500 hidden sm:table-cell font-mono text-xs">{formatDate(req.requested_date || req.created_at)}</td>
                  <td class="table-cell">
                    <span class="badge {statusBadge.class}">{statusBadge.label}</span>
                  </td>
                  <td class="table-cell text-right">
                    {#if req.status === 'pending'}
                      <button class="btn-success btn-sm text-xs" onclick={() => approveRequest(req.request_id)}>Setuju</button>
                    {/if}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>
    </div>

  {:else if activeTab === 'riwayat'}
    <div class="card">
      <div class="overflow-x-auto">
        {#if loading}
          <div class="flex items-center justify-center py-16">
            <div class="w-10 h-10 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"></div>
          </div>
        {:else if completedSurgeries.length === 0}
          <div class="text-center py-16 text-gray-400">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
            </svg>
            <p class="text-lg font-medium">Belum ada riwayat operasi</p>
          </div>
        {:else}
          <table class="w-full">
            <thead>
              <tr class="table-header">
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Pasien</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Prosedur</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Dokter Bedah</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Tanggal</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each completedSurgeries as s, i}
                {@const statusBadge = getStatusBadge(s.status)}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                  <td class="table-cell">
                    <p class="font-medium text-gray-900">{s.patient_name}</p>
                    <p class="text-xs text-gray-400 font-mono">{s.patient_no}</p>
                  </td>
                  <td class="table-cell text-gray-600">{s.procedure_name}</td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{s.surgeon_name}</td>
                  <td class="table-cell text-gray-500 hidden sm:table-cell font-mono text-xs">{formatDateTime(s.completed_at || s.scheduled_time)}</td>
                  <td class="table-cell">
                    <span class="badge {statusBadge.class}">{statusBadge.label}</span>
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
