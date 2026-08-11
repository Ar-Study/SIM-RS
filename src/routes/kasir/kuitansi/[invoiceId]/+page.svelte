<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatCurrency, formatDate, formatDateTime } from '$lib/utils/helpers.js';

  export let data = {};
  let invoiceId = data.invoiceId;

  let loading = true;
  let invoice = null;
  let visit = null;
  let patient = null;
  let clinic = null;
  let bills = [];
  let printError = null;

  async function loadInvoice() {
    try {
      const { data: invoiceData, error: invoiceErr } = await supabase
        .from('billing_invoices')
        .select(`
          invoice_id,
          visit_id,
          total_amount,
          discount,
          net_amount,
          paid_amount,
          payment_method,
          payment_note,
          paid_at,
          created_at,
          status,
          patient_visitations:visit_id (
            visit_id,
            visit_date,
            visit_type,
            patients:patient_id ( full_name, no_registration ),
            clinics:clinic_id ( name ),
            doctors:doctor_id ( full_name )
          )
        `)
        .eq('invoice_id', invoiceId)
        .single();

      if (invoiceErr) throw invoiceErr;
      invoice = invoiceData;

      visit = invoiceData?.patient_visitations || null;
      patient = visit?.patients || null;
      clinic = visit?.clinics || null;

      const { data: billData, error: billErr } = await supabase
        .from('treatment_bills')
        .select('description, amount, quantity, source_type')
        .eq('visit_id', invoiceData?.visit_id);

      if (billErr) throw billErr;
      bills = billData || [];
    } catch (err) {
      console.error('Load invoice error:', err);
      printError = 'Gagal memuat data kuitansi';
    } finally {
      loading = false;
      setTimeout(() => window.print(), 500);
    }
  }

  onMount(() => {
    loadInvoice();
  });
</script>

<svelte:head>
  <title>Kuitansi - {invoice?.invoice_id || 'Loading...'}</title>
  <style>
    @media print {
      .no-print { display: none !important; }
    }
    @media screen {
      .no-print { display: block; }
    }
    body { margin: 0; padding: 20px; font-family: monospace; }
  </style>
</svelte:head>

<div class="max-w-3xl mx-auto bg-white shadow-lg relative">
  <div class="no-print p-4 bg-gray-50 border-b">
    <div class="flex justify-between items-center">
      <h1 class="text-xl font-bold">Kuitansi Pembayaran</h1>
      <div class="flex gap-2">
        <button onclick={() => window.print()} class="btn-secondary btn-sm">
          <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 1.96a9 9 0 0112.46 12.46l-6.24 6.24a9 9 0 01-12.46-12.46l6.24-6.24z" />
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l2 2" />
          </svg>
          Cetak
        </button>
        <button onclick={() => history.back()} class="btn-secondary btn-sm">Kembali</button>
      </div>
    </div>
  </div>

  {#if loading}
    <div class="p-16 text-center text-gray-500">Memuat kuitansi...</div>
  {:else if printError}
    <div class="p-8 text-center text-red-500">{printError}</div>
  {:else}
    <div class="p-12">
      <div class="text-center mb-8">
        <h2 class="text-2xl font-bold">RS SIM-RS</h2>
        <p class="text-sm text-gray-600">Sistem Informasi Rumah Sakit</p>
      </div>

      <div class="border-2 border-dashed border-gray-300 p-6 mb-6">
        <div class="flex justify-between items-start mb-4">
          <div>
            <p class="font-semibold">No. Invoice</p>
            <p class="font-mono text-lg">{invoice?.invoice_id || '-'}</p>
          </div>
          <div class="text-right">
            <p class="font-semibold">Tanggal</p>
            <p>{formatDateTime(invoice?.paid_at || invoice?.created_at)}</p>
          </div>
        </div>

        <div class="border-t border-b border-gray-300 py-3 mb-3">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <p class="font-semibold text-sm">Pasien</p>
              <p class="font-medium">{patient?.full_name || '-'}</p>
              <p class="text-sm text-gray-600">No. RM: {patient?.no_registration || '-'}</p>
            </div>
            <div>
              <p class="font-semibold text-sm">Kunjungan</p>
              <p class="text-sm">Tanggal: {formatDate(visit?.visit_date)}</p>
              <p class="text-sm">Poli: {clinic?.name || '-'}</p>
            </div>
          </div>
        </div>

        <div class="mb-3">
          <p class="font-semibold mb-2">Rincian Tagihan</p>
          {#if bills.length > 0}
            <table class="w-full">
              <thead>
                <tr>
                  <th class="text-left text-xs pb-1">Keterangan</th>
                  <th class="text-right text-xs pb-1">Qty</th>
                  <th class="text-right text-xs pb-1">Harga</th>
                  <th class="text-right text-xs pb-1">Subtotal</th>
                </tr>
              </thead>
              <tbody>
                {#each bills as b}
                  <tr>
                    <td class="text-xs py-1">{b?.description || b?.source_type || '-'}</td>
                    <td class="text-xs text-right py-1">{b?.quantity || 1}</td>
                    <td class="text-xs text-right py-1">{formatCurrency(b?.amount)}</td>
                    <td class="text-xs text-right py-1">{formatCurrency((b?.quantity || 1) * (b?.amount || 0))}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          {:else}
            <p class="text-xs text-gray-500">Tidak ada rincian item</p>
          {/if}
        </div>
      </div>

      <div class="border-t-2 border-gray-400 pt-3 mb-6">
        <div class="flex justify-between mb-1">
          <span class="font-semibold">Subtotal</span>
          <span class="font-mono">{formatCurrency(invoice?.total_amount)}</span>
        </div>
        <div class="flex justify-between mb-1">
          <span class="font-semibold">Diskon</span>
          <span class="font-mono">({formatCurrency(invoice?.discount || 0)})</span>
        </div>
        <div class="flex justify-between mb-1 text-lg font-bold border-t border-gray-300 pt-2">
          <span>Total</span>
          <span class="font-mono">{formatCurrency(invoice?.total_amount)}</span>
        </div>
        <div class="flex justify-between mb-1">
          <span>Dibayar</span>
          <span class="font-mono">{formatCurrency(invoice?.paid_amount)}</span>
        </div>
        <div class="flex justify-between font-bold text-lg">
          <span>Metode</span>
          <span>{invoice?.payment_method === 'cash' ? 'Tunai' : invoice?.payment_method === 'card' ? 'Kartu' : invoice?.payment_method || '-'}</span>
        </div>
      </div>

      <div class="text-center">
        <p class="text-sm mb-1">* Pembayaran telah selesai</p>
        <p class="text-xs text-gray-500">Status: <span class="font-medium">{invoice?.status}</span></p>
      </div>
    </div>
  {/if}
</div>
