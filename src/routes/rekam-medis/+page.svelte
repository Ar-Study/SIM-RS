<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime } from '$lib/utils/helpers.js';
  import { VISIT_TYPES } from '$lib/utils/constants.js';

  let loading = $state(true);
  let patients = $state([]);
  let totalCount = $state(0);

  let searchQuery = $state('');
  let dateFrom = $state('');
  let dateTo = $state('');

  let currentPage = $state(1);
  const perPage = 15;

  let searchTimeout;

  const totalPages = $derived(Math.ceil(totalCount / perPage));

  let stats = $state({
    totalPasien: 0,
    kunjunganHariIni: 0,
    rawatInapAktif: 0
  });

  function calculateAge(dob) {
    if (!dob) return '-';
    const birth = new Date(dob);
    const today = new Date();
    let age = today.getFullYear() - birth.getFullYear();
    const m = today.getMonth() - birth.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--;
    return age;
  }

  function handleSearch() {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      currentPage = 1;
      fetchPatients();
    }, 300);
  }

  function handleFilter() {
    currentPage = 1;
    fetchPatients();
  }

  function clearFilters() {
    searchQuery = '';
    dateFrom = '';
    dateTo = '';
    currentPage = 1;
    fetchPatients();
  }

  function goToPage(page) {
    if (page < 1 || page > totalPages) return;
    currentPage = page;
    fetchPatients();
  }

  function viewHistory(patientId) {
    goto(`/rekam-medis/${patientId}`);
  }

  async function fetchStats() {
    try {
      const { count: totalPasien, error: err1 } = await supabase
        .from('patients')
        .select('*', { count: 'exact', head: true });

      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayEnd = new Date();
      todayEnd.setHours(23, 59, 59, 999);

      const { count: kunjunganHariIni, error: err2 } = await supabase
        .from('patient_visitations')
        .select('*', { count: 'exact', head: true })
        .gte('visit_date', todayStart.toISOString())
        .lte('visit_date', todayEnd.toISOString());

      const { count: rawatInapAktif, error: err3 } = await supabase
        .from('patient_visitations')
        .select('*', { count: 'exact', head: true })
        .eq('visit_type', 'rawat_inap')
        .is('exit_date', null);

      stats = {
        totalPasien: totalPasien || 0,
        kunjunganHariIni: kunjunganHariIni || 0,
        rawatInapAktif: rawatInapAktif || 0
      };
    } catch (err) {
      console.error('Fetch stats error:', err);
    }
  }

  async function fetchPatients() {
    loading = true;
    try {
      let query = supabase
        .from('patients')
        .select(`
          patient_id,
          no_registration,
          full_name,
          gender,
          date_of_birth,
          phone,
          nik
        `, { count: 'exact' });

      if (searchQuery.trim()) {
        const q = searchQuery.trim();
        query = query.or(`full_name.ilike.%${q}%,no_registration.ilike.%${q}%,nik.ilike.%${q}%`);
      }

      const from = (currentPage - 1) * perPage;
      const to = from + perPage - 1;

      const { data, count, error } = await query
        .order('full_name', { ascending: true })
        .range(from, to);

      if (error) throw error;

      const patientIds = (data || []).map(p => p.patient_id);

      let visitMap = {};
      if (patientIds.length > 0) {
        let visitQuery = supabase
          .from('patient_visitations')
          .select('patient_id, visit_date')
          .in('patient_id', patientIds);

        if (dateFrom) {
          const dayStart = new Date(dateFrom);
          dayStart.setHours(0, 0, 0, 0);
          visitQuery = visitQuery.gte('visit_date', dayStart.toISOString());
        }
        if (dateTo) {
          const dayEnd = new Date(dateTo);
          dayEnd.setHours(23, 59, 59, 999);
          visitQuery = visitQuery.lte('visit_date', dayEnd.toISOString());
        }

        const { data: visits, error: visitErr } = await visitQuery;
        if (!visitErr && visits) {
          visits.forEach(v => {
            if (!visitMap[v.patient_id]) {
              visitMap[v.patient_id] = { count: 0, lastVisit: null };
            }
            visitMap[v.patient_id].count++;
            if (!visitMap[v.patient_id].lastVisit || new Date(v.visit_date) > new Date(visitMap[v.patient_id].lastVisit)) {
              visitMap[v.patient_id].lastVisit = v.visit_date;
            }
          });
        }
      }

      patients = (data || []).map(p => ({
        ...p,
        totalVisits: visitMap[p.patient_id]?.count || 0,
        lastVisit: visitMap[p.patient_id]?.lastVisit || null
      }));

      totalCount = count || 0;
    } catch (err) {
      console.error('Fetch patients error:', err);
      patients = [];
      totalCount = 0;
    } finally {
      loading = false;
    }
  }

  onMount(async () => {
    await Promise.all([fetchPatients(), fetchStats()]);
  });
</script>

<svelte:head>
  <title>Rekam Medis - SIMRS</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Rekam Medis</h1>
      <p class="text-sm text-gray-500 mt-1">Pencarian dan riwayat rekam medis pasien</p>
    </div>
  </div>

  <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-blue-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Total Pasien</p>
          <p class="text-2xl font-bold text-gray-900 mt-0.5">{stats.totalPasien}</p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-emerald-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-emerald-600 uppercase tracking-wide font-medium">Kunjungan Hari Ini</p>
          <p class="text-2xl font-bold text-emerald-600 mt-0.5">{stats.kunjunganHariIni}</p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-amber-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 0 1-2.247 2.118H6.622a2.25 2.25 0 0 1-2.247-2.118L3.75 7.5m8.25 3v6.75m0 0l-3-3m3 3l3-3M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-amber-600 uppercase tracking-wide font-medium">Rawat Inap Aktif</p>
          <p class="text-2xl font-bold text-amber-600 mt-0.5">{stats.rawatInapAktif}</p>
        </div>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <div class="sm:col-span-2 lg:col-span-2">
        <label class="label" for="search">Cari Pasien</label>
        <div class="relative">
          <input
            id="search"
            type="text"
            bind:value={searchQuery}
            oninput={handleSearch}
            placeholder="Nama pasien, No.RM, atau NIK..."
            class="input-field pl-10"
          />
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
          </svg>
        </div>
      </div>
      <div>
        <label class="label" for="dateFrom">Tanggal Dari</label>
        <input
          id="dateFrom"
          type="date"
          bind:value={dateFrom}
          onchange={handleFilter}
          class="input-field"
        />
      </div>
      <div>
        <label class="label" for="dateTo">Tanggal Sampai</label>
        <input
          id="dateTo"
          type="date"
          bind:value={dateTo}
          onchange={handleFilter}
          class="input-field"
        />
      </div>
    </div>
    {#if searchQuery || dateFrom || dateTo}
      <div class="mt-3 flex items-center gap-2">
        <button onclick={clearFilters} class="text-sm text-primary-600 hover:text-primary-700 font-medium flex items-center gap-1">
          <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
          </svg>
          Reset Filter
        </button>
      </div>
    {/if}
  </div>

  <div class="card overflow-hidden p-0">
    <div class="overflow-x-auto">
      {#if loading}
        <div class="flex items-center justify-center py-16">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
        </div>
      {:else if patients.length === 0}
        <div class="flex flex-col items-center justify-center py-16 text-gray-400">
          <svg class="w-14 h-14 mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
          </svg>
          <p class="text-sm font-medium">Tidak ada data pasien ditemukan</p>
          <p class="text-xs text-gray-400 mt-1">Coba kata kunci pencarian lain</p>
        </div>
      {:else}
        <table class="w-full">
          <thead>
            <tr class="table-header">
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No.RM</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pasien</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">JK</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Tgl Lahir</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden xl:table-cell">No.Telp</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell text-center">Total Kunjungan</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Kunjungan Terakhir</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Aksi</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            {#each patients as patient, i}
              <tr class="hover:bg-gray-50 transition-colors">
                <td class="table-cell text-gray-400 font-mono text-xs">{(currentPage - 1) * perPage + i + 1}</td>
                <td class="table-cell">
                  <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">
                    {patient.no_registration || '-'}
                  </span>
                </td>
                <td class="table-cell">
                  <div>
                    <p class="font-medium text-gray-900">{patient.full_name || '-'}</p>
                    {#if patient.nik}
                      <p class="text-xs text-gray-400 font-mono">NIK: {patient.nik}</p>
                    {/if}
                  </div>
                </td>
                <td class="table-cell hidden md:table-cell">
                  <span class="badge {patient.gender === 'L' ? 'badge-info' : 'badge-warning'}">
                    {patient.gender === 'L' ? 'Laki-laki' : patient.gender === 'P' ? 'Perempuan' : '-'}
                  </span>
                </td>
                <td class="table-cell text-gray-500 hidden lg:table-cell text-xs font-mono">
                  {formatDate(patient.date_of_birth)}
                </td>
                <td class="table-cell text-gray-600 hidden xl:table-cell text-xs">
                  {patient.phone || '-'}
                </td>
                <td class="table-cell hidden md:table-cell text-center">
                  <span class="inline-flex items-center justify-center w-8 h-8 rounded-full {patient.totalVisits > 10 ? 'bg-blue-100 text-blue-700' : patient.totalVisits > 3 ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-600'} text-xs font-bold">
                    {patient.totalVisits}
                  </span>
                </td>
                <td class="table-cell text-gray-500 hidden lg:table-cell text-xs">
                  {patient.lastVisit ? formatDateTime(patient.lastVisit) : '-'}
                </td>
                <td class="table-cell">
                  <div class="flex items-center gap-1">
                    <button
                      onclick={() => viewHistory(patient.patient_id)}
                      class="p-1.5 rounded-lg text-primary-600 hover:bg-primary-50 transition-colors"
                      title="Riwayat Rekam Medis"
                    >
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
                      </svg>
                    </button>
                  </div>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>

    {#if !loading && totalCount > perPage}
      <div class="flex flex-col sm:flex-row items-center justify-between gap-4 px-4 py-3 border-t border-gray-200">
        <p class="text-sm text-gray-500">
          Menampilkan {(currentPage - 1) * perPage + 1}-{Math.min(currentPage * perPage, totalCount)} dari {totalCount} data
        </p>
        <div class="flex items-center gap-1">
          <button
            onclick={() => goToPage(currentPage - 1)}
            disabled={currentPage <= 1}
            class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            Sebelumnya
          </button>
          {#each Array(totalPages) as _, idx}
            {@const page = idx + 1}
            {#if page === 1 || page === totalPages || (page >= currentPage - 1 && page <= currentPage + 1)}
              <button
                onclick={() => goToPage(page)}
                class="px-3 py-1.5 text-sm rounded-lg font-medium transition-colors
                  {page === currentPage
                    ? 'bg-primary-600 text-white'
                    : 'border border-gray-300 text-gray-700 hover:bg-gray-50'}"
              >
                {page}
              </button>
            {:else if page === currentPage - 2 || page === currentPage + 2}
              <span class="px-1 text-gray-400">...</span>
            {/if}
          {/each}
          <button
            onclick={() => goToPage(currentPage + 1)}
            disabled={currentPage >= totalPages}
            class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            Selanjutnya
          </button>
        </div>
      </div>
    {/if}
  </div>
</div>
