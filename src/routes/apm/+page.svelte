<script>
  import { onMount, onDestroy } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, generateVisitId } from '$lib/utils/helpers.js';

  let step = $state(1);
  let loading = $state(false);
  let nikInput = $state('');
  let patient = $state(null);
  let clinics = $state([]);
  let selectedClinic = $state(null);
  let doctors = $state([]);
  let selectedDoctor = $state(null);
  let selectedSlot = $state(null);
  let registering = $state(false);
  let registrationComplete = $state(false);
  let ticketNo = $state('');
  let errorMsg = $state('');
  let inactivityTimer = null;
  let kioskTimer = $state(30);
  let kioskInterval = null;

  const TIME_SLOTS = $state([
    '08:00', '08:30', '09:00', '09:30', '10:00', '10:30',
    '11:00', '11:30', '13:00', '13:30', '14:00', '14:30',
    '15:00', '15:30', '16:00', '16:30'
  ]);

  let availableSlots = $derived.by(() => {
    if (!selectedDoctor || !selectedClinic) return TIME_SLOTS;
    const bookedSlots = [];
    return TIME_SLOTS.filter(slot => !bookedSlots.includes(slot));
  });

  function resetKioskTimer() {
    kioskTimer = 30;
    if (inactivityTimer) clearTimeout(inactivityTimer);
    if (kioskInterval) clearInterval(kioskInterval);

    kioskInterval = setInterval(() => {
      kioskTimer--;
      if (kioskTimer <= 0) {
        clearInterval(kioskInterval);
        resetToHome();
      }
    }, 1000);

    inactivityTimer = setTimeout(() => {
      resetToHome();
    }, 30000);
  }

  function resetToHome() {
    step = 1;
    nikInput = '';
    patient = null;
    selectedClinic = null;
    selectedDoctor = null;
    selectedSlot = null;
    registrationComplete = false;
    ticketNo = '';
    errorMsg = '';
    if (kioskInterval) clearInterval(kioskInterval);
    if (inactivityTimer) clearTimeout(inactivityTimer);
    kioskTimer = 30;
  }

  function handleActivity() {
    resetKioskTimer();
  }

  async function searchByNik() {
    if (nikInput.length < 10) {
      errorMsg = 'NIK minimal 10 digit';
      return;
    }
    loading = true;
    errorMsg = '';
    try {
      const { data, error } = await supabase
        .from('patients')
        .select('*')
        .eq('nik', nikInput)
        .single();

      if (error || !data) {
        errorMsg = 'Pasien dengan NIK tersebut tidak ditemukan';
        patient = null;
        loading = false;
        return;
      }

      patient = data;
      step = 2;
      resetKioskTimer();
    } catch (err) {
      errorMsg = 'Terjadi kesalahan saat pencarian';
      console.error('Search error:', err);
    } finally {
      loading = false;
    }
  }

  async function confirmIdentity() {
    step = 3;
    resetKioskTimer();
    loading = true;
    try {
      const { data, error } = await supabase
        .from('clinics')
        .select('clinic_id, name, description')
        .eq('is_active', true)
        .order('name');
      if (error) throw error;
      clinics = data || [];
    } catch (err) {
      console.error('Fetch clinics error:', err);
    } finally {
      loading = false;
    }
  }

  async function selectClinic(clinic) {
    selectedClinic = clinic;
    step = 4;
    resetKioskTimer();
    loading = true;
    try {
      const { data, error } = await supabase
        .from('users')
        .select('user_id, full_name, specialization')
        .eq('role', 'doctor')
        .eq('is_active', true)
        .order('full_name');
      if (error) throw error;
      doctors = data || [];
    } catch (err) {
      console.error('Fetch doctors error:', err);
    } finally {
      loading = false;
    }
  }

  function selectDoctorSlot(doctor, slot) {
    selectedDoctor = doctor;
    selectedSlot = slot;
    step = 5;
    resetKioskTimer();
  }

  async function confirmRegistration() {
    registering = true;
    errorMsg = '';
    resetKioskTimer();
    try {
      const visitId = generateVisitId();
      const ticketNum = Math.floor(1000 + Math.random() * 9000);

      const { error } = await supabase
        .from('patient_visitations')
        .insert({
          visit_id: visitId,
          patient_id: patient.patient_id,
          doctor_id: selectedDoctor.user_id,
          clinic_id: selectedClinic.clinic_id,
          visit_type: 'rawat_jalan',
          visit_date: new Date().toISOString(),
          ticket_no: ticketNum,
          source: 'kiosk',
          status_periksa: '0',
          status_keluar: '0'
        });

      if (error) throw error;

      ticketNo = String(ticketNum);
      registrationComplete = true;
      step = 6;
      resetKioskTimer();
    } catch (err) {
      errorMsg = 'Gagal melakukan registrasi. Silakan hubungi petugas.';
      console.error('Registration error:', err);
    } finally {
      registering = false;
    }
  }

  onMount(() => {
    resetKioskTimer();
  });

  onDestroy(() => {
    if (inactivityTimer) clearTimeout(inactivityTimer);
    if (kioskInterval) clearInterval(kioskInterval);
  });
</script>

<svelte:head>
  <title>Anjungan Pasien Mandiri - SIMRS</title>
</svelte:head>

<div
  class="min-h-screen bg-gradient-to-br from-primary-600 via-primary-700 to-primary-900 flex flex-col"
  onmousemove={handleActivity}
  onkeydown={handleActivity}
  ontouchstart={handleActivity}
  role="application"
>
  <!-- Kiosk Header -->
  <header class="bg-white/10 backdrop-blur-sm border-b border-white/20">
    <div class="max-w-5xl mx-auto px-6 py-4 flex items-center justify-between">
      <div class="flex items-center gap-4">
        <div class="w-12 h-12 rounded-xl bg-white flex items-center justify-center">
          <svg class="w-7 h-7 text-primary-700" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M4.26 10.147a60.438 60.438 0 00-.491 6.347A48.62 48.62 0 0112 20.904a48.62 48.62 0 018.232-4.41 60.46 60.46 0 00-.491-6.347m-15.482 0a50.636 50.636 0 00-2.658-.813A59.906 59.906 0 0112 3.493a59.903 59.903 0 0110.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0112 13.489a50.702 50.702 0 017.74-3.342" />
          </svg>
        </div>
        <div>
          <h1 class="text-white text-xl font-bold">SIMRS</h1>
          <p class="text-white/70 text-sm">Anjungan Pasien Mandiri</p>
        </div>
      </div>
      <div class="text-right text-white/80">
        <p class="text-sm">{new Date().toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}</p>
        <p class="text-xs text-white/50 mt-0.5">Sesi berakhir dalam {kioskTimer}s</p>
      </div>
    </div>
  </header>

  <!-- Progress Steps -->
  <div class="bg-white/5 border-b border-white/10">
    <div class="max-w-5xl mx-auto px-6 py-3">
      <div class="flex items-center justify-center gap-2">
        {#each [
          { num: 1, label: 'Identitas' },
          { num: 2, label: 'Konfirmasi' },
          { num: 3, label: 'Poli' },
          { num: 4, label: 'Dokter' },
          { num: 5, label: 'Konfirmasi' },
          { num: 6, label: 'Tiket' }
        ] as s}
          <div class="flex items-center gap-2">
            <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all duration-300
              {step >= s.num ? 'bg-white text-primary-700' : 'bg-white/20 text-white/60'}">
              {s.num}
            </div>
            <span class="text-xs font-medium hidden sm:inline {step >= s.num ? 'text-white' : 'text-white/40'}">{s.label}</span>
            {#if s.num < 6}
              <div class="w-6 h-0.5 {step > s.num ? 'bg-white' : 'bg-white/20'}"></div>
            {/if}
          </div>
        {/each}
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <main class="flex-1 flex items-center justify-center p-6">
    <div class="w-full max-w-2xl">

      {#if step === 1}
        <!-- Step 1: Enter NIK -->
        <div class="text-center space-y-8">
          <div>
            <div class="w-24 h-24 rounded-2xl bg-white/10 flex items-center justify-center mx-auto mb-6">
              <svg class="w-14 h-14 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 9h3.75M15 12h3.75M15 15h3.75M4.5 19.5h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5zm6-11.25a1.125 1.125 0 11-2.25 0 1.125 1.125 0 012.25 0zm-.375 5.125a.375.375 0 10-.75 0v3.375c0 .207.168.375.375.375h2.25a.375.375 0 00.375-.375V13.5" />
              </svg>
            </div>
            <h2 class="text-white text-3xl font-bold mb-2">Selamat Datang</h2>
            <p class="text-white/70 text-lg">Masukkan NIK Anda untuk memulai registrasi</p>
          </div>

          <div class="space-y-4">
            <input
              type="text"
              class="w-full px-8 py-6 text-2xl text-center font-mono tracking-widest rounded-2xl bg-white/10 border-2 border-white/30 text-white placeholder-white/40 focus:outline-none focus:ring-4 focus:ring-white/20 focus:border-white/50 transition-all"
              placeholder="Masukkan NIK (16 digit)"
              bind:value={nikInput}
              onkeydown={(e) => { if (e.key === 'Enter') searchByNik(); }}
              maxlength="16"
              inputmode="numeric"
            />
            {#if errorMsg}
              <div class="bg-red-500/20 border border-red-400/50 rounded-xl px-6 py-4">
                <p class="text-red-200 text-center">{errorMsg}</p>
              </div>
            {/if}
            <button
              class="w-full py-6 rounded-2xl bg-white text-primary-700 text-2xl font-bold hover:bg-white/90 active:scale-[0.98] transition-all shadow-xl"
              onclick={searchByNik}
              disabled={loading || nikInput.length < 10}
            >
              {#if loading}
                <span class="inline-block w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin mr-3"></span>
                Mencari...
              {:else}
                <svg class="w-7 h-7 inline-block mr-3 -mt-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
                </svg>
                Cari Data Saya
              {/if}
            </button>
          </div>

          <p class="text-white/40 text-sm">Atau hubungi petugas jika tidak memiliki NIK</p>
        </div>

      {:else if step === 2}
        <!-- Step 2: Confirm Identity -->
        <div class="space-y-6">
          <div class="bg-white rounded-3xl p-8 shadow-2xl">
            <div class="flex items-center gap-6 mb-8">
              <div class="w-20 h-20 rounded-2xl bg-primary-100 flex items-center justify-center shrink-0">
                <svg class="w-12 h-12 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
                </svg>
              </div>
              <div>
                <h2 class="text-2xl font-bold text-gray-900">{patient?.full_name}</h2>
                <p class="text-gray-500 mt-1">No. RM: <span class="font-mono font-semibold">{patient?.no_registration}</span></p>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4 mb-8">
              <div class="bg-gray-50 rounded-xl p-4">
                <p class="text-xs text-gray-500 uppercase tracking-wide">NIK</p>
                <p class="text-lg font-mono font-semibold text-gray-900 mt-1">{patient?.nik || '-'}</p>
              </div>
              <div class="bg-gray-50 rounded-xl p-4">
                <p class="text-xs text-gray-500 uppercase tracking-wide">Jenis Kelamin</p>
                <p class="text-lg font-semibold text-gray-900 mt-1">{patient?.gender === 'L' ? 'Laki-laki' : 'Perempuan'}</p>
              </div>
              <div class="bg-gray-50 rounded-xl p-4">
                <p class="text-xs text-gray-500 uppercase tracking-wide">Tanggal Lahir</p>
                <p class="text-lg font-semibold text-gray-900 mt-1">{formatDate(patient?.birth_date)}</p>
              </div>
              <div class="bg-gray-50 rounded-xl p-4">
                <p class="text-xs text-gray-500 uppercase tracking-wide">No. HP</p>
                <p class="text-lg font-semibold text-gray-900 mt-1">{patient?.phone || '-'}</p>
              </div>
            </div>

            <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 mb-8">
              <p class="text-sm text-blue-800 text-center">Apakah data di atas adalah data Anda?</p>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <button
                class="py-5 rounded-xl bg-gray-100 text-gray-700 text-xl font-bold hover:bg-gray-200 active:scale-[0.98] transition-all"
                onclick={resetToHome}
              >
                Bukan, Ulangi
              </button>
              <button
                class="py-5 rounded-xl bg-primary-600 text-white text-xl font-bold hover:bg-primary-700 active:scale-[0.98] transition-all shadow-lg"
                onclick={confirmIdentity}
              >
                Ya, Benar
              </button>
            </div>
          </div>
        </div>

      {:else if step === 3}
        <!-- Step 3: Select Clinic -->
        <div class="space-y-6">
          <div class="text-center mb-6">
            <h2 class="text-white text-2xl font-bold">Pilih Poli / Klinik</h2>
            <p class="text-white/60 mt-1">Ketuk untuk memilih poli yang ingin Anda kunjungi</p>
          </div>

          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-12 h-12 border-4 border-white/30 border-t-white rounded-full animate-spin"></div>
            </div>
          {:else}
            <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
              {#each clinics as clinic}
                <button
                  class="bg-white rounded-2xl p-6 text-center hover:bg-white/90 active:scale-[0.97] transition-all shadow-lg group"
                  onclick={() => selectClinic(clinic)}
                >
                  <div class="w-14 h-14 rounded-xl bg-primary-100 flex items-center justify-center mx-auto mb-3 group-hover:bg-primary-200 transition-colors">
                    <svg class="w-8 h-8 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zm0 9.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6z" />
                    </svg>
                  </div>
                  <p class="font-bold text-gray-900 text-lg">{clinic.name}</p>
                  {#if clinic.description}
                    <p class="text-xs text-gray-500 mt-1 line-clamp-2">{clinic.description}</p>
                  {/if}
                </button>
              {/each}
            </div>

            <button
              class="w-full mt-6 py-4 rounded-xl bg-white/10 text-white text-lg font-semibold hover:bg-white/20 active:scale-[0.98] transition-all"
              onclick={() => { step = 2; resetKioskTimer(); }}
            >
              Kembali
            </button>
          {/if}
        </div>

      {:else if step === 4}
        <!-- Step 4: Select Doctor & Time -->
        <div class="space-y-6">
          <div class="text-center mb-4">
            <h2 class="text-white text-2xl font-bold">Pilih Dokter & Jam</h2>
            <p class="text-white/60 mt-1">Klinik: <span class="text-white font-semibold">{selectedClinic?.name}</span></p>
          </div>

          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-12 h-12 border-4 border-white/30 border-t-white rounded-full animate-spin"></div>
            </div>
          {:else}
            <div class="bg-white rounded-2xl p-6 shadow-xl max-h-[50vh] overflow-y-auto space-y-4">
              {#each doctors as doctor}
                <div class="border border-gray-200 rounded-xl p-4">
                  <div class="flex items-center gap-4 mb-3">
                    <div class="w-12 h-12 rounded-full bg-primary-100 flex items-center justify-center shrink-0">
                      <svg class="w-6 h-6 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
                      </svg>
                    </div>
                    <div>
                      <p class="font-bold text-gray-900">dr. {doctor.full_name}</p>
                      <p class="text-sm text-gray-500">{doctor.specialization || 'Umum'}</p>
                    </div>
                  </div>
                  <div class="grid grid-cols-4 sm:grid-cols-6 gap-2">
                    {#each TIME_SLOTS as slot}
                      <button
                        class="px-3 py-2 rounded-lg text-sm font-medium transition-all
                          {selectedDoctor?.user_id === doctor.user_id && selectedSlot === slot
                            ? 'bg-primary-600 text-white'
                            : 'bg-gray-100 text-gray-700 hover:bg-primary-50 hover:text-primary-700'}"
                        onclick={() => selectDoctorSlot(doctor, slot)}
                      >
                        {slot}
                      </button>
                    {/each}
                  </div>
                </div>
              {/each}

              {#if doctors.length === 0}
                <p class="text-center text-gray-400 py-8">Tidak ada dokter tersedia</p>
              {/if}
            </div>

            <button
              class="w-full mt-4 py-4 rounded-xl bg-white/10 text-white text-lg font-semibold hover:bg-white/20 active:scale-[0.98] transition-all"
              onclick={() => { step = 3; resetKioskTimer(); }}
            >
              Kembali
            </button>
          {/if}
        </div>

      {:else if step === 5}
        <!-- Step 5: Confirm Registration -->
        <div class="space-y-6">
          <div class="bg-white rounded-3xl p-8 shadow-2xl">
            <h2 class="text-2xl font-bold text-gray-900 text-center mb-6">Konfirmasi Registrasi</h2>

            <div class="space-y-4 mb-8">
              <div class="flex justify-between py-3 border-b border-gray-100">
                <span class="text-gray-500">Nama Pasien</span>
                <span class="font-semibold text-gray-900">{patient?.full_name}</span>
              </div>
              <div class="flex justify-between py-3 border-b border-gray-100">
                <span class="text-gray-500">No. RM</span>
                <span class="font-mono font-semibold text-gray-900">{patient?.no_registration}</span>
              </div>
              <div class="flex justify-between py-3 border-b border-gray-100">
                <span class="text-gray-500">Klinik</span>
                <span class="font-semibold text-gray-900">{selectedClinic?.name}</span>
              </div>
              <div class="flex justify-between py-3 border-b border-gray-100">
                <span class="text-gray-500">Dokter</span>
                <span class="font-semibold text-gray-900">dr. {selectedDoctor?.full_name}</span>
              </div>
              <div class="flex justify-between py-3 border-b border-gray-100">
                <span class="text-gray-500">Jam</span>
                <span class="font-semibold text-primary-600 text-lg">{selectedSlot}</span>
              </div>
              <div class="flex justify-between py-3">
                <span class="text-gray-500">Tanggal</span>
                <span class="font-semibold text-gray-900">{new Date().toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })}</span>
              </div>
            </div>

            {#if errorMsg}
              <div class="bg-red-50 border border-red-200 rounded-xl p-4 mb-6">
                <p class="text-sm text-red-700 text-center">{errorMsg}</p>
              </div>
            {/if}

            <div class="grid grid-cols-2 gap-4">
              <button
                class="py-5 rounded-xl bg-gray-100 text-gray-700 text-xl font-bold hover:bg-gray-200 active:scale-[0.98] transition-all"
                onclick={() => { step = 4; resetKioskTimer(); }}
              >
                Kembali
              </button>
              <button
                class="py-5 rounded-xl bg-emerald-600 text-white text-xl font-bold hover:bg-emerald-700 active:scale-[0.98] transition-all shadow-lg"
                onclick={confirmRegistration}
                disabled={registering}
              >
                {#if registering}
                  <span class="inline-block w-6 h-6 border-4 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
                  Mendaftar...
                {:else}
                  Daftar Sekarang
                {/if}
              </button>
            </div>
          </div>
        </div>

      {:else if step === 6}
        <!-- Step 6: Print Ticket -->
        <div class="space-y-6">
          <div class="bg-white rounded-3xl p-8 shadow-2xl text-center">
            <div class="w-20 h-20 rounded-full bg-emerald-100 flex items-center justify-center mx-auto mb-6">
              <svg class="w-10 h-10 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>

            <h2 class="text-2xl font-bold text-gray-900 mb-2">Registrasi Berhasil!</h2>
            <p class="text-gray-500 mb-8">Silakan ambil nomor antrian Anda</p>

            <!-- Ticket -->
            <div class="bg-gray-50 border-2 border-dashed border-gray-300 rounded-2xl p-8 mb-8 mx-auto max-w-sm">
              <p class="text-sm text-gray-500 uppercase tracking-wider mb-2">Nomor Antrian</p>
              <p class="text-6xl font-black text-primary-600 font-mono">{ticketNo}</p>
              <div class="mt-4 pt-4 border-t border-gray-200 space-y-2 text-sm">
                <div class="flex justify-between">
                  <span class="text-gray-500">Klinik</span>
                  <span class="font-semibold text-gray-900">{selectedClinic?.name}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-500">Dokter</span>
                  <span class="font-semibold text-gray-900">dr. {selectedDoctor?.full_name}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-500">Jam</span>
                  <span class="font-bold text-primary-600">{selectedSlot}</span>
                </div>
              </div>
            </div>

            <button
              class="w-full py-5 rounded-xl bg-primary-600 text-white text-xl font-bold hover:bg-primary-700 active:scale-[0.98] transition-all shadow-lg mb-3"
              onclick={() => window.print()}
            >
              <svg class="w-6 h-6 inline-block mr-2 -mt-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0110.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0l.229 2.523a1.125 1.125 0 01-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0021 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 00-1.913-.247M6.34 18H5.25A2.25 2.25 0 013 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 011.913-.247m0 0a48.159 48.159 0 018.5 0" />
              </svg>
              Cetak Tiket
            </button>

            <button
              class="w-full py-4 rounded-xl bg-gray-100 text-gray-700 text-lg font-semibold hover:bg-gray-200 active:scale-[0.98] transition-all"
              onclick={resetToHome}
            >
              Kembali ke Awal
            </button>
          </div>
        </div>
      {/if}

    </div>
  </main>

  <!-- Kiosk Footer -->
  <footer class="bg-white/5 border-t border-white/10 py-4 text-center">
    <p class="text-white/40 text-sm">Sentuh layar kapan saja untuk memperpanjang sesi</p>
  </footer>
</div>
