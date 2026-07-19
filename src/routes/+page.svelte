<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { getCurrentUser } from '$lib/auth.js';
  import { formatCurrency } from '$lib/utils/helpers.js';
  import { VISIT_TYPES } from '$lib/utils/constants.js';

  let user = $state(null);
  let profile = $state(null);
  let now = $state(new Date());
  let loading = $state(true);

  let todayPatients = $state(0);
  let queueCount = $state(0);
  let inpatientCount = $state(0);
  let todayRevenue = $state(0);

  let recentVisits = $state([]);
  let bedAvailability = $state([]);
  let clinicStats = $state([]);

  let timer;

  const greeting = $derived.by(() => {
    const h = now.getHours();
    if (h < 12) return 'Selamat Pagi';
    if (h < 15) return 'Selamat Siang';
    if (h < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  });

  const formattedDate = $derived(
    now.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
  );

  const formattedTime = $derived(
    now.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
  );

  const maxClinicCount = $derived.by(() => {
    if (clinicStats.length === 0) return 1;
    return Math.max(...clinicStats.map(c => c.count), 1);
  });

  const quickActions = [
    { label: 'Registrasi Baru', href: '/registrasi', color: 'bg-primary-500 hover:bg-primary-600' },
    { label: 'IGD', href: '/igd', color: 'bg-red-500 hover:bg-red-600' },
    { label: 'Rawat Jalan', href: '/rawat-jalan', color: 'bg-emerald-500 hover:bg-emerald-600' },
    { label: 'Rawat Inap', href: '/rawat-inap', color: 'bg-amber-500 hover:bg-amber-600' },
    { label: 'Farmasi', href: '/farmasi', color: 'bg-purple-500 hover:bg-purple-600' },
    { label: 'Kasir', href: '/kasir', color: 'bg-teal-500 hover:bg-teal-600' }
  ];

  function getVisitTypeBadge(type) {
    switch (type) {
      case 'rawat_jalan': return 'badge-info';
      case 'rawat_inap': return 'badge-warning';
      case 'igd': return 'badge-danger';
      default: return 'badge-gray';
    }
  }

  function getVisitTypeLabel(type) {
    return VISIT_TYPES[type] || type;
  }

  function getStatusLabel(visit) {
    if (visit.status_keluar === '1') return 'Selesai';
    if (visit.status_periksa === '1') return 'Sedang Diperiksa';
    return 'Menunggu';
  }

  function getStatusClass(visit) {
    if (visit.status_keluar === '1') return 'badge-success';
    if (visit.status_periksa === '1') return 'badge-info';
    return 'badge-warning';
  }

  function getBedBarColor(percentage) {
    if (percentage >= 90) return 'bg-red-500';
    if (percentage >= 70) return 'bg-amber-500';
    return 'bg-emerald-500';
  }

  async function fetchDashboardData() {
    loading = true;
    try {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayEnd = new Date();
      todayEnd.setHours(23, 59, 59, 999);

      const [visitsResult, queueResult, inpatientResult, revenueResult, bedsResult, recentResult, clinicResult] = await Promise.all([
        supabase
          .from('patient_visitations')
          .select('visit_id', { count: 'exact', head: true })
          .gte('visit_date', todayStart.toISOString())
          .lte('visit_date', todayEnd.toISOString()),
        supabase
          .from('patient_visitations')
          .select('visit_id', { count: 'exact', head: true })
          .gte('visit_date', todayStart.toISOString())
          .lte('visit_date', todayEnd.toISOString())
          .eq('status_periksa', '0')
          .eq('status_keluar', '0'),
        supabase
          .from('patient_visitations')
          .select('visit_id', { count: 'exact', head: true })
          .eq('visit_type', 'rawat_inap')
          .eq('status_keluar', '0'),
        supabase
          .from('billing_invoices')
          .select('net_amount')
          .eq('status', 'paid')
          .gte('paid_at', todayStart.toISOString())
          .lte('paid_at', todayEnd.toISOString()),
        supabase
          .from('room_classes')
          .select(`
            class_id,
            name,
            rooms:rooms (
              room_id,
              beds:beds (
                bed_id,
                is_occupied,
                is_active
              )
            )
          `),
        supabase
          .from('patient_visitations')
          .select(`
            visit_id,
            visit_date,
            visit_type,
            status_periksa,
            status_keluar,
            ticket_no,
            patients:patient_id ( full_name, no_registration ),
            clinics:clinic_id ( name )
          `)
          .order('visit_date', { ascending: false })
          .limit(10),
        supabase
          .from('patient_visitations')
          .select(`
            clinic_id,
            clinics:clinic_id ( name )
          `)
          .gte('visit_date', todayStart.toISOString())
          .lte('visit_date', todayEnd.toISOString())
      ]);

      todayPatients = visitsResult.count || 0;
      queueCount = queueResult.count || 0;
      inpatientCount = inpatientResult.count || 0;

      const revenue = (revenueResult.data || []).reduce((sum, inv) => sum + (inv.net_amount || 0), 0);
      todayRevenue = revenue;

      recentVisits = (recentResult.data || []).map(v => ({
        ...v,
        patient_name: v.patients?.full_name || '-',
        patient_no: v.patients?.no_registration || '-',
        clinic_name: v.clinics?.name || '-'
      }));

      bedAvailability = (bedsResult.data || []).map(rc => {
        const allBeds = (rc.rooms || []).flatMap(r => r.beds || []);
        const activeBeds = allBeds.filter(b => b.is_active);
        const occupiedBeds = activeBeds.filter(b => b.is_occupied);
        return {
          class_id: rc.class_id,
          name: rc.name,
          total: activeBeds.length,
          occupied: occupiedBeds.length,
          available: activeBeds.length - occupiedBeds.length,
          percentage: activeBeds.length > 0 ? Math.round((occupiedBeds.length / activeBeds.length) * 100) : 0
        };
      }).filter(rc => rc.total > 0);

      const clinicCounts = {};
      (clinicResult.data || []).forEach(v => {
        const name = v.clinics?.name || 'Tidak Diketahui';
        clinicCounts[name] = (clinicCounts[name] || 0) + 1;
      });
      clinicStats = Object.entries(clinicCounts)
        .map(([name, count]) => ({ name, count }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 8);

    } catch (err) {
      console.error('Dashboard fetch error:', err);
    } finally {
      loading = false;
    }
  }

  onMount(async () => {
    try {
      const u = await getCurrentUser();
      user = u;
      profile = u?.profile || null;
    } catch (e) {
      console.error('Auth error:', e);
    }

    await fetchDashboardData();

    timer = setInterval(() => {
      now = new Date();
    }, 1000);

    return () => clearInterval(timer);
  });
</script>

<svelte:head>
  <title>Dashboard - SIMRS</title>
</svelte:head>

<div class="min-h-screen p-4 md:p-6 lg:p-8 space-y-6">
  <!-- Welcome Header -->
  <div class="card bg-gradient-to-r from-primary-600 to-primary-800 text-white border-0">
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div>
        <h1 class="text-2xl md:text-3xl font-bold">{greeting}, {profile?.full_name || 'User'}!</h1>
        <p class="text-primary-100 mt-1 text-sm md:text-base">Selamat datang di Sistem Informasi Manajemen Rumah Sakit</p>
      </div>
      <div class="text-right shrink-0">
        <p class="text-lg md:text-xl font-semibold">{formattedDate}</p>
        <p class="text-primary-200 text-2xl md:text-3xl font-mono font-bold">{formattedTime}</p>
      </div>
    </div>
  </div>

  <!-- Stats Cards -->
  <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
    <!-- Total Pasien Hari Ini -->
    <div class="card">
      <div class="flex items-center gap-4">
        <div class="shrink-0 w-12 h-12 rounded-xl bg-blue-100 flex items-center justify-center">
          <svg class="w-6 h-6 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
            <circle cx="9" cy="7" r="4"/>
            <path d="M22 21v-2a4 4 0 0 0-3-3.87"/>
            <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
          </svg>
        </div>
        <div class="min-w-0">
          <p class="text-xs text-gray-500 font-medium uppercase tracking-wide">Pasien Hari Ini</p>
          <p class="text-2xl md:text-3xl font-bold text-gray-900">{todayPatients}</p>
        </div>
      </div>
    </div>

    <!-- Sedang Antrian -->
    <div class="card">
      <div class="flex items-center gap-4">
        <div class="shrink-0 w-12 h-12 rounded-xl bg-amber-100 flex items-center justify-center">
          <svg class="w-6 h-6 text-amber-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"/>
            <polyline points="12 6 12 12 16 14"/>
          </svg>
        </div>
        <div class="min-w-0">
          <p class="text-xs text-gray-500 font-medium uppercase tracking-wide">Sedang Antrian</p>
          <p class="text-2xl md:text-3xl font-bold text-gray-900">{queueCount}</p>
        </div>
      </div>
    </div>

    <!-- Rawat Inap -->
    <div class="card">
      <div class="flex items-center gap-4">
        <div class="shrink-0 w-12 h-12 rounded-xl bg-emerald-100 flex items-center justify-center">
          <svg class="w-6 h-6 text-emerald-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M2 4v16"/>
            <path d="M2 8h18a2 2 0 0 1 2 2v10"/>
            <path d="M2 17h20"/>
            <path d="M6 8v9"/>
          </svg>
        </div>
        <div class="min-w-0">
          <p class="text-xs text-gray-500 font-medium uppercase tracking-wide">Rawat Inap</p>
          <p class="text-2xl md:text-3xl font-bold text-gray-900">{inpatientCount}</p>
        </div>
      </div>
    </div>

    <!-- Pendapatan Hari Ini -->
    <div class="card">
      <div class="flex items-center gap-4">
        <div class="shrink-0 w-12 h-12 rounded-xl bg-violet-100 flex items-center justify-center">
          <svg class="w-6 h-6 text-violet-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="12" y1="1" x2="12" y2="23"/>
            <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
          </svg>
        </div>
        <div class="min-w-0">
          <p class="text-xs text-gray-500 font-medium uppercase tracking-wide">Pendapatan Hari Ini</p>
          <p class="text-xl md:text-2xl font-bold text-gray-900 truncate">{formatCurrency(todayRevenue)}</p>
        </div>
      </div>
    </div>
  </div>

  <!-- Quick Actions -->
  <div class="card">
    <h2 class="text-lg font-semibold text-gray-900 mb-4">Aksi Cepat</h2>
    <div class="grid grid-cols-3 sm:grid-cols-3 md:grid-cols-6 gap-3">
      {#each quickActions as action}
        <a
          href={action.href}
          class="flex flex-col items-center gap-2 p-4 rounded-xl text-white font-medium text-sm transition-all duration-200 {action.color} shadow-sm hover:shadow-md active:scale-95 text-center"
        >
          <span class="text-lg">{action.label}</span>
        </a>
      {/each}
    </div>
  </div>

  <!-- Two Column Layout -->
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <!-- Recent Visits Table (Left - 2 cols) -->
    <div class="lg:col-span-2 card">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold text-gray-900">Kunjungan Terbaru</h2>
        <a href="/rawat-jalan" class="text-sm text-primary-600 hover:text-primary-700 font-medium">Lihat Semua</a>
      </div>
      <div class="overflow-x-auto">
        {#if loading}
          <div class="flex items-center justify-center py-12">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
          </div>
        {:else if recentVisits.length === 0}
          <div class="text-center py-12 text-gray-400">
            <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2"/>
              <rect x="9" y="3" width="6" height="4" rx="1"/>
              <path d="M9 14l2 2 4-4"/>
            </svg>
            <p>Belum ada kunjungan hari ini</p>
          </div>
        {:else}
          <table class="w-full">
            <thead>
              <tr class="table-header">
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Pasien</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">No. RM</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Poli</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Jenis</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each recentVisits as visit, i}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                  <td class="table-cell font-medium text-gray-900">{visit.patient_name}</td>
                  <td class="table-cell text-gray-500 hidden sm:table-cell font-mono text-xs">{visit.patient_no}</td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{visit.clinic_name}</td>
                  <td class="table-cell">
                    <span class="badge {getVisitTypeBadge(visit.visit_type)}">{getVisitTypeLabel(visit.visit_type)}</span>
                  </td>
                  <td class="table-cell">
                    <span class="badge {getStatusClass(visit)}">{getStatusLabel(visit)}</span>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>
    </div>

    <!-- Bed Availability (Right - 1 col) -->
    <div class="card">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold text-gray-900">Ketersediaan Tempat Tidur</h2>
      </div>
      <div class="space-y-4">
        {#if loading}
          <div class="flex items-center justify-center py-12">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
          </div>
        {:else if bedAvailability.length === 0}
          <div class="text-center py-12 text-gray-400">
            <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M2 4v16"/>
              <path d="M2 8h18a2 2 0 0 1 2 2v10"/>
              <path d="M2 17h20"/>
              <path d="M6 8v9"/>
            </svg>
            <p>Belum ada data kamar</p>
          </div>
        {:else}
          {#each bedAvailability as room}
            <div class="space-y-2">
              <div class="flex items-center justify-between">
                <span class="text-sm font-medium text-gray-700">{room.name}</span>
                <span class="text-xs text-gray-500">{room.occupied}/{room.total} terisi</span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-2.5">
                <div
                  class="h-2.5 rounded-full transition-all duration-500 {getBedBarColor(room.percentage)}"
                  style="width: {room.percentage}%"
                ></div>
              </div>
              <div class="flex justify-between text-xs">
                <span class="text-gray-500">{room.percentage}% terisi</span>
                <span class:text-emerald-600={room.available > 0} class:text-red-600={room.available === 0}>
                  {room.available} tersedia
                </span>
              </div>
            </div>
          {/each}
        {/if}
      </div>
    </div>
  </div>

  <!-- Poli Stats Bar Chart -->
  <div class="card">
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold text-gray-900">Poli Paling Ramai Hari Ini</h2>
      <span class="text-sm text-gray-500">{clinicStats.length} poli aktif</span>
    </div>
    <div class="space-y-3">
      {#if loading}
        <div class="flex items-center justify-center py-12">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
        </div>
      {:else if clinicStats.length === 0}
        <div class="text-center py-12 text-gray-400">
          <p>Belum ada data kunjungan poli hari ini</p>
        </div>
      {:else}
        {#each clinicStats as clinic, i}
          {@const barWidth = Math.round((clinic.count / maxClinicCount) * 100)}
          <div class="flex items-center gap-4">
            <span class="text-sm text-gray-500 w-8 text-right font-mono">{i + 1}.</span>
            <span class="text-sm font-medium text-gray-700 w-36 md:w-48 truncate shrink-0">{clinic.name}</span>
            <div class="flex-1 bg-gray-100 rounded-full h-7 overflow-hidden">
              <div
                class="h-full rounded-full flex items-center px-3 transition-all duration-700
                  {i === 0 ? 'bg-primary-500' : i === 1 ? 'bg-primary-400' : i === 2 ? 'bg-primary-300' : 'bg-gray-300'}"
                style="width: {barWidth}%"
              >
                <span class="text-xs font-bold {i < 3 ? 'text-white' : 'text-gray-600'} whitespace-nowrap">
                  {clinic.count} pasien
                </span>
              </div>
            </div>
          </div>
        {/each}
      {/if}
    </div>
  </div>
</div>
