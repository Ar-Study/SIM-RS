<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime } from '$lib/utils/helpers.js';

  let loading = $state(true);
  let saving = $state(false);
  let error = $state('');
  let success = $state('');

  let visit = $state(null);

  let clinics = $state([]);
  let doctors = $state([]);
  let roomClasses = $state([]);
  let rooms = $state([]);
  let availableBeds = $state([]);
  let payors = $state([]);

  let form = $state({
    visit_type: 'rawat_jalan',
    clinic_id: '',
    doctor_id: '',
    payor_id: '',
    class_id: '',
    room_id: '',
    bed_id: '',
    status_periksa: '0',
    status_pembayaran: '0',
    status_keluar: '0',
    description: ''
  });

  async function fetchMasterData() {
    const [clinicsResult, doctorsResult, classesResult, payorsResult] = await Promise.all([
      supabase.from('clinics').select('clinic_id, name').eq('is_active', true).order('name'),
      supabase.from('employees').select('employee_id, full_name').eq('is_dpjp', true).eq('is_active', true).order('full_name'),
      supabase.from('room_classes').select('class_id, name').order('name'),
      supabase.from('payors').select('payor_id, name, type').eq('is_active', true).order('name')
    ]);

    if (clinicsResult.error) throw clinicsResult.error;
    if (doctorsResult.error) throw doctorsResult.error;
    if (classesResult.error) throw classesResult.error;
    if (payorsResult.error) throw payorsResult.error;

    clinics = clinicsResult.data || [];
    doctors = doctorsResult.data || [];
    roomClasses = classesResult.data || [];
    payors = payorsResult.data || [];
  }

  async function fetchVisitDetail() {
    const visitId = $page.params.visitId;
    const { data, error: fetchError } = await supabase
      .from('patient_visitations')
      .select(`
        visit_id,
        visit_date,
        ticket_no,
        visit_type,
        clinic_id,
        doctor_id,
        payor_id,
        class_id,
        room_id,
        bed_id,
        status_periksa,
        status_pembayaran,
        status_keluar,
        description,
        patients:patient_id (
          full_name,
          no_registration,
          nik,
          gender,
          date_of_birth,
          phone
        )
      `)
      .eq('visit_id', visitId)
      .single();

    if (fetchError) throw fetchError;

    visit = data;
    form = {
      visit_type: data.visit_type || 'rawat_jalan',
      clinic_id: data.clinic_id || '',
      doctor_id: data.doctor_id || '',
      payor_id: data.payor_id || '',
      class_id: data.class_id || '',
      room_id: data.room_id || '',
      bed_id: data.bed_id || '',
      status_periksa: data.status_periksa || '0',
      status_pembayaran: data.status_pembayaran || '0',
      status_keluar: data.status_keluar || '0',
      description: data.description || ''
    };
  }

  async function fetchRoomsByClass(classId) {
    if (!classId) {
      rooms = [];
      return;
    }

    const { data, error: roomsError } = await supabase
      .from('rooms')
      .select('room_id, room_number')
      .eq('class_id', classId)
      .eq('is_active', true)
      .order('room_number');

    if (roomsError) throw roomsError;
    rooms = data || [];
  }

  async function fetchAvailableBeds(roomId, currentBedId = '') {
    if (!roomId) {
      availableBeds = [];
      return;
    }

    let query = supabase
      .from('beds')
      .select('bed_id, bed_number, is_occupied')
      .eq('room_id', roomId)
      .eq('is_active', true)
      .order('bed_number');

    if (currentBedId) {
      query = query.or(`is_occupied.eq.false,bed_id.eq.${currentBedId}`);
    } else {
      query = query.eq('is_occupied', false);
    }

    const { data, error: bedsError } = await query;
    if (bedsError) throw bedsError;
    availableBeds = data || [];
  }

  function handleVisitTypeChange(nextType) {
    form.visit_type = nextType;
    if (nextType !== 'rawat_inap') {
      form.class_id = '';
      form.room_id = '';
      form.bed_id = '';
      rooms = [];
      availableBeds = [];
    }
  }

  async function handleClassChange(nextClassId) {
    form.class_id = nextClassId;
    form.room_id = '';
    form.bed_id = '';
    availableBeds = [];

    try {
      await fetchRoomsByClass(nextClassId);
    } catch (err) {
      console.error('Fetch rooms error:', err);
      error = err.message || 'Gagal memuat kamar';
      rooms = [];
    }
  }

  async function handleRoomChange(nextRoomId) {
    form.room_id = nextRoomId;
    form.bed_id = '';

    try {
      await fetchAvailableBeds(nextRoomId, visit?.bed_id || '');
    } catch (err) {
      console.error('Fetch beds error:', err);
      error = err.message || 'Gagal memuat tempat tidur';
      availableBeds = [];
    }
  }

  function validateForm() {
    if (!form.clinic_id) return 'Poli / klinik wajib dipilih';

    if (form.visit_type === 'rawat_inap') {
      if (!form.class_id) return 'Kelas kamar wajib dipilih';
      if (!form.room_id) return 'Kamar wajib dipilih';
      if (!form.bed_id) return 'Tempat tidur wajib dipilih';
    }

    return '';
  }

  async function handleSave() {
    error = '';
    success = '';

    const validationError = validateForm();
    if (validationError) {
      error = validationError;
      return;
    }

    saving = true;
    try {
      const previousBedId = visit?.bed_id || null;
      const previousVisitType = visit?.visit_type || null;
      const newBedId = form.visit_type === 'rawat_inap' ? form.bed_id || null : null;

      const updatePayload = {
        visit_type: form.visit_type,
        clinic_id: form.clinic_id,
        doctor_id: form.doctor_id || null,
        payor_id: form.payor_id || null,
        class_id: form.visit_type === 'rawat_inap' ? form.class_id || null : null,
        room_id: form.visit_type === 'rawat_inap' ? form.room_id || null : null,
        bed_id: newBedId,
        status_periksa: form.status_periksa,
        status_pembayaran: form.status_pembayaran,
        status_keluar: form.status_keluar,
        description: form.description || null,
        updated_at: new Date().toISOString()
      };

      const { error: updateError } = await supabase
        .from('patient_visitations')
        .update(updatePayload)
        .eq('visit_id', visit.visit_id);

      if (updateError) throw updateError;

      if (previousBedId && (newBedId !== previousBedId || form.visit_type !== 'rawat_inap')) {
        const { error: releaseBedError } = await supabase
          .from('beds')
          .update({ is_occupied: false })
          .eq('bed_id', previousBedId);

        if (releaseBedError) throw releaseBedError;
      }

      if (form.visit_type === 'rawat_inap' && newBedId && (newBedId !== previousBedId || previousVisitType !== 'rawat_inap')) {
        const { error: occupyBedError } = await supabase
          .from('beds')
          .update({ is_occupied: true })
          .eq('bed_id', newBedId);

        if (occupyBedError) throw occupyBedError;
      }

      success = 'Perubahan registrasi berhasil disimpan';
      setTimeout(() => {
        goto(`/registrasi/${visit.visit_id}`);
      }, 900);
    } catch (err) {
      console.error('Update registration error:', err);
      error = err.message || 'Gagal menyimpan perubahan registrasi';
    } finally {
      saving = false;
    }
  }

  async function initPage() {
    loading = true;
    error = '';

    try {
      await fetchMasterData();
      await fetchVisitDetail();

      if (form.visit_type === 'rawat_inap' && form.class_id) {
        await fetchRoomsByClass(form.class_id);
      }

      if (form.visit_type === 'rawat_inap' && form.room_id) {
        await fetchAvailableBeds(form.room_id, form.bed_id);
      }
    } catch (err) {
      console.error('Init edit registration page error:', err);
      error = err.message || 'Gagal memuat data edit registrasi';
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    initPage();
  });
</script>

<svelte:head>
  <title>Edit Registrasi - SIMRS</title>
</svelte:head>

<div class="max-w-4xl mx-auto space-y-6">
  <div class="flex items-center gap-3">
    <button onclick={() => goto(`/registrasi/${$page.params.visitId}`)} class="p-2 rounded-lg text-gray-500 hover:bg-gray-100 transition-colors" title="Kembali">
      <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
      </svg>
    </button>
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Edit Registrasi</h1>
      <p class="text-sm text-gray-500">Perbarui data kunjungan pasien</p>
    </div>
  </div>

  {#if loading}
    <div class="card flex items-center justify-center py-16">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
    </div>
  {:else}
    {#if error}
      <div class="p-4 bg-red-50 border border-red-200 rounded-xl text-sm text-red-600">{error}</div>
    {/if}

    {#if success}
      <div class="p-4 bg-emerald-50 border border-emerald-200 rounded-xl text-sm text-emerald-700">{success}</div>
    {/if}

    {#if visit}
      <div class="card space-y-5">
        <h2 class="text-lg font-semibold text-gray-900">Informasi Pasien</h2>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm">
          <div>
            <p class="text-gray-500 text-xs">ID Kunjungan</p>
            <p class="font-medium text-gray-900 font-mono">{visit.visit_id}</p>
          </div>
          <div>
            <p class="text-gray-500 text-xs">No. Tiket</p>
            <p class="font-medium text-gray-900">{visit.ticket_no || '-'}</p>
          </div>
          <div>
            <p class="text-gray-500 text-xs">Tanggal Kunjungan</p>
            <p class="font-medium text-gray-900">{formatDateTime(visit.visit_date)}</p>
          </div>
          <div>
            <p class="text-gray-500 text-xs">Nama Pasien</p>
            <p class="font-medium text-gray-900">{visit.patients?.full_name || '-'}</p>
          </div>
          <div>
            <p class="text-gray-500 text-xs">No. RM</p>
            <p class="font-medium text-gray-900 font-mono">{visit.patients?.no_registration || '-'}</p>
          </div>
          <div>
            <p class="text-gray-500 text-xs">NIK</p>
            <p class="font-medium text-gray-900">{visit.patients?.nik || '-'}</p>
          </div>
          <div>
            <p class="text-gray-500 text-xs">Jenis Kelamin</p>
            <p class="font-medium text-gray-900">{visit.patients?.gender === 'L' ? 'Laki-laki' : visit.patients?.gender === 'P' ? 'Perempuan' : '-'}</p>
          </div>
          <div>
            <p class="text-gray-500 text-xs">Tanggal Lahir</p>
            <p class="font-medium text-gray-900">{formatDate(visit.patients?.date_of_birth)}</p>
          </div>
          <div>
            <p class="text-gray-500 text-xs">Telepon</p>
            <p class="font-medium text-gray-900">{visit.patients?.phone || '-'}</p>
          </div>
        </div>
      </div>

      <div class="card space-y-5">
        <h2 class="text-lg font-semibold text-gray-900">Data Kunjungan</h2>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="label" for="visit_type">Jenis Kunjungan <span class="text-red-500">*</span></label>
            <select
              id="visit_type"
              class="select-field"
              value={form.visit_type}
              onchange={(e) => handleVisitTypeChange(e.target.value)}
            >
              <option value="rawat_jalan">Rawat Jalan</option>
              <option value="rawat_inap">Rawat Inap</option>
              <option value="igd">IGD / Rawat Darurat</option>
            </select>
          </div>

          <div>
            <label class="label" for="clinic_id">Poli / Klinik <span class="text-red-500">*</span></label>
            <select id="clinic_id" bind:value={form.clinic_id} class="select-field">
              <option value="">- Pilih Poli -</option>
              {#each clinics as c}
                <option value={c.clinic_id}>{c.name}</option>
              {/each}
            </select>
          </div>

          <div>
            <label class="label" for="doctor_id">Dokter</label>
            <select id="doctor_id" bind:value={form.doctor_id} class="select-field">
              <option value="">- Pilih Dokter -</option>
              {#each doctors as d}
                <option value={d.employee_id}>{d.full_name}</option>
              {/each}
            </select>
          </div>

          <div>
            <label class="label" for="payor_id">Penanggung Biaya</label>
            <select id="payor_id" bind:value={form.payor_id} class="select-field">
              <option value="">- Pilih Penanggung -</option>
              {#each payors as p}
                <option value={p.payor_id}>{p.name} ({p.type})</option>
              {/each}
            </select>
          </div>

          {#if form.visit_type === 'rawat_inap'}
            <div>
              <label class="label" for="class_id">Kelas Kamar <span class="text-red-500">*</span></label>
              <select
                id="class_id"
                class="select-field"
                value={form.class_id}
                onchange={(e) => handleClassChange(e.target.value)}
              >
                <option value="">- Pilih Kelas -</option>
                {#each roomClasses as rc}
                  <option value={rc.class_id}>{rc.name}</option>
                {/each}
              </select>
            </div>

            <div>
              <label class="label" for="room_id">Kamar <span class="text-red-500">*</span></label>
              <select
                id="room_id"
                class="select-field"
                value={form.room_id}
                onchange={(e) => handleRoomChange(e.target.value)}
                disabled={!form.class_id}
              >
                <option value="">- Pilih Kamar -</option>
                {#each rooms as r}
                  <option value={r.room_id}>{r.room_number}</option>
                {/each}
              </select>
            </div>

            <div>
              <label class="label" for="bed_id">Tempat Tidur <span class="text-red-500">*</span></label>
              <select id="bed_id" bind:value={form.bed_id} class="select-field" disabled={!form.room_id}>
                <option value="">- Pilih Tempat Tidur -</option>
                {#each availableBeds as b}
                  <option value={b.bed_id}>{b.bed_number}{b.is_occupied ? ' (terpakai oleh kunjungan ini)' : ''}</option>
                {/each}
              </select>
            </div>
          {/if}

          <div>
            <label class="label" for="status_periksa">Status Periksa</label>
            <select id="status_periksa" bind:value={form.status_periksa} class="select-field">
              <option value="0">Belum Diperiksa</option>
              <option value="1">Sudah Diperiksa</option>
            </select>
          </div>

          <div>
            <label class="label" for="status_pembayaran">Status Pembayaran</label>
            <select id="status_pembayaran" bind:value={form.status_pembayaran} class="select-field">
              <option value="0">Belum Bayar</option>
              <option value="1">Sudah Bayar</option>
              <option value="2">Gratis</option>
            </select>
          </div>

          <div>
            <label class="label" for="status_keluar">Status Keluar</label>
            <select id="status_keluar" bind:value={form.status_keluar} class="select-field">
              <option value="0">Masih di RS</option>
              <option value="1">Sudah Keluar</option>
            </select>
          </div>

          <div class="sm:col-span-2">
            <label class="label" for="description">Catatan</label>
            <textarea id="description" bind:value={form.description} rows="3" class="input-field" placeholder="Catatan tambahan kunjungan"></textarea>
          </div>
        </div>

        <div class="flex items-center justify-end gap-2 pt-2">
          <button onclick={() => goto(`/registrasi/${visit.visit_id}`)} class="btn-secondary">Batal</button>
          <button onclick={handleSave} disabled={saving} class="btn-primary inline-flex items-center gap-2">
            {#if saving}
              <span class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></span>
              Menyimpan...
            {:else}
              Simpan Perubahan
            {/if}
          </button>
        </div>
      </div>
    {/if}
  {/if}
</div>
