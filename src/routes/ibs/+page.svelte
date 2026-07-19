<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime, generateId } from '$lib/utils/helpers.js';

  let loading = $state(true);
  let activeTab = $state('jadwal');

  let surgeries = $state([]);
  let patients = $state([]);
  let doctors = $state([]);
  let rooms = $state([]);

  let showForm = $state(false);
  let saving = $state(false);

  let newSurgery = $state({
    patient_id: '',
    procedure_name: '',
    description: '',
    priority: 'normal',
    scheduled_time: '',
    surgeon_id: '',
    anesthesia_type: 'lokal',
    room_id: ''
  });

  const stats = $derived({
    total: surgeries.length,
    scheduled: surgeries.filter(s => s.status === 'scheduled').length,
    inProgress: surgeries.filter(s => s.status === 'in_progress').length,
    recovery: surgeries.filter(s => s.status === 'recovery').length,
    discharged: surgeries.filter(s => s.status === 'completed').length
  });

  const todaySchedule = $derived.by(() => {
    const today = new Date().toDateString();
    return surgeries.filter(s => {
      const d = new Date(s.scheduled_time);
      return d.toDateString() === today;
    }).sort((a, b) => new Date(a.scheduled_time) - new Date(b.scheduled_time));
  });

  const completedToday = $derived(surgeries.filter(s => s.status === 'completed' && new Date(s.completed_at || s.scheduled_time).toDateString() === new Date().toDateString()));

  function getStatusBadge(status) {
    switch (status) {
      case 'scheduled': return { label: 'Terjadwal', class: 'badge-info', color: 'border-blue-300 bg-blue-50' };
      case 'in_progress': return { label: 'Operasi', class: 'badge-warning', color: 'border-amber-300 bg-amber-50' };
      case 'recovery': return { label: 'Recovery', class: 'badge-warning', color: 'border-purple-300 bg-purple-50' };
      case 'completed': return { label: 'Selesai', class: 'badge-success', color: 'border-emerald-300 bg-emerald-50' };
      case 'cancelled': return { label: 'Dibatalkan', class: 'badge-danger', color: 'border-red-300 bg-red-50' };
      default: return { label: status, class: 'badge-gray', color: 'border-gray-300 bg-gray-50' };
    }
  }

  function getFlowStep(status) {
    const steps = ['admission', 'scheduled', 'in_progress', 'recovery', 'completed'];
    const current = steps.indexOf(status);
    return { current, total: steps.length };
  }

  function getScheduleTime(timeStr) {
    if (!timeStr) return '-';
    return new Date(timeStr).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
  }

  async function advanceStatus(surgeryId, currentStatus) {
    const nextStatus = { scheduled: 'in_progress', in_progress: 'recovery', recovery: 'completed' };
    const next = nextStatus[currentStatus];
    if (!next) return;
    try {
      const update = { status: next };
      if (next === 'completed') update.completed_at = new Date().toISOString();
      const { error } = await supabase.from('surgeries').update(update).eq('surgery_id', surgeryId);
      if (error) throw error;
      await fetchSurgeries();
    } catch (err) {
      console.error('Advance status error:', err);
    }
  }

  async function submitSurgery() {
    if (!newSurgery.patient_id || !newSurgery.procedure_name || !newSurgery.scheduled_time) return;
    saving = true;
    try {
      const { error } = await supabase.from('surgeries').insert({
        surgery_id: generateId('OP'),
        ...newSurgery,
        status: 'scheduled',
        created_at: new Date().toISOString()
      });
      if (error) throw error;
      showForm = false;
      newSurgery = { patient_id: '', procedure_name: '', description: '', priority: 'normal', scheduled_time: '', surgeon_id: '', anesthesia_type: 'lokal', room_id: '' };
      await fetchSurgeries();
    } catch (err) {
      console.error('Submit surgery error:', err);
    } finally {
      saving = false;
    }
  }

  async function fetchSurgeries() {
    try {
      const { data, error } = await supabase
        .from('surgeries')
        .select(`
          *,
          patients:patient_id ( full_name, no_registration ),
          doctors:surgeon_id ( full_name ),
          rooms:room_id ( name )
        `)
        .order('scheduled_time', { ascending: false })
        .limit(100);
      if (error) throw error;
      surgeries = (data || []).map(s => ({
        ...s,
        patient_name: s.patients?.full_name || '-',
        patient_no: s.patients?.no_registration || '-',
        surgeon_name: s.doctors?.full_name || '-',
        room_name: s.rooms?.name || '-'
      }));
    } catch (err) {
      console.error('Fetch IBS surgeries error:', err);
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
    await Promise.all([fetchSurgeries(), fetchPatients(), fetchDoctors()]);
    loading = false;
  }

  onMount(async () => {
    await refreshAll();
  });
</script>

<svelte:head>
  <title>IBS - Instalasi Bedah Sentra</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div class="flex items-center gap-3">
      <div class="w-10 h-10 rounded-lg bg-teal-600 flex items-center justify-center">
        <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M11.42 15.17 17.25 21A2.652 2.652 0 0 0 21 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 1 1-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 0 0 4.486-6.336l-3.276 3.277a3.004 3.004 0 0 1-2.25-2.25l3.276-3.276a4.5 4.5 0 0 0-6.336 4.486c.091 1.076-.071 2.264-.904 2.95l-.102.085m-1.745 1.437L5.909 7.5H4.5L2.25 3.75l1.5-1.5L7.5 4.5v1.409l4.26 4.26m-1.745 1.437 1.745-1.437m6.615 8.206L15.75 15.75M4.867 19.125h.008v.008h-.008v-.008Z" />
        </svg>
      </div>
      <div>
        <h1 class="text-2xl font-bold text-teal-700">Instalasi Bedah Sentra (IBS)</h1>
        <p class="text-sm text-gray-500 mt-0.5">Manajemen bedah sentra dan alur pasien</p>
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
      <p class="text-xs text-blue-700 uppercase tracking-wide font-medium">Terjadwal</p>
      <p class="text-2xl font-bold text-blue-700 mt-1">{stats.scheduled}</p>
    </div>
    <div class="card p-4 border-amber-200 bg-amber-50">
      <p class="text-xs text-amber-700 uppercase tracking-wide font-medium">Operasi</p>
      <p class="text-2xl font-bold text-amber-700 mt-1">{stats.inProgress}</p>
    </div>
    <div class="card p-4 border-purple-200 bg-purple-50">
      <p class="text-xs text-purple-700 uppercase tracking-wide font-medium">Recovery</p>
      <p class="text-2xl font-bold text-purple-700 mt-1">{stats.recovery}</p>
    </div>
    <div class="card p-4 border-emerald-200 bg-emerald-50">
      <p class="text-xs text-emerald-700 uppercase tracking-wide font-medium">Selesai Hari Ini</p>
      <p class="text-2xl font-bold text-emerald-700 mt-1">{stats.discharged}</p>
    </div>
  </div>

  <div class="card">
    <div class="flex items-center gap-2 mb-4">
      <svg class="w-5 h-5 text-teal-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 0 1 0 3.75H5.625a1.875 1.875 0 0 1 0-3.75Z" />
      </svg>
      <h2 class="text-lg font-semibold text-gray-900">Alur Pasien Bedah</h2>
    </div>
    <div class="flex items-center gap-2 overflow-x-auto pb-2">
      {#each ['Admission', 'Terjadwal', 'Operasi', 'Recovery', 'Selesai'] as step, i}
        <div class="flex items-center gap-2 shrink-0">
          <div class="flex items-center justify-center w-8 h-8 rounded-full bg-teal-600 text-white text-xs font-bold">{i + 1}</div>
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
        {activeTab === 'jadwal' ? 'border-teal-600 text-teal-700 bg-teal-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'jadwal'}
    >
      Jadwal Hari Ini
    </button>
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {activeTab === 'riwayat' ? 'border-teal-600 text-teal-700 bg-teal-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'riwayat'}
    >
      Riwayat
    </button>
  </div>

  {#if activeTab === 'jadwal'}
    <div class="flex items-center justify-between mb-4">
      <p class="text-sm text-gray-500">{todaySchedule.length} jadwal hari ini</p>
      <button class="btn-primary btn-sm" onclick={() => showForm = !showForm}>
        <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        Jadwalkan Bedah
      </button>
    </div>

    {#if showForm}
      <div class="card border-teal-200">
        <h3 class="font-semibold text-gray-900 mb-4">Jadwalkan Bedah Baru</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="label">Pasien *</label>
            <select class="select-field" bind:value={newSurgery.patient_id}>
              <option value="">Pilih Pasien</option>
              {#each patients as p}
                <option value={p.patient_id}>{p.full_name} ({p.no_registration})</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Prosedur *</label>
            <input type="text" class="input-field" placeholder="Nama prosedur" bind:value={newSurgery.procedure_name} />
          </div>
          <div class="md:col-span-2">
            <label class="label">Deskripsi</label>
            <textarea class="input-field" rows="2" placeholder="Deskripsi singkat..." bind:value={newSurgery.description}></textarea>
          </div>
          <div>
            <label class="label">Jadwal *</label>
            <input type="datetime-local" class="input-field" bind:value={newSurgery.scheduled_time} />
          </div>
          <div>
            <label class="label">Dokter Bedah</label>
            <select class="select-field" bind:value={newSurgery.surgeon_id}>
              <option value="">Pilih Dokter</option>
              {#each doctors as d}
                <option value={d.doctor_id}>{d.full_name}</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Jenis Anestesi</label>
            <select class="select-field" bind:value={newSurgery.anesthesia_type}>
              <option value="lokal">Lokal</option>
              <option value="umum">Umum</option>
              <option value="regional">Regional</option>
              <option value="sedasi">Sedasi</option>
            </select>
          </div>
          <div>
            <label class="label">Prioritas</label>
            <select class="select-field" bind:value={newSurgery.priority}>
              <option value="normal">Normal</option>
              <option value="urgent">Urgent</option>
            </select>
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-5">
          <button class="btn-secondary btn-sm" onclick={() => showForm = false}>Batal</button>
          <button class="btn-primary btn-sm" onclick={submitSurgery} disabled={saving}>
            {saving ? 'Menyimpan...' : 'Simpan'}
          </button>
        </div>
      </div>
    {/if}

    <div class="space-y-3">
      {#if loading}
        <div class="flex items-center justify-center py-16">
          <div class="w-10 h-10 border-4 border-teal-200 border-t-teal-600 rounded-full animate-spin"></div>
        </div>
      {:else if todaySchedule.length === 0}
        <div class="card text-center py-16">
          <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
          </svg>
          <p class="text-lg font-medium text-gray-500">Tidak ada jadwal bedah hari ini</p>
        </div>
      {:else}
        {#each todaySchedule as surg}
          {@const statusCfg = getStatusBadge(surg.status)}
          {@const flow = getFlowStep(surg.status)}
          <div class="card p-4 {statusCfg.color}">
            <div class="flex flex-col lg:flex-row lg:items-center gap-4">
              <div class="flex items-center gap-3 lg:w-44 shrink-0">
                <div class="text-center">
                  <p class="text-xl font-bold text-teal-700">{getScheduleTime(surg.scheduled_time)}</p>
                  <p class="text-xs text-gray-500">{surg.room_name || '-'}</p>
                </div>
              </div>

              <div class="flex-1 min-w-0">
                <div class="flex items-start justify-between gap-2 mb-2">
                  <div>
                    <h3 class="font-semibold text-gray-900">{surg.procedure_name}</h3>
                    <p class="text-sm text-gray-500">{surg.patient_name} &middot; {surg.patient_no}</p>
                  </div>
                  <span class="badge {statusCfg.class} shrink-0">{statusCfg.label}</span>
                </div>

                <div class="flex items-center gap-1 mb-2">
                  {#each ['Admission', 'Jadwal', 'Operasi', 'Recovery', 'Selesai'] as stepLabel, si}
                    <div class="flex items-center gap-1">
                      <div class="w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold
                        {si <= flow.current ? 'bg-teal-600 text-white' : 'bg-gray-200 text-gray-500'}">
                        {si + 1}
                      </div>
                      {#if si < 4}
                        <div class="w-4 h-0.5 {si < flow.current ? 'bg-teal-600' : 'bg-gray-200'}"></div>
                      {/if}
                    </div>
                  {/each}
                </div>

                <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-500">
                  <span>Dokter: {surg.surgeon_name}</span>
                  <span>Anestesi: {surg.anesthesia_type || '-'}</span>
                </div>
              </div>

              <div class="shrink-0">
                {#if surg.status === 'scheduled'}
                  <button class="btn-success btn-sm text-xs" onclick={() => advanceStatus(surg.surgery_id, surg.status)}>
                    Mulai Operasi
                  </button>
                {:else if surg.status === 'in_progress'}
                  <button class="btn-primary btn-sm text-xs" onclick={() => advanceStatus(surg.surgery_id, surg.status)}>
                    Ke Recovery
                  </button>
                {:else if surg.status === 'recovery'}
                  <button class="btn-primary btn-sm text-xs" onclick={() => advanceStatus(surg.surgery_id, surg.status)}>
                    Selesai
                  </button>
                {/if}
              </div>
            </div>
          </div>
        {/each}
      {/if}
    </div>

  {:else if activeTab === 'riwayat'}
    <div class="card">
      <div class="overflow-x-auto">
        {#if loading}
          <div class="flex items-center justify-center py-16">
            <div class="w-10 h-10 border-4 border-teal-200 border-t-teal-600 rounded-full animate-spin"></div>
          </div>
        {:else if completedToday.length === 0}
          <div class="text-center py-16 text-gray-400">
            <p class="text-lg font-medium">Belum ada bedah selesai hari ini</p>
          </div>
        {:else}
          <table class="w-full">
            <thead>
              <tr class="table-header">
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Pasien</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Prosedur</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Dokter</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Jam</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each completedToday as s, i}
                {@const statusCfg = getStatusBadge(s.status)}
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
                    <span class="badge {statusCfg.class}">{statusCfg.label}</span>
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
