<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDateTime } from '$lib/utils/helpers.js';
  import { TRIAGE_LEVELS } from '$lib/utils/constants.js';

  let loading = $state(true);
  let visits = $state([]);
  let searchQuery = $state('');
  let viewMode = $state('triage');
  let now = $state(new Date());
  let timer;

  const formattedDate = $derived(
    now.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
  );

  const triageColumns = [
    { key: 'resuscitation', ...TRIAGE_LEVELS.resuscitation, bg: 'bg-red-800', border: 'border-red-700', headerBg: 'bg-red-800' },
    { key: 'emergency', ...TRIAGE_LEVELS.emergency, bg: 'bg-red-500', border: 'border-red-400', headerBg: 'bg-red-500' },
    { key: 'urgent', ...TRIAGE_LEVELS.urgent, bg: 'bg-orange-500', border: 'border-orange-400', headerBg: 'bg-orange-500' },
    { key: 'less_urgent', ...TRIAGE_LEVELS.less_urgent, bg: 'bg-yellow-500', border: 'border-yellow-400', headerBg: 'bg-yellow-500' },
    { key: 'non_urgent', ...TRIAGE_LEVELS.non_urgent, bg: 'bg-green-500', border: 'border-green-400', headerBg: 'bg-green-500' }
  ];

  const triageGroups = $derived.by(() => {
    const groups = {};
    triageColumns.forEach(col => { groups[col.key] = []; });
    visits.forEach(v => {
      const key = v.triage_level || 'non_urgent';
      if (groups[key]) groups[key].push(v);
    });
    Object.keys(groups).forEach(key => {
      groups[key].sort((a, b) => new Date(a.visit_date) - new Date(b.visit_date));
    });
    return groups;
  });

  const filteredVisits = $derived.by(() => {
    if (!searchQuery.trim()) return visits;
    const q = searchQuery.toLowerCase();
    return visits.filter(v =>
      v.patient_name.toLowerCase().includes(q) ||
      v.patient_no?.toLowerCase().includes(q) ||
      v.chief_complaint?.toLowerCase().includes(q)
    );
  });

  const stats = $derived({
    total: visits.length,
    resuscitation: visits.filter(v => v.triage_level === 'resuscitation').length,
    emergency: visits.filter(v => v.triage_level === 'emergency').length,
    urgent: visits.filter(v => v.triage_level === 'urgent').length,
    less_urgent: visits.filter(v => v.triage_level === 'less_urgent').length,
    non_urgent: visits.filter(v => v.triage_level === 'non_urgent').length,
    stillHere: visits.filter(v => v.status_keluar === '0').length
  });

  function getTimeElapsed(dateStr) {
    if (!dateStr) return '-';
    const arrival = new Date(dateStr);
    const diff = Math.floor((now - arrival) / 1000);
    const hours = Math.floor(diff / 3600);
    const minutes = Math.floor((diff % 3600) / 60);
    if (hours > 0) return `${hours}j ${minutes}m`;
    return `${minutes}m`;
  }

  function getVisitTime(dateStr) {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
  }

  function getTriageBadge(level) {
    const cfg = TRIAGE_LEVELS[level];
    return cfg || { name: '-', color: 'bg-gray-100 text-gray-800', priority: 99 };
  }

  function getStatusConfig(visit) {
    if (visit.status_keluar === '1') return { label: 'Selesai', class: 'badge-info' };
    if (visit.status_periksa === '1') return { label: 'Diperiksa', class: 'badge-success' };
    return { label: 'Menunggu', class: 'badge-warning' };
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
          triage_level,
          triage_score,
          chief_complaint,
          patient_id,
          doctor_id,
          patients:patient_id ( full_name, no_registration, date_of_birth ),
          doctors:doctor_id ( full_name )
        `)
        .eq('visit_type', 'igd')
        .gte('visit_date', todayStart.toISOString())
        .lte('visit_date', todayEnd.toISOString())
        .order('visit_date', { ascending: false });

      if (error) throw error;

      visits = (data || []).map(v => {
        let age = null;
        if (v.patients?.date_of_birth) {
          const birth = new Date(v.patients.date_of_birth);
          const today = new Date();
          age = today.getFullYear() - birth.getFullYear();
          const m = today.getMonth() - birth.getMonth();
          if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--;
        }
        return {
          ...v,
          patient_name: v.patients?.full_name || '-',
          patient_no: v.patients?.no_registration || '-',
          doctor_name: v.doctors?.full_name || '-',
          patient_age: age
        };
      });
    } catch (err) {
      console.error('Fetch IGD visits error:', err);
    }
  }

  function goDetail(visitId) {
    goto(`/igd/${visitId}`);
  }

  async function refreshAll() {
    loading = true;
    await fetchVisits();
    loading = false;
  }

  onMount(async () => {
    await fetchVisits();
    loading = false;

    timer = setInterval(() => {
      now = new Date();
    }, 60000);

    return () => clearInterval(timer);
  });
</script>

<svelte:head>
  <title>IGD - Instalasi Gawat Darurat</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-lg bg-red-600 flex items-center justify-center">
          <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
          </svg>
        </div>
        <div>
          <h1 class="text-2xl font-bold text-red-700">IGD - Instalasi Gawat Darurat</h1>
          <p class="text-sm text-gray-500 mt-0.5">{formattedDate}</p>
        </div>
      </div>
    </div>
    <div class="flex items-center gap-3">
      <button class="btn-secondary btn-sm" onclick={refreshAll}>
        <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182" />
        </svg>
        Refresh
      </button>
      <a href="/registrasi/tambah" class="btn-danger btn-sm inline-flex items-center gap-2">
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        Pasien Baru IGD
      </a>
    </div>
  </div>

  <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
    <div class="card p-4">
      <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Total</p>
      <p class="text-2xl font-bold text-gray-900 mt-1">{stats.total}</p>
    </div>
    <div class="card p-4 border-red-200 bg-red-50">
      <p class="text-xs text-red-700 uppercase tracking-wide font-medium">Resusitasi</p>
      <p class="text-2xl font-bold text-red-800 mt-1">{stats.resuscitation}</p>
    </div>
    <div class="card p-4 border-red-100 bg-red-50">
      <p class="text-xs text-red-600 uppercase tracking-wide font-medium">Darurat</p>
      <p class="text-2xl font-bold text-red-600 mt-1">{stats.emergency}</p>
    </div>
    <div class="card p-4 border-orange-100 bg-orange-50">
      <p class="text-xs text-orange-600 uppercase tracking-wide font-medium">Urgent</p>
      <p class="text-2xl font-bold text-orange-600 mt-1">{stats.urgent}</p>
    </div>
    <div class="card p-4 border-yellow-100 bg-yellow-50">
      <p class="text-xs text-yellow-600 uppercase tracking-wide font-medium">Less Urgent</p>
      <p class="text-2xl font-bold text-yellow-600 mt-1">{stats.less_urgent}</p>
    </div>
    <div class="card p-4 border-green-100 bg-green-50">
      <p class="text-xs text-green-600 uppercase tracking-wide font-medium">Non Urgent</p>
      <p class="text-2xl font-bold text-green-600 mt-1">{stats.non_urgent}</p>
    </div>
  </div>

  <div class="flex items-center gap-2 border-b border-gray-200">
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {viewMode === 'triage'
          ? 'border-red-600 text-red-700 bg-red-50'
          : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => viewMode = 'triage'}
    >
      <svg class="w-4 h-4 inline-block mr-1.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6Zm0 9.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6Zm0 9.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25a2.25 2.25 0 0 1-2.25-2.25v-2.25Z" />
      </svg>
      Papan Triage
    </button>
    <button
      class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
        {viewMode === 'table'
          ? 'border-red-600 text-red-700 bg-red-50'
          : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
      onclick={() => viewMode = 'table'}
    >
      <svg class="w-4 h-4 inline-block mr-1.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 0 1 0 3.75H5.625a1.875 1.875 0 0 1 0-3.75Z" />
      </svg>
      Tabel
    </button>
  </div>

  {#if viewMode === 'triage'}
    {#if loading}
      <div class="flex items-center justify-center py-16">
        <div class="w-10 h-10 border-4 border-red-200 border-t-red-600 rounded-full animate-spin"></div>
      </div>
    {:else}
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
        {#each triageColumns as col}
          {@const patients = triageGroups[col.key] || []}
          <div class="rounded-xl border {col.border} overflow-hidden">
            <div class="{col.headerBg} px-4 py-3 flex items-center justify-between">
              <span class="text-white font-semibold text-sm">{col.name}</span>
              <span class="bg-white/20 text-white text-xs font-bold px-2 py-0.5 rounded-full">{patients.length}</span>
            </div>
            <div class="bg-gray-50 p-3 space-y-2 max-h-[500px] overflow-y-auto scrollbar-thin">
              {#if patients.length === 0}
                <div class="text-center py-6">
                  <p class="text-xs text-gray-400">Tidak ada pasien</p>
                </div>
              {:else}
                {#each patients as v}
                  {@const elapsed = getTimeElapsed(v.visit_date)}
                  <button
                    class="w-full text-left bg-white rounded-lg border border-gray-200 p-3 hover:shadow-md transition-shadow cursor-pointer"
                    onclick={() => goDetail(v.visit_id)}
                  >
                    <div class="flex items-start justify-between gap-2 mb-1.5">
                      <p class="font-semibold text-sm text-gray-900 truncate">{v.patient_name}</p>
                      <span class="text-[10px] font-mono font-bold {col.bg} text-white px-1.5 py-0.5 rounded shrink-0">
                        {elapsed}
                      </span>
                    </div>
                    <p class="text-xs text-gray-500 mb-1">
                      {v.patient_age != null ? `${v.patient_age} th` : '-'} &middot; {getVisitTime(v.visit_date)}
                    </p>
                    {#if v.chief_complaint}
                      <p class="text-xs text-gray-700 bg-gray-100 rounded px-2 py-1 mt-1.5 line-clamp-2">{v.chief_complaint}</p>
                    {/if}
                  </button>
                {/each}
              {/if}
            </div>
          </div>
        {/each}
      </div>
    {/if}

  {:else}
    <div class="card">
      <div class="mb-4">
        <div class="relative">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
          </svg>
          <input
            type="text"
            class="input-field pl-10"
            placeholder="Cari nama pasien, No.RM, atau keluhan..."
            bind:value={searchQuery}
          />
        </div>
      </div>

      <div class="overflow-x-auto">
        {#if loading}
          <div class="flex items-center justify-center py-16">
            <div class="w-10 h-10 border-4 border-red-200 border-t-red-600 rounded-full animate-spin"></div>
          </div>
        {:else if filteredVisits.length === 0}
          <div class="text-center py-16 text-gray-400">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
            </svg>
            <p class="text-lg font-medium">Tidak ada pasien IGD</p>
            <p class="text-sm mt-1">Belum ada kunjungan IGD hari ini</p>
          </div>
        {:else}
          <table class="w-full">
            <thead>
              <tr class="table-header">
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Triage</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pasien</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Umur</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Keluhan</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Jam Datang</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Lama</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each filteredVisits as visit, i}
                {@const triage = getTriageBadge(visit.triage_level)}
                {@const status = getStatusConfig(visit)}
                {@const elapsed = getTimeElapsed(visit.visit_date)}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                  <td class="table-cell">
                    <span class="{triage.color} text-xs font-semibold px-2 py-1 rounded">{triage.name}</span>
                  </td>
                  <td class="table-cell">
                    <div>
                      <p class="font-medium text-gray-900">{visit.patient_name}</p>
                      <p class="text-xs text-gray-400 font-mono">{visit.patient_no}</p>
                    </div>
                  </td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{visit.patient_age != null ? `${visit.patient_age} th` : '-'}</td>
                  <td class="table-cell text-gray-600 hidden lg:table-cell max-w-[200px] truncate">{visit.chief_complaint || '-'}</td>
                  <td class="table-cell text-gray-500 hidden sm:table-cell font-mono text-xs">{getVisitTime(visit.visit_date)}</td>
                  <td class="table-cell">
                    <span class="font-mono text-xs font-semibold text-red-600">{elapsed}</span>
                  </td>
                  <td class="table-cell">
                    <span class="badge {status.class}">{status.label}</span>
                  </td>
                  <td class="table-cell text-right">
                    <button class="btn-primary btn-sm text-xs" onclick={() => goDetail(visit.visit_id)}>
                      Periksa
                    </button>
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
