<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime } from '$lib/utils/helpers.js';

  let loading = $state(true);
  let activeTab = $state('jadwal');

  let okClinicId = $state('POL-OK');
  let visits = $state([]);
  let requests = $state([]);
  let doctors = $state([]);

  let showForm = $state(false);
  let saving = $state(false);

  let newRequest = $state({
    visit_id: '',
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
    total: visits.length,
    menunggu: visits.filter(v => v.status_keluar === '0' && v.status_periksa === '0').length,
    diperiksa: visits.filter(v => v.status_keluar === '0' && v.status_periksa === '1').length,
    selesai: visits.filter(v => v.status_keluar === '1').length,
    pengajuan: requests.filter(r => r.status === 'pending').length
  });

  const todayVisits = $derived(
    [...visits].sort((a, b) => new Date(a.visit_date) - new Date(b.visit_date))
  );

  const pendingRequests = $derived(requests.filter(r => r.status === 'pending'));

  const completedRequests = $derived(requests.filter(r => r.status === 'completed').sort((a, b) => new Date(b.updated_at || b.created_at) - new Date(a.updated_at || a.created_at)));

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

  function getVisitStatus(v) {
    if (v.status_keluar === '1') return { label: 'Selesai', class: 'badge-info' };
    if (v.status_periksa === '1') return { label: 'Diperiksa', class: 'badge-success' };
    return { label: 'Menunggu', class: 'badge-warning' };
  }

  function onSelectPatient() {
    const v = visits.find(x => x.patient_id === newRequest.patient_id);
    newRequest.visit_id = v?.visit_id || '';
  }

  function startRequestForVisit(v) {
    newRequest = { ...newRequest, visit_id: v.visit_id, patient_id: v.patient_id };
    activeTab = 'pengajuan';
    showForm = true;
  }

  async function submitRequest() {
    if (!newRequest.visit_id || !newRequest.procedure_name || !newRequest.requested_date) return;
    saving = true;
    try {
      const { error } = await supabase.from('surgery_requests').insert({
        visit_id: newRequest.visit_id,
        procedure_name: newRequest.procedure_name,
        description: newRequest.description || null,
        requested_date: newRequest.requested_date || null,
        priority: newRequest.priority,
        surgeon_id: newRequest.surgeon_id || null,
        assistant_surgeon_id: newRequest.assistant || null,
        anesthesia_type: newRequest.anesthesia_type,
        status: 'pending'
      });
      if (error) throw error;
      showForm = false;
      newRequest = { visit_id: '', patient_id: '', procedure_name: '', description: '', priority: 'normal', requested_date: '', surgeon_id: '', assistant: '', anesthesia_type: 'umum' };
      await fetchRequests();
      await fetchVisits();
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
        .eq('id', requestId);
      if (error) throw error;
      await fetchRequests();
    } catch (err) {
      console.error('Approve request error:', err);
    }
  }

  async function fetchOkClinic() {
    try {
      const { data, error } = await supabase.from('clinics').select('clinic_id, name').order('name');
      if (error) throw error;
      const match = (data || []).find(c => c.clinic_id === 'POL-OK' || /operasi/i.test(c.name));
      if (match) okClinicId = match.clinic_id;
    } catch (err) {
      console.error('Fetch OK clinic error:', err);
    }
  }

  async function fetchVisits() {
    try {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayEnd = new Date();
      todayEnd.setHours(23, 59, 59, 999);

      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          visit_id,
          visit_date,
          ticket_no,
          status_periksa,
          status_keluar,
          description,
          patient_id,
          doctor_id,
          patients:patient_id ( full_name, no_registration ),
          employees:doctor_id ( full_name )
        `)
        .eq('clinic_id', okClinicId)
        .gte('visit_date', todayStart.toISOString())
        .lte('visit_date', todayEnd.toISOString())
        .order('visit_date', { ascending: true });

      if (error) throw error;
      visits = (data || []).map(v => {
        const patient = Array.isArray(v.patients) ? v.patients[0] : v.patients;
        const employee = Array.isArray(v.employees) ? v.employees[0] : v.employees;
        return {
          ...v,
          patient_name: patient?.full_name || '-',
          patient_no: patient?.no_registration || '-',
          doctor_name: employee?.full_name || '-'
        };
      });
    } catch (err) {
      console.error('Fetch visitasi poli operasi error:', err);
    }
  }

  async function fetchRequests() {
    try {
      const { data, error } = await supabase
        .from('surgery_requests')
        .select(`
          *,
          employees:surgeon_id ( full_name ),
          visitations:visit_id ( patients:patient_id ( full_name, no_registration ) )
        `)
        .order('created_at', { ascending: false });
      if (error) throw error;
      requests = (data || []).map(r => {
        const visitations = Array.isArray(r.visitations) ? r.visitations[0] : r.visitations;
        const patient = Array.isArray(visitations?.patients) ? visitations.patients[0] : visitations?.patients;
        const surgeon = Array.isArray(r.employees) ? r.employees[0] : r.employees;
        return {
          ...r,
          patient_name: patient?.full_name || '-',
          patient_no: patient?.no_registration || '-',
          surgeon_name: surgeon?.full_name || '-'
        };
      });
    } catch (err) {
      console.error('Fetch requests error:', err);
    }
  }

  async function fetchDoctors() {
    try {
      const { data, error } = await supabase
        .from('employees')
        .select('employee_id, full_name, specialization')
        .eq('is_active', true)
        .order('full_name');
      if (error) throw error;
      doctors = data || [];
    } catch (err) {
      console.error('Fetch doctors error:', err);
    }
  }

  async function refreshAll() {
    loading = true;
    await fetchOkClinic();
    await Promise.all([fetchVisits(), fetchRequests(), fetchDoctors()]);
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
      <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Total Pasien</p>
      <p class="text-2xl font-bold text-gray-900 mt-1">{stats.total}</p>
    </div>
    <div class="card p-4 border-blue-200 bg-blue-50">
      <p class="text-xs text-blue-700 uppercase tracking-wide font-medium">Menunggu</p>
      <p class="text-2xl font-bold text-blue-700 mt-1">{stats.menunggu}</p>
    </div>
    <div class="card p-4 border-amber-200 bg-amber-50">
      <p class="text-xs text-amber-700 uppercase tracking-wide font-medium">Diperiksa</p>
      <p class="text-2xl font-bold text-amber-700 mt-1">{stats.diperiksa}</p>
    </div>
    <div class="card p-4 border-emerald-200 bg-emerald-50">
      <p class="text-xs text-emerald-700 uppercase tracking-wide font-medium">Selesai</p>
      <p class="text-2xl font-bold text-emerald-700 mt-1">{stats.selesai}</p>
    </div>
    <div class="card p-4 border-red-200 bg-red-50">
      <p class="text-xs text-red-700 uppercase tracking-wide font-medium">Pengajuan</p>
      <p class="text-2xl font-bold text-red-700 mt-1">{stats.pengajuan}</p>
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
    {:else if todayVisits.length === 0}
      <div class="card text-center py-16">
        <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        <p class="text-lg font-medium text-gray-500">Tidak ada pasien terdaftar di Poli Operasi hari ini</p>
        <p class="text-sm text-gray-400 mt-1">Pasien yang didaftarkan lewat registrasi dengan poli Kamar Operasi akan muncul di sini</p>
      </div>
    {:else}
      <div class="space-y-4">
        {#each todayVisits as visit}
          {@const visitStatus = getVisitStatus(visit)}
          <div class="card p-4">
            <div class="flex flex-col lg:flex-row lg:items-center gap-4">
              <div class="flex items-center gap-3 lg:w-48 shrink-0">
                <div class="text-center">
                  <p class="text-2xl font-bold text-indigo-700">{getScheduleTime(visit.visit_date)}</p>
                  <p class="text-xs text-gray-500">Antrian {visit.ticket_no || '-'}</p>
                </div>
                <div class="w-px h-12 bg-gray-200 hidden lg:block"></div>
              </div>

              <div class="flex-1 min-w-0">
                <div class="flex items-start justify-between gap-2 mb-2">
                  <div>
                    <h3 class="font-semibold text-gray-900">{visit.patient_name}</h3>
                    <p class="text-sm text-gray-500">{visit.patient_no}</p>
                  </div>
                  <span class="badge {visitStatus.class} shrink-0">{visitStatus.label}</span>
                </div>
                <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-500">
                  <span class="flex items-center gap-1">
                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
                    </svg>
                    {visit.doctor_name || '-'}
                  </span>
                  <span class="flex items-center gap-1">
                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21M3 3h12m-.75 4.5H21m-3.75 3h.008v.008h-.008v-.008Zm0 3h.008v.008h-.008v-.008Zm0 3h.008v.008h-.008v-.008Z" />
                    </svg>
                    Poli Operasi
                  </span>
                </div>
                {#if visit.description}
                  <p class="text-xs text-gray-400 mt-2 italic">{visit.description}</p>
                {/if}
              </div>

              <div class="flex gap-2 shrink-0">
                <button class="btn-primary btn-sm text-xs" onclick={() => startRequestForVisit(visit)}>
                  <svg class="w-3.5 h-3.5 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                  </svg>
                  Ajukan Operasi
                </button>
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
            <select class="select-field" bind:value={newRequest.patient_id} onchange={onSelectPatient}>
              <option value="">Pilih Pasien</option>
              {#each visits as v}
                <option value={v.patient_id}>{v.patient_name} ({v.patient_no})</option>
              {/each}
            </select>
            {#if newRequest.patient_id && !newRequest.visit_id}
              <p class="text-xs text-red-500 mt-1">Pasien tidak ditemukan dalam daftar registrasi hari ini</p>
            {/if}
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
                <option value={d.employee_id}>{d.full_name} ({d.specialization || '-'})</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Asisten</label>
            <select class="select-field" bind:value={newRequest.assistant}>
              <option value="">Pilih Asisten</option>
              {#each doctors as d}
                <option value={d.employee_id}>{d.full_name} ({d.specialization || '-'})</option>
              {/each}
            </select>
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
                      <button class="btn-success btn-sm text-xs" onclick={() => approveRequest(req.id)}>Setuju</button>
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
        {:else if completedRequests.length === 0}
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
              {#each completedRequests as r, i}
                {@const statusBadge = getStatusBadge(r.status)}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                  <td class="table-cell">
                    <p class="font-medium text-gray-900">{r.patient_name}</p>
                    <p class="text-xs text-gray-400 font-mono">{r.patient_no}</p>
                  </td>
                  <td class="table-cell text-gray-600">{r.procedure_name}</td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{r.surgeon_name}</td>
                  <td class="table-cell text-gray-500 hidden sm:table-cell font-mono text-xs">{formatDateTime(r.updated_at || r.created_at)}</td>
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
