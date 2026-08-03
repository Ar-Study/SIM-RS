<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime, generateId } from '$lib/utils/helpers.js';

  let loading = $state(true);
  let activeTab = $state('jadwal');

  let sessions = $state([]);
  let history = $state([]);
  let machines = $state([]);
  let patients = $state([]);
  let nurses = $state([]);

  let showForm = $state(false);
  let saving = $state(false);

  let newSession = $state({
    patient_id: '',
    scheduled_time: '',
    duration_minutes: 240,
    machine_id: '',
    nurse_id: '',
    notes: ''
  });

  const stats = $derived({
    totalMachines: machines.length,
    available: machines.filter(m => m.status === 'available').length,
    inUse: machines.filter(m => m.status === 'in_use').length,
    maintenance: machines.filter(m => m.status === 'maintenance').length,
    todaySessions: sessions.length
  });

  const todaySessions = $derived.by(() => {
    const today = new Date().toDateString();
    return sessions.filter(s => {
      const schedDate = new Date(s.scheduled_time);
      return schedDate.toDateString() === today;
    }).sort((a, b) => new Date(a.scheduled_time) - new Date(b.scheduled_time));
  });

  function getScheduleTime(timeStr) {
    if (!timeStr) return '-';
    return new Date(timeStr).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
  }

  function getSessionStatus(status) {
    switch (status) {
      case 'scheduled': return { label: 'Terjadwal', class: 'badge-info' };
      case 'in_progress': return { label: 'Berlangsung', class: 'badge-warning' };
      case 'completed': return { label: 'Selesai', class: 'badge-success' };
      case 'cancelled': return { label: 'Dibatalkan', class: 'badge-danger' };
      default: return { label: status, class: 'badge-gray' };
    }
  }

  function getMachineStatus(status) {
    switch (status) {
      case 'available': return { label: 'Tersedia', class: 'badge-success' };
      case 'in_use': return { label: 'Digunakan', class: 'badge-warning' };
      case 'maintenance': return { label: 'Maintenance', class: 'badge-danger' };
      default: return { label: status, class: 'badge-gray' };
    }
  }

  async function submitSession() {
    if (!newSession.patient_id || !newSession.scheduled_time) return;
    saving = true;
    try {
      const { error } = await supabase.from('hd_sessions').insert({
        session_id: generateId('HD'),
        ...newSession,
        status: 'scheduled',
        created_at: new Date().toISOString()
      });
      if (error) throw error;
      showForm = false;
      newSession = { patient_id: '', scheduled_time: '', duration_minutes: 240, machine_id: '', nurse_id: '', notes: '' };
      await fetchSessions();
    } catch (err) {
      console.error('Submit HD session error:', err);
    } finally {
      saving = false;
    }
  }

  async function startSession(sessionId) {
    try {
      const { error } = await supabase
        .from('hd_sessions')
        .update({ status: 'in_progress', started_at: new Date().toISOString() })
        .eq('session_id', sessionId);
      if (error) throw error;
      await fetchSessions();
    } catch (err) {
      console.error('Start HD session error:', err);
    }
  }

  async function completeSession(sessionId) {
    try {
      const { error } = await supabase
        .from('hd_sessions')
        .update({ status: 'completed', completed_at: new Date().toISOString() })
        .eq('session_id', sessionId);
      if (error) throw error;
      await Promise.all([fetchSessions(), fetchHistory()]);
    } catch (err) {
      console.error('Complete HD session error:', err);
    }
  }

  async function fetchSessions() {
    try {
      const { data, error } = await supabase
        .from('hd_sessions')
        .select(`
          *,
          patients:patient_id ( full_name, no_registration ),
          employees:nurse_id ( employee_id, full_name )
        `)
        .in('status', ['scheduled', 'in_progress'])
        .order('scheduled_time', { ascending: false });
      if (error) throw error;
      sessions = (data || []).map(s => ({
        ...s,
        patient_name: s.patients?.full_name || '-',
        patient_no: s.patients?.no_registration || '-',
        nurse_name: s.employees?.full_name || '-',
        machine_no: s.machine_id || '-'
      }));
    } catch (err) {
      console.error('Fetch HD sessions error:', err);
    }
  }

  async function fetchHistory() {
    try {
      const { data, error } = await supabase
        .from('hd_sessions')
        .select(`
          *,
          patients:patient_id ( full_name, no_registration )
        `)
        .eq('status', 'completed')
        .order('completed_at', { ascending: false })
        .limit(50);
      if (error) throw error;
      history = (data || []).map(s => ({
        ...s,
        patient_name: s.patients?.full_name || '-',
        patient_no: s.patients?.no_registration || '-'
      }));
    } catch (err) {
      console.error('Fetch HD history error:', err);
    }
  }

  async function fetchMachines() {
    try {
      const { data, error } = await supabase.from('hd_machines').select('*').order('machine_no');
      if (error) throw error;
      machines = data || [];
    } catch (err) {
      console.error('Fetch HD machines error:', err);
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

  async function fetchNurses() {
    try {
      const { data, error } = await supabase.from('employees')
        .select('employee_id, full_name')
        .eq('role', 'nurse')
        .eq('is_active', true)
        .order('full_name');
      if (error) throw error;
      nurses = data || [];
    } catch (err) {
      console.error('Fetch nurses error:', err);
    }
  }

  async function refreshAll() {
    loading = true;
    await Promise.all([fetchSessions(), fetchHistory(), fetchMachines(), fetchPatients(), fetchNurses()]);
    loading = false;
  }

  onMount(async () => {
    await refreshAll();
  });
</script>

<svelte:head>
  <title>Hemodialisis - SIMRS</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div class="flex items-center gap-3">
      <div class="w-10 h-10 rounded-lg bg-cyan-600 flex items-center justify-center">
        <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 0 0 8.716-6.747M12 21a9.004 9.004 0 0 1-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 0 1 7.843 4.582M12 3a8.997 8.997 0 0 0-7.843 4.582m15.686 0A11.953 11.953 0 0 1 12 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0 1 21 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0 1 12 16.5a17.92 17.92 0 0 1-8.716-2.247m0 0A8.966 8.966 0 0 1 3 12c0-1.264.26-2.466.729-3.561" />
        </svg>
      </div>
      <div>
        <h1 class="text-2xl font-bold text-cyan-700">Hemodialisis</h1>
        <p class="text-sm text-gray-500 mt-0.5">Manajemen sesi hemodialisis dan mesin HD</p>
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
      <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Total Mesin</p>
      <p class="text-2xl font-bold text-gray-900 mt-1">{stats.totalMachines}</p>
    </div>
    <div class="card p-4 border-emerald-200 bg-emerald-50">
      <p class="text-xs text-emerald-700 uppercase tracking-wide font-medium">Tersedia</p>
      <p class="text-2xl font-bold text-emerald-700 mt-1">{stats.available}</p>
    </div>
    <div class="card p-4 border-amber-200 bg-amber-50">
      <p class="text-xs text-amber-700 uppercase tracking-wide font-medium">Digunakan</p>
      <p class="text-2xl font-bold text-amber-700 mt-1">{stats.inUse}</p>
    </div>
    <div class="card p-4 border-red-200 bg-red-50">
      <p class="text-xs text-red-700 uppercase tracking-wide font-medium">Maintenance</p>
      <p class="text-2xl font-bold text-red-700 mt-1">{stats.maintenance}</p>
    </div>
    <div class="card p-4 border-cyan-200 bg-cyan-50">
      <p class="text-xs text-cyan-700 uppercase tracking-wide font-medium">Sesi Hari Ini</p>
      <p class="text-2xl font-bold text-cyan-700 mt-1">{stats.todaySessions}</p>
    </div>
  </div>

  {#if machines.length > 0}
    <div class="card">
      <div class="flex items-center gap-2 mb-4">
        <svg class="w-5 h-5 text-cyan-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 0 0 2.25-2.25V6.75a2.25 2.25 0 0 0-2.25-2.25H6.75A2.25 2.25 0 0 0 4.5 6.75v10.5a2.25 2.25 0 0 0 2.25 2.25Zm.75-12h3v3h-3v-3Zm-3 3h3v3h-3v-3Zm6 0h3v3h-3v-3Zm-3 3h3v3h-3v-3Z" />
        </svg>
        <h2 class="text-lg font-semibold text-gray-900">Status Mesin HD</h2>
      </div>
      <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-3">
        {#each machines as machine}
          {@const mStatus = getMachineStatus(machine.status)}
          <div class="rounded-xl border-2 p-3 text-center transition-all
            {machine.status === 'available' ? 'border-emerald-300 bg-emerald-50' : machine.status === 'in_use' ? 'border-amber-300 bg-amber-50' : 'border-red-300 bg-red-50'}">
            <p class="font-bold text-sm text-gray-900">{machine.machine_no}</p>
            <span class="badge {mStatus.class} text-[10px] mt-1">{mStatus.label}</span>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  <div class="flex items-center gap-2 border-b border-gray-200">
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {activeTab === 'jadwal' ? 'border-cyan-600 text-cyan-700 bg-cyan-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'jadwal'}
    >
      Jadwal Hari Ini
    </button>
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {activeTab === 'riwayat' ? 'border-cyan-600 text-cyan-700 bg-cyan-50' : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => activeTab = 'riwayat'}
    >
      Riwayat Sesi
    </button>
  </div>

  {#if activeTab === 'jadwal'}
    <div class="flex items-center justify-between mb-4">
      <p class="text-sm text-gray-500">{todaySessions.length} sesi hari ini</p>
      <button class="btn-primary btn-sm" onclick={() => showForm = !showForm}>
        <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        Sesi Baru
      </button>
    </div>

    {#if showForm}
      <div class="card border-cyan-200">
        <h3 class="font-semibold text-gray-900 mb-4">Sesi Hemodialisis Baru</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="label">Pasien *</label>
            <select class="select-field" bind:value={newSession.patient_id}>
              <option value="">Pilih Pasien</option>
              {#each patients as p}
                <option value={p.patient_id}>{p.full_name} ({p.no_registration})</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Jadwal *</label>
            <input type="datetime-local" class="input-field" bind:value={newSession.scheduled_time} />
          </div>
          <div>
            <label class="label">Durasi (menit)</label>
            <input type="number" class="input-field" bind:value={newSession.duration_minutes} min="60" step="30" />
          </div>
          <div>
            <label class="label">Mesin HD</label>
            <select class="select-field" bind:value={newSession.machine_id}>
              <option value="">Pilih Mesin</option>
              {#each machines.filter(m => m.status === 'available') as m}
                <option value={m.machine_id}>{m.machine_no}</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Perawat</label>
            <select class="select-field" bind:value={newSession.nurse_id}>
              <option value="">Pilih Perawat</option>
              {#each nurses as n}
                <option value={n.employee_id}>{n.full_name}</option>
              {/each}
            </select>
          </div>
          <div class="md:col-span-2">
            <label class="label">Catatan</label>
            <input type="text" class="input-field" placeholder="Catatan sesi..." bind:value={newSession.notes} />
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-5">
          <button class="btn-secondary btn-sm" onclick={() => showForm = false}>Batal</button>
          <button class="btn-primary btn-sm" onclick={submitSession} disabled={saving}>
            {saving ? 'Menyimpan...' : 'Simpan'}
          </button>
        </div>
      </div>
    {/if}

    <div class="card">
      {#if loading}
        <div class="flex items-center justify-center py-16">
          <div class="w-10 h-10 border-4 border-cyan-200 border-t-cyan-600 rounded-full animate-spin"></div>
        </div>
      {:else if todaySessions.length === 0}
        <div class="text-center py-16 text-gray-400">
          <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
          </svg>
          <p class="text-lg font-medium">Tidak ada jadwal HD hari ini</p>
        </div>
      {:else}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="table-header">
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Jam</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Pasien</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Durasi</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Mesin</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Perawat</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each todaySessions as sess, i}
                {@const sessStatus = getSessionStatus(sess.status)}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                  <td class="table-cell">
                    <span class="font-bold text-cyan-700">{getScheduleTime(sess.scheduled_time)}</span>
                  </td>
                  <td class="table-cell">
                    <p class="font-medium text-gray-900">{sess.patient_name}</p>
                    <p class="text-xs text-gray-400 font-mono">{sess.patient_no}</p>
                  </td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{sess.duration_minutes} menit</td>
                  <td class="table-cell text-gray-600 hidden lg:table-cell">
                    <span class="font-mono text-sm font-semibold text-cyan-700 bg-cyan-50 px-2 py-0.5 rounded">{sess.machine_no}</span>
                  </td>
                  <td class="table-cell text-gray-600 hidden sm:table-cell">{sess.nurse_name}</td>
                  <td class="table-cell">
                    <span class="badge {sessStatus.class}">{sessStatus.label}</span>
                  </td>
                  <td class="table-cell text-right">
                    {#if sess.status === 'scheduled'}
                      <button class="btn-success btn-sm text-xs" onclick={() => startSession(sess.session_id)}>Mulai</button>
                    {:else if sess.status === 'in_progress'}
                      <button class="btn-primary btn-sm text-xs" onclick={() => completeSession(sess.session_id)}>Selesai</button>
                    {/if}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    </div>

  {:else if activeTab === 'riwayat'}
    <div class="card">
      <div class="overflow-x-auto">
        {#if loading}
          <div class="flex items-center justify-center py-16">
            <div class="w-10 h-10 border-4 border-cyan-200 border-t-cyan-600 rounded-full animate-spin"></div>
          </div>
        {:else if history.length === 0}
          <div class="text-center py-16 text-gray-400">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
            </svg>
            <p class="text-lg font-medium">Belum ada riwayat sesi HD</p>
          </div>
        {:else}
          <table class="w-full">
            <thead>
              <tr class="table-header">
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Pasien</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Tanggal</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Durasi</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">BB Pre</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">BB Post</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">UF</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each history as h, i}
                {@const sessStatus = getSessionStatus(h.status)}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                  <td class="table-cell">
                    <p class="font-medium text-gray-900">{h.patient_name}</p>
                    <p class="text-xs text-gray-400 font-mono">{h.patient_no}</p>
                  </td>
                  <td class="table-cell text-gray-500 hidden sm:table-cell font-mono text-xs">{formatDateTime(h.completed_at || h.scheduled_time)}</td>
                  <td class="table-cell text-gray-600">{h.duration_minutes} mnt</td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{h.pre_weight ?? '-'} kg</td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{h.post_weight ?? '-'} kg</td>
                  <td class="table-cell text-gray-600 hidden lg:table-cell">{h.ultrafiltration ?? '-'} mL</td>
                  <td class="table-cell">
                    <span class="badge {sessStatus.class}">{sessStatus.label}</span>
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
