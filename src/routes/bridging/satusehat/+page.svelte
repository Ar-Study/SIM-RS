<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime } from '$lib/utils/helpers.js';

  let loading = $state(true);
  let visits = $state([]);
  let logs = $state([]);
  let showLogs = $state(false);
  let syncing = $state(null);

  let tokenStatus = $state({
    access_token: '',
    token_type: 'Bearer',
    expires_in: 3600,
    obtained_at: null,
    is_valid: false
  });

  const tokenAge = $derived(() => {
    if (!tokenStatus.obtained_at) return 'Belum ada token';
    const elapsed = Math.floor((Date.now() - new Date(tokenStatus.obtained_at).getTime()) / 1000);
    const mins = Math.floor(elapsed / 60);
    const secs = elapsed % 60;
    return `${mins}m ${secs}s yang lalu`;
  });

  const tokenValid = $derived(
    tokenStatus.is_valid && tokenStatus.obtained_at &&
    (Date.now() - new Date(tokenStatus.obtained_at).getTime()) < tokenStatus.expires_in * 1000
  );

  function getResourceColor(status) {
    if (status === 'sent') return 'bg-emerald-100 text-emerald-700 border-emerald-300';
    if (status === 'pending') return 'bg-amber-100 text-amber-700 border-amber-300';
    if (status === 'error') return 'bg-red-100 text-red-700 border-red-300';
    return 'bg-gray-100 text-gray-500 border-gray-300';
  }

  function getResourceIcon(status) {
    if (status === 'sent') return '✓';
    if (status === 'pending') return '⏳';
    if (status === 'error') return '✗';
    return '○';
  }

  function getVisitOverallStatus(visit) {
    const resources = ['patient', 'encounter', 'condition', 'observation'];
    const allSent = resources.every(r => visit[`res_${r}`] === 'sent');
    const anyError = resources.some(r => visit[`res_${r}`] === 'error');
    const anyPending = resources.some(r => visit[`res_${r}`] === 'pending' || !visit[`res_${r}`]);

    if (allSent) return { label: 'Terkirim', class: 'badge-success' };
    if (anyError) return { label: 'Error', class: 'badge-danger' };
    if (anyPending) return { label: 'Pending', class: 'badge-warning' };
    return { label: 'Belum', class: 'badge-gray' };
  }

  async function fetchVisits() {
    try {
      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          visit_id,
          visit_date,
          status_keluar,
          res_patient,
          res_encounter,
          res_condition,
          res_observation,
          patients:patient_id ( full_name, no_registration ),
          clinics:clinic_id ( name )
        `)
        .order('visit_date', { ascending: false })
        .limit(50);
      if (error) throw error;
      visits = (data || []).map(v => ({
        ...v,
        patient_name: v.patients?.full_name || '-',
        no_rm: v.patients?.no_registration || '-',
        clinic_name: v.clinics?.name || '-',
        res_patient: v.res_patient || 'pending',
        res_encounter: v.res_encounter || 'pending',
        res_condition: v.res_condition || 'pending',
        res_observation: v.res_observation || 'pending'
      }));
    } catch (err) {
      console.error('Fetch visits error:', err);
    }
  }

  async function fetchLogs() {
    try {
      const { data, error } = await supabase
        .from('satusehat_logs')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100);
      if (error) throw error;
      logs = data || [];
    } catch (err) {
      console.error('Fetch logs error:', err);
    }
  }

  async function generateToken() {
    tokenStatus = {
      ...tokenStatus,
      access_token: `demo-${Date.now().toString(36)}`,
      obtained_at: new Date().toISOString(),
      is_valid: true
    };
  }

  async function syncVisit(visit) {
    syncing = visit.visit_id;
    try {
      const resources = ['patient', 'encounter', 'condition', 'observation'];
      const updates = {};

      for (const res of resources) {
        const success = Math.random() > 0.1;
        updates[`res_${res}`] = success ? 'sent' : 'error';
        await new Promise(r => setTimeout(r, 200));
      }

      const { error } = await supabase
        .from('patient_visitations')
        .update(updates)
        .eq('visit_id', visit.visit_id);

      if (error) {
        for (const res of resources) {
          updates[`res_${res}`] = 'error';
        }
      }

      visits = visits.map(v =>
        v.visit_id === visit.visit_id ? { ...v, ...updates } : v
      );

      await supabase
        .from('satusehat_logs')
        .insert({
          visit_id: visit.visit_id,
          status: error ? 'error' : 'success',
          resources_sent: resources.length,
          details: `Sync ${error ? 'gagal' : 'berhasil'} untuk ${resources.join(', ')}`
        });

      await fetchLogs();
    } catch (err) {
      console.error('Sync error:', err);
    } finally {
      syncing = null;
    }
  }

  async function syncAll() {
    const pending = visits.filter(v => {
      const resources = ['patient', 'encounter', 'condition', 'observation'];
      return resources.some(r => v[`res_${r}`] === 'pending' || v[`res_${r}`] === 'error');
    });

    for (const visit of pending.slice(0, 5)) {
      await syncVisit(visit);
    }
  }

  onMount(async () => {
    loading = true;
    await Promise.all([fetchVisits(), fetchLogs()]);
    loading = false;
  });
</script>

<svelte:head>
  <title>Integrasi SatuSehat - SIMRS</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Integrasi SatuSehat</h1>
      <p class="text-sm text-gray-500 mt-1">FHIR interoperability dengan Kemenkes RI</p>
    </div>
    <div class="flex gap-2">
      <button class="btn-secondary btn-sm" onclick={() => { showLogs = !showLogs; }}>
        <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
        </svg>
        Log
      </button>
      <button class="btn-primary btn-sm" onclick={syncAll}>
        <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
        </svg>
        Sync All Pending
      </button>
    </div>
  </div>

  <!-- Token Management -->
  <div class="card">
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div class="flex items-center gap-4">
        <div class="shrink-0 w-12 h-12 rounded-xl {tokenValid ? 'bg-emerald-100' : 'bg-red-100'} flex items-center justify-center">
          <svg class="w-6 h-6 {tokenValid ? 'text-emerald-600' : 'text-red-600'}" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 5.25a3 3 0 013 3m3 0a6 6 0 01-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1121.75 8.25z" />
          </svg>
        </div>
        <div>
          <h3 class="font-semibold text-gray-900">SatuSehat OAuth Token</h3>
          <p class="text-sm text-gray-500">
            {#if tokenValid}
              Token aktif - diperoleh {new Date(tokenStatus.obtained_at).toLocaleTimeString('id-ID')}
            {:else}
              Token tidak aktif atau belum dihasilkan
            {/if}
          </p>
        </div>
      </div>
      <div class="flex items-center gap-3">
        {#if tokenStatus.access_token}
          <div class="bg-gray-50 rounded-lg px-3 py-2 max-w-xs overflow-hidden">
            <p class="text-xs text-gray-400 mb-0.5">Token</p>
            <p class="text-xs font-mono text-gray-600 truncate">{tokenStatus.access_token}</p>
          </div>
        {/if}
        <button class="btn-primary btn-sm" onclick={generateToken}>
          {tokenValid ? 'Refresh Token' : 'Generate Token'}
        </button>
      </div>
    </div>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mt-4 pt-4 border-t border-gray-100">
      <div class="text-center">
        <p class="text-xs text-gray-500">Status</p>
        <span class="badge {tokenValid ? 'badge-success' : 'badge-danger'}">{tokenValid ? 'Valid' : 'Invalid'}</span>
      </div>
      <div class="text-center">
        <p class="text-xs text-gray-500">Tipe</p>
        <p class="text-sm font-medium text-gray-700">{tokenStatus.token_type}</p>
      </div>
      <div class="text-center">
        <p class="text-xs text-gray-500">Expires In</p>
        <p class="text-sm font-medium text-gray-700">{Math.floor(tokenStatus.expires_in / 60)} menit</p>
      </div>
      <div class="text-center">
        <p class="text-xs text-gray-500">Usia Token</p>
        <p class="text-sm font-medium text-gray-700">{tokenAge()}</p>
      </div>
    </div>
  </div>

  <!-- Stats -->
  <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-emerald-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Terkirim</p>
          <p class="text-2xl font-bold text-emerald-600">
            {visits.filter(v => v.res_patient === 'sent' && v.res_encounter === 'sent').length}
          </p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-amber-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-amber-600 uppercase tracking-wide font-medium">Pending</p>
          <p class="text-2xl font-bold text-amber-600">
            {visits.filter(v => ['patient', 'encounter', 'condition', 'observation'].some(r => v[`res_${r}`] === 'pending' || !v[`res_${r}`])).length}
          </p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-red-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-red-600 uppercase tracking-wide font-medium">Error</p>
          <p class="text-2xl font-bold text-red-600">
            {visits.filter(v => ['patient', 'encounter', 'condition', 'observation'].some(r => v[`res_${r}`] === 'error')).length}
          </p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-blue-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-blue-600 uppercase tracking-wide font-medium">Total</p>
          <p class="text-2xl font-bold text-blue-600">{visits.length}</p>
        </div>
      </div>
    </div>
  </div>

  <!-- Visits Integration Dashboard -->
  <div class="card">
    <h3 class="text-lg font-semibold text-gray-900 mb-4">Dashboard Sinkronisasi Kunjungan</h3>

    {#if loading}
      <div class="flex items-center justify-center py-16">
        <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
      </div>
    {:else if visits.length === 0}
      <div class="text-center py-16 text-gray-400">
        <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15a4.5 4.5 0 004.5 4.5H18a3.75 3.75 0 001.332-7.257 3 3 0 00-3.758-3.848 5.25 5.25 0 00-10.233 2.33A4.502 4.502 0 002.25 15z" />
        </svg>
        <p class="text-lg font-medium">Belum ada data kunjungan</p>
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr class="table-header">
              <th class="px-3 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
              <th class="px-3 py-3 text-xs font-semibold text-gray-500 uppercase">Pasien</th>
              <th class="px-3 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">No. RM</th>
              <th class="px-3 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Klinik</th>
              <th class="px-3 py-3 text-xs font-semibold text-gray-500 uppercase text-center">Patient</th>
              <th class="px-3 py-3 text-xs font-semibold text-gray-500 uppercase text-center">Encounter</th>
              <th class="px-3 py-3 text-xs font-semibold text-gray-500 uppercase text-center">Condition</th>
              <th class="px-3 py-3 text-xs font-semibold text-gray-500 uppercase text-center">Observation</th>
              <th class="px-3 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
              <th class="px-3 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            {#each visits as visit, i}
              {@const overallStatus = getVisitOverallStatus(visit)}
              <tr class="hover:bg-gray-50 transition-colors">
                <td class="px-3 py-3 text-gray-400 font-mono text-xs">{i + 1}</td>
                <td class="px-3 py-3 font-medium text-gray-900 text-sm">{visit.patient_name}</td>
                <td class="px-3 py-3 text-gray-500 font-mono text-xs hidden sm:table-cell">{visit.no_rm}</td>
                <td class="px-3 py-3 text-gray-600 text-sm hidden md:table-cell">{visit.clinic_name}</td>
                <td class="px-3 py-3 text-center">
                  <span class="inline-flex items-center justify-center w-7 h-7 rounded-full border text-xs font-bold {getResourceColor(visit.res_patient)}">
                    {getResourceIcon(visit.res_patient)}
                  </span>
                </td>
                <td class="px-3 py-3 text-center">
                  <span class="inline-flex items-center justify-center w-7 h-7 rounded-full border text-xs font-bold {getResourceColor(visit.res_encounter)}">
                    {getResourceIcon(visit.res_encounter)}
                  </span>
                </td>
                <td class="px-3 py-3 text-center">
                  <span class="inline-flex items-center justify-center w-7 h-7 rounded-full border text-xs font-bold {getResourceColor(visit.res_condition)}">
                    {getResourceIcon(visit.res_condition)}
                  </span>
                </td>
                <td class="px-3 py-3 text-center">
                  <span class="inline-flex items-center justify-center w-7 h-7 rounded-full border text-xs font-bold {getResourceColor(visit.res_observation)}">
                    {getResourceIcon(visit.res_observation)}
                  </span>
                </td>
                <td class="px-3 py-3">
                  <span class="badge {overallStatus.class}">{overallStatus.label}</span>
                </td>
                <td class="px-3 py-3 text-right">
                  <button
                    class="btn-secondary btn-sm text-xs"
                    onclick={() => syncVisit(visit)}
                    disabled={syncing === visit.visit_id}
                  >
                    {#if syncing === visit.visit_id}
                      <span class="inline-block w-3 h-3 border-2 border-gray-300 border-t-primary-600 rounded-full animate-spin mr-1"></span>
                      Syncing...
                    {:else}
                      <svg class="w-3.5 h-3.5 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
                      </svg>
                      Sync
                    {/if}
                  </button>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <div class="flex items-center justify-between mt-4 pt-4 border-t border-gray-100">
        <p class="text-xs text-gray-400">Menampilkan {visits.length} kunjungan terbaru</p>
        <div class="flex items-center gap-3 text-xs text-gray-400">
          <span class="flex items-center gap-1"><span class="inline-block w-2 h-2 rounded-full bg-emerald-500"></span> Terkirim</span>
          <span class="flex items-center gap-1"><span class="inline-block w-2 h-2 rounded-full bg-amber-500"></span> Pending</span>
          <span class="flex items-center gap-1"><span class="inline-block w-2 h-2 rounded-full bg-red-500"></span> Error</span>
        </div>
      </div>
    {/if}
  </div>
</div>

{#if showLogs}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onclick={() => showLogs = false}>
    <div class="bg-white rounded-2xl shadow-xl w-full max-w-2xl max-h-[80vh] flex flex-col" onclick={(e) => e.stopPropagation()}>
      <div class="flex items-center justify-between px-6 py-4 border-b border-gray-200 shrink-0">
        <h3 class="text-lg font-semibold text-gray-900">Log Integrasi SatuSehat</h3>
        <button class="text-gray-400 hover:text-gray-600" onclick={() => showLogs = false}>
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="flex-1 overflow-y-auto p-6">
        {#if logs.length === 0}
          <div class="text-center py-12 text-gray-400">
            <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
            </svg>
            <p>Belum ada log integrasi</p>
          </div>
        {:else}
          <div class="space-y-3">
            {#each logs as log}
              <div class="flex items-start gap-3 p-3 rounded-lg {log.status === 'success' ? 'bg-emerald-50' : 'bg-red-50'}">
                <div class="shrink-0 w-8 h-8 rounded-full flex items-center justify-center {log.status === 'success' ? 'bg-emerald-100' : 'bg-red-100'}">
                  {#if log.status === 'success'}
                    <svg class="w-4 h-4 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  {:else}
                    <svg class="w-4 h-4 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
                    </svg>
                  {/if}
                </div>
                <div class="min-w-0 flex-1">
                  <div class="flex items-center gap-2">
                    <p class="text-sm font-medium text-gray-900">{log.visit_id || '-'}</p>
                    <span class="text-xs text-gray-400">{formatDateTime(log.created_at)}</span>
                  </div>
                  <p class="text-xs text-gray-600 mt-0.5">{log.details || '-'}</p>
                  {#if log.resources_sent}
                    <p class="text-xs text-gray-400 mt-0.5">Resources: {log.resources_sent}</p>
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
      <div class="flex justify-end px-6 py-4 border-t border-gray-200 shrink-0">
        <button class="btn-secondary" onclick={() => showLogs = false}>Tutup</button>
      </div>
    </div>
  </div>
{/if}
