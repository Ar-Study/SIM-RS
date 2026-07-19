<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase.js';
  import { generateVisitId, formatDate } from '$lib/utils/helpers.js';
  import { VISIT_TYPES } from '$lib/utils/constants.js';

  let currentStep = $state(1);
  let loading = $state(false);
  let saving = $state(false);
  let error = $state('');
  let success = $state('');

  // Patient search
  let patientSearch = $state('');
  let patientResults = $state([]);
  let searchingPatient = $state(false);
  let showNewPatientForm = $state(false);
  let searchTimeout;

  // Patient data (selected or new)
  let selectedPatient = $state(null);

  // New patient form
  let newPatient = $state({
    full_name: '',
    nik: '',
    no_registration: '',
    date_of_birth: '',
    gender: 'L',
    phone: '',
    address: '',
    blood_type: '',
    religion: '',
    payor_id: '',
    insurance_number: ''
  });

  // Visit details
  let visitType = $state('rawat_jalan');
  let clinicId = $state('');
  let doctorId = $state('');
  let payorId = $state('');
  let classId = $state('');
  let roomId = $state('');
  let bedId = $state('');
  let notes = $state('');

  // Master data
  let clinics = $state([]);
  let doctors = $state([]);
  let filteredDoctors = $state([]);
  let roomClasses = $state([]);
  let rooms = $state([]);
  let availableBeds = $state([]);
  let payors = $state([]);

  const bloodTypes = ['A', 'B', 'AB', 'O'];
  const religions = ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'];

  const isFormValid = $derived.by(() => {
    if (!selectedPatient && !showNewPatientForm) return false;
    if (showNewPatientForm && (!newPatient.full_name || !newPatient.date_of_birth)) return false;
    if (!visitType) return false;
    if (!clinicId) return false;
    if (visitType === 'rawat_inap') {
      if (!classId || !roomId || !bedId) return false;
    }
    return true;
  });

  function handlePatientSearch(e) {
    clearTimeout(searchTimeout);
    const q = e.target.value.trim();
    if (q.length < 2) {
      patientResults = [];
      return;
    }
    searchTimeout = setTimeout(async () => {
      searchingPatient = true;
      try {
        const { data, error } = await supabase
          .from('patients')
          .select('patient_id, full_name, no_registration, nik, date_of_birth, gender, phone, address, blood_type, religion, payor_id, insurance_number')
          .or(`full_name.ilike.%${q}%,nik.ilike.%${q}%,no_registration.ilike.%${q}%`)
          .limit(10);
        if (error) throw error;
        patientResults = data || [];
      } catch (err) {
        console.error('Search error:', err);
        patientResults = [];
      } finally {
        searchingPatient = false;
      }
    }, 300);
  }

  function selectPatient(patient) {
    selectedPatient = patient;
    showNewPatientForm = false;
    payorId = patient.payor_id || '';
    patientSearch = patient.full_name;
    patientResults = [];
  }

  function clearPatientSelection() {
    selectedPatient = null;
    showNewPatientForm = false;
    patientSearch = '';
    patientResults = [];
    payorId = '';
    newPatient = {
      full_name: '', nik: '', no_registration: '', date_of_birth: '',
      gender: 'L', phone: '', address: '', blood_type: '', religion: '',
      payor_id: '', insurance_number: ''
    };
  }

  async function fetchMasterData() {
    try {
      const [clinicsResult, doctorsResult, classesResult, payorsResult] = await Promise.all([
        supabase.from('clinics').select('clinic_id, name').eq('is_active', true).order('name'),
        supabase.from('employees').select('employee_id, fullname').eq('is_dpjp', true).eq('is_active', true).order('fullname'),
        supabase.from('room_classes').select('class_id, name').order('name'),
        supabase.from('payors').select('payor_id, name, type').eq('is_active', true).order('name')
      ]);
      

      clinics = clinicsResult.data || [];
      doctors = doctorsResult.data || [];
      filteredDoctors = doctorsResult.data || [];
      roomClasses = classesResult.data || [];
      payors = payorsResult.data || [];
      console.log('Master data fetched:', { clinics, doctors, roomClasses, payors });
    } catch (err) {
      console.error('Fetch master data error:', err);
    }
  }

  function fetchDoctorsByClinic() {
    // employees table in full migration has no clinic_id relation
    filteredDoctors = doctors;
  }

  async function fetchRoomsByClass(classId) {
    if (!classId) {
      rooms = [];
      return;
    }
    try {
      const { data, error } = await supabase
        .from('rooms')
        .select(`
          room_id,
          room_number,
          beds:beds (
            bed_id,
            bed_number,
            is_occupied,
            is_active
          )
        `)
        .eq('class_id', classId)
        .eq('is_active', true)
        .order('room_number');
      if (error) throw error;
      rooms = data || [];
    } catch (err) {
      console.error('Fetch rooms error:', err);
      rooms = [];
    }
  }

  async function fetchAvailableBeds(roomId) {
    if (!roomId) {
      availableBeds = [];
      return;
    }
    try {
      const { data, error } = await supabase
        .from('beds')
        .select('bed_id, bed_number, is_occupied')
        .eq('room_id', roomId)
        .eq('is_active', true)
        .eq('is_occupied', false)
        .order('bed_number');
      if (error) throw error;
      availableBeds = data || [];
    } catch (err) {
      console.error('Fetch beds error:', err);
      availableBeds = [];
    }
  }

  function goNext() {
    if (currentStep === 1 && !selectedPatient && !showNewPatientForm) {
      error = 'Silakan pilih pasien atau buat pasien baru';
      return;
    }
    if (currentStep === 1 && showNewPatientForm && !newPatient.full_name) {
      error = 'Nama pasien wajib diisi';
      return;
    }
    if (currentStep === 1 && showNewPatientForm && !newPatient.date_of_birth) {
      error = 'Tanggal lahir wajib diisi';
      return;
    }
    if (currentStep === 2) {
      if (!clinicId) {
        error = 'Poli wajib dipilih';
        return;
      }
      if (visitType === 'rawat_inap') {
        if (!classId || !roomId || !bedId) {
          error = 'Kelas, kamar, dan tempat tidur wajib dipilih untuk rawat inap';
          return;
        }
      }
    }
    error = '';
    currentStep++;
  }

  function goBack() {
    error = '';
    currentStep--;
  }

  async function handleSave() {
    saving = true;
    error = '';
    try {
      let patientId = selectedPatient?.patient_id;

      if (showNewPatientForm && !selectedPatient) {
        const { count } = await supabase
          .from('patients')
          .select('patient_id', { count: 'exact', head: true });
        const seq = (count || 0) + 1;
        const y = new Date().getFullYear().toString().slice(-2);
        const m = String(new Date().getMonth() + 1).padStart(2, '0');
        const noReg = `RM${y}${m}${String(seq).padStart(5, '0')}`;

        const { data: newPatientData, error: patientError } = await supabase
          .from('patients')
          .insert({
            full_name: newPatient.full_name,
            nik: newPatient.nik || null,
            no_registration: noReg,
            date_of_birth: newPatient.date_of_birth,
            gender: newPatient.gender,
            phone: newPatient.phone || null,
            address: newPatient.address || null,
            blood_type: newPatient.blood_type || null,
            religion: newPatient.religion || null,
            payor_id: newPatient.payor_id || null,
            insurance_number: newPatient.insurance_number || null
          })
          .select('patient_id')
          .single();

        if (patientError) throw patientError;
        patientId = newPatientData.patient_id;
      }

      if (!patientId) {
        throw new Error('Gagal mendapatkan ID pasien');
      }

      const visitData = {
        patient_id: patientId,
        clinic_id: clinicId,
        visit_id: generateVisitId(),
        doctor_id: doctorId || null,
        visit_type: visitType,
        visit_date: new Date().toISOString(),
        status_periksa: '0',
        status_pembayaran: '0',
        status_keluar: '0',
        description: notes || null,
        payor_id: payorId || null
      };

      if (visitType === 'rawat_inap') {
        visitData.bed_id = bedId;
        visitData.room_id = roomId;
        visitData.class_id = classId;
      }

      const { error: visitError } = await supabase
        .from('patient_visitations')
        .insert(visitData);

      if (visitError) throw visitError;

      if (visitType === 'rawat_inap' && bedId) {
        await supabase
          .from('beds')
          .update({ is_occupied: true })
          .eq('bed_id', bedId);
      }

      success = 'Registrasi berhasil disimpan';
      setTimeout(() => {
        goto('/registrasi');
      }, 1000);
    } catch (err) {
      console.error('Save registration error:', err);
      error = err.message || 'Gagal menyimpan registrasi';
    } finally {
      saving = false;
    }
  }

  onMount(() => {
    fetchMasterData();
  });

  $effect(() => {
    if (clinicId) {
      doctorId = '';
      fetchDoctorsByClinic();
    } else {
      filteredDoctors = doctors;
    }
  });

  $effect(() => {
    if (visitType === 'rawat_inap' && classId) {
      roomId = '';
      bedId = '';
      fetchRoomsByClass(classId);
    } else if (visitType !== 'rawat_inap') {
      rooms = [];
      availableBeds = [];
      roomId = '';
      bedId = '';
    }
  });

  $effect(() => {
    if (roomId) {
      bedId = '';
      fetchAvailableBeds(roomId);
    } else {
      availableBeds = [];
    }
  });
</script>

<svelte:head>
  <title>Registrasi Baru - SIMRS</title>
</svelte:head>

<div class="max-w-4xl mx-auto space-y-6">
  <!-- Header -->
  <div class="flex items-center gap-4">
    <a href="/registrasi" class="p-2 rounded-lg text-gray-500 hover:bg-gray-100 transition-colors">
      <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
      </svg>
    </a>
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Registrasi Baru</h1>
      <p class="text-sm text-gray-500">Daftarkan kunjungan pasien baru</p>
    </div>
  </div>

  <!-- Steps Indicator -->
  <div class="card">
    <div class="flex items-center justify-between">
      {#each [
        { step: 1, label: 'Data Pasien' },
        { step: 2, label: 'Detail Kunjungan' },
        { step: 3, label: 'Konfirmasi' }
      ] as s}
        <div class="flex items-center {s.step < 3 ? 'flex-1' : ''}">
          <div class="flex items-center gap-2">
            <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-colors
              {currentStep > s.step ? 'bg-emerald-500 text-white' : currentStep === s.step ? 'bg-primary-600 text-white' : 'bg-gray-200 text-gray-500'}">
              {#if currentStep > s.step}
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="m4.5 12.75 6 6 9-13.5" />
                </svg>
              {:else}
                {s.step}
              {/if}
            </div>
            <span class="text-sm font-medium {currentStep >= s.step ? 'text-gray-900' : 'text-gray-400'} hidden sm:block">{s.label}</span>
          </div>
          {#if s.step < 3}
            <div class="flex-1 mx-3 h-0.5 {currentStep > s.step ? 'bg-emerald-500' : 'bg-gray-200'} hidden sm:block"></div>
          {/if}
        </div>
      {/each}
    </div>
  </div>

  <!-- Alerts -->
  {#if error}
    <div class="p-4 bg-red-50 border border-red-200 rounded-xl flex items-start gap-3">
      <svg class="w-5 h-5 text-red-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <p class="text-sm text-red-600">{error}</p>
    </div>
  {/if}

  {#if success}
    <div class="p-4 bg-emerald-50 border border-emerald-200 rounded-xl flex items-start gap-3">
      <svg class="w-5 h-5 text-emerald-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
      </svg>
      <p class="text-sm text-emerald-600">{success}</p>
    </div>
  {/if}

  <!-- Step 1: Patient Search / New Patient -->
  {#if currentStep === 1}
    <div class="card space-y-6">
      <h2 class="text-lg font-semibold text-gray-900">Pilih Pasien</h2>

      <!-- Search existing patient -->
      <div>
        <label class="label" for="patientSearch">Cari Pasien (NIK atau Nama)</label>
        <div class="relative">
          <input
            id="patientSearch"
            type="text"
            value={patientSearch}
            oninput={handlePatientSearch}
            placeholder="Ketik NIK atau nama pasien..."
            class="input-field pl-10"
            disabled={showNewPatientForm}
          />
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
          </svg>
          {#if searchingPatient}
            <div class="absolute right-3 top-1/2 -translate-y-1/2">
              <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-primary-600"></div>
            </div>
          {/if}
        </div>

        <!-- Search results dropdown -->
        {#if patientResults.length > 0}
          <div class="mt-2 border border-gray-200 rounded-xl bg-white shadow-lg max-h-64 overflow-y-auto">
            {#each patientResults as patient}
              <button
                onclick={() => selectPatient(patient)}
                class="w-full px-4 py-3 text-left hover:bg-gray-50 border-b border-gray-100 last:border-0 transition-colors"
              >
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm font-medium text-gray-900">{patient.full_name}</p>
                    <p class="text-xs text-gray-500">No.RM: {patient.no_registration} | NIK: {patient.nik || '-'}</p>
                  </div>
                  <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="m8.25 4.5 7.5 7.5-7.5 7.5" />
                  </svg>
                </div>
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <!-- Selected patient info -->
      {#if selectedPatient}
        <div class="p-4 bg-blue-50 border border-blue-200 rounded-xl">
          <div class="flex items-center justify-between mb-2">
            <h3 class="text-sm font-semibold text-blue-900">Pasien Terpilih</h3>
            <button onclick={clearPatientSelection} class="text-xs text-blue-600 hover:text-blue-800 font-medium">Ganti</button>
          </div>
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-3 text-sm">
            <div>
              <p class="text-blue-600 text-xs">Nama</p>
              <p class="font-medium text-blue-900">{selectedPatient.full_name}</p>
            </div>
            <div>
              <p class="text-blue-600 text-xs">No.RM</p>
              <p class="font-medium text-blue-900">{selectedPatient.no_registration}</p>
            </div>
            <div>
              <p class="text-blue-600 text-xs">NIK</p>
              <p class="font-medium text-blue-900">{selectedPatient.nik || '-'}</p>
            </div>
            <div>
              <p class="text-blue-600 text-xs">Jenis Kelamin</p>
              <p class="font-medium text-blue-900">{selectedPatient.gender === 'L' ? 'Laki-laki' : 'Perempuan'}</p>
            </div>
            <div>
              <p class="text-blue-600 text-xs">Tanggal Lahir</p>
              <p class="font-medium text-blue-900">{formatDate(selectedPatient.date_of_birth)}</p>
            </div>
            <div>
              <p class="text-blue-600 text-xs">Telepon</p>
              <p class="font-medium text-blue-900">{selectedPatient.phone || '-'}</p>
            </div>
          </div>
        </div>
      {/if}

      <div class="relative">
        <div class="absolute inset-0 flex items-center">
          <div class="w-full border-t border-gray-200"></div>
        </div>
        <div class="relative flex justify-center text-sm">
          <span class="px-3 bg-white text-gray-500">atau</span>
        </div>
      </div>

      <!-- New patient toggle -->
      {#if !selectedPatient}
        <button
          onclick={() => { showNewPatientForm = !showNewPatientForm; error = ''; }}
          class="w-full p-4 border-2 border-dashed border-gray-300 rounded-xl text-center hover:border-primary-400 hover:bg-primary-50 transition-colors"
        >
          <div class="flex items-center justify-center gap-2 text-gray-600">
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
            </svg>
            <span class="font-medium">Daftarkan Pasien Baru</span>
          </div>
        </button>
      {/if}

      <!-- New patient form -->
      {#if showNewPatientForm && !selectedPatient}
        <div class="space-y-4 p-4 bg-gray-50 rounded-xl border border-gray-200">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-semibold text-gray-900">Data Pasien Baru</h3>
            <button onclick={() => { showNewPatientForm = false; }} class="text-xs text-gray-500 hover:text-gray-700">Batal</button>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div class="sm:col-span-2">
              <label class="label" for="pn_name">Nama Lengkap <span class="text-red-500">*</span></label>
              <input id="pn_name" type="text" bind:value={newPatient.full_name} class="input-field" placeholder="Nama lengkap pasien" />
            </div>
            <div>
              <label class="label" for="pn_nik">NIK</label>
              <input id="pn_nik" type="text" bind:value={newPatient.nik} class="input-field" placeholder="Nomor induk kependudukan" maxlength="16" />
            </div>
            <div>
              <label class="label" for="pn_dob">Tanggal Lahir</label>
              <input id="pn_dob" type="date" bind:value={newPatient.date_of_birth} class="input-field" />
            </div>
            <div>
              <label class="label" for="pn_gender">Jenis Kelamin</label>
              <select id="pn_gender" bind:value={newPatient.gender} class="select-field">
                <option value="L">Laki-laki</option>
                <option value="P">Perempuan</option>
              </select>
            </div>
            <div>
              <label class="label" for="pn_phone">Telepon</label>
              <input id="pn_phone" type="text" bind:value={newPatient.phone} class="input-field" placeholder="Nomor telepon" />
            </div>
            <div>
              <label class="label" for="pn_blood">Golongan Darah</label>
              <select id="pn_blood" bind:value={newPatient.blood_type} class="select-field">
                <option value="">- Pilih -</option>
                {#each bloodTypes as bt}
                  <option value={bt}>{bt}</option>
                {/each}
              </select>
            </div>
            <div>
              <label class="label" for="pn_religion">Agama</label>
              <select id="pn_religion" bind:value={newPatient.religion} class="select-field">
                <option value="">- Pilih -</option>
                {#each religions as r}
                  <option value={r}>{r}</option>
                {/each}
              </select>
            </div>
            <div class="sm:col-span-2">
              <label class="label" for="pn_address">Alamat</label>
              <textarea id="pn_address" bind:value={newPatient.address} class="input-field" rows="2" placeholder="Alamat lengkap"></textarea>
            </div>
            <div>
              <label class="label" for="pn_payor">Penanggung Biaya Pasien</label>
              <select id="pn_payor" bind:value={newPatient.payor_id} class="select-field">
                <option value="">- Pilih Penanggung -</option>
                {#each payors as p}
                  <option value={p.payor_id}>{p.name} ({p.type})</option>
                {/each}
              </select>
            </div>
            <div>
              <label class="label" for="pn_ins_num">No. Asuransi</label>
              <input id="pn_ins_num" type="text" bind:value={newPatient.insurance_number} class="input-field" placeholder="Nomor polis asuransi" />
            </div>
          </div>
        </div>
      {/if}
    </div>
  {/if}

  <!-- Step 2: Visit Details -->
  {#if currentStep === 2}
    <div class="card space-y-6">
      <h2 class="text-lg font-semibold text-gray-900">Detail Kunjungan</h2>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="label" for="visitType">Jenis Kunjungan <span class="text-red-500">*</span></label>
          <select id="visitType" bind:value={visitType} class="select-field">
            <option value="rawat_jalan">Rawat Jalan</option>
            <option value="rawat_inap">Rawat Inap</option>
            <option value="igd">IGD / Rawat Darurat</option>
          </select>
        </div>
        <div>
          <label class="label" for="clinic">Poli / Klinik <span class="text-red-500">*</span></label>
          <select id="clinic" bind:value={clinicId} class="select-field">
            <option value="">- Pilih Poli -</option>
            {#each clinics as c}
              <option value={c.clinic_id}>{c.name}</option>
            {/each}
          </select>
        </div>
        <div>
          <label class="label" for="doctor">Dokter (DPJP)</label>
          <select id="doctor" bind:value={doctorId} class="select-field">
            <option value="">- Pilih Dokter -</option>
            {#each filteredDoctors as d}
              <option value={d.employee_id}>{d.fullname}</option>
            {/each}
          </select>
        </div>
        <div>
          <label class="label" for="payor">Penanggung Biaya</label>
          <select id="payor" bind:value={payorId} class="select-field">
            <option value="">- Pilih Penanggung -</option>
            {#each payors as p}
              <option value={p.payor_id}>{p.name} ({p.type})</option>
            {/each}
          </select>
        </div>

        {#if visitType === 'rawat_inap'}
          <div>
            <label class="label" for="roomClass">Kelas Kamar <span class="text-red-500">*</span></label>
            <select id="roomClass" bind:value={classId} class="select-field">
              <option value="">- Pilih Kelas -</option>
              {#each roomClasses as rc}
                <option value={rc.class_id}>{rc.name}</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label" for="room">Kamar <span class="text-red-500">*</span></label>
            <select id="room" bind:value={roomId} class="select-field" disabled={!classId}>
              <option value="">- Pilih Kamar -</option>
              {#each rooms as r}
                <option value={r.room_id}>{r.room_number}</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label" for="bed">Tempat Tidur <span class="text-red-500">*</span></label>
            <select id="bed" bind:value={bedId} class="select-field" disabled={!roomId}>
              <option value="">- Pilih Tempat Tidur -</option>
              {#each availableBeds as b}
                <option value={b.bed_id}>{b.bed_number}</option>
              {/each}
            </select>
            {#if roomId && availableBeds.length === 0}
              <p class="text-xs text-red-500 mt-1">Tidak ada tempat tidur tersedia</p>
            {/if}
          </div>
        {/if}

        <div class="sm:col-span-2">
          <label class="label" for="notes">Catatan / Keterangan</label>
          <textarea id="notes" bind:value={notes} class="input-field" rows="3" placeholder="Catatan tambahan untuk kunjungan ini..."></textarea>
        </div>
      </div>
    </div>
  {/if}

  <!-- Step 3: Confirmation --> 
  {#if currentStep === 3}
    <div class="card space-y-6">
      <h2 class="text-lg font-semibold text-gray-900">Konfirmasi Registrasi</h2>

      <!-- Patient Summary -->
      <div class="p-4 bg-gray-50 rounded-xl">
        <h3 class="text-sm font-semibold text-gray-700 mb-3">Data Pasien</h3>
        {#if selectedPatient}
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-3 text-sm">
            <div><p class="text-gray-500 text-xs">Nama</p><p class="font-medium text-gray-900">{selectedPatient.full_name}</p></div>
            <div><p class="text-gray-500 text-xs">No.RM</p><p class="font-medium text-gray-900">{selectedPatient.no_registration}</p></div>
            <div><p class="text-gray-500 text-xs">NIK</p><p class="font-medium text-gray-900">{selectedPatient.nik || '-'}</p></div>
            <div><p class="text-gray-500 text-xs">Jenis Kelamin</p><p class="font-medium text-gray-900">{selectedPatient.gender === 'L' ? 'Laki-laki' : 'Perempuan'}</p></div>
            <div><p class="text-gray-500 text-xs">Tanggal Lahir</p><p class="font-medium text-gray-900">{formatDate(selectedPatient.date_of_birth)}</p></div>
            <div><p class="text-gray-500 text-xs">Telepon</p><p class="font-medium text-gray-900">{selectedPatient.phone || '-'}</p></div>
          </div>
        {:else}
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-3 text-sm">
            <div><p class="text-gray-500 text-xs">Nama</p><p class="font-medium text-gray-900">{newPatient.full_name}</p></div>
            <div><p class="text-gray-500 text-xs">NIK</p><p class="font-medium text-gray-900">{newPatient.nik || '-'}</p></div>
            <div><p class="text-gray-500 text-xs">Jenis Kelamin</p><p class="font-medium text-gray-900">{newPatient.gender === 'L' ? 'Laki-laki' : 'Perempuan'}</p></div>
            <div><p class="text-gray-500 text-xs">Tanggal Lahir</p><p class="font-medium text-gray-900">{newPatient.date_of_birth || '-'}</p></div>
            <div><p class="text-gray-500 text-xs">Telepon</p><p class="font-medium text-gray-900">{newPatient.phone || '-'}</p></div>
            <div><p class="text-gray-500 text-xs">Gol. Darah</p><p class="font-medium text-gray-900">{newPatient.blood_type || '-'}</p></div>
          </div>
        {/if}
      </div>

      <!-- Visit Summary -->
      <div class="p-4 bg-gray-50 rounded-xl">
        <h3 class="text-sm font-semibold text-gray-700 mb-3">Detail Kunjungan</h3>
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-3 text-sm">
          <div><p class="text-gray-500 text-xs">Jenis Kunjungan</p><p class="font-medium text-gray-900">{VISIT_TYPES[visitType]}</p></div>
          <div><p class="text-gray-500 text-xs">Poli</p><p class="font-medium text-gray-900">{clinics.find(c => c.clinic_id === clinicId)?.name || '-'}</p></div>
          <div><p class="text-gray-500 text-xs">Dokter</p><p class="font-medium text-gray-900">{filteredDoctors.find(d => d.employee_id === doctorId)?.fullname || '-'}</p></div>
          <div><p class="text-gray-500 text-xs">Penanggung Biaya</p><p class="font-medium text-gray-900">{payors.find(p => p.payor_id === payorId)?.name || '-'}</p></div>
          {#if visitType === 'rawat_inap'}
            <div><p class="text-gray-500 text-xs">Kelas</p><p class="font-medium text-gray-900">{roomClasses.find(r => r.class_id === classId)?.name || '-'}</p></div>
            <div><p class="text-gray-500 text-xs">Kamar</p><p class="font-medium text-gray-900">{rooms.find(r => r.room_id === roomId)?.room_number || '-'}</p></div>
            <div><p class="text-gray-500 text-xs">Tempat Tidur</p><p class="font-medium text-gray-900">{availableBeds.find(b => b.bed_id === bedId)?.bed_number || '-'}</p></div>
          {/if}
          <div class="sm:col-span-3">
            <p class="text-gray-500 text-xs">Catatan</p>
            <p class="font-medium text-gray-900">{notes || '-'}</p>
          </div>
        </div>
      </div>
    </div>
  {/if}

  <!-- Navigation Buttons -->
  <div class="flex items-center justify-between">
    {#if currentStep > 1}
      <button onclick={goBack} class="btn-secondary inline-flex items-center gap-2">
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
        </svg>
        Sebelumnya
      </button>
    {:else}
      <div></div>
    {/if}

    {#if currentStep < 3}
      <button onclick={goNext} class="btn-primary inline-flex items-center gap-2">
        Selanjutnya
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3" />
        </svg>
      </button>
    {:else}
      <button
        onclick={handleSave}
        disabled={saving}
        class="btn-success inline-flex items-center gap-2"
      >
        {#if saving}
          <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span>Menyimpan...</span>
        {:else}
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
          </svg>
          <span>Simpan Registrasi</span>
        {/if}
      </button>
    {/if}
  </div>
</div>
