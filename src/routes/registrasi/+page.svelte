<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime } from '$lib/utils/helpers.js';
  import { VISIT_TYPES, STATUS_PEMBAYARAN, STATUS_PERIKSA } from '$lib/utils/constants.js';

  let loading = $state(true);
  let registrations = $state([]);
  let totalCount = $state(0);

  let searchQuery = $state('');
  let filterType = $state('all');
  let filterDate = $state(new Date().toISOString().split('T')[0]);

  let currentPage = $state(1);
  const perPage = 15;

  let searchTimeout;

  const totalPages = $derived(Math.ceil(totalCount / perPage));

  const today = new Date().toISOString().split('T')[0];

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

  function getPaymentBadge(status) {
    if (status === '1') return 'badge-success';
    if (status === '2') return 'badge-info';
    return 'badge-danger';
  }

  function getPaymentLabel(status) {
    return STATUS_PEMBAYARAN[status] || 'Belum Bayar';
  }

  function getExamBadge(status) {
    if (status === '1') return 'badge-info';
    return 'badge-warning';
  }

  function getExamLabel(status) {
    return STATUS_PERIKSA[status] || 'Belum Diperiksa';
  }

  function handleSearch(e) {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      currentPage = 1;
      fetchRegistrations();
    }, 300);
  }

  function handleFilter() {
    currentPage = 1;
    fetchRegistrations();
  }

  function goToPage(page) {
    if (page < 1 || page > totalPages) return;
    currentPage = page;
    fetchRegistrations();
  }

  async function fetchRegistrations() {
    loading = true;
    try {
      let query = supabase
        .from('patient_visitations')
        .select(`
          visit_id,
          visit_date,
          visit_type,
          ticket_no,
          status_periksa,
          status_pembayaran,
          status_keluar,
          patients:patient_id (
            full_name,
            no_registration,
            nik
          ),
          clinics:clinic_id ( name ),
          employees:doctor_id ( fullname ) 
        `, { count: 'exact' });

      // *Catatan: Jika di database kolom foreign key Anda adalah employee_id (bukan doctor_id), 
      // ganti baris di atas menjadi -> employees:employee_id ( fullname )

      if (filterType !== 'all') {
        query = query.eq('visit_type', filterType);
      }

      if (filterDate) {
        const dayStart = new Date(filterDate);
        dayStart.setHours(0, 0, 0, 0);
        const dayEnd = new Date(filterDate);
        dayEnd.setHours(23, 59, 59, 999);
        query = query.gte('visit_date', dayStart.toISOString());
        query = query.lte('visit_date', dayEnd.toISOString());
      }

      if (searchQuery.trim()) {
        const q = searchQuery.trim();
        query = query.or(`patients.full_name.ilike.%${q}%,patients.no_registration.ilike.%${q}%,patients.nik.ilike.%${q}%`);
      }

      const from = (currentPage - 1) * perPage;
      const to = from + perPage - 1;

      const { data, count, error } = await query
        .order('visit_date', { ascending: false })
        .range(from, to);

      if (error) throw error;

      registrations = (data || []).map(v => ({
        ...v,
        patient_name: v.patients?.full_name || '-',
        patient_no: v.patients?.no_registration || '-',
        patient_nik: v.patients?.nik || '-',
        clinic_name: v.clinics?.name || '-',
        doctor_name: v.employees?.fullname || '-' // REVISI: v.employees.fullname
      }));

      totalCount = count || 0;
    } catch (err) {
      console.error('Fetch registrations error:', err);
      registrations = [];
      totalCount = 0;
    } finally {
      loading = false;
    }
  }
  function viewDetail(visitId) {
    goto(`/registrasi/${visitId}`);
  }

  function editRegistration(visitId) {
    goto(`/registrasi/${visitId}/edit`);
  }

  function printTicket(visit) {
    const ticketContent = `
      <html>
      <head>
        <title>Tiket Kunjungan</title>
        <style>
          body { font-family: monospace; width: 80mm; margin: 0; padding: 10mm; }
          h2 { text-align: center; font-size: 14pt; margin: 0 0 5px 0; }
          h3 { text-align: center; font-size: 10pt; margin: 0 0 10px 0; font-weight: normal; }
          .info { font-size: 9pt; line-height: 1.8; }
          .info td { padding: 0; }
          .info td:first-child { font-weight: bold; width: 100px; }
          .divider { border-top: 1px dashed #000; margin: 10px 0; }
          .footer { text-align: center; font-size: 8pt; margin-top: 10px; }
        </style>
      </head>
      <body>
        <h2>SIMRS</h2>
        <h3>Tiket Kunjungan</h3>
        <div class="divider"></div>
        <table class="info">
          <tr><td>No. Registrasi</td><td>: ${visit.visit_id}</td></tr>
          <tr><td>No. RM</td><td>: ${visit.patient_no}</td></tr>
          <tr><td>Nama Pasien</td><td>: ${visit.patient_name}</td></tr>
          <tr><td>Poli</td><td>: ${visit.clinic_name}</td></tr>
          <tr><td>Dokter</td><td>: ${visit.doctor_name}</td></tr>
          <tr><td>Jenis Kunjungan</td><td>: ${getVisitTypeLabel(visit.visit_type)}</td></tr>
          <tr><td>Tanggal</td><td>: ${formatDateTime(visit.visit_date)}</td></tr>
          <tr><td>No. Tiket</td><td>: ${visit.ticket_no || '-'}</td></tr>
        </table>
        <div class="divider"></div>
        <div class="footer">Simpan tiket ini sebagai bukti registrasi</div>
      </body>
      </html>
    `;
    const printWindow = window.open('', '_blank', 'width=400,height=600');
    if (printWindow) {
      printWindow.document.write(ticketContent);
      printWindow.document.close();
      printWindow.print();
    }
  }

  onMount(() => {
    fetchRegistrations();
  });
</script>

<svelte:head>
  <title>Registrasi Pasien - SIMRS</title>
</svelte:head>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Registrasi Pasien</h1>
      <p class="text-sm text-gray-500 mt-1">Daftar kunjungan pasien hari ini</p>
    </div>
    <a href="/registrasi/tambah" class="btn-primary inline-flex items-center gap-2 shrink-0">
      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
      </svg>
      Registrasi Baru
    </a>
  </div>

  <!-- Filters -->
  <div class="card">
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
      <div class="sm:col-span-1">
        <label class="label" for="search">Cari Pasien</label>
        <div class="relative">
          <input
            id="search"
            type="text"
            bind:value={searchQuery}
            oninput={handleSearch}
            placeholder="Nama, No.RM, atau No.Reg..."
            class="input-field pl-10"
          />
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
          </svg>
        </div>
      </div>
      <div>
        <label class="label" for="filterType">Jenis Kunjungan</label>
        <select id="filterType" bind:value={filterType} onchange={handleFilter} class="select-field">
          <option value="all">Semua Jenis</option>
          <option value="rawat_jalan">Rawat Jalan</option>
          <option value="rawat_inap">Rawat Inap</option>
          <option value="igd">IGD</option>
        </select>
      </div>
      <div>
        <label class="label" for="filterDate">Tanggal</label>
        <input
          id="filterDate"
          type="date"
          bind:value={filterDate}
          onchange={handleFilter}
          max={today}
          class="input-field"
        />
      </div>
    </div>
  </div>

  <!-- Table -->
  <div class="card overflow-hidden p-0">
    <div class="overflow-x-auto">
      {#if loading}
        <div class="flex items-center justify-center py-16">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
        </div>
      {:else if registrations.length === 0}
        <div class="flex flex-col items-center justify-center py-16 text-gray-400">
          <svg class="w-14 h-14 mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2"/>
            <rect x="9" y="3" width="6" height="4" rx="1"/>
            <path d="M9 14l2 2 4-4"/>
          </svg>
          <p class="text-sm font-medium">Tidak ada data registrasi</p>
          <p class="text-xs text-gray-400 mt-1">untuk filter yang dipilih</p>
        </div>
      {:else}
        <table class="w-full">
          <thead>
            <tr class="table-header">
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No.Reg</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">No.RM</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pasien</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Poli</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Dokter</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden xl:table-cell">Tgl Kunjungan</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Tiket</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status Bayar</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Status Periksa</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Aksi</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            {#each registrations as visit, i}
              <tr class="hover:bg-gray-50 transition-colors">
                <td class="table-cell text-gray-400 font-mono text-xs">{(currentPage - 1) * perPage + i + 1}</td>
                <td class="table-cell font-mono text-xs text-gray-900">{visit.visit_id}</td>
                <td class="table-cell font-mono text-xs text-gray-500 hidden lg:table-cell">{visit.patient_no}</td>
                <td class="table-cell font-medium text-gray-900">{visit.patient_name}</td>
                <td class="table-cell text-gray-600 hidden md:table-cell">{visit.clinic_name}</td>
                <td class="table-cell text-gray-600 hidden lg:table-cell">{visit.doctor_name}</td>
                <td class="table-cell text-gray-500 hidden xl:table-cell text-xs">{formatDateTime(visit.visit_date)}</td>
                <td class="table-cell font-mono text-xs text-gray-600 hidden sm:table-cell">{visit.ticket_no || '-'}</td>
                <td class="table-cell">
                  <span class="badge {getPaymentBadge(visit.status_pembayaran)}">{getPaymentLabel(visit.status_pembayaran)}</span>
                </td>
                <td class="table-cell hidden md:table-cell">
                  <span class="badge {getExamBadge(visit.status_periksa)}">{getExamLabel(visit.status_periksa)}</span>
                </td>
                <td class="table-cell">
                  <div class="flex items-center gap-1">
                    <button
                      onclick={() => viewDetail(visit.visit_id)}
                      class="p-1.5 rounded-lg text-blue-600 hover:bg-blue-50 transition-colors"
                      title="Lihat"
                    >
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z" />
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0Z" />
                      </svg>
                    </button>
                    <button
                      onclick={() => editRegistration(visit.visit_id)}
                      class="p-1.5 rounded-lg text-amber-600 hover:bg-amber-50 transition-colors"
                      title="Edit"
                    >
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10" />
                      </svg>
                    </button>
                    <button
                      onclick={() => printTicket(visit)}
                      class="p-1.5 rounded-lg text-emerald-600 hover:bg-emerald-50 transition-colors"
                      title="Cetak Tiket"
                    >
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0 1 10.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0 .229 2.523a1.125 1.125 0 0 1-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0 0 21 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 0 0-1.913-.247M6.34 18H5.25A2.25 2.25 0 0 1 3 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 0 1 1.913-.247m10.5 0a48.536 48.536 0 0 0-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659M18 10.5h.008v.008H18V10.5Zm-3 0h.008v.008H15V10.5Z" />
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

    <!-- Pagination -->
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
