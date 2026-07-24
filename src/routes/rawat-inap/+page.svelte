<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate } from '$lib/utils/helpers.js';

  let loading = $state(true);
  let inpatients = $state([]);
  let rooms = $state([]);
  let beds = $state([]);
  let selectedClass = $state('');
  let selectedRoomStatus = $state('');
  let searchQuery = $state('');
  let selectedRoom = $state(null);
  let showRoomDetail = $state(false);

  const classOptions = ['', 'VVIP', 'VIP', 'Kelas I', 'Kelas II', 'Kelas III', 'ICU', 'HCU', 'NICU', 'PICU'];

  const stats = $derived({
    total: beds.length,
    terisi: beds.filter(b => b.status === 'occupied').length,
    kosong: beds.filter(b => b.status === 'empty').length,
    okupansi: beds.length > 0 ? Math.round((beds.filter(b => b.status === 'occupied').length / beds.length) * 100) : 0
  });

  const roomCards = $derived.by(() => {
    let result = rooms.map(room => {
      const roomBeds = beds.filter(b => b.room_id === room.room_id);
      const occupied = roomBeds.filter(b => b.status === 'occupied').length;
      const total = roomBeds.length;
      return {
        ...room,
        occupied,
        totalBeds: total,
        status: total === 0 ? 'empty' : occupied === total ? 'full' : 'available'
      };
    });

    if (selectedClass) {
      result = result.filter(r => r.class === selectedClass);
    }
    if (selectedRoomStatus) {
      result = result.filter(r => r.status === selectedRoomStatus);
    }
    return result;
  });

  const filteredInpatients = $derived.by(() => {
    let result = inpatients;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(p =>
        p.patient_name.toLowerCase().includes(q) ||
        p.patient_no?.toLowerCase().includes(q) ||
        p.room_name?.toLowerCase().includes(q) ||
        p.doctor_name?.toLowerCase().includes(q)
      );
    }
    return result;
  });

  function getDaysStayed(inDate) {
    if (!inDate) return 0;
    const start = new Date(inDate).getTime();
    const now = Date.now();
    const diff = Math.floor((now - start) / (1000 * 60 * 60 * 24));
    return Math.max(1, diff + 1);
  }

  function getRoomCardStyle(status) {
    if (status === 'full') return 'border-red-300 bg-red-50';
    if (status === 'available') return 'border-emerald-300 bg-emerald-50';
    return 'border-gray-200 bg-gray-50';
  }

  function getRoomStatusBadge(status) {
    if (status === 'full') return { label: 'Penuh', class: 'badge-danger' };
    if (status === 'available') return { label: 'Tersedia', class: 'badge-success' };
    return { label: 'Kosong', class: 'badge-gray' };
  }

  function selectRoomDetail(room) {
    selectedRoom = room;
    showRoomDetail = true;
  }

  function closeRoomDetail() {
    selectedRoom = null;
    showRoomDetail = false;
  }

  async function fetchRooms() {
    try {
      const { data, error } = await supabase
        .from('rooms')
        .select('room_id, room_number, room_classes:class_id ( name ), is_active')
        .eq('is_active', true)
        .order('room_number');
      if (error) throw error;
      rooms = (data || []).map(room => ({
        ...room,
        name: room.room_number,
        class: (() => {
          const roomClasses = /** @type {any} */ (room.room_classes);
          const roomClass = Array.isArray(roomClasses) ? roomClasses[0] : roomClasses;
          return roomClass?.name || '-';
        })()
      }));
    } catch (err) {
      console.error('Fetch rooms error:', err);
    }
  }

  async function fetchBeds() {
    try {
      const { data, error } = await supabase
        .from('beds')
        .select('*')
        .order('bed_number');
      if (error) throw error;
      beds = (data || []).map(bed => ({
        ...bed,
        bed_no: bed.bed_number
      }));
    } catch (err) {
      console.error('Fetch beds error:', err);
    }
  }

  async function fetchInpatients() {
    try {
      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          visit_id,
          visit_date,
          admission_date:in_date,
          discharge_date:exit_date,
          patient_id,
          room_id,
          bed_id,
          doctor_id,
      
          patients:patient_id ( full_name, no_registration ),
          rooms:room_id ( room_number, room_classes:class_id ( name ) ),
          beds:bed_id ( bed_id, bed_number ),
          doctors:doctor_id ( full_name )
        `)
        .eq('visit_type', 'rawat_inap')
        .is('exit_date', null)
        .order('in_date', { ascending: false });

      if (error) throw error;

      inpatients = (data || []).map(v => {
        const patient = Array.isArray(v.patients) ? v.patients[0] : v.patients;
        const room = Array.isArray(v?.rooms) ? v.rooms[0] : v?.rooms;
        const bed = Array.isArray(v.beds) ? v.beds[0] : v.beds;
        const doctor = Array.isArray(v.doctors) ? v.doctors[0] : v.doctors;
        const roomClasses = /** @type {any} */ (room?.room_classes);
        const roomClass = Array.isArray(roomClasses) ? roomClasses[0] : roomClasses;

        return {
          ...v,
          patient_name: patient?.full_name || '-',
          patient_no: patient?.no_registration || '-',
          room_name: room?.room_number || '-',
          room_class: roomClass?.name || '-',
          bed_id: bed?.bed_number || '-',
          doctor_name: doctor?.full_name || '-',
          days_stayed: getDaysStayed(v.admission_date || v.visit_date)
        };
      });
    } catch (err) {
      console.error('Fetch inpatients error:', err);
    }
  }

  async function refreshAll() {
    loading = true;
    await Promise.all([fetchRooms(), fetchBeds(), fetchInpatients()]);
    loading = false;
  }

  onMount(async () => {
    await refreshAll();
  });
</script>

<svelte:head>
  <title>Rawat Inap - Manajemen Tempat Tidur</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Rawat Inap - Manajemen Tempat Tidur</h1>
      <p class="text-sm text-gray-500 mt-1">Pemantauan okupansi kamar dan pasien rawat inap</p>
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
      <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Total Bed</p>
      <p class="text-2xl font-bold text-gray-900 mt-1">{stats.total}</p>
    </div>
    <div class="card p-4">
      <p class="text-xs text-red-600 uppercase tracking-wide font-medium">Terisi</p>
      <p class="text-2xl font-bold text-red-600 mt-1">{stats.terisi}</p>
    </div>
    <div class="card p-4">
      <p class="text-xs text-emerald-600 uppercase tracking-wide font-medium">Kosong</p>
      <p class="text-2xl font-bold text-emerald-600 mt-1">{stats.kosong}</p>
    </div>
    <div class="card p-4">
      <p class="text-xs text-blue-600 uppercase tracking-wide font-medium">Okupansi</p>
      <p class="text-2xl font-bold text-blue-600 mt-1">{stats.okupansi}%</p>
    </div>
  </div>

  <div class="grid grid-cols-1 xl:grid-cols-3 gap-6">
    <div class="xl:col-span-2 space-y-6">
      <div class="card">
        <div class="flex items-center gap-2 mb-4">
          <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25a2.25 2.25 0 0 1-2.25-2.25v-2.25Z" />
          </svg>
          <h2 class="text-lg font-semibold text-gray-900">Peta Kamar</h2>
        </div>

        <div class="flex flex-col sm:flex-row gap-3 mb-4">
          <div class="w-full sm:w-44">
            <select class="select-field" bind:value={selectedClass}>
              <option value="">Semua Kelas</option>
              {#each classOptions.filter(c => c) as cls}
                <option value={cls}>{cls}</option>
              {/each}
            </select>
          </div>
          <div class="w-full sm:w-44">
            <select class="select-field" bind:value={selectedRoomStatus}>
              <option value="">Semua Status</option>
              <option value="available">Tersedia</option>
              <option value="full">Penuh</option>
              <option value="empty">Kosong</option>
            </select>
          </div>
        </div>

        {#if loading}
          <div class="flex items-center justify-center py-16">
            <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
          </div>
        {:else if roomCards.length === 0}
          <div class="text-center py-16 text-gray-400">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21M3 3h12m-.75 4.5H21m-3.75 3h.008v.008h-.008v-.008Zm0 3h.008v.008h-.008v-.008Zm0 3h.008v.008h-.008v-.008Z" />
            </svg>
            <p class="text-lg font-medium">Tidak ada data kamar</p>
            <p class="text-sm mt-1">Belum ada kamar yang terdaftar</p>
          </div>
        {:else}
          <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
            {#each roomCards as room}
              {@const roomStatus = getRoomStatusBadge(room.status)}
              <button
                class="rounded-xl border-2 p-4 text-left transition-all hover:shadow-md cursor-pointer {getRoomCardStyle(room.status)}"
                onclick={() => selectRoomDetail(room)}
              >
                <div class="flex items-center justify-between mb-2">
                  <span class="font-bold text-gray-900 text-sm">{room.name}</span>
                  <span class="badge {roomStatus.class} text-[10px]">{roomStatus.label}</span>
                </div>
                <p class="text-xs text-gray-500 mb-1">{room.class}</p>
                <div class="flex items-baseline gap-1 mt-2">
                  <span class="text-lg font-bold {room.status === 'full' ? 'text-red-600' : room.status === 'available' ? 'text-emerald-600' : 'text-gray-400'}">
                    {room.occupied}
                  </span>
                  <span class="text-xs text-gray-400">/ {room.totalBeds} tempat tidur</span>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-1.5 mt-2">
                  <div
                    class="h-1.5 rounded-full {room.status === 'full' ? 'bg-red-500' : room.status === 'available' ? 'bg-emerald-500' : 'bg-gray-300'}"
                    style="width: {room.totalBeds > 0 ? (room.occupied / room.totalBeds * 100) : 0}%"
                  ></div>
                </div>
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <div class="card">
        <div class="flex items-center gap-2 mb-4">
          <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z" />
          </svg>
          <h2 class="text-lg font-semibold text-gray-900">Daftar Pasien Rawat Inap</h2>
        </div>

        <div class="flex-1 mb-4">
          <div class="relative">
            <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
            </svg>
            <input
              type="text"
              class="input-field pl-10"
              placeholder="Cari nama pasien, no. RM, kamar, atau dokter..."
              bind:value={searchQuery}
            />
          </div>
        </div>

        <div class="overflow-x-auto">
          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          {:else if filteredInpatients.length === 0}
            <div class="text-center py-16 text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12l8.954-8.955a1.126 1.126 0 0 1 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25" />
              </svg>
              <p class="text-lg font-medium">Tidak ada pasien rawat inap</p>
              <p class="text-sm mt-1">Belum ada pasien yang sedang dirawat</p>
            </div>
          {:else}
            <table class="w-full">
              <thead>
                <tr class="table-header">
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No.RM</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pasien</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Kamar</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Kelas</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Tgl Masuk</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Hari ke-</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Dokter</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredInpatients as ip, i}
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                    <td class="table-cell">
                      <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">
                        {ip.patient_no || '-'}
                      </span>
                    </td>
                    <td class="table-cell">
                      <p class="font-medium text-gray-900">{ip.patient_name}</p>
                    </td>
                    <td class="table-cell text-gray-600 hidden md:table-cell">{ip.room_name}</td>
                    <td class="table-cell hidden lg:table-cell">
                      <span class="badge badge-gray">{ip.room_class}</span>
                    </td>
                    <td class="table-cell text-gray-500 hidden sm:table-cell font-mono text-xs">
                      {formatDate(ip.admission_date || ip.visit_date)}
                    </td>
                    <td class="table-cell">
                      <span class="inline-flex items-center justify-center w-8 h-8 rounded-full {ip.days_stayed > 7 ? 'bg-red-100 text-red-700' : ip.days_stayed > 3 ? 'bg-amber-100 text-amber-700' : 'bg-emerald-100 text-emerald-700'} text-xs font-bold">
                        {ip.days_stayed}
                      </span>
                    </td>
                    <td class="table-cell text-gray-600 hidden lg:table-cell">{ip.doctor_name}</td>
                    <td class="table-cell text-right">
                      <a
                        href="/rawat-inap/{ip.visit_id}"
                        class="btn-primary btn-sm text-xs"
                      >
                        Detail
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
            <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z" />
          </svg>
          <h2 class="text-lg font-semibold text-gray-900">Ringkasan</h2>
        </div>

        <div class="space-y-4">
          <div class="rounded-xl border border-gray-200 overflow-hidden">
            <div class="bg-gradient-to-r from-primary-600 to-primary-700 px-4 py-3">
              <p class="text-white font-semibold text-sm">Okupansi Hari Ini</p>
            </div>
            <div class="p-4">
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm text-gray-600">Terisi / Total</span>
                <span class="text-sm font-bold text-gray-900">{stats.terisi} / {stats.total}</span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-3">
                <div
                  class="h-3 rounded-full transition-all duration-500 {stats.okupansi > 90 ? 'bg-red-500' : stats.okupansi > 70 ? 'bg-amber-500' : 'bg-emerald-500'}"
                  style="width: {stats.okupansi}%"
                ></div>
              </div>
              <p class="text-center text-lg font-bold text-primary-700 mt-2">{stats.okupansi}%</p>
            </div>
          </div>

          <div class="rounded-xl border border-gray-200 p-4">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">Legenda Status Kamar</h3>
            <div class="space-y-2">
              <div class="flex items-center gap-3">
                <div class="w-4 h-4 rounded bg-emerald-100 border border-emerald-300"></div>
                <span class="text-sm text-gray-600">Tersedia - Masih ada tempat tidur kosong</span>
              </div>
              <div class="flex items-center gap-3">
                <div class="w-4 h-4 rounded bg-red-100 border border-red-300"></div>
                <span class="text-sm text-gray-600">Penuh - Semua tempat tidur terisi</span>
              </div>
              <div class="flex items-center gap-3">
                <div class="w-4 h-4 rounded bg-gray-100 border border-gray-200"></div>
                <span class="text-sm text-gray-600">Kosong - Belum ada tempat tidur terdaftar</span>
              </div>
            </div>
          </div>

          <div class="rounded-xl border border-gray-200 p-4">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">Peringatan Okupansi</h3>
            {#if stats.okupansi > 90}
              <div class="bg-red-50 border border-red-200 rounded-lg p-3">
                <div class="flex items-start gap-2">
                  <svg class="w-5 h-5 text-red-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
                  </svg>
                  <div>
                    <p class="text-sm font-medium text-red-800">Okupansi Sangat Tinggi!</p>
                    <p class="text-xs text-red-600 mt-1">Okupansi melebihi 90%. Pertimbangkan untuk menambah kapasitas atau melakukan discharge pasien yang memungkinkan.</p>
                  </div>
                </div>
              </div>
            {:else if stats.okupansi > 70}
              <div class="bg-amber-50 border border-amber-200 rounded-lg p-3">
                <div class="flex items-start gap-2">
                  <svg class="w-5 h-5 text-amber-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
                  </svg>
                  <div>
                    <p class="text-sm font-medium text-amber-800">Okupansi Cukup Tinggi</p>
                    <p class="text-xs text-amber-600 mt-1">Okupansi mendekati batas maksimal. Perlu dipantau secara berkala.</p>
                  </div>
                </div>
              </div>
            {:else}
              <div class="bg-emerald-50 border border-emerald-200 rounded-lg p-3">
                <div class="flex items-start gap-2">
                  <svg class="w-5 h-5 text-emerald-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                  </svg>
                  <div>
                    <p class="text-sm font-medium text-emerald-800">Okupansi Aman</p>
                    <p class="text-xs text-emerald-600 mt-1">Kapasitas kamar masih mencukupi.</p>
                  </div>
                </div>
              </div>
            {/if}
          </div>
        </div>
      </div>
    </div>
  </div>
</div>

{#if showRoomDetail && selectedRoom}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" onclick={closeRoomDetail} role="presentation">
    <div
      class="bg-white rounded-2xl shadow-xl max-w-lg w-full mx-4 max-h-[80vh] overflow-y-auto"
      onclick={(e) => e.stopPropagation()}
      role="dialog"
    >
      <div class="flex items-center justify-between p-5 border-b border-gray-200">
        <div>
          <h3 class="text-lg font-bold text-gray-900">{selectedRoom.name}</h3>
          <p class="text-sm text-gray-500">{selectedRoom.class}</p>
        </div>
        <button class="text-gray-400 hover:text-gray-600 transition-colors" onclick={closeRoomDetail}>
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div class="p-5">
        <div class="grid grid-cols-3 gap-3 mb-5">
          <div class="bg-gray-50 rounded-lg p-3 text-center">
            <p class="text-xs text-gray-500 uppercase">Total Bed</p>
            <p class="text-xl font-bold text-gray-900 mt-1">{selectedRoom.totalBeds}</p>
          </div>
          <div class="bg-red-50 rounded-lg p-3 text-center">
            <p class="text-xs text-red-500 uppercase">Terisi</p>
            <p class="text-xl font-bold text-red-600 mt-1">{selectedRoom.occupied}</p>
          </div>
          <div class="bg-emerald-50 rounded-lg p-3 text-center">
            <p class="text-xs text-emerald-500 uppercase">Kosong</p>
            <p class="text-xl font-bold text-emerald-600 mt-1">{selectedRoom.totalBeds - selectedRoom.occupied}</p>
          </div>
        </div>

        {#if beds.filter(b => b.room_id === selectedRoom.room_id).length > 0}
          <h4 class="text-sm font-semibold text-gray-700 mb-3">Daftar Tempat Tidur</h4>
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-2">
            {#each beds.filter(b => b.room_id === selectedRoom.room_id) as bed}
              <div class="rounded-lg border px-3 py-2 {bed.status === 'occupied' ? 'border-red-200 bg-red-50' : 'border-emerald-200 bg-emerald-50'}">
                <div class="flex items-center justify-between">
                  <span class="text-sm font-semibold text-gray-900">{bed.bed_no}</span>
                  {#if bed.status === 'occupied'}
                    <svg class="w-4 h-4 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
                    </svg>
                  {:else}
                    <svg class="w-4 h-4 text-emerald-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                    </svg>
                  {/if}
                </div>
                <p class="text-xs {bed.status === 'occupied' ? 'text-red-500' : 'text-emerald-500'} mt-0.5">
                  {bed.status === 'occupied' ? 'Terisi' : 'Kosong'}
                </p>
              </div>
            {/each}
          </div>
        {:else}
          <p class="text-sm text-gray-400 text-center py-4">Belum ada data tempat tidur untuk kamar ini</p>
        {/if}
      </div>
    </div>
  </div>
{/if}
