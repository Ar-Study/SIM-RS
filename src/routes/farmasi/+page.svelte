<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatCurrency, formatDate, formatDateTime } from '$lib/utils/helpers.js';
  import { DRUG_CATEGORIES } from '$lib/utils/constants.js';

  let loading = $state(true);
  let activeTab = $state('resep');

  let drugs = $state([]);
  let prescriptions = $state([]);
  let sales = $state([]);
  let stockLogs = $state([]);

  let showAddDrug = $state(false);
  let showStockLog = $state(false);
  let selectedDrug = $state(null);
  let saving = $state(false);

  let newDrug = $state({
    code: '',
    name: '',
    category: 'Lainnya',
    unit: 'tablet',
    stock: 0,
    min_stock: 10,
    buy_price: 0,
    sell_price: 0,
    description: ''
  });

  let stats = $derived({
    totalDrugs: drugs.length,
    lowStock: drugs.filter(d => d.stock > 0 && d.stock <= d.min_stock).length,
    todayPrescriptions: prescriptions.filter(p => {
      const d = new Date(p.created_at);
      const today = new Date();
      return d.toDateString() === today.toDateString();
    }).length,
    todaySales: sales.filter(s => {
      const d = new Date(s.created_at);
      const today = new Date();
      return d.toDateString() === today.toDateString();
    }).length
  });

  let filteredPrescriptions = $derived.by(() => {
    let result = prescriptions;
    if (activeTab === 'resep') {
      result = result.filter(p => p.status === 'pending');
    }
    if (activeTab === 'resep_done') {
      result = result.filter(p => p.status === 'dispensed');
    }
    return result;
  });

  let allPrescriptions = $derived(prescriptions);

  function getDrugStatus(drug) {
    if (drug.stock === 0) return { label: 'Habis', class: 'badge-danger' };
    if (drug.stock <= drug.min_stock) return { label: 'Menipis', class: 'badge-warning' };
    return { label: 'Aman', class: 'badge-success' };
  }

  function getRxStatus(status) {
    if (status === 'dispensed') return { label: 'Sudah Diserahkan', class: 'badge-success' };
    if (status === 'cancelled') return { label: 'Dibatalkan', class: 'badge-danger' };
    return { label: 'Menunggu', class: 'badge-warning' };
  }

  function getRxItemCount(rx) {
    return rx.items?.length || rx.qty || 0;
  }

  async function fetchDrugs() {
    try {
      const { data, error } = await supabase
        .from('drugs')
        .select('*')
        .order('name');
      if (error) throw error;
      drugs = data || [];
    } catch (err) {
      console.error('Fetch drugs error:', err);
    }
  }

  async function fetchPrescriptions() {
    try {
      const { data, error } = await supabase
        .from('prescriptions')
        .select(`
          *,
          patient_visitations:visit_id (
            visit_id,
            ticket_no,
            patients:patient_id ( full_name, no_registration ),
            doctors:doctor_id ( full_name )
          )
        `)
        .order('created_at', { ascending: false });
      if (error) throw error;
      prescriptions = (data || []).map(p => ({
        ...p,
        patient_name: p.patient_visitations?.patients?.full_name || '-',
        doctor_name: p.patient_visitations?.doctors?.full_name || '-',
        ticket_no: p.patient_visitations?.ticket_no || '-',
        visit_id: p.patient_visitations?.visit_id || p.visit_id
      }));
    } catch (err) {
      console.error('Fetch prescriptions error:', err);
    }
  }

  async function fetchSales() {
    try {
      const { data, error } = await supabase
        .from('free_drug_sales')
        .select('*')
        .order('sale_date', { ascending: false });
      if (error) throw error;
      sales = (data || []).map(s => ({
        ...s,
        sale_id: 'FS-' + String(s.id),
        created_at: s.sale_date,
        total: s.net_amount
      }));
    } catch (err) {
      console.error('Fetch sales error:', err);
    }
  }

  async function addDrug() {
    if (!newDrug.name.trim() || !newDrug.code.trim()) return;
    saving = true;
    try {
      const { error } = await supabase
        .from('drugs')
        .insert({
          code: newDrug.code,
          name: newDrug.name,
          category: newDrug.category,
          unit: newDrug.unit,
          stock: Number(newDrug.stock),
          min_stock: Number(newDrug.min_stock),
          buy_price: Number(newDrug.buy_price),
          sell_price: Number(newDrug.sell_price),
          description: newDrug.description,
          is_active: true
        });
      if (error) throw error;
      newDrug = { code: '', name: '', category: 'Lainnya', unit: 'tablet', stock: 0, min_stock: 10, buy_price: 0, sell_price: 0, description: '' };
      showAddDrug = false;
      await fetchDrugs();
    } catch (err) {
      console.error('Add drug error:', err);
    } finally {
      saving = false;
    }
  }

  function openStockLog(drug) {
    selectedDrug = drug;
    showStockLog = true;
  }

  async function refreshAll() {
    loading = true;
    await Promise.all([fetchDrugs(), fetchPrescriptions(), fetchSales()]);
    loading = false;
  }

  onMount(async () => {
    await refreshAll();
  });
</script>

<svelte:head>
  <title>Farmasi & Apotik</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Farmasi & Apotik</h1>
      <p class="text-sm text-gray-500 mt-1">Manajemen resep, stok obat, dan penjualan bebas</p>
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
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-blue-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Total Obat</p>
          <p class="text-2xl font-bold text-gray-900">{stats.totalDrugs}</p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-amber-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-amber-600 uppercase tracking-wide font-medium">Stok Menipis</p>
          <p class="text-2xl font-bold text-amber-600">{stats.lowStock}</p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-purple-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-purple-600 uppercase tracking-wide font-medium">Resep Hari Ini</p>
          <p class="text-2xl font-bold text-purple-600">{stats.todayPrescriptions}</p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-emerald-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm3 0h.008v.008H18V10.5Zm-12 0h.008v.008H6V10.5Z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-emerald-600 uppercase tracking-wide font-medium">Penjualan Hari Ini</p>
          <p class="text-2xl font-bold text-emerald-600">{stats.todaySales}</p>
        </div>
      </div>
    </div>
  </div>

  <div class="card p-0">
    <div class="flex overflow-x-auto border-b border-gray-200 scrollbar-thin">
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'resep'
            ? 'border-primary-600 text-primary-700 bg-primary-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => activeTab = 'resep'}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
        </svg>
        Resep Masuk
      </button>
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'stok'
            ? 'border-primary-600 text-primary-700 bg-primary-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => activeTab = 'stok'}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
        </svg>
        Stok Obat
      </button>
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'penjualan'
            ? 'border-primary-600 text-primary-700 bg-primary-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => activeTab = 'penjualan'}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm3 0h.008v.008H18V10.5Zm-12 0h.008v.008H6V10.5Z" />
        </svg>
        Penjualan Obat Bebas
      </button>
    </div>

    <div class="p-6">
      {#if activeTab === 'resep' || activeTab === 'resep_done'}
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold text-gray-900">Resep Masuk</h3>
            <div class="flex gap-2">
              <select class="select-field text-sm w-auto" bind:value={activeTab}>
                <option value="resep">Menunggu</option>
                <option value="resep_done">Selesai</option>
              </select>
            </div>
          </div>
                  
          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          {:else if filteredPrescriptions.length === 0}
            <div class="text-center py-16 text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
              </svg>
              <p class="text-lg font-medium">Tidak ada resep menunggu</p>
              <p class="text-sm mt-1">Semua resep sudah ditangani</p>
            </div>
          {:else}
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="table-header">
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No. Resep</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Pasien</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Dokter</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Tgl</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-center">Jumlah Item</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  {#each allPrescriptions as rx, i}
                    {@const status = getRxStatus(rx.status)}
                    <tr class="hover:bg-gray-50 transition-colors">
                      <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                      <td class="table-cell">
                        <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">
                          {rx.prescription_id || `RX-${rx.id}` || '-'}
                        </span>
                      </td>
                      <td class="table-cell">
                        <div>
                          <p class="font-medium text-gray-900">{rx.patient_name}</p>
                          <p class="text-xs text-gray-400 font-mono">{rx.ticket_no}</p>
                        </div>
                      </td>
                      <td class="table-cell text-gray-600 hidden md:table-cell">{rx.doctor_name}</td>
                      <td class="table-cell text-gray-500 hidden lg:table-cell text-xs">{formatDate(rx.created_at)}</td>
                      <td class="table-cell text-center">
                        <span class="inline-flex items-center justify-center w-7 h-7 rounded-full bg-gray-100 text-sm font-semibold text-gray-700">
                          {rx.qty || 1}
                        </span>
                      </td>
                      <td class="table-cell">
                        <span class="badge {status.class}">{status.label}</span>
                      </td>
                      <td class="table-cell text-right">
                        {#if rx.status === 'pending'}
                          <a
                            href="/farmasi/resep/{rx.visit_id || rx.id}"
                            class="btn-success btn-sm text-xs"
                          >
                            <svg class="w-3.5 h-3.5 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                            </svg>
                            Serahkan
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

      {:else if activeTab === 'stok'}
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold text-gray-900">Stok Obat</h3>
            <div class="flex gap-2">
              <button class="btn-secondary btn-sm" onclick={() => showStockLog = true}>
                <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                </svg>
                Log Stok
              </button>
              <button class="btn-primary btn-sm" onclick={() => showAddDrug = true}>
                <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
                Tambah Obat
              </button>
            </div>
          </div>

          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          {:else if drugs.length === 0}
            <div class="text-center py-16 text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
              </svg>
              <p class="text-lg font-medium">Belum ada data obat</p>
              <p class="text-sm mt-1">Klik "Tambah Obat" untuk menambahkan obat baru</p>
            </div>
          {:else}
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="table-header">
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Kode Obat</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Obat</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Kategori</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Stok</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right hidden lg:table-cell">Stok Min</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right hidden md:table-cell">Harga Beli</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Harga Jual</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  {#each drugs as drug, i}
                    {@const drugStatus = getDrugStatus(drug)}
                    <tr class="hover:bg-gray-50 transition-colors">
                      <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                      <td class="table-cell">
                        <span class="font-mono text-xs font-semibold text-gray-600 bg-gray-100 px-2 py-0.5 rounded">
                          {drug.code}
                        </span>
                      </td>
                      <td class="table-cell">
                        <div>
                          <p class="font-medium text-gray-900">{drug.name}</p>
                          <p class="text-xs text-gray-400">{drug.unit}</p>
                        </div>
                      </td>
                      <td class="table-cell hidden md:table-cell">
                        <span class="badge badge-gray">{drug.category}</span>
                      </td>
                      <td class="table-cell text-right">
                        <span class="font-semibold {drug.stock === 0 ? 'text-red-600' : drug.stock <= drug.min_stock ? 'text-amber-600' : 'text-gray-900'}">
                          {drug.stock}
                        </span>
                      </td>
                      <td class="table-cell text-right text-gray-500 hidden lg:table-cell">{drug.min_stock}</td>
                      <td class="table-cell text-right text-gray-600 hidden md:table-cell">{formatCurrency(drug.buy_price)}</td>
                      <td class="table-cell text-right font-semibold text-gray-900">{formatCurrency(drug.sell_price)}</td>
                      <td class="table-cell">
                        <span class="badge {drugStatus.class}">{drugStatus.label}</span>
                      </td>
                      <td class="table-cell text-right">
                        <button class="text-gray-400 hover:text-primary-600 transition-colors" onclick={() => openStockLog(drug)} title="Log Stok">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                          </svg>
                        </button>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </div>

      {:else if activeTab === 'penjualan'}
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold text-gray-900">Penjualan Obat Bebas</h3>
            <a href="/farmasi/penjualan" class="btn-primary btn-sm">
              <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Penjualan Baru
            </a>
          </div>

          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          {:else if sales.length === 0}
            <div class="text-center py-16 text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm3 0h.008v.008H18V10.5Zm-12 0h.008v.008H6V10.5Z" />
              </svg>
              <p class="text-lg font-medium">Belum ada penjualan</p>
              <p class="text-sm mt-1">Klik "Penjualan Baru" untuk memulai transaksi</p>
            </div>
          {:else}
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="table-header">
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No. Nota</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pembeli</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Tgl</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Metode Bayar</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Total</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  {#each sales as sale, i}
                    <tr class="hover:bg-gray-50 transition-colors">
                      <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                      <td class="table-cell">
                        <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">
                          {sale.sale_id || `FS-${sale.id}` || '-'}
                        </span>
                      </td>
                      <td class="table-cell font-medium text-gray-900">{sale.buyer_name || '-'}</td>
                      <td class="table-cell text-gray-500 hidden md:table-cell text-xs">{formatDate(sale.created_at)}</td>
                      <td class="table-cell hidden lg:table-cell">
                        <span class="badge badge-gray">{sale.payment_method || '-'}</span>
                      </td>
                      <td class="table-cell text-right font-semibold text-gray-900">{formatCurrency(sale.total)}</td>
                      <td class="table-cell text-right">
                        <a href="/farmasi/penjualan?id={sale.id}" class="text-gray-400 hover:text-primary-600 transition-colors" title="Detail">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z" />
                            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
                          </svg>
                        </a>
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

{#if showAddDrug}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onclick={() => showAddDrug = false}>
    <div class="bg-white rounded-2xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto" onclick={(e) => e.stopPropagation()}>
      <div class="flex items-center justify-between px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">Tambah Obat Baru</h3>
        <button class="text-gray-400 hover:text-gray-600" onclick={() => showAddDrug = false}>
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="p-6 space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-1">
            <label class="label">Kode Obat</label>
            <input type="text" class="input-field" bind:value={newDrug.code} placeholder="OB001" />
          </div>
          <div class="space-y-1">
            <label class="label">Nama Obat</label>
            <input type="text" class="input-field" bind:value={newDrug.name} placeholder="Parasetamol 500mg" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-1">
            <label class="label">Kategori</label>
            <select class="select-field" bind:value={newDrug.category}>
              {#each DRUG_CATEGORIES as cat}
                <option value={cat}>{cat}</option>
              {/each}
            </select>
          </div>
          <div class="space-y-1">
            <label class="label">Satuan</label>
            <select class="select-field" bind:value={newDrug.unit}>
              <option value="tablet">Tablet</option>
              <option value="kapul">Kapsul</option>
              <option value="botol">Botol</option>
              <option value="tube">Tube</option>
              <option value="sachet">Sachet</option>
              <option value="ampul">Ampul</option>
              <option value="vial">Vial</option>
              <option value="strip">Strip</option>
            </select>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-1">
            <label class="label">Stok Awal</label>
            <input type="number" class="input-field" bind:value={newDrug.stock} placeholder="0" />
          </div>
          <div class="space-y-1">
            <label class="label">Stok Minimum</label>
            <input type="number" class="input-field" bind:value={newDrug.min_stock} placeholder="10" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-1">
            <label class="label">Harga Beli</label>
            <input type="number" class="input-field" bind:value={newDrug.buy_price} placeholder="0" />
          </div>
          <div class="space-y-1">
            <label class="label">Harga Jual</label>
            <input type="number" class="input-field" bind:value={newDrug.sell_price} placeholder="0" />
          </div>
        </div>
        <div class="space-y-1">
          <label class="label">Deskripsi (opsional)</label>
          <textarea class="input-field h-20 resize-none" bind:value={newDrug.description} placeholder="Keterangan obat..."></textarea>
        </div>
      </div>
      <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200">
        <button class="btn-secondary" onclick={() => showAddDrug = false}>Batal</button>
        <button class="btn-primary" onclick={addDrug} disabled={saving || !newDrug.name.trim() || !newDrug.code.trim()}>
          {#if saving}
            <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
          {/if}
          Simpan Obat
        </button>
      </div>
    </div>
  </div>
{/if}

{#if showStockLog}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onclick={() => { showStockLog = false; selectedDrug = null; }}>
    <div class="bg-white rounded-2xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto" onclick={(e) => e.stopPropagation()}>
      <div class="flex items-center justify-between px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">
          {selectedDrug ? `Log Stok - ${selectedDrug.name}` : 'Log Stok'}
        </h3>
        <button class="text-gray-400 hover:text-gray-600" onclick={() => { showStockLog = false; selectedDrug = null; }}>
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="p-6">
        {#if selectedDrug}
          <div class="bg-gray-50 rounded-lg px-4 py-3 mb-4">
            <div class="flex justify-between text-sm">
              <span class="text-gray-500">Stok Saat Ini:</span>
              <span class="font-semibold text-gray-900">{selectedDrug.stock} {selectedDrug.unit}</span>
            </div>
            <div class="flex justify-between text-sm mt-1">
              <span class="text-gray-500">Stok Minimum:</span>
              <span class="font-semibold text-gray-900">{selectedDrug.min_stock} {selectedDrug.unit}</span>
            </div>
          </div>
        {/if}
        <p class="text-sm text-gray-400 text-center py-8">
          Log perubahan stok akan ditampilkan di sini
        </p>
      </div>
      <div class="flex justify-end px-6 py-4 border-t border-gray-200">
        <button class="btn-secondary" onclick={() => { showStockLog = false; selectedDrug = null; }}>Tutup</button>
      </div>
    </div>
  </div>
{/if}
