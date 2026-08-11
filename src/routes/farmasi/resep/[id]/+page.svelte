<script>
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatCurrency, formatDate, formatDateTime } from '$lib/utils/helpers.js';
  import { addDrugBill } from '$lib/billing.js';

  let visitId = $derived(page.params.id);
  let loading = $state(true);
  let dispensing = $state(false);
  let saving = $state(false);

  let visit = $state(null);
  let patient = $state(null);
  let doctor = $state(null);
  let clinic = $state(null);
  let prescriptions = $state([]);
  let notes = $state('');

  let dispensedItems = $state({});

  const totalHarga = $derived(
    prescriptions.reduce((sum, rx) => {
      const price = rx.sell_price || rx.drugs?.sell_price || 0;
      return sum + (price * (rx.qty || 0));
    }, 0)
  );

  const allDispensed = $derived(
    prescriptions.length > 0 && prescriptions.every(rx => dispensedItems[rx.id])
  );

  async function fetchVisitData() {
    try {
      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          *,
          patients:patient_id ( patient_id, full_name, no_registration, date_of_birth, gender, phone, address ),
          doctors:doctor_id ( employee_id, full_name ),
          clinics:clinic_id ( clinic_id, name )
        `)
        .eq('visit_id', visitId)
        .single();

      if (error) throw error;
      visit = data;
      patient = data.patients;
      doctor = data.doctors;
      clinic = data.clinics;
    } catch (err) {
      console.error('Fetch visit error:', err);
    }
  }

  async function fetchPrescriptions() {
    try {
      const { data, error } = await supabase
        .from('prescriptions')
        .select(`
          *,
          drugs:drug_id ( drug_id, name, unit, sell_price, stock, generic_name )
        `)
        .eq('visit_id', visitId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      prescriptions = data || [];

      const existing = {};
      prescriptions.forEach(rx => {
        if (rx.status === 'dispensed') {
          existing[rx.id] = true;
        }
      });
      dispensedItems = existing;
    } catch (err) {
      console.error('Fetch prescriptions error:', err);
    }
  }

  function toggleDispensed(rxId) {
    dispensedItems = { ...dispensedItems, [rxId]: !dispensedItems[rxId] };
  }

  async function dispenseAll() {
    if (saving) return;
    saving = true;
    dispensing = true;

    try {
      const undispensed = prescriptions.filter(rx => !dispensedItems[rx.id]);
      const now = new Date().toISOString();

      for (const rx of undispensed) {
        const newStock = (rx.drugs?.stock || 0) - (rx.qty || 0);
        // console.log("visit_id", rx.visit_id);
        const { error: rxError } = await supabase
          .from('prescriptions')
          .update({
            status: 'dispensed',
            dispensed_at: now,
            dispensed_notes: notes
          })
          .eq('id', rx.id);

        if (rxError) throw rxError;

        // Add billing for prescription dispensing
        const drugName = rx.drug_name || (rx.drugs ? rx.drugs.name : null) || 'Obat';
        await addDrugBill(rx.visit_id, rx.drug_id, drugName, rx.qty, rx.id);

        if (rx.drug_id && rx.drugs) {
          const { error: stockError } = await supabase
            .from('drugs')
            .update({ stock: Math.max(0, newStock) })
            .eq('drug_id', rx.drug_id);

          if (stockError) throw stockError;

          const { error: logError } = await supabase
            .from('drug_stock_logs')
            .insert({
              drug_id: rx.drug_id,
              change_type: 'out',
              quantity: -(rx.qty || 0),
              reference: `resep-${visitId}`,
              notes: `Resep ${visitId} - ${patient?.full_name || '-'}`
            });

          if (logError) throw logError;
        }
      }

      await fetchPrescriptions();
      goto('/farmasi');
    } catch (err) {
      console.error('Dispense error:', err);
      alert('Gagal menyerahkan resep. Silakan coba lagi.');
    } finally {
      saving = false;
      dispensing = false;
    }
  }

  function printLabel() {
    window.print();
  }

  function goBack() {
    goto('/farmasi');
  }

  onMount(async () => {
    loading = true;
    await Promise.all([fetchVisitData(), fetchPrescriptions()]);
    loading = false;
  });
</script>

<svelte:head>
  <title>Detail Resep - Farmasi</title>
</svelte:head>

{#if loading}
  <div class="flex items-center justify-center py-24">
    <div class="flex flex-col items-center gap-4">
      <div class="w-12 h-12 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
      <p class="text-sm text-gray-500 font-medium">Memuat data resep...</p>
    </div>
  </div>
{:else if !visit}
  <div class="card text-center py-16">
    <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
    </svg>
    <p class="text-lg font-medium text-gray-700">Resep tidak ditemukan</p>
    <button class="btn-primary mt-4" onclick={goBack}>Kembali ke Farmasi</button>
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
      <h1 class="text-xl font-bold text-gray-900">Detail Resep</h1>
    </div>

    <div class="card bg-gradient-to-r from-purple-50 to-blue-50 border-purple-200">
      <div class="flex flex-col md:flex-row md:items-center gap-4">
        <div class="shrink-0 w-14 h-14 rounded-full bg-purple-100 flex items-center justify-center">
          <svg class="w-7 h-7 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
          </svg>
        </div>
        <div class="flex-1">
          <h2 class="text-xl font-bold text-gray-900">{patient?.full_name || '-'}</h2>
          <div class="flex flex-wrap gap-x-6 gap-y-1 mt-1 text-sm text-gray-600">
            <span>No. RM: <strong class="text-gray-900 font-mono">{patient?.no_registration || '-'}</strong></span>
            <span>Jenis Kelamin: <strong class="text-gray-900">{patient?.gender === 'L' ? 'Laki-laki' : patient?.gender === 'P' ? 'Perempuan' : '-'}</strong></span>
            <span>No. Telepon: <strong class="text-gray-900">{patient?.phone || '-'}</strong></span>
          </div>
        </div>
        <div class="flex flex-wrap gap-3 text-sm">
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">Dokter</p>
            <p class="font-semibold text-gray-900">{doctor?.full_name || '-'}</p>
          </div>
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">Poli</p>
            <p class="font-semibold text-gray-900">{clinic?.name || '-'}</p>
          </div>
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">No. Tiket</p>
            <p class="font-semibold text-primary-600 font-mono">{visit?.ticket_no || '-'}</p>
          </div>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold text-gray-900">Daftar Obat Resep</h3>
        <div class="flex gap-2">
          <button class="btn-secondary btn-sm" onclick={printLabel}>
            <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0 1 10.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0 .229 2.523a1.125 1.125 0 0 1-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0 0 21 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 0 0-1.913-.247M6.34 18H5.25A2.25 2.25 0 0 1 3 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 0 1 1.913-.247m10.5 0a48.536 48.536 0 0 0-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659" />
            </svg>
            Cetak Label
          </button>
        </div>
      </div>

      {#if prescriptions.length === 0}
        <div class="text-center py-12 text-gray-400">
          <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" />
          </svg>
          <p class="text-lg font-medium">Tidak ada obat dalam resep ini</p>
        </div>
      {:else}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="table-header">
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Obat</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-center">Jml</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Dosis</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Frekuensi</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Instruksi</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Harga</th>
                <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-center">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each prescriptions as rx, i}
                {@const price = rx.sell_price || rx.drugs?.sell_price || 0}
                {@const subtotal = price * (rx.qty || 0)}
                {@const isDispensed = dispensedItems[rx.id] || rx.status === 'dispensed'}
                <tr class="hover:bg-gray-50 transition-colors {isDispensed ? 'bg-emerald-50/50' : ''}">
                  <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                  <td class="table-cell">
                    <div>
                      <p class="font-medium text-gray-900">{rx.drug_name || rx.drugs?.name || '-'}</p>
                      {#if rx.drugs?.code}
                        <p class="text-xs text-gray-400 font-mono">{rx.drugs.code}</p>
                      {/if}
                    </div>
                  </td>
                  <td class="table-cell text-center">
                    <span class="font-semibold text-gray-900">{rx.qty}</span>
                    <span class="text-xs text-gray-400 ml-1">{rx.drugs?.unit || ''}</span>
                  </td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{rx.dosage || '-'}</td>
                  <td class="table-cell text-gray-600 hidden md:table-cell">{rx.frequency || '-'}</td>
                  <td class="table-cell text-gray-600 hidden lg:table-cell">{rx.instruction || '-'}</td>
                  <td class="table-cell text-right font-semibold text-gray-900">{formatCurrency(subtotal)}</td>
                  <td class="table-cell text-center">
                    {#if rx.status === 'dispensed'}
                      <span class="badge badge-success">Diserahkan</span>
                    {:else}
                      <label class="inline-flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          class="w-4 h-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500"
                          checked={dispensedItems[rx.id] || false}
                          onchange={() => toggleDispensed(rx.id)}
                        />
                        <span class="text-xs text-gray-500">Serahkan</span>
                      </label>
                    {/if}
                  </td>
                </tr>
              {/each}
            </tbody>
            <tfoot>
              <tr class="border-t-2 border-gray-300">
                <td colspan="6" class="px-4 py-3 text-sm font-bold text-gray-900 text-right">Total Harga</td>
                <td class="px-4 py-3 text-sm font-bold text-primary-700 text-right">{formatCurrency(totalHarga)}</td>
                <td class="table-cell"></td>
              </tr>
            </tfoot>
          </table>
        </div>
      {/if}
    </div>

    <div class="card space-y-4">
      <div class="space-y-1">
        <label class="label">Catatan Farmasi (opsional)</label>
        <textarea
          class="input-field h-20 resize-none"
          bind:value={notes}
          placeholder="Catatan untuk obat yang diserahkan..."
        ></textarea>
      </div>
    </div>

    {#if prescriptions.some(rx => rx.status !== 'dispensed')}
      <div class="flex justify-end">
        <button
          class="btn-success"
          onclick={dispenseAll}
          disabled={saving || dispensing}
        >
          {#if dispensing}
            <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
          {/if}
          <svg class="w-5 h-5 inline-block mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
          </svg>
          Serahkan Resep
        </button>
      </div>
    {:else}
      <div class="card bg-emerald-50 border-emerald-200 text-center py-6">
        <svg class="w-12 h-12 mx-auto mb-3 text-emerald-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        <p class="font-semibold text-emerald-700">Semua obat sudah diserahkan</p>
        <p class="text-sm text-emerald-600 mt-1">Resep ini sudah ditangani sepenuhnya</p>
      </div>
    {/if}
  </div>
{/if}
