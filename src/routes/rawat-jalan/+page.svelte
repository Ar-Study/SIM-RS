<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDateTime } from '$lib/utils/helpers.js';

  let loading = $state(true);
  let visits = $state([]);
  let clinics = $state([]);
  let selectedClinic = $state('');
  let searchQuery = $state('');
  let queueBoard = $state([]);
  let now = $state(new Date());
  let timer;

  const filteredVisits = $derived.by(() => {
    let result = visits;
    if (selectedClinic) {
      result = result.filter(v => v.clinic_id === selectedClinic);
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(v =>
        v.patient_name.toLowerCase().includes(q) ||
        v.ticket_no?.toLowerCase().includes(q) ||
        v.clinic_name?.toLowerCase().includes(q) ||
        v.doctor_name?.toLowerCase().includes(q)
      );
    }
    return result;
  });

  const stats = $derived({
    total: visits.length,
    menunggu: visits.filter(v => v.status_periksa === '0' && v.status_keluar === '0').length,
    diperiksa: visits.filter(v => v.status_periksa === '1' && v.status_keluar === '0').length,
    selesai: visits.filter(v => v.status_keluar === '1').length
  });

  const formattedDate = $derived(
    now.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
  );

  function getStatusConfig(visit) {
    if (visit.status_keluar === '1') return { label: 'Selesai', class: 'badge-info' };
    if (visit.status_periksa === '1') return { label: 'Diperiksa', class: 'badge-success' };
    return { label: 'Menunggu', class: 'badge-warning' };
  }

  function getVisitTime(dateStr) {
    if (!dateStr) return '-';
    const d = new Date(dateStr);
    return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
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
          call_times,
          patient_id,
          clinic_id,
          doctor_id,
          patients:patient_id ( full_name, no_registration ),
          clinics:clinic_id ( name ),
          employees:doctor_id ( fullname ) 
        `)
        .eq('visit_type', 'rawat_jalan')
        .gte('visit_date', todayStart.toISOString())
        .lte('visit_date', todayEnd.toISOString())
        .order('visit_date', { ascending: true });

      if (error) throw error;

      // REVISI: Sesuaikan pemetaan dengan perubahan nama kolom di atas
      visits = (data || []).map(v => ({
        ...v,
        patient_name: v.patients?.full_name || '-',
        patient_no: v.patients?.no_registration || '-',
        clinic_name: v.clinics?.name || '-',
        doctor_name: v.employees?.fullname || '-' 
      }));
    } catch (err) {
      console.error('Fetch visits error:', err);
    }
  }

  async function fetchClinics() {
    try {
      const { data, error } = await supabase
        .from('clinics')
        .select('clinic_id, name')
        .eq('is_active', true)
        .order('name');

      if (error) throw error;
      clinics = data || [];
    } catch (err) {
      console.error('Fetch clinics error:', err);
    }
  }

  async function buildQueueBoard() {
    const poliMap = {};
    visits.forEach(v => {
      if (!poliMap[v.clinic_id]) {
        poliMap[v.clinic_id] = {
          clinic_id: v.clinic_id,
          clinic_name: v.clinic_name,
          tickets: [],
          current_call: null,
          total_waiting: 0
        };
      }
      poliMap[v.clinic_id].tickets.push(v);
    });

    queueBoard = Object.values(poliMap).map(poli => {
      const waiting = poli.tickets.filter(v => v.status_keluar === '0');
      const menunggu = waiting.filter(v => v.status_periksa === '0')
        .sort((a, b) => (a.call_times || 0) - (b.call_times || 0));
      const diperiksa = waiting.filter(v => v.status_periksa === '1');

      let currentCall = null;
      if (diperiksa.length > 0) {
        currentCall = diperiksa[0];
      } else if (menunggu.length > 0) {
        currentCall = menunggu[0];
      }

      return {
        clinic_id: poli.clinic_id,
        clinic_name: poli.clinic_name,
        current_call: currentCall,
        current_ticket: currentCall?.ticket_no || '-',
        patient_name: currentCall?.patient_name || '-',
        total_waiting: menunggu.length,
        next_ticket: menunggu.length > 0 ? menunggu[0].ticket_no : null
      };
    });
  }

  async function callNext(visitId) {
    try {
      const visit = visits.find(v => v.visit_id === visitId);
      if (!visit) return;

      const newCallTimes = (visit.call_times || 0) + 1;

      const { error } = await supabase
        .from('patient_visitations')
        .update({
          call_times: newCallTimes,
          status_periksa: '1'
        })
        .eq('visit_id', visitId);

      if (error) throw error;

      await refreshAll();
    } catch (err) {
      console.error('Call next error:', err);
    }
  }

  async function refreshAll() {
    await fetchVisits();
    await buildQueueBoard();
  }

  onMount(async () => {
    loading = true;
    await Promise.all([fetchVisits(), fetchClinics()]);
    await buildQueueBoard();
    loading = false;

    timer = setInterval(() => {
      now = new Date();
    }, 1000);

    return () => clearInterval(timer);
  });

  $effect(() => {
    if (visits.length >= 0) {
      buildQueueBoard();
    }
  });
</script>

<svelte:head>
  <title>Rawat Jalan - Antrian Hari Ini</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Rawat Jalan - Antrian Hari Ini</h1>
      <p class="text-sm text-gray-500 mt-1">{formattedDate}</p>
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

  <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
    <div class="card p-4">
      <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Total</p>
      <p class="text-2xl font-bold text-gray-900 mt-1">{stats.total}</p>
    </div>
    <div class="card p-4">
      <p class="text-xs text-amber-600 uppercase tracking-wide font-medium">Menunggu</p>
      <p class="text-2xl font-bold text-amber-600 mt-1">{stats.menunggu}</p>
    </div>
    <div class="card p-4">
      <p class="text-xs text-emerald-600 uppercase tracking-wide font-medium">Diperiksa</p>
      <p class="text-2xl font-bold text-emerald-600 mt-1">{stats.diperiksa}</p>
    </div>
    <div class="card p-4">
      <p class="text-xs text-blue-600 uppercase tracking-wide font-medium">Selesai</p>
      <p class="text-2xl font-bold text-blue-600 mt-1">{stats.selesai}</p>
    </div>
  </div>

  <div class="grid grid-cols-1 xl:grid-cols-3 gap-6">
    <div class="xl:col-span-2 space-y-4">
      <div class="card">
        <div class="flex flex-col sm:flex-row sm:items-center gap-3 mb-4">
          <div class="flex-1">
            <div class="relative">
              <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
              </svg>
              <input
                type="text"
                class="input-field pl-10"
                placeholder="Cari nama pasien, tiket, poli, atau dokter..."
                bind:value={searchQuery}
              />
            </div>
          </div>
          <div class="w-full sm:w-56">
            <select class="select-field" bind:value={selectedClinic}>
              <option value="">Semua Poli</option>
              {#each clinics as clinic}
                <option value={clinic.clinic_id}>{clinic.name}</option>
              {/each}
            </select>
          </div>
        </div>

        <div class="overflow-x-auto">
          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          {:else if filteredVisits.length === 0}
            <div class="text-center py-16 text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 0 1 0 3.75H5.625a1.875 1.875 0 0 1 0-3.75Z" />
              </svg>
              <p class="text-lg font-medium">Tidak ada antrian</p>
              <p class="text-sm mt-1">Belum ada pasien rawat jalan hari ini</p>
            </div>
          {:else}
            <table class="w-full">
              <thead>
                <tr class="table-header">
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tiket</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pasien</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Poli</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Dokter</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Jam Datang</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredVisits as visit, i}
                  {@const status = getStatusConfig(visit)}
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                    <td class="table-cell">
                      <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">
                        {visit.ticket_no || '-'}
                      </span>
                    </td>
                    <td class="table-cell">
                      <div>
                        <p class="font-medium text-gray-900">{visit.patient_name}</p>
                        <p class="text-xs text-gray-400 font-mono">{visit.patient_no}</p>
                      </div>
                    </td>
                    <td class="table-cell text-gray-600 hidden md:table-cell">{visit.clinic_name}</td>
                    <td class="table-cell text-gray-600 hidden lg:table-cell">{visit.doctor_name}</td>
                    <td class="table-cell text-gray-500 hidden sm:table-cell font-mono text-xs">{getVisitTime(visit.visit_date)}</td>
                    <td class="table-cell">
                      <span class="badge {status.class}">{status.label}</span>
                    </td>
                    <td class="table-cell text-right">
                      <a
                        href="/rawat-jalan/{visit.visit_id}"
                        class="btn-primary btn-sm text-xs"
                      >
                        Periksa
                      </a>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          {/if}
        </div>
      </div>
    </div>

    <div class="xl:col-span-1">
      <div class="card sticky top-24">
        <div class="flex items-center gap-2 mb-5">
          <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 0 0 6 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0 1 18 16.5h-2.25m-7.5 0h7.5m-7.5 0-1 3m8.5-3 1 3m0 0 .5 1.5m-.5-1.5h-9.5m0 0-.5 1.5M9 11.25v1.5M12 9v3.75m3-6v6" />
          </svg>
          <h2 class="text-lg font-semibold text-gray-900">Papan Antrian</h2>
        </div>

        {#if loading}
          <div class="flex items-center justify-center py-12">
            <div class="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
          </div>
        {:else if queueBoard.length === 0}
          <div class="text-center py-12 text-gray-400">
            <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 0 0 6 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0 1 18 16.5h-2.25m-7.5 0h7.5m-7.5 0-1 3m8.5-3 1 3m0 0 .5 1.5m-.5-1.5h-9.5m0 0-.5 1.5" />
            </svg>
            <p class="font-medium">Belum ada data poli</p>
          </div>
        {:else}
          <div class="space-y-4 max-h-[calc(100vh-20rem)] overflow-y-auto scrollbar-thin pr-1">
            {#each queueBoard as poli}
              <div class="rounded-xl border border-gray-200 overflow-hidden">
                <div class="bg-gradient-to-r from-primary-600 to-primary-700 px-4 py-3">
                  <p class="text-white font-semibold text-sm">{poli.clinic_name}</p>
                  <p class="text-primary-200 text-xs">{poli.total_waiting} menunggu</p>
                </div>

                <div class="p-4 bg-gray-50">
                  {#if poli.current_call && poli.current_ticket !== '-'}
                    <div class="text-center mb-3">
                      <p class="text-xs text-gray-500 uppercase tracking-wide mb-1">Sedang Dipanggil</p>
                      <p class="text-4xl font-bold text-primary-600 font-mono leading-none">{poli.current_ticket}</p>
                      <p class="text-sm text-gray-600 mt-1">{poli.patient_name}</p>
                    </div>
                  {:else}
                    <div class="text-center mb-3">
                      <p class="text-xs text-gray-400 uppercase tracking-wide">Belum Ada</p>
                      <p class="text-2xl font-bold text-gray-300 mt-1">-</p>
                    </div>
                  {/if}

                  {#if poli.total_waiting > 0}
                    <button
                      class="w-full btn-success btn-sm text-xs flex items-center justify-center gap-2"
                      onclick={() => poli.current_call && callNext(poli.current_call.visit_id)}
                    >
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0" />
                      </svg>
                      Panggil
                    </button>
                  {:else}
                    <button class="w-full btn-secondary btn-sm text-xs" disabled>
                      Antrian Kosong
                    </button>
                  {/if}

                  {#if poli.next_ticket && poli.next_ticket !== poli.current_ticket}
                    <p class="text-center text-xs text-gray-400 mt-2">
                      Berikutnya: <span class="font-mono font-semibold text-gray-600">{poli.next_ticket}</span>
                    </p>
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>
