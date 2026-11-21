<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime, withBasePath } from '$lib/utils/helpers.js';
  import { toast } from '$lib/toast.svelte.js';

  // State
  let loading = $state(true);
  let submitting = $state(false);
  let error = $state('');

  // Selected visit from outpatient / IGD
  let selectedVisit = $state(null);
  let searchQuery = $state('');
  let candidateVisits = $state([]);
  let searchingVisits = $state(false);
  let searchTimeout;

  // Admit form details
  let classId = $state('');
  let roomId = $state('');
  let bedId = $state('');
  let doctorId = $state('');
  let inDate = $state(new Date().toISOString().slice(0, 16));
  let notes = $state('');

  // Master data
  let roomClasses = $state([]);
  let rooms = $state([]);
  let availableBeds = $state([]);
  let doctors = $state([]);

  // Check query params
  const paramVisitId = $derived(page.url.searchParams.get('visit_id'));
  const paramRoomId = $derived(page.url.searchParams.get('room_id'));
  const paramBedId = $derived(page.url.searchParams.get('bed_id'));

  const isFormValid = $derived(
    Boolean(selectedVisit && classId && roomId && bedId)
  );

  async function fetchMasterData() {
    try {
      const [classesResult, doctorsResult] = await Promise.all([
        supabase.from('room_classes').select('class_id, name').order('name'),
        supabase.from('employees').select('employee_id, full_name').eq('is_dpjp', true).eq('is_active', true).order('full_name')
      ]);

      roomClasses = classesResult.data || [];
      doctors = doctorsResult.data || [];
    } catch (err) {
      console.error('Fetch master data error:', err);
    }
  }

  async function fetchCandidateVisits(query = '') {
    searchingVisits = true;
    try {
      let q = supabase
        .from('patient_visitations')
        .select(`
          visit_id,
          visit_date,
          visit_type,
          ticket_no,
          status_periksa,
          status_pembayaran,
          clinic_id,
          doctor_id,
          description,
          patients:patient_id (
            patient_id,
            full_name,
            no_registration,
            nik,
            gender,
            date_of_birth,
            phone,
            address,
            blood_type
          ),
          clinics:clinic_id ( clinic_id, name ),
          employees:doctor_id ( employee_id, full_name ),
          payors:payor_id ( name, type )
        `)
        .in('visit_type', ['rawat_jalan', 'igd'])
        .is('room_id', null)
        .is('exit_date', null)
        .order('visit_date', { ascending: false })
        .limit(20);

      if (query.trim()) {
        const clean = query.trim();
        q = q.or(`visit_id.ilike.%${clean}%,patients.full_name.ilike.%${clean}%,patients.no_registration.ilike.%${clean}%,patients.nik.ilike.%${clean}%`);
      }

      const { data, error: fetchErr } = await q;
      if (fetchErr) throw fetchErr;

      candidateVisits = (data || []).map(v => {
        const patient = Array.isArray(v.patients) ? v.patients[0] : v.patients;
        const clinic = Array.isArray(v.clinics) ? v.clinics[0] : v.clinics;
        const doctor = Array.isArray(v.employees) ? v.employees[0] : v.employees;
        const payor = Array.isArray(v.payors) ? v.payors[0] : v.payors;

        return {
          ...v,
          patient,
          clinic_name: clinic?.name || '-',
          doctor_name: doctor?.full_name || '-',
          payor_name: payor?.name || 'Umum'
        };
      });
    } catch (err) {
      console.error('Fetch candidate visits error:', err);
    } finally {
      searchingVisits = false;
    }
  }

  async function fetchVisitById(id) {
    if (!id) return;
    try {
      const { data, error: fetchErr } = await supabase
        .from('patient_visitations')
        .select(`
          visit_id,
          visit_date,
          visit_type,
          ticket_no,
          status_periksa,
          status_pembayaran,
          clinic_id,
          doctor_id,
          description,
          patients:patient_id (
            patient_id,
            full_name,
            no_registration,
            nik,
            gender,
            date_of_birth,
            phone,
            address,
            blood_type
          ),
          clinics:clinic_id ( clinic_id, name ),
          employees:doctor_id ( employee_id, full_name ),
          payors:payor_id ( name, type )
        `)
        .eq('visit_id', id)
        .single();

      if (fetchErr) throw fetchErr;

      if (data) {
        const patient = Array.isArray(data.patients) ? data.patients[0] : data.patients;
        const clinic = Array.isArray(data.clinics) ? data.clinics[0] : data.clinics;
        const doctor = Array.isArray(data.employees) ? data.employees[0] : data.employees;
        const payor = Array.isArray(data.payors) ? data.payors[0] : data.payors;

        selectVisit({
          ...data,
          patient,
          clinic_name: clinic?.name || '-',
          doctor_name: doctor?.full_name || '-',
          payor_name: payor?.name || 'Umum'
        });
      }
    } catch (err) {
      console.error('Fetch visit by ID error:', err);
    }
  }

  function handleSearchInput(e) {
    clearTimeout(searchTimeout);
    const q = e.target.value;
    searchTimeout = setTimeout(() => {
      fetchCandidateVisits(q);
    }, 300);
  }

  function selectVisit(v) {
    selectedVisit = v;
    if (v.doctor_id) {
      doctorId = v.doctor_id;
    }
    error = '';
  }

  function clearSelectedVisit() {
    selectedVisit = null;
    searchQuery = '';
    fetchCandidateVisits();
  }

  async function fetchRoomsByClass(selectedClassId) {
    if (!selectedClassId) {
      rooms = [];
      roomId = '';
      bedId = '';
      availableBeds = [];
      return;
    }
    try {
      const { data, error: roomErr } = await supabase
        .from('rooms')
        .select(`
          room_id,
          room_number,
          beds (
            bed_id,
            bed_number,
            is_occupied,
            is_active
          )
        `)
        .eq('class_id', selectedClassId)
        .eq('is_active', true)
        .order('room_number');

      if (roomErr) throw roomErr;
      rooms = data || [];
    } catch (err) {
      console.error('Fetch rooms error:', err);
      rooms = [];
    }
  }

  async function fetchAvailableBeds(selectedRoomId) {
    if (!selectedRoomId) {
      availableBeds = [];
      bedId = '';
      return;
    }
    try {
      const { data, error: bedErr } = await supabase
        .from('beds')
        .select('bed_id, bed_number, is_occupied')
        .eq('room_id', selectedRoomId)
        .eq('is_active', true)
        .eq('is_occupied', false)
        .order('bed_number');

      if (bedErr) throw bedErr;
      availableBeds = data || [];
    } catch (err) {
      console.error('Fetch beds error:', err);
      availableBeds = [];
    }
  }

  async function handleAdmit() {
    if (!isFormValid) {
      error = 'Mohon lengkapi pemilihan Pasien, Kelas, Kamar, dan Tempat Tidur.';
      return;
    }

    submitting = true;
    error = '';

    try {
      // 1. Update patient_visitations with same visit_id (Id Rawat Jalan)
      const updatePayload = {
        visit_type: 'rawat_inap',
        class_id: classId,
        room_id: roomId,
        bed_id: bedId,
        in_date: inDate ? new Date(inDate).toISOString() : new Date().toISOString(),
        status_keluar: '0'
      };

      if (doctorId) {
        updatePayload.doctor_id = doctorId;
      }

      if (notes.trim()) {
        const prevDesc = selectedVisit.description ? `${selectedVisit.description} | ` : '';
        updatePayload.description = `${prevDesc}Admit Rawat Inap: ${notes.trim()}`;
      }

      const { error: visitUpdateErr } = await supabase
        .from('patient_visitations')
        .update(updatePayload)
        .eq('visit_id', selectedVisit.visit_id);

      if (visitUpdateErr) throw visitUpdateErr;

      // 2. Mark bed as occupied
      const { error: bedUpdateErr } = await supabase
        .from('beds')
        .update({ is_occupied: true })
        .eq('bed_id', bedId);

      if (bedUpdateErr) throw bedUpdateErr;

      // 3. Log room transfer / initial admit record
      try {
        await supabase
          .from('room_transfers')
          .insert({
            visit_id: selectedVisit.visit_id,
            to_room_id: roomId,
            to_bed_id: bedId,
            reason: notes || 'Admit dari Rawat Jalan / IGD'
          });
      } catch (logErr) {
        console.warn('Room transfer log warning:', logErr);
      }

      toast('Pasien berhasil di-admit ke Rawat Inap!', 'success');
      goto(withBasePath('/rawat-inap'));
    } catch (err) {
      console.error('Admit error:', err);
      error = err.message || 'Gagal memproses admit rawat inap.';
      toast(error, 'error');
    } finally {
      submitting = false;
    }
  }

  onMount(async () => {
    loading = true;
    await fetchMasterData();

    if (paramVisitId) {
      await fetchVisitById(paramVisitId);
    } else {
      await fetchCandidateVisits();
    }

    if (paramRoomId) {
      const { data: rm } = await supabase.from('rooms').select('class_id').eq('room_id', paramRoomId).single();
      if (rm?.class_id) {
        classId = rm.class_id;
        await fetchRoomsByClass(classId);
        roomId = paramRoomId;
        await fetchAvailableBeds(roomId);
        if (paramBedId) {
          bedId = paramBedId;
        }
      }
    }

    loading = false;
  });

  $effect(() => {
    if (classId) {
      fetchRoomsByClass(classId);
    }
  });

  $effect(() => {
    if (roomId) {
      fetchAvailableBeds(roomId);
    }
  });
</script>

<svelte:head>
  <title>Admit Pasien Rawat Inap - SIMRS</title>
</svelte:head>

<div class="max-w-6xl mx-auto space-y-6">
  <!-- Header -->
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div class="flex items-center gap-3">
      <a href="/rawat-inap" aria-label="Kembali ke Rawat Inap" class="p-2 rounded-lg text-gray-500 hover:bg-gray-100 transition-colors">
        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
        </svg>
      </a>
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Admit Pasien Rawat Inap</h1>
        <p class="text-sm text-gray-500">Pindahkan pasien dari kunjungan Rawat Jalan / IGD ke Tempat Tidur Rawat Inap</p>
      </div>
    </div>
  </div>

  <!-- Flow Explanation Banner -->
  <div class="bg-gradient-to-r from-primary-900 to-indigo-900 text-white rounded-2xl p-5 shadow-sm border border-primary-800">
    <div class="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
      <div class="space-y-1">
        <div class="flex items-center gap-2">
          <span class="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-white/20 text-white uppercase tracking-wider">
            Alur Terintegrasi
          </span>
          <h2 class="text-base font-semibold">Id Rawat Jalan sebagai Kunci Transaksi Tunggal</h2>
        </div>
        <p class="text-xs text-primary-200 max-w-2xl leading-relaxed">
          Semua transaksi pemeriksaan poli/IGD, tindakan, lab, radiologi, hingga kasir berawal dari <strong>ID Rawat Jalan (VST-...)</strong>. Saat pasien di-admit ke Rawat Inap, ID kunjungan ini tetap dipertahankan sehingga seluruh biaya dan riwayat tersambung utuh sampai kasir.
        </p>
      </div>
      <div class="flex items-center gap-2 bg-black/25 px-3 py-2 rounded-xl text-xs font-mono text-primary-200 shrink-0">
        <span>Reg / Poli</span>
        <svg class="w-3.5 h-3.5 text-primary-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3" />
        </svg>
        <span class="text-white font-bold">Admit Ranap</span>
        <svg class="w-3.5 h-3.5 text-primary-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3" />
        </svg>
        <span>Kasir</span>
      </div>
    </div>
  </div>

  {#if error}
    <div class="p-4 bg-red-50 border border-red-200 rounded-xl flex items-start gap-3">
      <svg class="w-5 h-5 text-red-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <div>
        <p class="text-sm font-semibold text-red-800">Perhatian</p>
        <p class="text-xs text-red-600 mt-0.5">{error}</p>
      </div>
    </div>
  {/if}

  <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
    <!-- Left Column: Patient / Visit Selection (5 cols) -->
    <div class="lg:col-span-5 space-y-4">
      <div class="card p-5 space-y-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="w-6 h-6 rounded-full bg-primary-100 text-primary-700 text-xs font-bold flex items-center justify-center">1</span>
            <h3 class="font-bold text-gray-900 text-sm">Pilih Kunjungan Rawat Jalan / IGD</h3>
          </div>
          {#if selectedVisit}
            <button class="text-xs font-semibold text-primary-600 hover:text-primary-800" onclick={clearSelectedVisit}>
              Ganti Pasien
            </button>
          {/if}
        </div>

        {#if selectedVisit}
          <!-- Selected Visit Card -->
          <div class="p-4 rounded-xl border-2 border-primary-200 bg-primary-50/50 space-y-3">
            <div class="flex items-start justify-between">
              <div>
                <span class="font-mono text-xs font-bold text-primary-700 bg-primary-100/80 px-2 py-0.5 rounded">
                  {selectedVisit.visit_id}
                </span>
                <h4 class="text-base font-bold text-gray-900 mt-1">{selectedVisit.patient?.full_name || '-'}</h4>
                <p class="text-xs text-gray-500">No. RM: <strong class="text-gray-700 font-mono">{selectedVisit.patient?.no_registration || '-'}</strong></p>
              </div>
              <span class="badge {selectedVisit.visit_type === 'igd' ? 'badge-danger' : 'badge-info'} text-[10px]">
                {selectedVisit.clinic_name}
              </span>
            </div>

            <div class="grid grid-cols-2 gap-2 text-xs pt-2 border-t border-primary-100">
              <div>
                <span class="text-gray-400 block">Jenis Kelamin:</span>
                <span class="font-medium text-gray-700">{selectedVisit.patient?.gender === 'L' ? 'Laki-laki' : selectedVisit.patient?.gender === 'P' ? 'Perempuan' : '-'}</span>
              </div>
              <div>
                <span class="text-gray-400 block">Tgl Lahir / Usia:</span>
                <span class="font-medium text-gray-700">{formatDate(selectedVisit.patient?.date_of_birth)}</span>
              </div>
              <div>
                <span class="text-gray-400 block">Dokter Pengirim:</span>
                <span class="font-medium text-gray-700">{selectedVisit.doctor_name}</span>
              </div>
              <div>
                <span class="text-gray-400 block">Penjamin:</span>
                <span class="font-medium text-gray-700">{selectedVisit.payor_name}</span>
              </div>
            </div>

            {#if selectedVisit.description}
              <div class="p-2.5 bg-white rounded-lg border border-primary-100 text-xs text-gray-600">
                <span class="font-semibold text-gray-700 block mb-0.5">Keluhan / Catatan Awal:</span>
                {selectedVisit.description}
              </div>
            {/if}
          </div>
        {:else}
          <!-- Search input -->
          <div>
            <label class="label" for="searchVisit">Cari ID Rawat Jalan (vst-), No RM, atau Nama</label>
            <div class="relative">
              <input
                id="searchVisit"
                type="text"
                class="input-field pl-9 text-sm"
                placeholder="Ketik ID kunjungan vst-..., nama, atau no RM..."
                bind:value={searchQuery}
                oninput={handleSearchInput}
              />
              <svg class="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
              </svg>
            </div>
          </div>

          <!-- List of candidate visits -->
          <div class="space-y-2 max-h-[420px] overflow-y-auto pr-1">
            <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">
              Kunjungan Rawat Jalan &amp; IGD Aktif
            </p>

            {#if searchingVisits}
              <div class="py-8 text-center text-gray-400">
                <div class="w-6 h-6 border-2 border-primary-600 border-t-transparent rounded-full animate-spin mx-auto mb-2"></div>
                <p class="text-xs">Mencari kunjungan...</p>
              </div>
            {:else if candidateVisits.length === 0}
              <div class="py-8 text-center text-gray-400 border border-dashed rounded-xl p-4">
                <p class="text-sm font-medium">Tidak ada kunjungan ditemukan</p>
                <p class="text-xs mt-1 text-gray-400">Pastikan pasien sudah terdaftar di Rawat Jalan / IGD dan belum di-admit.</p>
              </div>
            {:else}
              {#each candidateVisits as v}
                <button
                  type="button"
                  class="w-full text-left p-3 rounded-xl border border-gray-200 hover:border-primary-400 hover:bg-primary-50/40 transition-all space-y-1.5 cursor-pointer group"
                  onclick={() => selectVisit(v)}
                >
                  <div class="flex items-center justify-between">
                    <span class="font-mono text-xs font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded group-hover:bg-white">
                      {v.visit_id}
                    </span>
                    <span class="badge {v.visit_type === 'igd' ? 'badge-danger' : 'badge-info'} text-[10px]">
                      {v.clinic_name}
                    </span>
                  </div>
                  <div>
                    <p class="font-bold text-gray-900 text-sm">{v.patient?.full_name || '-'}</p>
                    <p class="text-xs text-gray-500">RM: <span class="font-mono">{v.patient?.no_registration || '-'}</span> • {v.doctor_name}</p>
                  </div>
                  <div class="flex items-center justify-between text-[11px] text-gray-400 pt-1 border-t border-gray-100">
                    <span>{formatDateTime(v.visit_date)}</span>
                    <span class="text-primary-600 font-semibold group-hover:underline">Pilih Pasien &rarr;</span>
                  </div>
                </button>
              {/each}
            {/if}
          </div>
        {/if}
      </div>
    </div>

    <!-- Right Column: Room & Bed Placement (7 cols) -->
    <div class="lg:col-span-7 space-y-6">
      <div class="card p-5 space-y-6">
        <div class="flex items-center gap-2">
          <span class="w-6 h-6 rounded-full bg-primary-100 text-primary-700 text-xs font-bold flex items-center justify-center">2</span>
          <h3 class="font-bold text-gray-900 text-sm">Penempatan Kamar &amp; Tempat Tidur</h3>
        </div>

        {#if !selectedVisit}
          <div class="p-8 text-center text-gray-400 border-2 border-dashed rounded-xl bg-gray-50/60">
            <svg class="w-12 h-12 mx-auto mb-2 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
            </svg>
            <p class="text-sm font-semibold text-gray-700">Pilih Pasien Terlebih Dahulu</p>
            <p class="text-xs text-gray-500 mt-1">Pilih ID Rawat Jalan pasien di kolom sebelah kiri untuk membuka form penempatan kamar.</p>
          </div>
        {:else}
          <div class="space-y-4">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <!-- Kelas Kamar -->
              <div>
                <label class="label" for="roomClass">Kelas Kamar <span class="text-red-500">*</span></label>
                <select id="roomClass" bind:value={classId} class="select-field">
                  <option value="">- Pilih Kelas Kamar -</option>
                  {#each roomClasses as rc}
                    <option value={rc.class_id}>{rc.name}</option>
                  {/each}
                </select>
              </div>

              <!-- Kamar -->
              <div>
                <label class="label" for="room">Kamar <span class="text-red-500">*</span></label>
                <select id="room" bind:value={roomId} class="select-field" disabled={!classId}>
                  <option value="">- {classId ? 'Pilih Kamar' : 'Pilih Kelas Dahulu'} -</option>
                  {#each rooms as r}
                    {@const available = (r.beds || []).filter(b => !b.is_occupied).length}
                    <option value={r.room_id} disabled={available === 0}>
                      {r.room_number} ({available} bed tersedia)
                    </option>
                  {/each}
                </select>
              </div>

              <!-- Tempat Tidur -->
              <div>
                <label class="label" for="bed">Tempat Tidur (Bed) <span class="text-red-500">*</span></label>
                <select id="bed" bind:value={bedId} class="select-field" disabled={!roomId}>
                  <option value="">- {roomId ? 'Pilih Tempat Tidur' : 'Pilih Kamar Dahulu'} -</option>
                  {#each availableBeds as b}
                    <option value={b.bed_id}>Bed No. {b.bed_number}</option>
                  {/each}
                </select>
                {#if roomId && availableBeds.length === 0}
                  <p class="text-xs text-red-500 mt-1 font-medium">Semua tempat tidur di kamar ini sedang penuh.</p>
                {/if}
              </div>

              <!-- Dokter DPJP Rawat Inap -->
              <div>
                <label class="label" for="doctor">Dokter DPJP Rawat Inap</label>
                <select id="doctor" bind:value={doctorId} class="select-field">
                  <option value="">- Pilih Dokter DPJP -</option>
                  {#each doctors as d}
                    <option value={d.employee_id}>{d.full_name}</option>
                  {/each}
                </select>
              </div>

              <!-- Tanggal & Waktu Masuk -->
              <div class="sm:col-span-2">
                <label class="label" for="inDate">Waktu Masuk Rawat Inap <span class="text-red-500">*</span></label>
                <input
                  id="inDate"
                  type="datetime-local"
                  bind:value={inDate}
                  class="input-field"
                />
              </div>

              <!-- Catatan Masuk -->
              <div class="sm:col-span-2">
                <label class="label" for="notes">Indikasi Masuk / Catatan Medis Rawat Inap</label>
                <textarea
                  id="notes"
                  rows="3"
                  class="input-field text-sm"
                  placeholder="Contoh: Observasi demam hari ke-4, rencana terapi cairan parenteral dan antibiotik..."
                  bind:value={notes}
                ></textarea>
              </div>
            </div>

            <!-- Confirmation Action -->
            <div class="pt-4 border-t border-gray-100 flex items-center justify-between gap-4">
              <a href="/rawat-inap" class="btn-secondary text-sm">
                Batal
              </a>
              <button
                type="button"
                class="btn-primary text-sm inline-flex items-center gap-2"
                disabled={!isFormValid || submitting}
                onclick={handleAdmit}
              >
                {#if submitting}
                  <div class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                  <span>Menyimpan...</span>
                {:else}
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="m4.5 12.75 6 6 9-13.5" />
                  </svg>
                  <span>Selesai - Admit ke Rawat Inap</span>
                {/if}
              </button>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>
