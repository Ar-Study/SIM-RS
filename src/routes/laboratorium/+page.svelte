<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime, generateId } from '$lib/utils/helpers.js';
  import { LAB_CATEGORIES } from '$lib/utils/constants.js';

  let loading = $state(true);
  let activeTab = $state('order_masuk');
  let saving = $state(false);

  let orders = $state([]);
  let completedOrders = $state([]);
  let selectedOrder = $state(null);
  let resultItems = $state([]);

  let stats = $derived({
    todayOrders: orders.filter(o => {
      const d = new Date(o.created_at);
      const today = new Date();
      return d.toDateString() === today.toDateString();
    }).length,
    inProgress: orders.filter(o => o.status === 'diproses').length,
    completed: completedOrders.length
  });

  let pendingOrders = $derived(orders.filter(o => o.status === 'dipesan'));
  let inProgressOrders = $derived(orders.filter(o => o.status === 'diproses'));

  function getStatusBadge(status) {
    const map = {
      dipesan: { label: 'Dipesan', class: 'badge-info' },
      diproses: { label: 'Diproses', class: 'badge-warning' },
      selesai: { label: 'Selesai', class: 'badge-success' },
      dibatalkan: { label: 'Dibatalkan', class: 'badge-danger' }
    };
    return map[status] || { label: status, class: 'badge-gray' };
  }

  async function fetchOrders() {
    try {
      const { data, error } = await supabase
        .from('lab_orders')
        .select(`
          *,
          patient_visitations:visit_id (
            visit_id,
            ticket_no,
            patients:patient_id ( full_name, no_registration ),
            doctors:doctor_id ( full_name )
          )
        `)
        .in('status', ['dipesan', 'diproses'])
        .order('created_at', { ascending: false });
      if (error) throw error;
      orders = (data || []).map(o => ({
        ...o,
        patient_name: o.patient_visitations?.patients?.full_name || '-',
        no_rm: o.patient_visitations?.patients?.no_registration || '-',
        doctor_name: o.patient_visitations?.doctors?.full_name || '-',
        ticket_no: o.patient_visitations?.ticket_no || '-',
        visit_id: o.patient_visitations?.visit_id || o.visit_id
      }));
    } catch (err) {
      console.error('Fetch lab orders error:', err);
    }
  }

  async function fetchCompletedOrders() {
    try {
      const { data, error } = await supabase
        .from('lab_orders')
        .select(`
          *,
          patient_visitations:visit_id (
            visit_id,
            ticket_no,
            patients:patient_id ( full_name, no_registration ),
            doctors:doctor_id ( full_name )
          )
        `)
        .eq('status', 'selesai')
        .order('completed_at', { ascending: false });
      if (error) throw error;
      completedOrders = (data || []).map(o => ({
        ...o,
        patient_name: o.patient_visitations?.patients?.full_name || '-',
        no_rm: o.patient_visitations?.patients?.no_registration || '-',
        doctor_name: o.patient_visitations?.doctors?.full_name || '-',
        ticket_no: o.patient_visitations?.ticket_no || '-'
      }));
    } catch (err) {
      console.error('Fetch completed orders error:', err);
    }
  }

  async function startProcessing(order) {
    saving = true;
    try {
      const { error } = await supabase
        .from('lab_orders')
        .update({ status: 'diproses' })
        .eq('id', order.id);
      if (error) throw error;
      await fetchOrders();
    } catch (err) {
      console.error('Start processing error:', err);
    } finally {
      saving = false;
    }
  }

  function openInputHasil(order) {
    selectedOrder = order;
    const items = order.items || order.analysis_items || [];
    resultItems = items.map(item => ({
      id: item.id || null,
      name: item.name || item.nama_pemeriksaan || '-',
      category: item.category || item.kategori || '-',
      normal_value: item.normal_value || item.nilai_normal || '-',
      result: item.result || '',
      unit: item.unit || item.satuan || '-',
      method: item.method || item.metode || '-',
      is_abnormal: false
    }));
    activeTab = 'input_hasil';
  }

  function checkAbnormal(item) {
    if (!item.result || !item.normal_value) return false;
    const val = parseFloat(item.result);
    const normalStr = item.normal_value;
    if (isNaN(val)) return false;
    const rangeMatch = normalStr.match(/([\d.]+)\s*[-–]\s*([\d.]+)/);
    if (rangeMatch) {
      const low = parseFloat(rangeMatch[1]);
      const high = parseFloat(rangeMatch[2]);
      return val < low || val > high;
    }
    const ltMatch = normalStr.match(/<\s*([\d.]+)/);
    if (ltMatch) return val >= parseFloat(ltMatch[1]);
    const gtMatch = normalStr.match(/>\s*([\d.]+)/);
    if (gtMatch) return val <= parseFloat(gtMatch[1]);
    return false;
  }

  async function saveResults() {
    if (!selectedOrder) return;
    saving = true;
    try {
      const { error: updateError } = await supabase
        .from('lab_orders')
        .update({ status: 'selesai' })
        .eq('id', selectedOrder.id);
      if (updateError) throw updateError;

      for (const item of resultItems) {
        if (item.id) {
          await supabase
            .from('lab_order_items')
            .update({
              result: item.result,
              is_abnormal: checkAbnormal(item)
            })
            .eq('id', item.id);
        } else {
          await supabase
            .from('lab_order_items')
            .insert({
              order_id: selectedOrder.id,
              name: item.name,
              category: item.category,
              normal_value: item.normal_value,
              result: item.result,
              unit: item.unit,
              method: item.method,
              is_abnormal: checkAbnormal(item)
            });
        }
      }

      selectedOrder = null;
      resultItems = [];
      activeTab = 'order_masuk';
      await Promise.all([fetchOrders(), fetchCompletedOrders()]);
    } catch (err) {
      console.error('Save results error:', err);
    } finally {
      saving = false;
    }
  }

  function cancelInputHasil() {
    selectedOrder = null;
    resultItems = [];
    activeTab = 'order_masuk';
  }

  async function refreshAll() {
    loading = true;
    await Promise.all([fetchOrders(), fetchCompletedOrders()]);
    loading = false;
  }

  onMount(async () => {
    await refreshAll();
  });
</script>

<svelte:head>
  <title>Laboratorium</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-lg bg-indigo-600 flex items-center justify-center">
          <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" />
          </svg>
        </div>
        <div>
          <h1 class="text-2xl font-bold text-indigo-700">Laboratorium</h1>
          <p class="text-sm text-gray-500 mt-0.5">Pemesanan, pemrosesan, dan hasil pemeriksaan laboratorium</p>
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
    </div>
  </div>

  <div class="grid grid-cols-2 lg:grid-cols-3 gap-4">
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-blue-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Order Hari Ini</p>
          <p class="text-2xl font-bold text-gray-900">{stats.todayOrders}</p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-amber-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-amber-600 uppercase tracking-wide font-medium">Dalam Proses</p>
          <p class="text-2xl font-bold text-amber-600">{stats.inProgress}</p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-emerald-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-emerald-600 uppercase tracking-wide font-medium">Selesai</p>
          <p class="text-2xl font-bold text-emerald-600">{stats.completed}</p>
        </div>
      </div>
    </div>
  </div>

  <div class="card p-0">
    <div class="flex overflow-x-auto border-b border-gray-200 scrollbar-thin">
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'order_masuk'
            ? 'border-indigo-600 text-indigo-700 bg-indigo-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => activeTab = 'order_masuk'}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
        </svg>
        Order Masuk
      </button>
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'input_hasil'
            ? 'border-indigo-600 text-indigo-700 bg-indigo-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => { if (!selectedOrder) return; activeTab = 'input_hasil'; }}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10" />
        </svg>
        Input Hasil
      </button>
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'riwayat'
            ? 'border-indigo-600 text-indigo-700 bg-indigo-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => activeTab = 'riwayat'}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        Riwayat
      </button>
    </div>

    <div class="p-6">
      {#if activeTab === 'order_masuk'}
        <div class="space-y-4">
          <h3 class="text-lg font-semibold text-gray-900">Order Masuk</h3>

          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"></div>
            </div>
          {:else if orders.length === 0}
            <div class="text-center py-16 text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" />
              </svg>
              <p class="text-lg font-medium">Tidak ada order laboratorium</p>
              <p class="text-sm mt-1">Order baru akan muncul dari dokter</p>
            </div>
          {:else}
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="table-header">
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No. Order</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">No. RM</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pasien</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Tgl Order</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-center">Jumlah Item</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  {#each orders as order, i}
                    {@const status = getStatusBadge(order.status)}
                    {@const itemCount = order.items?.length || order.analysis_items?.length || 0}
                    <tr class="hover:bg-gray-50 transition-colors">
                      <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                      <td class="table-cell">
                        <span class="font-mono text-sm font-semibold text-indigo-700 bg-indigo-50 px-2 py-0.5 rounded">
                          {order.order_id || order.id?.slice(0, 8) || '-'}
                        </span>
                      </td>
                      <td class="table-cell text-gray-600 font-mono text-xs hidden md:table-cell">{order.no_rm}</td>
                      <td class="table-cell">
                        <div>
                          <p class="font-medium text-gray-900">{order.patient_name}</p>
                          <p class="text-xs text-gray-400">{order.ticket_no}</p>
                        </div>
                      </td>
                      <td class="table-cell text-gray-500 hidden lg:table-cell text-xs">{formatDate(order.created_at)}</td>
                      <td class="table-cell text-center">
                        <span class="inline-flex items-center justify-center w-7 h-7 rounded-full bg-gray-100 text-sm font-semibold text-gray-700">
                          {itemCount || '-'}
                        </span>
                      </td>
                      <td class="table-cell">
                        <span class="badge {status.class}">{status.label}</span>
                      </td>
                      <td class="table-cell text-right">
                        {#if order.status === 'dipesan'}
                          <button class="btn-primary btn-sm text-xs" onclick={() => startProcessing(order)} disabled={saving}>
                            Proses
                          </button>
                        {:else if order.status === 'diproses'}
                          <button class="btn-success btn-sm text-xs" onclick={() => openInputHasil(order)}>
                            <svg class="w-3.5 h-3.5 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10" />
                            </svg>
                            Input Hasil
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

      {:else if activeTab === 'input_hasil'}
        {#if !selectedOrder}
          <div class="text-center py-16 text-gray-400">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125" />
            </svg>
            <p class="text-lg font-medium">Pilih order dari tab "Order Masuk"</p>
            <p class="text-sm mt-1">Klik tombol "Input Hasil" pada order yang sedang diproses</p>
          </div>
        {:else}
          <div class="space-y-6">
            <div class="bg-indigo-50 border border-indigo-200 rounded-xl px-5 py-4">
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <div>
                  <p class="text-sm text-indigo-600 font-medium">Informasi Pasien</p>
                  <p class="text-lg font-bold text-gray-900">{selectedOrder.patient_name}</p>
                  <div class="flex flex-wrap gap-x-4 gap-y-1 mt-1 text-xs text-gray-500">
                    <span>No. RM: <span class="font-mono font-semibold text-gray-700">{selectedOrder.no_rm}</span></span>
                    <span>No. Order: <span class="font-mono font-semibold text-indigo-700">{selectedOrder.order_id || selectedOrder.id?.slice(0, 8)}</span></span>
                    <span>Tgl: <span class="font-semibold text-gray-700">{formatDateTime(selectedOrder.created_at)}</span></span>
                    <span>Dokter: <span class="font-semibold text-gray-700">{selectedOrder.doctor_name}</span></span>
                  </div>
                </div>
                <button class="btn-secondary btn-sm" onclick={cancelInputHasil}>
                  <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
                  </svg>
                  Kembali
                </button>
              </div>
            </div>

            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="table-header">
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pemeriksaan</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Kategori</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Nilai Normal</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Hasil</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Satuan</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Metode</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  {#each resultItems as item, i}
                    {@const abnormal = checkAbnormal(item)}
                    <tr class="hover:bg-gray-50 transition-colors">
                      <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                      <td class="table-cell font-medium text-gray-900">{item.name}</td>
                      <td class="table-cell hidden md:table-cell">
                        <span class="badge badge-gray">{item.category}</span>
                      </td>
                      <td class="table-cell text-gray-500 text-xs hidden lg:table-cell">{item.normal_value}</td>
                      <td class="table-cell">
                        <input
                          type="text"
                          class="input-field text-sm w-full max-w-[140px] {abnormal ? 'border-red-400 bg-red-50 text-red-700 font-semibold' : ''}"
                          bind:value={item.result}
                          placeholder="-"
                        />
                        {#if abnormal}
                          <span class="text-[10px] text-red-600 font-semibold mt-0.5 block">Abnormal</span>
                        {/if}
                      </td>
                      <td class="table-cell text-gray-500 text-xs hidden md:table-cell">{item.unit}</td>
                      <td class="table-cell text-gray-500 text-xs hidden lg:table-cell">{item.method}</td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>

            {#if resultItems.length === 0}
              <div class="text-center py-8 text-gray-400">
                <p class="text-sm">Tidak ada item pemeriksaan pada order ini</p>
              </div>
            {/if}

            <div class="flex justify-end gap-3 pt-4 border-t border-gray-200">
              <button class="btn-secondary" onclick={cancelInputHasil}>Batal</button>
              <button
                class="btn-primary"
                onclick={saveResults}
                disabled={saving || resultItems.every(it => !it.result.trim())}
              >
                {#if saving}
                  <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
                {/if}
                <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                </svg>
                Simpan Hasil
              </button>
            </div>
          </div>
        {/if}

      {:else if activeTab === 'riwayat'}
        <div class="space-y-4">
          <h3 class="text-lg font-semibold text-gray-900">Riwayat Pemeriksaan</h3>

          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"></div>
            </div>
          {:else if completedOrders.length === 0}
            <div class="text-center py-16 text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
              </svg>
              <p class="text-lg font-medium">Belum ada riwayat</p>
              <p class="text-sm mt-1">Pemeriksaan yang selesai akan muncul di sini</p>
            </div>
          {:else}
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="table-header">
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No. Order</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">No. RM</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pasien</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Dokter</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Tgl Selesai</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-center">Jumlah Item</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  {#each completedOrders as order, i}
                    {@const itemCount = order.items?.length || order.analysis_items?.length || 0}
                    <tr class="hover:bg-gray-50 transition-colors">
                      <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                      <td class="table-cell">
                        <span class="font-mono text-sm font-semibold text-indigo-700 bg-indigo-50 px-2 py-0.5 rounded">
                          {order.order_id || order.id?.slice(0, 8) || '-'}
                        </span>
                      </td>
                      <td class="table-cell text-gray-600 font-mono text-xs hidden md:table-cell">{order.no_rm}</td>
                      <td class="table-cell">
                        <div>
                          <p class="font-medium text-gray-900">{order.patient_name}</p>
                          <p class="text-xs text-gray-400">{order.ticket_no}</p>
                        </div>
                      </td>
                      <td class="table-cell text-gray-600 hidden lg:table-cell">{order.doctor_name}</td>
                      <td class="table-cell text-gray-500 hidden lg:table-cell text-xs">{formatDateTime(order.completed_at)}</td>
                      <td class="table-cell text-center">
                        <span class="inline-flex items-center justify-center w-7 h-7 rounded-full bg-emerald-100 text-sm font-semibold text-emerald-700">
                          {itemCount || '-'}
                        </span>
                      </td>
                      <td class="table-cell">
                        <span class="badge badge-success">Selesai</span>
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
