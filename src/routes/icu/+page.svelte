<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate } from '$lib/utils/helpers.js';
  import { addLabBill, addRadiologyBill, addDrugBill } from '$lib/billing.js';
  import { toast } from '$lib/toast.svelte.js';

  let loading = $state(true);
  let icuPatients = $state([]);
  let beds = $state([]);
  let searchQuery = $state('');

  let showQuickAction = $state(null);
  let quickActionData = $state({ patient_id: null, content: '' });

  const filteredPatients = $derived.by(() => {
    let result = icuPatients;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(p =>
        p.patient_name.toLowerCase().includes(q) ||
        p.patient_no?.toLowerCase().includes(q) ||
        p.room_name?.toLowerCase().includes(q)
      );
    }
    return result;
  });

  const stats = $derived({
    total: beds.length,
    occupied: beds.filter(b => b.status === 'occupied').length,
    available: beds.filter(b => b.status === 'empty').length,
    patients: icuPatients.length
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
      case 'worsening': return { label: 'Memburuk', class: 'badge-warning' };
      default: return { label: condition || '-', class: 'badge-gray' };
    }
  }

  function openQuickAction(patientId, action) {
    showQuickAction = action;
    quickActionData = { patient_id: patientId, content: '' };
  }

  function closeQuickAction() {
    showQuickAction = null;
    quickActionData = { patient_id: null, content: '' };
  }

  async function saveQuickAction() {
    if (!quickActionData.content?.trim()) {
      toast('Silakan isi data terlebih dahulu', 'error');
      return;
    }
    try {
      if (showQuickAction === 'cppt') {
        const { error } = await supabase.from('cppt').insert({
          visit_id: quickActionData.patient_id,
          subyektif: quickActionData.content
        });
        if (error) throw error;
        toast('CPPT berhasil disimpan', 'success');
      } else if (showQuickAction === 'lab') {
        const { data: order, error } = await supabase.from('lab_orders').insert({
          visit_id: quickActionData.patient_id,
          test_name: quickActionData.content,
          category: 'Lainnya',
          status: 'ordered'
        }).select().single();
        if (error) throw error;
        if (order) await addLabBill(order.visit_id, order.test_name, order.id);
        toast('Order laboratorium berhasil dibuat', 'success');
      } else if (showQuickAction === 'radiology') {
        const { data: order, error } = await supabase.from('radiology_orders').insert({
          visit_id: quickActionData.patient_id,
          examination_type: quickActionData.content,
          exam_type: quickActionData.content,
          description: quickActionData.content,
          status: 'ordered'
        }).select().single();
        if (error) throw error;
        if (order) await addRadiologyBill(order.visit_id, order.exam_type || order.examination_type, order.id);
        toast('Order radiologi berhasil dibuat', 'success');
      } else if (showQuickAction === 'medication') {
        const { data: prescription, error } = await supabase.from('prescriptions').insert({
          visit_id: quickActionData.patient_id,
          drug_name: quickActionData.content,
          qty: 1,
          prescription_type: 'ranap',
          status: 'pending'
        }).select().single();
        if (error) throw error;
        if (prescription) {
          const { data: drug } = await supabase.from('drugs')
            .select('drug_id, sell_price')
            .ilike('name', prescription.drug_name)
            .limit(1)
            .maybeSingle();
          await addDrugBill(prescription.visit_id, drug?.drug_id || null, prescription.drug_name, prescription.qty, prescription.id);
        }
        toast('Obat berhasil ditambahkan', 'success');
      }
      closeQuickAction();
    } catch (err) {
      console.error('Save quick action error:', err);
      toast(`Gagal menyimpan: ${err.message || err}`, 'error');
    }
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
          status: b.is_occupied ? 'occupied' : 'empty',
          rooms: room
            ? { ...room, name: room.room_number, class: roomClass?.name || '-' }
            : room
        };
      }).filter(b => b.rooms?.class === 'ICU' || b.rooms?.class === 'HCU');
    } catch (err) {
      console.error('Fetch ICU beds error:', err);
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
          patients:patient_id ( full_name, no_registration ),
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
        ventilator: false,
        iv_medications: []
      }));

      icuPatients = allPatients.filter(p => p.room_class === 'ICU' || p.room_class === 'HCU');
    } catch (err) {
      console.error('Fetch ICU patients error:', err);
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
  <title>ICU - Intensive Care Unit</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div class="flex items-center gap-3">
      <div class="w-10 h-10 rounded-lg bg-red-600 flex items-center justify-center">
        <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
        </svg>
      </div>
      <div>
        <h1 class="text-2xl font-bold text-red-700">Intensive Care Unit (ICU)</h1>
        <p class="text-sm text-gray-500 mt-0.5">Pemantauan pasien kritis dan bed ICU</p>
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
      <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Total Bed ICU</p>
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
    <div class="card p-4 border-amber-200 bg-amber-50">
      <p class="text-xs text-amber-700 uppercase tracking-wide font-medium">Pasien ICU</p>
      <p class="text-2xl font-bold text-amber-700 mt-1">{stats.patients}</p>
    </div>
  </div>

  {#if beds.length > 0}
    <div class="card">
      <div class="flex items-center gap-2 mb-4">
        <svg class="w-5 h-5 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25a2.25 2.25 0 0 1-2.25-2.25v-2.25Z" />
        </svg>
        <h2 class="text-lg font-semibold text-gray-900">Status Bed ICU</h2>
      </div>
      <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-3">
        {#each beds as bed}
          <div class="rounded-xl border-2 p-3 text-center transition-all
            {bed.status === 'occupied' ? 'border-red-300 bg-red-50' : 'border-emerald-300 bg-emerald-50'}">
            <p class="font-bold text-sm {bed.status === 'occupied' ? 'text-red-700' : 'text-emerald-700'}">{bed.bed_no}</p>
            <p class="text-[10px] {bed.status === 'occupied' ? 'text-red-500' : 'text-emerald-500'} mt-0.5">
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
        <svg class="w-5 h-5 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z" />
        </svg>
        <h2 class="text-lg font-semibold text-gray-900">Pasien ICU</h2>
      </div>
      <div class="relative">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
        </svg>
        <input type="text" class="input-field pl-10 w-64" placeholder="Cari pasien..." bind:value={searchQuery} />
      </div>
    </div>

    <div class="overflow-x-auto">
      {#if loading}
        <div class="flex items-center justify-center py-16">
          <div class="w-10 h-10 border-4 border-red-200 border-t-red-600 rounded-full animate-spin"></div>
        </div>
      {:else if filteredPatients.length === 0}
        <div class="text-center py-16 text-gray-400">
          <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
          </svg>
          <p class="text-lg font-medium">Tidak ada pasien ICU</p>
        </div>
      {:else}
        <table class="w-full">
          <thead>
            <tr class="table-header">
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No.RM</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Kamar</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden sm:table-cell">Tgl Masuk</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Hari ke-</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Kondisi</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Dokter</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Vital Signs</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden xl:table-cell">Ventilator</th>
              <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            {#each filteredPatients as ip, i}
              {@const condition = getConditionBadge(ip.condition)}
              <tr class="hover:bg-gray-50 transition-colors">
                <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                <td class="table-cell">
                  <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">{ip.patient_no}</span>
                </td>
                <td class="table-cell">
                  <p class="font-medium text-gray-900">{ip.patient_name}</p>
                </td>
                <td class="table-cell text-gray-600 hidden md:table-cell">{ip.room_name}</td>
                <td class="table-cell text-gray-500 hidden sm:table-cell font-mono text-xs">{formatDate(ip.admission_date)}</td>
                <td class="table-cell">
                  <span class="inline-flex items-center justify-center w-8 h-8 rounded-full {ip.days_stayed > 7 ? 'bg-red-100 text-red-700' : ip.days_stayed > 3 ? 'bg-amber-100 text-amber-700' : 'bg-emerald-100 text-emerald-700'} text-xs font-bold">
                    {ip.days_stayed}
                  </span>
                </td>
                <td class="table-cell hidden lg:table-cell">
                  <span class="badge {condition.class}">{condition.label}</span>
                </td>
                <td class="table-cell text-gray-600 hidden lg:table-cell">{ip.doctor_name}</td>
                <td class="table-cell">
                  <div class="flex gap-1">
                    <span class="text-[10px] bg-red-50 text-red-700 px-1.5 py-0.5 rounded">HR</span>
                    <span class="text-[10px] bg-blue-50 text-blue-700 px-1.5 py-0.5 rounded">SpO2</span>
                    <span class="text-[10px] bg-amber-50 text-amber-700 px-1.5 py-0.5 rounded">BP</span>
                  </div>
                </td>
                <td class="table-cell hidden xl:table-cell">
                  {#if ip.ventilator}
                    <span class="badge badge-danger">Ya</span>
                  {:else}
                    <span class="badge badge-gray">Tidak</span>
                  {/if}
                </td>
                <td class="table-cell text-right">
                  <div class="flex gap-1 justify-end">
                    <button class="btn-secondary btn-sm text-[10px] px-2 py-1" onclick={() => openQuickAction(ip.visit_id, 'cppt')} title="CPPT">CPPT</button>
                    <button class="btn-secondary btn-sm text-[10px] px-2 py-1" onclick={() => openQuickAction(ip.visit_id, 'lab')} title="Lab">Lab</button>
                    <button class="btn-secondary btn-sm text-[10px] px-2 py-1" onclick={() => openQuickAction(ip.visit_id, 'radiology')} title="Radiologi">Radiologi</button>
                    <button class="btn-secondary btn-sm text-[10px] px-2 py-1" onclick={() => openQuickAction(ip.visit_id, 'medication')} title="Obat">Obat</button>
                    <a href="/rawat-inap/{ip.visit_id}" class="btn-primary btn-sm text-[10px] px-2 py-1">Detail</a>
                  </div>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>
  </div>
</div>

{#if showQuickAction}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" onclick={closeQuickAction} role="presentation">
    <div
      class="bg-white rounded-2xl shadow-xl max-w-md w-full mx-4"
      onclick={(e) => e.stopPropagation()}
      role="dialog"
    >
      <div class="flex items-center justify-between p-5 border-b border-gray-200">
        <h3 class="text-lg font-bold text-gray-900">
          {#if showQuickAction === 'cppt'}Tambah CPPT
          {:else if showQuickAction === 'lab'}Order Laboratorium
          {:else if showQuickAction === 'radiology'}Order Radiologi
          {:else if showQuickAction === 'medication'}Tambah Obat
          {/if}
        </h3>
        <button class="text-gray-400 hover:text-gray-600 transition-colors" onclick={closeQuickAction}>
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="p-5 space-y-4">
        <div>
          <label class="label">
            {#if showQuickAction === 'cppt'}Isi CPPT
            {:else if showQuickAction === 'lab'}Pemeriksaan
            {:else if showQuickAction === 'radiology'}Pemeriksaan
            {:else if showQuickAction === 'medication'}Nama Obat
            {/if}
          </label>
          {#if showQuickAction === 'cppt'}
            <textarea class="input-field" rows="4" placeholder="Isi CPPT..." bind:value={quickActionData.content}></textarea>
          {:else}
            <input type="text" class="input-field" placeholder="Nama pemeriksaan/obat" bind:value={quickActionData.content} />
          {/if}
        </div>
        <div class="flex justify-end gap-2">
          <button class="btn-secondary btn-sm" onclick={closeQuickAction}>Batal</button>
          <button class="btn-primary btn-sm" onclick={saveQuickAction}>Simpan</button>
        </div>
      </div>
    </div>
  </div>
{/if}
