<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime } from '$lib/utils/helpers.js';
  import { PAYOR_TYPES } from '$lib/utils/constants.js';

  let loading = $state(true);
  let activeTab = $state('vclaim');

  let seps = $state([]);
  let beds = $state([]);
  let mobileJknQueue = $state([]);
  let showBuatSep = $state(false);
  let showUpdateBed = $state(false);
  let saving = $state(false);
  let searchQuery = $state('');
  let searchResults = $state([]);

  let newSep = $state({
    no_rkm_medis: '',
    patient_name: '',
    no_kartu: '',
    tgl_sep: new Date().toISOString().split('T')[0],
    poli: '',
    diagnosis: '',
    dpjp: '',
    catatan: ''
  });

  let updateBedData = $state({
    kamar: '',
    kelas: '',
    total: 0,
    terisi: 0,
    tersedia: 0
  });

  let filteredSeps = $derived.by(() => {
    if (!searchQuery) return seps;
    const q = searchQuery.toLowerCase();
    return seps.filter(s =>
      (s.patient_name || '').toLowerCase().includes(q) ||
      (s.no_rkm_medis || '').toLowerCase().includes(q) ||
      (s.no_sep || '').toLowerCase().includes(q) ||
      (s.no_kartu || '').toLowerCase().includes(q)
    );
  });

  let sepsToday = $derived(seps.filter(s => {
    const d = new Date(s.tgl_sep);
    const today = new Date();
    return d.toDateString() === today.toDateString();
  }).length);

  function getSepStatus(status) {
    if (status === 'active') return { label: 'Aktif', class: 'badge-success' };
    if (status === 'closed') return { label: 'Selesai', class: 'badge-gray' };
    if (status === 'cancelled') return { label: 'Dibatalkan', class: 'badge-danger' };
    return { label: 'Pending', class: 'badge-warning' };
  }

  async function fetchSEPs() {
    try {
      const { data, error } = await supabase
        .from('bpjs_sep')
        .select(`
          *,
          patient_visitations:visit_id (
            visit_id,
            ticket_no,
            patients:patient_id ( full_name, no_registration, no_bpjs )
          )
        `)
        .order('created_at', { ascending: false });
      if (error) throw error;
      seps = (data || []).map(s => ({
        ...s,
        patient_name: s.patient_visitations?.patients?.full_name || '-',
        no_rkm_medis: s.patient_visitations?.patients?.no_registration || '-',
        no_kartu: s.patient_visitations?.patients?.no_bpjs || s.no_kartu || '-',
        visit_id: s.visit_id
      }));
    } catch (err) {
      console.error('Fetch SEP error:', err);
    }
  }

  async function fetchBeds() {
    try {
      const { data, error } = await supabase
        .from('room_classes')
        .select(`
          class_id,
          name,
          rooms:rooms (
            room_id,
            name,
            beds:beds (
              bed_id,
              is_occupied,
              is_active
            )
          )
        `);
      if (error) throw error;
      beds = (data || []).flatMap(rc =>
        (rc.rooms || []).map(room => {
          const allBeds = (room.beds || []).filter(b => b.is_active);
          const occupied = allBeds.filter(b => b.is_occupied);
          return {
            kamar: room.name,
            kelas: rc.name,
            total: allBeds.length,
            terisi: occupied.length,
            tersedia: allBeds.length - occupied.length
          };
        }).filter(r => r.total > 0)
      );
    } catch (err) {
      console.error('Fetch beds error:', err);
    }
  }

  async function fetchMobileJknQueue() {
    try {
      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          visit_id,
          visit_date,
          ticket_no,
          source,
          patients:patient_id ( full_name, no_registration ),
          clinics:clinic_id ( name )
        `)
        .eq('source', 'mobile_jkn')
        .order('visit_date', { ascending: false })
        .limit(50);
      if (error) throw error;
      mobileJknQueue = (data || []).map(v => ({
        ...v,
        patient_name: v.patients?.full_name || '-',
        no_rm: v.patients?.no_registration || '-',
        poli: v.clinics?.name || '-'
      }));
    } catch (err) {
      console.error('Fetch Mobile JKN error:', err);
    }
  }

  async function searchPatients() {
    if (searchQuery.length < 2) {
      searchResults = [];
      return;
    }
    try {
      const { data } = await supabase
        .from('patients')
        .select('patient_id, full_name, no_registration, no_bpjs, gender, birth_date')
        .or(`full_name.ilike.%${searchQuery}%,no_registration.ilike.%${searchQuery}%,no_bpjs.ilike.%${searchQuery}%`)
        .limit(10);
      searchResults = data || [];
    } catch (err) {
      console.error('Search error:', err);
    }
  }

  function selectPatient(patient) {
    newSep.no_rkm_medis = patient.no_registration;
    newSep.patient_name = patient.full_name;
    newSep.no_kartu = patient.no_bpjs || '';
    searchQuery = patient.full_name;
    searchResults = [];
  }

  async function createSEP() {
    if (!newSep.no_rkm_medis || !newSep.patient_name) return;
    saving = true;
    try {
      const { error } = await supabase
        .from('bpjs_sep')
        .insert({
          no_sep: `SEP-${Date.now().toString(36).toUpperCase()}`,
          no_rkm_medis: newSep.no_rkm_medis,
          no_kartu: newSep.no_kartu,
          tgl_sep: newSep.tgl_sep,
          poli: newSep.poli,
          diagnosa: newSep.diagnosis,
          dpjp: newSep.dpjp,
          catatan: newSep.catatan,
          status: 'active'
        });
      if (error) throw error;
      showBuatSep = false;
      newSep = { no_rkm_medis: '', patient_name: '', no_kartu: '', tgl_sep: new Date().toISOString().split('T')[0], poli: '', diagnosis: '', dpjp: '', catatan: '' };
      searchQuery = '';
      await fetchSEPs();
    } catch (err) {
      console.error('Create SEP error:', err);
    } finally {
      saving = false;
    }
  }

  async function cancelSep(sep) {
    if (!confirm(`Batalkan SEP ${sep.no_sep}?`)) return;
    try {
      const { error } = await supabase
        .from('bpjs_sep')
        .update({ status: 'cancelled' })
        .eq('id', sep.id);
      if (error) throw error;
      await fetchSEPs();
    } catch (err) {
      console.error('Cancel SEP error:', err);
    }
  }

  onMount(async () => {
    loading = true;
    await Promise.all([fetchSEPs(), fetchBeds(), fetchMobileJknQueue()]);
    loading = false;
  });
</script>

<svelte:head>
  <title>Bridging BPJS Kesehatan - SIMRS</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Bridging BPJS Kesehatan</h1>
      <p class="text-sm text-gray-500 mt-1">Integrasi VClaim, Aplicare, dan Mobile JKN</p>
    </div>
  </div>

  <div class="card p-0">
    <div class="flex overflow-x-auto border-b border-gray-200 scrollbar-thin">
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'vclaim'
            ? 'border-primary-600 text-primary-700 bg-primary-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => activeTab = 'vclaim'}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m9.86-2.06a4.5 4.5 0 00-1.242-7.244l-4.5-4.5a4.5 4.5 0 00-6.364 6.364L4.34 8.374" />
        </svg>
        VClaim (SEP)
      </button>
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'aplicare'
            ? 'border-primary-600 text-primary-700 bg-primary-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => activeTab = 'aplicare'}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15a4.5 4.5 0 004.5 4.5H18a3.75 3.75 0 001.332-7.257 3 3 0 00-3.758-3.848 5.25 5.25 0 00-10.233 2.33A4.502 4.502 0 002.25 15z" />
        </svg>
        Aplicare
      </button>
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'mobilejkn'
            ? 'border-primary-600 text-primary-700 bg-primary-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => activeTab = 'mobilejkn'}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3" />
        </svg>
        Mobile JKN
      </button>
    </div>

    <div class="p-6">
      {#if activeTab === 'vclaim'}
        <div class="space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div class="flex items-center gap-3">
              <h3 class="text-lg font-semibold text-gray-900">SEP (Surat Elegibilitas Peserta)</h3>
              <span class="badge badge-info">{sepsToday} hari ini</span>
            </div>
            <div class="flex gap-2">
              <div class="relative">
                <input
                  type="text"
                  class="input-field text-sm pl-9 w-64"
                  placeholder="Cari nama, no RM, no kartu..."
                  bind:value={searchQuery}
                  oninput={() => searchPatients()}
                />
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
                </svg>
                {#if searchResults.length > 0}
                  <div class="absolute z-20 top-full mt-1 w-full bg-white rounded-lg shadow-lg border border-gray-200 max-h-60 overflow-y-auto">
                    {#each searchResults as patient}
                      <button
                        class="w-full text-left px-3 py-2 hover:bg-gray-50 text-sm border-b border-gray-100 last:border-0"
                        onclick={() => selectPatient(patient)}
                      >
                        <p class="font-medium text-gray-900">{patient.full_name}</p>
                        <p class="text-xs text-gray-400">RM: {patient.no_registration} | BPJS: {patient.no_bpjs || '-'}</p>
                      </button>
                    {/each}
                  </div>
                {/if}
              </div>
              <button class="btn-primary btn-sm" onclick={() => showBuatSep = true}>
                <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
                Buat SEP
              </button>
            </div>
          </div>

          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          {:else if filteredSeps.length === 0}
            <div class="text-center py-16 text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m9.86-2.06a4.5 4.5 0 00-1.242-7.244l-4.5-4.5a4.5 4.5 0 00-6.364 6.364L4.34 8.374" />
              </svg>
              <p class="text-lg font-medium">Tidak ada data SEP</p>
              <p class="text-sm mt-1">Klik "Buat SEP" untuk membuat surat elegibilitas baru</p>
            </div>
          {:else}
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="table-header">
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No. SEP</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No. RM</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Peserta</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">No. Kartu BPJS</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tgl SEP</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Poli Tujuan</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden xl:table-cell">Diagnosa</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  {#each filteredSeps as sep, i}
                    {@const status = getSepStatus(sep.status)}
                    <tr class="hover:bg-gray-50 transition-colors">
                      <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                      <td class="table-cell">
                        <span class="font-mono text-xs font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">
                          {sep.no_sep}
                        </span>
                      </td>
                      <td class="table-cell text-gray-500 font-mono text-xs">{sep.no_rkm_medis}</td>
                      <td class="table-cell font-medium text-gray-900">{sep.patient_name}</td>
                      <td class="table-cell text-gray-500 font-mono text-xs hidden md:table-cell">{sep.no_kartu}</td>
                      <td class="table-cell text-gray-500 text-xs">{formatDate(sep.tgl_sep)}</td>
                      <td class="table-cell text-gray-600 hidden lg:table-cell">{sep.poli || '-'}</td>
                      <td class="table-cell text-gray-600 hidden xl:table-cell max-w-[150px] truncate">{sep.diagnosa || '-'}</td>
                      <td class="table-cell">
                        <span class="badge {status.class}">{status.label}</span>
                      </td>
                      <td class="table-cell text-right">
                        {#if sep.status === 'active'}
                          <button class="text-gray-400 hover:text-red-600 transition-colors" onclick={() => cancelSep(sep)} title="Batalkan">
                            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                            </svg>
                          </button>
                        {/if}
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </div>

      {:else if activeTab === 'aplicare'}
        <div class="space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <h3 class="text-lg font-semibold text-gray-900">Ketersediaan Tempat Tidur (Aplicare)</h3>
            <button class="btn-primary btn-sm" onclick={() => showUpdateBed = true}>
              <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
              </svg>
              Update Ketersediaan
            </button>
          </div>

          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          {:else if beds.length === 0}
            <div class="text-center py-16 text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5m8.25 3v6.75m0 0l-3-3m3 3l3-3M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
              </svg>
              <p class="text-lg font-medium">Belum ada data kamar</p>
            </div>
          {:else}
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {#each beds as bed}
                {@const pct = bed.total > 0 ? Math.round((bed.terisi / bed.total) * 100) : 0}
                <div class="card">
                  <div class="flex items-center justify-between mb-3">
                    <div>
                      <p class="font-semibold text-gray-900">{bed.kamar}</p>
                      <p class="text-xs text-gray-500">Kelas {bed.kelas}</p>
                    </div>
                    <span class="badge {pct >= 90 ? 'badge-danger' : pct >= 70 ? 'badge-warning' : 'badge-success'}">
                      {pct}% terisi
                    </span>
                  </div>
                  <div class="grid grid-cols-3 gap-3 text-center">
                    <div class="bg-blue-50 rounded-lg py-2">
                      <p class="text-lg font-bold text-blue-700">{bed.total}</p>
                      <p class="text-[10px] text-blue-500 uppercase">Total</p>
                    </div>
                    <div class="bg-amber-50 rounded-lg py-2">
                      <p class="text-lg font-bold text-amber-700">{bed.terisi}</p>
                      <p class="text-[10px] text-amber-500 uppercase">Terisi</p>
                    </div>
                    <div class="bg-emerald-50 rounded-lg py-2">
                      <p class="text-lg font-bold text-emerald-700">{bed.tersedia}</p>
                      <p class="text-[10px] text-emerald-500 uppercase">Tersedia</p>
                    </div>
                  </div>
                  <div class="mt-3 w-full bg-gray-100 rounded-full h-2">
                    <div class="h-2 rounded-full transition-all duration-500 {pct >= 90 ? 'bg-red-500' : pct >= 70 ? 'bg-amber-500' : 'bg-emerald-500'}"
                      style="width: {pct}%"></div>
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        </div>

      {:else if activeTab === 'mobilejkn'}
        <div class="space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <h3 class="text-lg font-semibold text-gray-900">Antrian Mobile JKN</h3>
            <button class="btn-secondary btn-sm" onclick={fetchMobileJknQueue}>
              <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
              </svg>
              Refresh
            </button>
          </div>

          <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div class="flex items-start gap-3">
              <svg class="w-5 h-5 text-blue-600 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" />
              </svg>
              <div>
                <p class="text-sm font-medium text-blue-800">Pendaftaran dari Mobile JKN</p>
                <p class="text-xs text-blue-600 mt-1">Pasien yang mendaftar melalui aplikasi Mobile JKN akan muncul di sini. Proses registrasi dan antrian dilakukan secara otomatis.</p>
              </div>
            </div>
          </div>

          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          {:else if mobileJknQueue.length === 0}
            <div class="text-center py-16 text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3" />
              </svg>
              <p class="text-lg font-medium">Belum ada pendaftaran Mobile JKN</p>
              <p class="text-sm mt-1">Antrian akan muncul saat pasien mendaftar melalui aplikasi</p>
            </div>
          {:else}
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="table-header">
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pasien</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">No. RM</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Poli</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">No. Antrian</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tgl Kunjungan</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  {#each mobileJknQueue as item, i}
                    <tr class="hover:bg-gray-50 transition-colors">
                      <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                      <td class="table-cell font-medium text-gray-900">{item.patient_name}</td>
                      <td class="table-cell text-gray-500 font-mono text-xs hidden sm:table-cell">{item.no_rm}</td>
                      <td class="table-cell text-gray-600">{item.poli}</td>
                      <td class="table-cell hidden md:table-cell">
                        <span class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-primary-100 text-primary-700 text-sm font-bold">
                          {item.ticket_no || '-'}
                        </span>
                      </td>
                      <td class="table-cell text-gray-500 text-xs">{formatDateTime(item.visit_date)}</td>
                      <td class="table-cell">
                        <span class="badge {item.status_keluar === '1' ? 'badge-success' : item.status_periksa === '1' ? 'badge-info' : 'badge-warning'}">
                          {item.status_keluar === '1' ? 'Selesai' : item.status_periksa === '1' ? 'Diperiksa' : 'Menunggu'}
                        </span>
                      </td>
                      <td class="table-cell text-right">
                        {#if item.status_keluar !== '1'}
                          <a
                            href="/rawat-jalan/{item.visit_id}"
                            class="text-primary-600 hover:text-primary-700 transition-colors"
                            title="Buka Kunjungan"
                          >
                            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25" />
                            </svg>
                          </a>
                        {/if}
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </div>
      {/if}
    </div>
  </div>
</div>

{#if showBuatSep}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onclick={() => showBuatSep = false}>
    <div class="bg-white rounded-2xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto" onclick={(e) => e.stopPropagation()}>
      <div class="flex items-center justify-between px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">Buat SEP Baru</h3>
        <button class="text-gray-400 hover:text-gray-600" onclick={() => showBuatSep = false}>
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="p-6 space-y-4">
        <div class="space-y-1">
          <label class="label">No. RM / Nama Pasien</label>
          <input type="text" class="input-field" bind:value={newSep.patient_name} placeholder="Cari pasien..." />
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-1">
            <label class="label">No. Kartu BPJS</label>
            <input type="text" class="input-field" bind:value={newSep.no_kartu} placeholder="0001234567890" />
          </div>
          <div class="space-y-1">
            <label class="label">Tanggal SEP</label>
            <input type="date" class="input-field" bind:value={newSep.tgl_sep} />
          </div>
        </div>
        <div class="space-y-1">
          <label class="label">Poli Tujuan</label>
          <input type="text" class="input-field" bind:value={newSep.poli} placeholder="Poli Umum" />
        </div>
        <div class="space-y-1">
          <label class="label">Diagnosa (ICD-10)</label>
          <input type="text" class="input-field" bind:value={newSep.diagnosis} placeholder="Kode + Nama Diagnosa" />
        </div>
        <div class="space-y-1">
          <label class="label">DPJP</label>
          <input type="text" class="input-field" bind:value={newSep.dpjp} placeholder="Nama Dokter Penanggung Jawab Pelayanan" />
        </div>
        <div class="space-y-1">
          <label class="label">Catatan (opsional)</label>
          <textarea class="input-field h-20 resize-none" bind:value={newSep.catatan} placeholder="Catatan tambahan..."></textarea>
        </div>
      </div>
      <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200">
        <button class="btn-secondary" onclick={() => showBuatSep = false}>Batal</button>
        <button class="btn-primary" onclick={createSEP} disabled={saving || !newSep.patient_name.trim()}>
          {#if saving}
            <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
          {/if}
          Buat SEP
        </button>
      </div>
    </div>
  </div>
{/if}

{#if showUpdateBed}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onclick={() => showUpdateBed = false}>
    <div class="bg-white rounded-2xl shadow-xl w-full max-w-md max-h-[90vh] overflow-y-auto" onclick={(e) => e.stopPropagation()}>
      <div class="flex items-center justify-between px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">Update Ketersediaan Bed</h3>
        <button class="text-gray-400 hover:text-gray-600" onclick={() => showUpdateBed = false}>
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="p-6 space-y-4">
        <p class="text-sm text-gray-500">
          Ketersediaan bed akan diperbarui dan dikirimkan ke sistem Aplicare secara otomatis.
        </p>
        <div class="bg-gray-50 rounded-lg p-4 text-center">
          <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15a4.5 4.5 0 004.5 4.5H18a3.75 3.75 0 001.332-7.257 3 3 0 00-3.758-3.848 5.25 5.25 0 00-10.233 2.33A4.502 4.502 0 002.25 15z" />
          </svg>
          <p class="text-sm text-gray-500">Data bed saat ini akan dikirim ulang ke Aplicare</p>
        </div>
      </div>
      <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200">
        <button class="btn-secondary" onclick={() => showUpdateBed = false}>Batal</button>
        <button class="btn-primary" onclick={() => { showUpdateBed = false; }}>
          <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
          </svg>
          Kirim ke Aplicare
        </button>
      </div>
    </div>
  </div>
{/if}
