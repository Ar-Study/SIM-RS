<script>
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatCurrency, formatDate, formatDateTime, generateId } from '$lib/utils/helpers.js';
  import { PAYOR_TYPES } from '$lib/utils/constants.js';

  let visitId = $derived(page.params.visitId);
  let loading = $state(true);
  let processing = $state(false);
  let paymentDone = $state(false);

  let visit = $state(null);
  let patient = $state(null);
  let clinic = $state(null);
  let doctor = $state(null);
  let bills = $state([]);

  let paymentMethod = $state('tunai');
  let amountReceived = $state(0);
  let discount = $state(0);
  let notes = $state('');
  let invoiceNo = $state('');

  const categoryMap = {
    'Konsultasi': 'Konsultasi',
    'Akomodasi': 'Akomodasi',
    'Laboratorium': 'Lab',
    'Radiologi': 'Radiologi',
    'Obat': 'Obat',
    'BMHP': 'BMHP',
    'Tindakan': 'Tindakan'
  };

  const billByCategory = $derived.by(() => {
    const map = {};
    bills.forEach(b => {
      const cat = b.tariff_type || 'Lainnya';
      if (!map[cat]) map[cat] = { items: [], total: 0 };
      map[cat].items.push(b);
      map[cat].total += (b.quantity || 1) * (b.amount || 0);
    });
    return map;
  });

  const subtotal = $derived(bills.reduce((sum, b) => sum + (b.quantity || 1) * (b.amount || 0), 0));
  const discountAmount = $derived(Math.min(Number(discount) || 0, subtotal));
  const netAmount = $derived(subtotal - discountAmount);
  const change = $derived(paymentMethod === 'tunai' ? Math.max(0, (Number(amountReceived) || 0) - netAmount) : 0);
  const canPay = $derived(Number(amountReceived) >= netAmount && !processing);

  async function fetchVisitData() {
    try {
      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          *,
          patients:patient_id ( patient_id, full_name, no_registration, date_of_birth, gender, phone, address ),
          clinics:clinic_id ( clinic_id, name ),
          doctors:doctor_id ( employee_id, full_name )
        `)
        .eq('visit_id', visitId)
        .single();

      if (error) throw error;

      visit = data;
      patient = data.patients;
      clinic = data.clinics;
      doctor = data.doctors;
    } catch (err) {
      console.error('Fetch visit error:', err);
    }
  }

  async function fetchBills() {
    try {
      const { data, error } = await supabase
        .from('treatment_bills')
        .select('*')
        .eq('visit_id', visitId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      bills = data || [];
    } catch (err) {
      console.error('Fetch bills error:', err);
    }
  }

  async function processPayment() {
    if (paymentMethod === 'tunai' && Number(amountReceived) < netAmount) return;
    processing = true;

    try {
      const { data: invoice, error: invoiceErr } = await supabase
        .from('billing_invoices')
        .insert({
          visit_id: visitId,
          total_amount: subtotal,
          discount: discountAmount,
          net_amount: netAmount,
          paid_amount: Number(amountReceived) || netAmount,
          payment_method: paymentMethod,
          payment_note: notes,
          paid_at: new Date().toISOString(),
          status: 'paid'
        })
        .select()
        .single();

      if (invoiceErr) throw invoiceErr;

      const { error: visitErr } = await supabase
        .from('patient_visitations')
        .update({ status_pembayaran: '1' })
        .eq('visit_id', visitId);

      if (visitErr) throw visitErr;

      invoiceNo = invoice?.invoice_id || '';
      paymentDone = true;
    } catch (err) {
      console.error('Process payment error:', err);
      alert('Gagal memproses pembayaran. Silakan coba lagi.');
    } finally {
      processing = false;
    }
  }

  function printReceipt() {
    window.print();
  }

  function goBack() {
    goto('/kasir');
  }

  onMount(async () => {
    loading = true;
    await Promise.all([fetchVisitData(), fetchBills()]);
    loading = false;
  });
</script>

<svelte:head>
  <title>Pembayaran - {patient?.full_name || 'Pasien'}</title>
</svelte:head>

{#if loading}
  <div class="flex items-center justify-center py-24">
    <div class="flex flex-col items-center gap-4">
      <div class="w-12 h-12 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
      <p class="text-sm text-gray-500 font-medium">Memuat data tagihan...</p>
    </div>
  </div>
{:else if !visit}
  <div class="card text-center py-16">
    <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
    </svg>
    <p class="text-lg font-medium text-gray-700">Kunjungan tidak ditemukan</p>
    <button class="btn-primary mt-4" onclick={goBack}>Kembali ke Kasir</button>
  </div>
{:else if paymentDone}
  <div class="flex items-center justify-center py-24">
    <div class="card text-center py-12 px-8 max-w-md">
      <div class="w-20 h-20 mx-auto rounded-full bg-emerald-100 flex items-center justify-center mb-6">
        <svg class="w-10 h-10 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
      </div>
      <h2 class="text-2xl font-bold text-gray-900 mb-2">Pembayaran Berhasil</h2>
      <p class="text-sm text-gray-500 mb-1">{patient?.full_name}</p>
      <p class="text-sm text-gray-500 mb-1">No. Invoice: <span class="font-mono font-semibold text-gray-900">{invoiceNo || '-'}</span></p>
      <p class="text-3xl font-bold text-emerald-600 mb-6">{formatCurrency(netAmount)}</p>

      <div class="bg-gray-50 rounded-lg p-4 mb-6 text-sm space-y-2">
        <div class="flex justify-between">
          <span class="text-gray-500">Metode Bayar</span>
          <span class="font-semibold text-gray-900 capitalize">{paymentMethod}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-500">Waktu</span>
          <span class="font-semibold text-gray-900">{formatDateTime(new Date())}</span>
        </div>
        {#if paymentMethod === 'tunai'}
          <div class="flex justify-between">
            <span class="text-gray-500">Diterima</span>
            <span class="font-semibold text-gray-900">{formatCurrency(amountReceived)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-500">Kembali</span>
            <span class="font-semibold text-primary-600">{formatCurrency(change)}</span>
          </div>
        {/if}
      </div>

      <div class="flex gap-3">
        <button class="btn-secondary flex-1" onclick={goBack}>Kembali</button>
        <button class="btn-primary flex-1" onclick={printReceipt}>
          <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0 1 10.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0 .229 2.523a1.125 1.125 0 0 1-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0 0 21 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 0 0-1.913-.247M6.34 18H5.25A2.25 2.25 0 0 1 3 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 0 1 1.913-.247m10.5 0a48.536 48.536 0 0 0-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659" />
          </svg>
          Cetak Kwitansi
        </button>
      </div>
    </div>
  </div>
{:else}
  <div class="space-y-6">
    <div class="flex items-center gap-3">
      <button class="btn-secondary btn-sm" onclick={goBack}>
        <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
        </svg>
        Kembali
      </button>
      <h1 class="text-xl font-bold text-gray-900">Proses Pembayaran</h1>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-5 gap-6">
      <div class="lg:col-span-3 space-y-6">
        <div class="card bg-gradient-to-r from-primary-50 to-blue-50 border-primary-200">
          <div class="flex flex-col sm:flex-row sm:items-center gap-4">
            <div class="shrink-0 w-12 h-12 rounded-full bg-primary-100 flex items-center justify-center">
              <svg class="w-6 h-6 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
              </svg>
            </div>
            <div class="flex-1">
              <h2 class="text-lg font-bold text-gray-900">{patient?.full_name || '-'}</h2>
              <div class="flex flex-wrap gap-x-5 gap-y-1 mt-1 text-sm text-gray-600">
                <span>No. RM: <strong class="text-gray-900 font-mono">{patient?.no_registration || '-'}</strong></span>
                <span>Poli: <strong class="text-gray-900">{clinic?.name || '-'}</strong></span>
                <span>Dokter: <strong class="text-gray-900">{doctor?.full_name || '-'}</strong></span>
              </div>
            </div>
            <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
              <p class="text-xs text-gray-500">Penanggung Jawab</p>
              <p class="font-semibold text-primary-700">{PAYOR_TYPES[visit?.payor_type] || visit?.payor_type || '-'}</p>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="flex items-center gap-2 mb-4">
            <svg class="w-5 h-5 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
            </svg>
            <h3 class="text-lg font-semibold text-gray-900">Rincian Tagihan</h3>
          </div>

          {#if bills.length === 0}
            <div class="text-center py-10 text-gray-400">
              <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
              </svg>
              <p class="font-medium">Belum ada tagihan</p>
            </div>
          {:else}
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="table-header">
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Kategori</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Deskripsi</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-center">Qty</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Harga</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Subtotal</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  {#each bills as bill, i}
                    <tr class="hover:bg-gray-50">
                      <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                      <td class="table-cell">
                        <span class="badge badge-gray text-xs">{bill.tariff_type || '-'}</span>
                      </td>
                      <td class="table-cell font-medium text-gray-900">{bill.description || '-'}</td>
                      <td class="table-cell text-center text-gray-600">{bill.quantity || 1}</td>
                      <td class="table-cell text-right text-gray-600">{formatCurrency(bill.amount)}</td>
                      <td class="table-cell text-right font-semibold text-gray-900">{formatCurrency((bill.quantity || 1) * (bill.amount || 0))}</td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </div>

        {#if bills.length > 0}
          <div class="card">
            <div class="flex items-center gap-2 mb-4">
              <svg class="w-5 h-5 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25a2.25 2.25 0 0 1-2.25-2.25v-2.25Z" />
              </svg>
              <h3 class="text-lg font-semibold text-gray-900">Ringkasan per Kategori</h3>
            </div>
            <div class="space-y-2">
              {#each Object.entries(billByCategory) as [category, data]}
                <div class="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-lg">
                  <div class="flex items-center gap-3">
                    <span class="badge badge-gray">{category}</span>
                    <span class="text-sm text-gray-500">{data.items.length} item</span>
                  </div>
                  <span class="font-semibold text-gray-900">{formatCurrency(data.total)}</span>
                </div>
              {/each}
            </div>
          </div>
        {/if}

        <div class="card">
          <div class="space-y-4">
            <div class="space-y-2">
              <label class="label">Diskon (Rp)</label>
              <input
                type="number"
                class="input-field"
                bind:value={discount}
                placeholder="0"
                min="0"
                max={subtotal}
              />
            </div>

            <div class="border-t border-gray-200 pt-4 space-y-3">
              <div class="flex justify-between text-sm">
                <span class="text-gray-500">Subtotal</span>
                <span class="font-medium text-gray-900">{formatCurrency(subtotal)}</span>
              </div>
              {#if discountAmount > 0}
                <div class="flex justify-between text-sm">
                  <span class="text-gray-500">Diskon</span>
                  <span class="font-medium text-red-600">- {formatCurrency(discountAmount)}</span>
                </div>
              {/if}
              <div class="flex justify-between border-t border-gray-200 pt-3">
                <span class="text-lg font-bold text-gray-900">Total yang harus dibayar</span>
                <span class="text-3xl font-bold text-primary-600">{formatCurrency(netAmount)}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="lg:col-span-2">
        <div class="card sticky top-24 space-y-5">
          <div class="flex items-center gap-2">
            <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm3 0h.008v.008H18V10.5Zm-12 0h.008v.008H6V10.5Z" />
            </svg>
            <h3 class="text-lg font-semibold text-gray-900">Form Pembayaran</h3>
          </div>

          <div class="space-y-3">
            <label class="label">Metode Pembayaran</label>
            <div class="grid grid-cols-2 gap-2">
              {#each [
                { id: 'tunai', label: 'Tunai', icon: 'M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75' },
                { id: 'kartu', label: 'Kartu', icon: 'M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 0 0 2.25-2.25V6.75A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25v10.5A2.25 2.25 0 0 0 4.5 19.5Z' },
                { id: 'transfer', label: 'Transfer', icon: 'M12 21a9.004 9.004 0 0 0 8.716-6.747M12 21a9.004 9.004 0 0 1-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 0 1 7.843 4.582M12 3a8.997 8.997 0 0 0-7.843 4.582m15.686 0A11.953 11.953 0 0 1 12 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0 1 21 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0 1 12 16.5a17.92 17.92 0 0 1-8.716-2.247m0 0A9.015 9.015 0 0 1 3 12c0-1.605.42-3.113 1.157-4.418' },
                { id: 'bpjs', label: 'BPJS', icon: 'M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z' }
              ] as method}
                <button
                  class="flex items-center justify-center gap-2 px-3 py-2.5 rounded-lg border-2 text-sm font-medium transition-colors
                    {paymentMethod === method.id
                      ? 'border-primary-600 bg-primary-50 text-primary-700'
                      : 'border-gray-200 text-gray-600 hover:border-gray-300 hover:bg-gray-50'}"
                  onclick={() => paymentMethod = method.id}
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d={method.icon} />
                  </svg>
                  {method.label}
                </button>
              {/each}
            </div>
          </div>

          <div class="space-y-2">
            <label class="label">
              {paymentMethod === 'tunai' ? 'Jumlah Diterima' : 'Jumlah Dibayar'}
            </label>
            <div class="relative">
              <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 font-medium text-sm">Rp</span>
              <input
                type="number"
                class="input-field pl-10 text-lg font-semibold"
                bind:value={amountReceived}
                placeholder="0"
                min="0"
              />
            </div>
          </div>

          {#if paymentMethod === 'tunai' && Number(amountReceived) > 0}
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="flex justify-between">
                <span class="text-sm text-gray-500">Kembalian</span>
                <span class="text-xl font-bold {change >= 0 ? 'text-emerald-600' : 'text-red-600'}">{formatCurrency(change)}</span>
              </div>
              {#if Number(amountReceived) < netAmount}
                <p class="text-xs text-red-500 mt-1">Jumlah diterima kurang dari total yang harus dibayar</p>
              {/if}
            </div>
          {/if}

          <div class="space-y-2">
            <label class="label">Catatan (opsional)</label>
            <textarea
              class="input-field h-20 resize-none text-sm"
              bind:value={notes}
              placeholder="Catatan pembayaran..."
            ></textarea>
          </div>

          <div class="space-y-3 border-t border-gray-200 pt-4">
            <div class="flex justify-between items-center">
              <span class="text-gray-500">Total Bayar</span>
              <span class="text-2xl font-bold text-primary-600">{formatCurrency(netAmount)}</span>
            </div>

            <button
              class="w-full btn-primary py-3 text-base font-semibold flex items-center justify-center gap-2"
              onclick={processPayment}
              disabled={!canPay}
            >
              {#if processing}
                <span class="inline-block w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
                Memproses...
              {:else}
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                </svg>
                Proses Pembayaran
              {/if}
            </button>

            {#if paymentDone}
              <button class="w-full btn-secondary py-3 text-base font-semibold flex items-center justify-center gap-2" onclick={printReceipt}>
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0 1 10.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0 .229 2.523a1.125 1.125 0 0 1-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0 0 21 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 0 0-1.913-.247M6.34 18H5.25A2.25 2.25 0 0 1 3 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 0 1 1.913-.247m10.5 0a48.536 48.536 0 0 0-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659" />
                </svg>
                Cetak Kwitansi
              </button>
            {/if}
          </div>
        </div>
      </div>
    </div>
  </div>
{/if}
