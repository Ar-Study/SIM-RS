<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate } from '$lib/utils/helpers.js';

  let loading = $state(true);
  let nicuPatients = $state([]);
  let beds = $state([]);
  let searchQuery = $state('');

  const filteredPatients = $derived.by(() => {
    let result = nicuPatients;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(p =>
        p.patient_name.toLowerCase().includes(q) ||
        p.patient_no?.toLowerCase().includes(q) ||
        p.mother_name?.toLowerCase().includes(q)
      );
    }
    return result;
  });

  const stats = $derived({
    total: beds.length,
    occupied: beds.filter(b => b.status === 'occupied').length,
    available: beds.filter(b => b.status === 'empty').length,
    patients: nicuPatients.length
  });

  function getDaysStayed(inDate) {
    if (!inDate) return 0;
    const start = new Date(inDate);
    const now = new Date();
    return Math.max(1, Math.floor((now - start) / (1000 * 60 * 60 * 24)) + 1);
  }

  function getConditionBadge(condition) {
    switch (condition) {
      case 'critical': return { label: 'Kritis', class: 'badge-danger' };
      case 'stable': return { label: 'Stabil', class: 'badge-success' };
      case 'improving': return { label: 'Membaik', class: 'badge-info' };
      case 'incubator': return { label: 'Inkubator', class: 'badge-warning' };
      default: return { label: condition || '-', class: 'badge-gray' };
    }
  }

  function getApgarColor(score) {
    if (score >= 7) return 'text-emerald-600';
    if (score >= 4) return 'text-amber-600';
    return 'text-red-600';
  }

  async function fetchBeds() {
    try {
      const { data, error } = await supabase
        .from('beds')
        .select('*, rooms:room_id (room_number, room_classes:class_id (name))')
        .order('bed_number');
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
      }).filter(b => b.rooms?.class === 'NICU');
    } catch (err) {
      console.error('Fetch NICU beds error:', err);
    }
  }

  async function fetchPatients() {
    try {
      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          visit_id,
          admission_date:in_date,
          patient_id,
          room_id,
          doctor_id,
          diagnosis,
          patients:patient_id ( full_name, no_registration, date_of_birth ),
          rooms:room_id ( room_number, room_classes:class_id ( name ) ),
          doctors:doctor_id ( full_name )
        `)
        .eq('visit_type', 'rawat_inap')
        .is('exit_date', null)
        .order('in_date', { ascending: false });
      if (error) throw error;

      const allPatients = (data || []).map(v => ({
        ...v,
        patient_name: v.patients?.full_name || '-',
        patient_no: v.patients?.no_registration || '-',
        room_name: v.rooms?.room_number || '-',
        room_class: (Array.isArray(v.rooms?.room_classes) ? v.rooms.room_classes[0] : v.rooms?.room_classes)?.name || '-',
        doctor_name: v.doctors?.full_name || '-',
        days_stayed: getDaysStayed(v.admission_date),
        condition: 'stable',
        birth_weight: null,
        gestational_age: null,
        apgar_score: null,
        mother_name: '-',
        mother_no: '-'
      }));

      nicuPatients = allPatients.filter(p => p.room_class === 'NICU');
    } catch (err) {
      console.error('Fetch NICU patients error:', err);
    }
  }

  async function refreshAll() {
    loading = true;
    await Promise.all([fetchBeds(), fetchPatients()]);
    loading = false;
  }

  onMount(async () => {
    await refreshAll();
  });
</script>

<svelte:head>
  <title>NICU - Neonatal Intensive Care Unit</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div class="flex items-center gap-3">
      <div class="w-10 h-10 rounded-lg bg-pink-600 flex items-center justify-center">
        <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
        </svg>
      </div>
      <div>
        <h1 class="text-2xl font-bold text-pink-700">Neonatal Intensive Care Unit (NICU)</h1>
        <p class="text-sm text-gray-500 mt-0.5">Pemantauan pasien neonatus dan bed NICU</p>
      </div>
    </div>
    <button class="btn-secondary btn-sm" onclick={refreshAll}>
      <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182" />
      </svg>
      Refresh
    </button>
  </div>

  <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
    <div class="card p-4">
      <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Total Bed NICU</p>
      <p class="text-2xl font-bold text-gray-900 mt-1">{stats.total}</p>
    </div>
    <div class="card p-4 border-red-200 bg-red-50">
      <p class="text-xs text-red-700 uppercase tracking-wide font-medium">Terisi</p>
      <p class="text-2xl font-bold text-red-700 mt-1">{stats.occupied}</p>
    </div>
    <div class="card p-4 border-emerald-200 bg-emerald-50">
      <p class="text-xs text-emerald-700 uppercase tracking-wide font-medium">Kosong</p>
      <p class="text-2xl font-bold text-emerald-700 mt-1">{stats.available}</p>
    </div>
    <div class="card p-4 border-pink-200 bg-pink-50">
      <p class="text-xs text-pink-700 uppercase tracking-wide font-medium">Bayi NICU</p>
      <p class="text-2xl font-bold text-pink-700 mt-1">{stats.patients}</p>
    </div>
  </div>

  {#if beds.length > 0}
    <div class="card">
      <div class="flex items-center gap-2 mb-4">
        <svg class="w-5 h-5 text-pink-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25a2.25 2.25 0 0 1-2.25-2.25v-2.25Z" />
        </svg>
        <h2 class="text-lg font-semibold text-gray-900">Status Bed NICU</h2>
      </div>
      <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-3">
        {#each beds as bed}
          <div class="rounded-xl border-2 p-3 text-center transition-all
            {bed.status === 'occupied' ? 'border-pink-300 bg-pink-50' : 'border-emerald-300 bg-emerald-50'}">
            <p class="font-bold text-sm {bed.status === 'occupied' ? 'text-pink-700' : 'text-emerald-700'}">{bed.bed_no}</p>
            <p class="text-[10px] {bed.status === 'occupied' ? 'text-pink-500' : 'text-emerald-500'} mt-0.5">
              {bed.status === 'occupied' ? 'Terisi' : 'Kosong'}
            </p>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  <div class="card">
    <div class="flex items-center justify-between mb-4">
      <div class="flex items-center gap-2">
        <svg class="w-5 h-5 text-pink-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z" />
        </svg>
        <h2 class="text-lg font-semibold text-gray-900">Bayi di NICU</h2>
      </div>
      <div class="relative">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
        </svg>
        <input type="text" class="input-field pl-10 w-64" placeholder="Cari bayi/ibu..." bind:value={searchQuery} />
      </div>
    </div>

    {#if loading}
      <div class="flex items-center justify-center py-16">
        <div class="w-10 h-10 border-4 border-pink-200 border-t-pink-600 rounded-full animate-spin"></div>
      </div>
    {:else if filteredPatients.length === 0}
      <div class="text-center py-16 text-gray-400">
        <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.182 15.182a4.5 4.5 0 0 1-6.364 0M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0ZM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Z" />
        </svg>
        <p class="text-lg font-medium">Tidak ada bayi di NICU</p>
      </div>
    {:else}
      <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {#each filteredPatients as baby, i}
          {@const condition = getConditionBadge(baby.condition)}
          <div class="rounded-xl border border-gray-200 bg-white p-5 hover:shadow-md transition-shadow">
            <div class="flex items-start justify-between mb-3">
              <div class="flex items-center gap-2">
                <div class="w-10 h-10 rounded-full bg-pink-100 flex items-center justify-center">
                  <svg class="w-5 h-5 text-pink-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.182 15.182a4.5 4.5 0 0 1-6.364 0M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0ZM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Z" />
                  </svg>
                </div>
                <div>
                  <p class="font-semibold text-gray-900 text-sm">{baby.patient_name}</p>
                  <p class="text-xs text-gray-400 font-mono">{baby.patient_no}</p>
                </div>
              </div>
              <span class="badge {condition.class}">{condition.label}</span>
            </div>

            <div class="grid grid-cols-3 gap-2 mb-3">
              <div class="bg-gray-50 rounded-lg p-2 text-center">
                <p class="text-[10px] text-gray-500 uppercase">BB Lahir</p>
                <p class="text-sm font-bold text-gray-900">{baby.birth_weight ? `${baby.birth_weight}g` : '-'}</p>
              </div>
              <div class="bg-gray-50 rounded-lg p-2 text-center">
                <p class="text-[10px] text-gray-500 uppercase">Usia GA</p>
                <p class="text-sm font-bold text-gray-900">{baby.gestational_age ? `${baby.gestational_age}w` : '-'}</p>
              </div>
              <div class="bg-gray-50 rounded-lg p-2 text-center">
                <p class="text-[10px] text-gray-500 uppercase">Apgar</p>
                <p class="text-sm font-bold {getApgarColor(baby.apgar_score)}">{baby.apgar_score ?? '-'}</p>
              </div>
            </div>

            <div class="space-y-1.5 text-xs text-gray-600 mb-3">
              <div class="flex items-center gap-2">
                <svg class="w-3.5 h-3.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21M3 3h12m-.75 4.5H21" />
                </svg>
                <span>{baby.room_name}</span>
              </div>
              <div class="flex items-center gap-2">
                <svg class="w-3.5 h-3.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
                </svg>
                <span>Dokter: {baby.doctor_name}</span>
              </div>
              <div class="flex items-center gap-2">
                <svg class="w-3.5 h-3.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5" />
                </svg>
                <span>Hari ke-{baby.days_stayed}</span>
              </div>
            </div>

            {#if baby.mother_name && baby.mother_name !== '-'}
              <div class="bg-pink-50 rounded-lg p-2 mb-3">
                <p class="text-[10px] text-pink-600 uppercase font-medium mb-0.5">Ibu</p>
                <p class="text-xs text-pink-800 font-medium">{baby.mother_name}</p>
                <p class="text-[10px] text-pink-600 font-mono">{baby.mother_no}</p>
              </div>
            {/if}

            <div class="flex gap-2">
              <a href="/rawat-inap/{baby.visit_id}" class="btn-primary btn-sm text-xs flex-1 text-center">Detail</a>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>
