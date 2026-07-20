<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabase.js';
  import { formatDate, formatDateTime } from '$lib/utils/helpers.js';
  import { VISIT_TYPES, STATUS_PEMBAYARAN, STATUS_PERIKSA, STATUS_KELUAR } from '$lib/utils/constants.js';

  let loading = $state(true);
  let error = $state('');
  let visit = $state(null);

  function badgePembayaran(status) {
    if (status === '1') return 'badge-success';
    if (status === '2') return 'badge-info';
    return 'badge-danger';
  }

  function badgePeriksa(status) {
    return status === '1' ? 'badge-info' : 'badge-warning';
  }

  function badgeKeluar(status) {
    return status === '1' ? 'badge-success' : 'badge-warning';
  }

  async function fetchVisitDetail() {
    loading = true;
    error = '';

    try {
      const visitId = $page.params.visitId;
      const { data, error: fetchError } = await supabase
        .from('patient_visitations')
        .select(`
          visit_id,
          visit_date,
          booked_date,
          in_date,
          exit_date,
          visit_type,
          ticket_no,
          status_periksa,
          status_pembayaran,
          status_keluar,
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
            insurance_number
          ),
          clinics:clinic_id ( clinic_id, name ),
          employees:doctor_id ( employee_id, full_name ),
          payors:payor_id ( payor_id, name, type ),
          room_classes:class_id ( class_id, name ),
          rooms:room_id ( room_id, room_number ),
          beds:bed_id ( bed_id, bed_number )
        `)
        .eq('visit_id', visitId)
        .single();

      if (fetchError) throw fetchError;

      visit = {
        ...data,
        patient_name: data.patients?.full_name || '-',
        patient_no: data.patients?.no_registration || '-',
        patient_nik: data.patients?.nik || '-',
        patient_gender: data.patients?.gender || '-',
        patient_dob: data.patients?.date_of_birth || null,
        patient_phone: data.patients?.phone || '-',
        patient_address: data.patients?.address || '-',
        clinic_name: data.clinics?.name || '-',
        doctor_name: data.employees?.full_name || '-',
        payor_name: data.payors?.name || '-',
        payor_type: data.payors?.type || '-',
        class_name: data.room_classes?.name || '-',
        room_number: data.rooms?.room_number || '-',
        bed_number: data.beds?.bed_number || '-'
      };
    } catch (err) {
      console.error('Fetch visit detail error:', err);
      error = err.message || 'Gagal memuat detail registrasi';
      visit = null;
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    fetchVisitDetail();
  });
</script>

<svelte:head>
  <title>Detail Registrasi - SIMRS</title>
</svelte:head>

<div class="max-w-5xl mx-auto space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
    <div class="flex items-center gap-3">
      <button onclick={() => goto('/registrasi')} class="p-2 rounded-lg text-gray-500 hover:bg-gray-100 transition-colors" title="Kembali">
        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
        </svg>
      </button>
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Detail Registrasi</h1>
        <p class="text-sm text-gray-500">Lihat informasi kunjungan pasien</p>
      </div>
    </div>

    {#if visit}
      <button onclick={() => goto(`/registrasi/${visit.visit_id}/edit`)} class="btn-primary inline-flex items-center gap-2">
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125" />
        </svg>
        Edit Registrasi
      </button>
    {/if}
  </div>

  {#if loading}
    <div class="card flex items-center justify-center py-16">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
    </div>
  {:else if error}
    <div class="card border border-red-200 bg-red-50">
      <p class="text-sm text-red-600">{error}</p>
    </div>
  {:else if visit}
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div class="lg:col-span-2 space-y-6">
        <div class="card">
          <h2 class="text-lg font-semibold text-gray-900 mb-4">Informasi Kunjungan</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
            <div>
              <p class="text-gray-500 text-xs">ID Kunjungan</p>
              <p class="font-medium text-gray-900 font-mono">{visit.visit_id}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">No. Tiket</p>
              <p class="font-medium text-gray-900">{visit.ticket_no || '-'}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">Jenis Kunjungan</p>
              <p class="font-medium text-gray-900">{VISIT_TYPES[visit.visit_type] || visit.visit_type}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">Poli / Klinik</p>
              <p class="font-medium text-gray-900">{visit.clinic_name}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">Dokter</p>
              <p class="font-medium text-gray-900">{visit.doctor_name}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">Penanggung Biaya</p>
              <p class="font-medium text-gray-900">{visit.payor_name} {visit.payor_type !== '-' ? `(${visit.payor_type})` : ''}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">Tanggal Kunjungan</p>
              <p class="font-medium text-gray-900">{formatDateTime(visit.visit_date)}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">Tanggal Booking</p>
              <p class="font-medium text-gray-900">{formatDate(visit.booked_date)}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">Tanggal Masuk</p>
              <p class="font-medium text-gray-900">{formatDateTime(visit.in_date)}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">Tanggal Keluar</p>
              <p class="font-medium text-gray-900">{formatDateTime(visit.exit_date)}</p>
            </div>

            {#if visit.visit_type === 'rawat_inap'}
              <div>
                <p class="text-gray-500 text-xs">Kelas</p>
                <p class="font-medium text-gray-900">{visit.class_name}</p>
              </div>
              <div>
                <p class="text-gray-500 text-xs">Kamar</p>
                <p class="font-medium text-gray-900">{visit.room_number}</p>
              </div>
              <div>
                <p class="text-gray-500 text-xs">Bed</p>
                <p class="font-medium text-gray-900">{visit.bed_number}</p>
              </div>
            {/if}

            <div class="sm:col-span-2">
              <p class="text-gray-500 text-xs">Catatan</p>
              <p class="font-medium text-gray-900">{visit.description || '-'}</p>
            </div>
          </div>
        </div>

        <div class="card">
          <h2 class="text-lg font-semibold text-gray-900 mb-4">Informasi Pasien</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
            <div>
              <p class="text-gray-500 text-xs">Nama</p>
              <p class="font-medium text-gray-900">{visit.patient_name}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">No. RM</p>
              <p class="font-medium text-gray-900 font-mono">{visit.patient_no}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">NIK</p>
              <p class="font-medium text-gray-900">{visit.patient_nik}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">Jenis Kelamin</p>
              <p class="font-medium text-gray-900">{visit.patient_gender === 'L' ? 'Laki-laki' : visit.patient_gender === 'P' ? 'Perempuan' : '-'}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">Tanggal Lahir</p>
              <p class="font-medium text-gray-900">{formatDate(visit.patient_dob)}</p>
            </div>
            <div>
              <p class="text-gray-500 text-xs">Telepon</p>
              <p class="font-medium text-gray-900">{visit.patient_phone}</p>
            </div>
            <div class="sm:col-span-2">
              <p class="text-gray-500 text-xs">Alamat</p>
              <p class="font-medium text-gray-900">{visit.patient_address}</p>
            </div>
          </div>
        </div>
      </div>

      <div class="space-y-6">
        <div class="card">
          <h2 class="text-lg font-semibold text-gray-900 mb-4">Status</h2>
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-600">Pembayaran</span>
              <span class="badge {badgePembayaran(visit.status_pembayaran)}">{STATUS_PEMBAYARAN[visit.status_pembayaran] || 'Belum Bayar'}</span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-600">Pemeriksaan</span>
              <span class="badge {badgePeriksa(visit.status_periksa)}">{STATUS_PERIKSA[visit.status_periksa] || 'Belum Diperiksa'}</span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-600">Status Keluar</span>
              <span class="badge {badgeKeluar(visit.status_keluar)}">{STATUS_KELUAR[visit.status_keluar] || 'Masih di RS'}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>
