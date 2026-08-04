<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatCurrency, formatDate, formatDateTime } from '$lib/utils/helpers.js';
  import { VISIT_TYPES, PAYOR_TYPES, STATUS_PEMBAYARAN } from '$lib/utils/constants.js';

  let loading = $state(true);
  let activeTab = $state('tagihan');
  let searchQuery = $state('');
  let filterStatus = $state('');
  let filterDate = $state('');

  let visits = $state([]);
  let invoices = $state([]);

  let stats = $derived({
    belumBayar: visits.filter(v => v.status_pembayaran === '0').reduce((sum, v) => sum + (v.total_tagihan || 0), 0),
    sudahBayar: visits.filter(v => {
      if (v.status_pembayaran !== '1') return false;
      const d = new Date(v.updated_at || v.visit_date);
      const today = new Date();
      return d.toDateString() === today.toDateString();
    }).reduce((sum, v) => sum + (v.total_dibayar || 0), 0),
    pendapatanHari: invoices.filter(inv => {
      const d = new Date(inv.paid_at || inv.created_at);
      const today = new Date();
      return d.toDateString() === today.toDateString() && inv.status === 'paid';
    }).reduce((sum, inv) => sum + (inv.net_amount || inv.total_amount || 0), 0),
    totalTransaksi: invoices.filter(inv => {
      const d = new Date(inv.paid_at || inv.created_at);
      const today = new Date();
      return d.toDateString() === today.toDateString();
    }).length
  });

  const filteredTagihan = $derived.by(() => {
    let result = visits.filter(v => v.status_pembayaran !== '1');
    if (filterStatus) {
      if (filterStatus === 'belum') result = visits.filter(v => v.status_pembayaran === '0' && !v.partial_amount);
      else if (filterStatus === 'sebagian') result = visits.filter(v => v.partial_amount > 0 && v.status_pembayaran !== '1');
      else if (filterStatus === 'lunas') result = visits.filter(v => v.status_pembayaran === '1');
    }
    if (filterDate) {
      result = result.filter(v => {
        const d = new Date(v.visit_date);
        return d.toISOString().slice(0, 10) === filterDate;
      });
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(v =>
        v.invoice_no?.toLowerCase().includes(q) ||
        v.patient_no?.toLowerCase().includes(q) ||
        v.patient_name?.toLowerCase().includes(q) ||
        v.clinic_name?.toLowerCase().includes(q)
      );
    }
    return result;
  });

  const filteredRiwayat = $derived.by(() => {
    let result = invoices.filter(inv => inv.status === 'paid');
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
        result = result.filter(inv =>
          inv.invoice_id?.toLowerCase().includes(q) ||
          inv.patient_name?.toLowerCase().includes(q)
        );
    }
    if (filterDate) {
      result = result.filter(inv => {
        const d = new Date(inv.paid_at || inv.created_at);
        return d.toISOString().slice(0, 10) === filterDate;
      });
    }
    return result.sort((a, b) => new Date(b.paid_at || b.created_at) - new Date(a.paid_at || a.created_at));
  });

  function getPaymentStatus(visit) {
    if (visit.status_pembayaran === '1') return { label: 'Lunas', class: 'badge-success' };
    if (visit.partial_amount > 0) return { label: 'Sebagian', class: 'badge-warning' };
    return { label: 'Belum Bayar', class: 'badge-danger' };
  }

  function getVisitTypeLabel(type) {
    return VISIT_TYPES[type] || type || '-';
  }

  async function fetchVisits() {
    try {
      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          visit_id,
          visit_date,
          visit_type,
          status_pembayaran,
          ticket_no,
          patient_id,
          clinic_id,
          doctor_id,
          payor_id,
          patients:patient_id ( full_name, no_registration ),
          clinics:clinic_id ( name ),
          doctors:doctor_id ( full_name ),
          payors:payor_id ( type )
        `)
        .neq('status_pembayaran', '1')
        .order('visit_date', { ascending: false });

      if (error) throw error;

      const visitIds = (data || []).map(v => v.visit_id);

      let billsMap = {};
      let partialMap = {};
      if (visitIds.length > 0) {
        const { data: bills } = await supabase
          .from('treatment_bills')
          .select('visit_id, amount')
          .in('visit_id', visitIds);

        if (bills) {
          bills.forEach(b => {
            billsMap[b.visit_id] = (billsMap[b.visit_id] || 0) + (b.amount || 0);
          });
        }

        const { data: invoices } = await supabase
          .from('billing_invoices')
          .select('visit_id, status, paid_amount')
          .in('visit_id', visitIds);

        if (invoices) {
          invoices.forEach(inv => {
            if (inv.status === 'partial' || inv.paid_amount > 0) {
              partialMap[inv.visit_id] = (partialMap[inv.visit_id] || 0) + (inv.paid_amount || 0);
            }
          });
        }
      }

      visits = (data || []).map(v => ({
        ...v,
        patient_name: v.patients?.full_name || '-',
        patient_no: v.patients?.no_registration || '-',
        clinic_name: v.clinics?.name || '-',
        doctor_name: v.doctors?.full_name || '-',
        total_tagihan: billsMap[v.visit_id] || 0,
        total_dibayar: partialMap[v.visit_id] || 0,
        partial_amount: partialMap[v.visit_id] || 0,
        payor_type: v.payors?.type || 'personal',
        invoice_no: `INV-${v.visit_id?.slice(-8) || '-'}`
      }));
    } catch (err) {
      console.error('Fetch visits error:', err);
    }
  }

  async function fetchInvoices() {
    try {
      const { data, error } = await supabase
        .from('billing_invoices')
        .select(`
          *,
          patient_visitations:visit_id (
            visit_id,
            visit_type,
            patients:patient_id ( full_name, no_registration ),
            clinics:clinic_id ( name )
          )
        `)
        .order('created_at', { ascending: false });

      if (error) throw error;

      invoices = (data || []).map(inv => ({
        ...inv,
        patient_name: inv.patient_visitations?.patients?.full_name || '-',
        patient_no: inv.patient_visitations?.patients?.no_registration || '-',
        clinic_name: inv.patient_visitations?.clinics?.name || '-',
        visit_type: inv.patient_visitations?.visit_type || '-'
      }));
    } catch (err) {
      console.error('Fetch invoices error:', err);
    }
  }

  function goPayment(visitId) {
    goto(`/kasir/${visitId}`);
  }

  function viewDetail(invoiceId) {
    const inv = invoices.find(i => i.invoice_id === invoiceId);
    if (inv) goto(`/kasir/${inv.visit_id}`);
  }

  function printReceipt(invoiceId) {
    window.print();
  }

  async function refreshAll() {
    loading = true;
    await Promise.all([fetchVisits(), fetchInvoices()]);
    loading = false;
  }

  onMount(async () => {
    await refreshAll();
  });
</script>

<svelte:head>
  <title>Kasir & Billing</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Kasir & Billing</h1>
      <p class="text-sm text-gray-500 mt-1">Manajemen tagihan dan pembayaran pasien</p>
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
        <div class="shrink-0 w-10 h-10 rounded-lg bg-red-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v12m-3-2.818.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-red-600 uppercase tracking-wide font-medium">Total Belum Bayar</p>
          <p class="text-xl font-bold text-red-600">{formatCurrency(stats.belumBayar)}</p>
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
          <p class="text-xs text-emerald-600 uppercase tracking-wide font-medium">Sudah Bayar (Hari Ini)</p>
          <p class="text-xl font-bold text-emerald-600">{formatCurrency(stats.sudahBayar)}</p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-blue-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm3 0h.008v.008H18V10.5Zm-12 0h.008v.008H6V10.5Z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-blue-600 uppercase tracking-wide font-medium">Pendapatan Hari Ini</p>
          <p class="text-xl font-bold text-blue-600">{formatCurrency(stats.pendapatanHari)}</p>
        </div>
      </div>
    </div>
    <div class="card p-4">
      <div class="flex items-center gap-3">
        <div class="shrink-0 w-10 h-10 rounded-lg bg-purple-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
          </svg>
        </div>
        <div>
          <p class="text-xs text-purple-600 uppercase tracking-wide font-medium">Total Transaksi Hari Ini</p>
          <p class="text-2xl font-bold text-purple-600">{stats.totalTransaksi}</p>
        </div>
      </div>
    </div>
  </div>

  <div class="card p-0">
    <div class="flex overflow-x-auto border-b border-gray-200 scrollbar-thin">
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'tagihan'
            ? 'border-primary-600 text-primary-700 bg-primary-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => { activeTab = 'tagihan'; searchQuery = ''; filterStatus = ''; filterDate = ''; }}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
        </svg>
        Tagihan Masuk
        {#if visits.length > 0}
          <span class="inline-flex items-center justify-center w-5 h-5 rounded-full bg-red-100 text-xs font-semibold text-red-700">
            {visits.length}
          </span>
        {/if}
      </button>
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'riwayat'
            ? 'border-primary-600 text-primary-700 bg-primary-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => { activeTab = 'riwayat'; searchQuery = ''; filterStatus = ''; filterDate = ''; }}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        Riwayat Pembayaran
      </button>
    </div>

    <div class="p-6">
      <div class="flex flex-col sm:flex-row gap-3 mb-4">
        <div class="flex-1 relative">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
          </svg>
          <input
            type="text"
            class="input-field pl-10"
            placeholder={activeTab === 'tagihan' ? 'Cari invoice, No.RM, nama pasien, atau poli...' : 'Cari invoice atau nama pasien...'}
            bind:value={searchQuery}
          />
        </div>
        {#if activeTab === 'tagihan'}
          <div class="w-full sm:w-40">
            <select class="select-field" bind:value={filterStatus}>
              <option value="">Semua Status</option>
              <option value="belum">Belum Bayar</option>
              <option value="sebagian">Sebagian</option>
            </select>
          </div>
        {/if}
        <div class="w-full sm:w-44">
          <input type="date" class="input-field" bind:value={filterDate} />
        </div>
      </div>

      {#if activeTab === 'tagihan'}
        {#if loading}
          <div class="flex items-center justify-center py-16">
            <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
          </div>
        {:else if filteredTagihan.length === 0}
          <div class="text-center py-16 text-gray-400">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
            </svg>
            <p class="text-lg font-medium">Tidak ada tagihan</p>
            <p class="text-sm mt-1">Belum ada tagihan yang perlu diproses</p>
          </div>
        {:else}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="table-header">
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No. Invoice</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No. RM</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pasien</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Poli</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Tipe Kunjungan</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Total</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredTagihan as visit, i}
                  {@const status = getPaymentStatus(visit)}
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                    <td class="table-cell">
                      <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">
                        {visit.invoice_no}
                      </span>
                    </td>
                    <td class="table-cell">
                      <span class="font-mono text-xs text-gray-600">{visit.patient_no}</span>
                    </td>
                    <td class="table-cell">
                      <p class="font-medium text-gray-900">{visit.patient_name}</p>
                    </td>
                    <td class="table-cell text-gray-600 hidden md:table-cell">{visit.clinic_name}</td>
                    <td class="table-cell hidden lg:table-cell">
                      <span class="badge badge-gray">{getVisitTypeLabel(visit.visit_type)}</span>
                    </td>
                    <td class="table-cell text-right font-semibold text-gray-900">{formatCurrency(visit.total_tagihan)}</td>
                    <td class="table-cell">
                      <span class="badge {status.class}">{status.label}</span>
                    </td>
                    <td class="table-cell text-right">
                      <button class="btn-primary btn-sm text-xs" onclick={() => goPayment(visit.visit_id)}>
                        <svg class="w-3.5 h-3.5 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75" />
                        </svg>
                        Bayar
                      </button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}

      {:else if activeTab === 'riwayat'}
        {#if loading}
          <div class="flex items-center justify-center py-16">
            <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
          </div>
        {:else if filteredRiwayat.length === 0}
          <div class="text-center py-16 text-gray-400">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
            </svg>
            <p class="text-lg font-medium">Belum ada riwayat pembayaran</p>
            <p class="text-sm mt-1">Riwayat pembayaran yang sudah dilakukan akan muncul di sini</p>
          </div>
        {:else}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="table-header">
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No. Invoice</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Pasien</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Tgl Bayar</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Total</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Dibayar</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Metode</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                  <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredRiwayat as inv, i}
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                    <td class="table-cell">
                      <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">
                        {inv.invoice_id || '-'}
                      </span>
                    </td>
                    <td class="table-cell">
                      <p class="font-medium text-gray-900">{inv.patient_name}</p>
                    </td>
                    <td class="table-cell text-gray-500 hidden md:table-cell text-xs">{formatDateTime(inv.paid_at || inv.created_at)}</td>
                    <td class="table-cell text-right text-gray-600">{formatCurrency(inv.total_amount)}</td>
                    <td class="table-cell text-right font-semibold text-gray-900">{formatCurrency(inv.net_amount || inv.total_amount)}</td>
                    <td class="table-cell hidden lg:table-cell">
                      <span class="badge badge-gray">{inv.payment_method || '-'}</span>
                    </td>
                    <td class="table-cell">
                      <span class="badge badge-success">Lunas</span>
                    </td>
                    <td class="table-cell text-right">
                      <div class="flex items-center justify-end gap-2">
                        <button class="text-gray-400 hover:text-primary-600 transition-colors" onclick={() => viewDetail(inv.invoice_id)} title="Lihat Detail">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z" />
                            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
                          </svg>
                        </button>
                        <button class="text-gray-400 hover:text-emerald-600 transition-colors" onclick={() => printReceipt(inv.invoice_id)} title="Cetak Kwitansi">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0 1 10.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0 .229 2.523a1.125 1.125 0 0 1-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0 0 21 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 0 0-1.913-.247M6.34 18H5.25A2.25 2.25 0 0 1 3 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 0 1 1.913-.247m10.5 0a48.536 48.536 0 0 0-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659" />
                          </svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      {/if}
    </div>
  </div>
</div>
