<script>
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatCurrency, formatDate, formatDateTime } from '$lib/utils/helpers.js';
  import { PAYOR_TYPES, DISCHARGE_CONDITIONS } from '$lib/utils/constants.js';

  let visitId = $derived(page.params.visitId);
  let loading = $state(true);
  let saving = $state(false);
  let activeTab = $state('ringkasan');

  let visit = $state(null);
  let patient = $state(null);
  let room = $state(null);
  let bed = $state(null);
  let doctor = $state(null);

  let cpptList = $state([]);
  let diagnoses = $state([]);
  let labOrders = $state([]);
  let radiologyOrders = $state([]);
  let prescriptions = $state([]);
  let treatmentBills = $state([]);
  let doctorVisits = $state([]);
  let consultations = $state([]);
  let roomTransfers = $state([]);

  let newCppt = $state({ subyektif: '', obyektif: '', assessment: '', planning: '', instruksi: '' });
  let diagnosisSearch = $state('');
  let diagnosisResults = $state([]);
  let searchDiagTimeout;
  let labSearch = $state('');
  let labResults = $state([]);
  let radiologySearch = $state('');
  let radiologyResults = $state([]);
  let drugSearch = $state('');
  let drugResults = $state([]);
  let newPrescription = $state({ drug_id: '', drug_name: '', qty: '', dosage: '', frequency: '', instruction: '' });
  let tariffSearch = $state('');
  let tariffResults = $state([]);
  let newBill = $state({ description: '', tariff_type: 'Konsultasi', amount: '' });
  let newDoctorVisit = $state({ doctor_name: '', notes: '', visit_type: 'visite' });
  let newConsultation = $state({ specialist: '', reason: '', urgency: 'normal' });
  let newTransfer = $state({ to_room_id: '', to_bed_id: '', reason: '' });
  let availableRooms = $state([]);
  let availableBeds = $state([]);
  let dischargeForm = $state({ condition: 'berobat_jalan', final_diagnosis: '', treatment_summary: '', discharge_medications: '', notes: '' });

  const daysStayed = $derived.by(() => {
    if (!visit) return 0;
    const d = visit.admission_date || visit.visit_date;
    if (!d) return 0;
    return Math.max(1, Math.floor((new Date().getTime() - new Date(d).getTime()) / (1000 * 60 * 60 * 24)) + 1);
  });

  const billByType = $derived.by(() => {
    const map = {};
    treatmentBills.forEach(b => {
      const t = b.tariff_type || 'Lainnya';
      map[t] = (map[t] || 0) + (b.amount || 0);
    });
    return map;
  });

  const totalBill = $derived(treatmentBills.reduce((sum, b) => sum + (b.amount || 0), 0));

  const tabs = [
    { id: 'ringkasan', label: 'Ringkasan', icon: 'summary' },
    { id: 'cppt', label: 'CPPT/SOAP', icon: 'file-text' },
    { id: 'diagnosis', label: 'Diagnosis', icon: 'activity' },
    { id: 'lab', label: 'Lab/Radiologi', icon: 'flask' },
    { id: 'resep', label: 'Resep', icon: 'pill' },
    { id: 'billing', label: 'Billing', icon: 'receipt' },
    { id: 'visite', label: 'Visite Dokter', icon: 'user-check' },
    { id: 'konsulen', label: 'Konsulen', icon: 'users' },
    { id: 'kamar', label: 'Kamar', icon: 'bed' },
    { id: 'pulang', label: 'Pulang', icon: 'logout' },
    { id: 'cetak', label: 'Cetak', icon: 'printer' }
  ];

  async function fetchVisitData() {
    try {
      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          *,
          patients:patient_id ( patient_id, full_name, no_registration, date_of_birth, gender, phone, address ),
          rooms:room_id ( room_id, name, class ),
          beds:bed_id ( bed_id, bed_no ),
          doctors:doctor_id ( doctor_id, full_name )
        `)
        .eq('visit_id', visitId)
        .single();
      if (error) throw error;
      visit = data;
      patient = data.patients;
      room = data.rooms;
      bed = data.beds;
      doctor = data.doctors;
      if (patient?.date_of_birth) {
        const birth = new Date(patient.date_of_birth);
        const today = new Date();
        let age = today.getFullYear() - birth.getFullYear();
        const m = today.getMonth() - birth.getMonth();
        if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--;
        patient.age = age;
      }
    } catch (err) {
      console.error('Fetch visit error:', err);
    }
  }

  async function fetchCppt() {
    try {
      const { data, error } = await supabase
        .from('cppt').select('*').eq('visit_id', visitId).order('created_at', { ascending: true });
      if (error) throw error;
      cpptList = data || [];
    } catch (err) { console.error('Fetch CPPT error:', err); }
  }

  async function fetchDiagnoses() {
    try {
      const { data, error } = await supabase
        .from('patient_diagnoses').select('*').eq('visit_id', visitId);
      if (error) throw error;
      diagnoses = data || [];
    } catch (err) { console.error('Fetch diagnoses error:', err); }
  }

  async function fetchLabOrders() {
    try {
      const { data, error } = await supabase
        .from('lab_orders').select('*').eq('visit_id', visitId).order('created_at', { ascending: false });
      if (error) throw error;
      labOrders = data || [];
    } catch (err) { console.error('Fetch lab orders error:', err); }
  }

  async function fetchRadiologyOrders() {
    try {
      const { data, error } = await supabase
        .from('radiology_orders').select('*').eq('visit_id', visitId).order('created_at', { ascending: false });
      if (error) throw error;
      radiologyOrders = data || [];
    } catch (err) { console.error('Fetch radiology error:', err); }
  }

  async function fetchPrescriptions() {
    try {
      const { data, error } = await supabase
        .from('prescriptions').select('*').eq('visit_id', visitId).order('created_at', { ascending: false });
      if (error) throw error;
      prescriptions = data || [];
    } catch (err) { console.error('Fetch prescriptions error:', err); }
  }

  async function fetchBills() {
    try {
      const { data, error } = await supabase
        .from('treatment_bills').select('*').eq('visit_id', visitId).order('created_at', { ascending: false });
      if (error) throw error;
      treatmentBills = data || [];
    } catch (err) { console.error('Fetch bills error:', err); }
  }

  async function fetchDoctorVisits() {
    try {
      const { data, error } = await supabase
        .from('doctor_visits').select('*').eq('visit_id', visitId).order('visit_date', { ascending: false });
      if (error) throw error;
      doctorVisits = data || [];
    } catch (err) { console.error('Fetch doctor visits error:', err); }
  }

  async function fetchConsultations() {
    try {
      const { data, error } = await supabase
        .from('consultations').select('*').eq('visit_id', visitId).order('created_at', { ascending: false });
      if (error) throw error;
      consultations = data || [];
    } catch (err) { console.error('Fetch consultations error:', err); }
  }

  async function fetchRoomTransfers() {
    try {
      const { data, error } = await supabase
        .from('room_transfers').select('*').eq('visit_id', visitId).order('transfer_date', { ascending: false });
      if (error) throw error;
      roomTransfers = data || [];
    } catch (err) { console.error('Fetch room transfers error:', err); }
  }

  async function fetchRooms() {
    try {
      const { data, error } = await supabase
        .from('rooms').select('*').eq('is_active', true).order('name');
      if (error) throw error;
      availableRooms = data || [];
    } catch (err) { console.error('Fetch rooms error:', err); }
  }

  async function fetchBeds(roomId) {
    if (!roomId) { availableBeds = []; return; }
    try {
      const { data, error } = await supabase
        .from('beds').select('*').eq('room_id', roomId).eq('status', 'empty').order('bed_no');
      if (error) throw error;
      availableBeds = data || [];
    } catch (err) { console.error('Fetch beds error:', err); }
  }

  async function saveCppt() {
    if (!newCppt.subyektif.trim() && !newCppt.obyektif.trim()) return;
    saving = true;
    try {
      const { error } = await supabase.from('cppt').insert({
        visit_id: visitId, subyektif: newCppt.subyektif, obyektif: newCppt.obyektif,
        assessment: newCppt.assessment, planning: newCppt.planning, instruksi: newCppt.instruksi
      });
      if (error) throw error;
      newCppt = { subyektif: '', obyektif: '', assessment: '', planning: '', instruksi: '' };
      await fetchCppt();
    } catch (err) { console.error('Save CPPT error:', err); }
    finally { saving = false; }
  }

  function searchDiagnosis() {
    if (diagnosisSearch.length < 2) { diagnosisResults = []; return; }
    clearTimeout(searchDiagTimeout);
    searchDiagTimeout = setTimeout(async () => {
      try {
        const { data, error } = await supabase.from('diagnoses').select('diagnosis_id, code, name')
          .eq('is_active', true)
          .or(`code.ilike.%${diagnosisSearch}%,name.ilike.%${diagnosisSearch}%`).limit(10);
        if (error) throw error;
        diagnosisResults = data || [];
      } catch (err) { console.error('Search ICD error:', err); }
    }, 300);
  }

  async function addDiagnosis(diagnosisId, type = 'primer') {
    try {
      if (diagnoses.find(d => d.diagnosis_id === diagnosisId)) return;
      const { error } = await supabase.from('patient_diagnoses').insert({
        visit_id: visitId,
        diagnosis_id: diagnosisId,
        diagnosis_type: type
      });
      if (error) throw error;
      await fetchDiagnoses();
      diagnosisSearch = '';
      diagnosisResults = [];
    } catch (err) { console.error('Add diagnosis error:', err); }
  }

  async function removeDiagnosis(id) {
    try {
      const { error } = await supabase.from('patient_diagnoses').delete().eq('id', id);
      if (error) throw error;
      await fetchDiagnoses();
    } catch (err) { console.error('Remove diagnosis error:', err); }
  }

  async function searchLabTests() {
    if (labSearch.length < 2) { labResults = []; return; }
    try {
      const { data, error } = await supabase.from('lab_test_catalog')
        .select('test_id, test_name, category, price').ilike('test_name', `%${labSearch}%`).limit(10);
      if (error) throw error;
      labResults = data || [];
    } catch (err) { console.error('Search lab tests error:', err); }
  }

  async function orderLab(testName, category) {
    try {
      const { error } = await supabase.from('lab_orders').insert({
        visit_id: visitId, test_name: testName, category, status: 'ordered'
      });
      if (error) throw error;
      await fetchLabOrders();
    } catch (err) { console.error('Order lab error:', err); }
  }

  async function searchRadiologyTests() {
    if (radiologySearch.length < 2) { radiologyResults = []; return; }
    try {
      const { data, error } = await supabase.from('radiology_catalog')
        .select('exam_id, exam_type, description, price').ilike('exam_type', `%${radiologySearch}%`).limit(10);
      if (error) throw error;
      radiologyResults = data || [];
    } catch (err) { console.error('Search radiology error:', err); }
  }

  async function orderRadiology(examType, description) {
    try {
      const { error } = await supabase.from('radiology_orders').insert({
        visit_id: visitId,
        examination_type: examType,
        clinical_info: description,
        exam_type: examType,
        description,
        status: 'ordered'
      });
      if (error) throw error;
      await fetchRadiologyOrders();
    } catch (err) { console.error('Order radiology error:', err); }
  }

  async function searchDrugs() {
    if (drugSearch.length < 2) { drugResults = []; return; }
    try {
      const { data, error } = await supabase.from('drugs')
        .select('drug_id, name, unit, category').ilike('name', `%${drugSearch}%`).eq('is_active', true).limit(10);
      if (error) throw error;
      drugResults = data || [];
    } catch (err) { console.error('Search drugs error:', err); }
  }

  function selectDrug(drug) {
    newPrescription.drug_id = drug.drug_id;
    newPrescription.drug_name = `${drug.name} (${drug.unit})`;
    drugSearch = '';
    drugResults = [];
  }

  async function savePrescription() {
    if (!newPrescription.drug_id || !newPrescription.qty) return;
    saving = true;
    try {
      const { error } = await supabase.from('prescriptions').insert({
        visit_id: visitId, drug_id: newPrescription.drug_id, drug_name: newPrescription.drug_name,
        qty: Number(newPrescription.qty), dosage: newPrescription.dosage,
        frequency: newPrescription.frequency, instruction: newPrescription.instruction, prescription_type: 'ranap'
      });
      if (error) throw error;
      newPrescription = { drug_id: '', drug_name: '', qty: '', dosage: '', frequency: '', instruction: '' };
      await fetchPrescriptions();
    } catch (err) { console.error('Save prescription error:', err); }
    finally { saving = false; }
  }

  async function removePrescription(id) {
    try {
      const { error } = await supabase.from('prescriptions').delete().eq('id', id);
      if (error) throw error;
      await fetchPrescriptions();
    } catch (err) { console.error('Remove prescription error:', err); }
  }

  async function searchTariffs() {
    if (tariffSearch.length < 2) { tariffResults = []; return; }
    try {
      const { data, error } = await supabase.from('tariffs')
        .select('tariff_id, name, category, price').ilike('name', `%${tariffSearch}%`).limit(10);
      if (error) throw error;
      tariffResults = data || [];
    } catch (err) { console.error('Search tariffs error:', err); }
  }

  async function addBill(tariff) {
    try {
      const { error } = await supabase.from('treatment_bills').insert({
        visit_id: visitId, tariff_id: tariff.tariff_id, description: tariff.name, tariff_type: tariff.category, amount: tariff.price
      });
      if (error) throw error;
      tariffSearch = '';
      tariffResults = [];
      await fetchBills();
    } catch (err) { console.error('Add bill error:', err); }
  }

  async function addCustomBill() {
    if (!newBill.description.trim() || !newBill.amount) return;
    saving = true;
    try {
      const { error } = await supabase.from('treatment_bills').insert({
        visit_id: visitId, description: newBill.description, tariff_type: newBill.tariff_type, amount: Number(newBill.amount)
      });
      if (error) throw error;
      newBill = { description: '', tariff_type: 'Konsultasi', amount: '' };
      await fetchBills();
    } catch (err) { console.error('Add custom bill error:', err); }
    finally { saving = false; }
  }

  async function removeBill(id) {
    try {
      const { error } = await supabase.from('treatment_bills').delete().eq('id', id);
      if (error) throw error;
      await fetchBills();
    } catch (err) { console.error('Remove bill error:', err); }
  }

  async function saveDoctorVisit() {
    if (!newDoctorVisit.notes.trim()) return;
    saving = true;
    try {
      const { error } = await supabase.from('doctor_visits').insert({
        visit_id: visitId, doctor_name: newDoctorVisit.doctor_name, notes: newDoctorVisit.notes,
        visit_type: newDoctorVisit.visit_type
      });
      if (error) throw error;
      newDoctorVisit = { doctor_name: '', notes: '', visit_type: 'visite' };
      await fetchDoctorVisits();
    } catch (err) { console.error('Save doctor visit error:', err); }
    finally { saving = false; }
  }

  async function saveConsultation() {
    if (!newConsultation.specialist.trim() || !newConsultation.reason.trim()) return;
    saving = true;
    try {
      const { error } = await supabase.from('consultations').insert({
        visit_id: visitId, specialist: newConsultation.specialist, reason: newConsultation.reason,
        urgency: newConsultation.urgency
      });
      if (error) throw error;
      newConsultation = { specialist: '', reason: '', urgency: 'normal' };
      await fetchConsultations();
    } catch (err) { console.error('Save consultation error:', err); }
    finally { saving = false; }
  }

  async function updateConsultationStatus(id, status) {
    try {
      const { error } = await supabase.from('consultations').update({ status }).eq('id', id);
      if (error) throw error;
      await fetchConsultations();
    } catch (err) { console.error('Update consultation error:', err); }
  }

  async function saveRoomTransfer() {
    if (!newTransfer.to_room_id || !newTransfer.reason.trim()) return;
    saving = true;
    try {
      const { error } = await supabase.from('room_transfers').insert({
        visit_id: visitId, from_room_id: visit?.room_id, from_bed_id: visit?.bed_id,
        to_room_id: newTransfer.to_room_id, to_bed_id: newTransfer.to_bed_id || null,
        reason: newTransfer.reason
      });
      if (error) throw error;

      if (visit?.bed_id) {
        await supabase.from('beds').update({ status: 'empty' }).eq('bed_id', visit.bed_id);
      }
      if (newTransfer.to_bed_id) {
        await supabase.from('beds').update({ status: 'occupied' }).eq('bed_id', newTransfer.to_bed_id);
        await supabase.from('patient_visitations').update({
          room_id: newTransfer.to_room_id, bed_id: newTransfer.to_bed_id
        }).eq('visit_id', visitId);
      } else {
        await supabase.from('patient_visitations').update({
          room_id: newTransfer.to_room_id
        }).eq('visit_id', visitId);
      }

      newTransfer = { to_room_id: '', to_bed_id: '', reason: '' };
      await Promise.all([fetchRoomTransfers(), fetchVisitData()]);
    } catch (err) { console.error('Save room transfer error:', err); }
    finally { saving = false; }
  }

  async function processDischarge() {
    if (!dischargeForm.final_diagnosis.trim()) return;
    saving = true;
    try {
      const { error } = await supabase.from('patient_visitations').update({
        discharge_date: new Date().toISOString(),
        discharge_condition: dischargeForm.condition,
        final_diagnosis: dischargeForm.final_diagnosis,
        treatment_summary: dischargeForm.treatment_summary,
        discharge_medications: dischargeForm.discharge_medications,
        discharge_notes: dischargeForm.notes
      }).eq('visit_id', visitId);
      if (error) throw error;

      if (visit?.bed_id) {
        await supabase.from('beds').update({ status: 'empty' }).eq('bed_id', visit.bed_id);
      }

      await fetchVisitData();
    } catch (err) { console.error('Discharge error:', err); }
    finally { saving = false; }
  }

  function goBack() {
    goto('/rawat-inap');
  }

  function printResume() {
    window.print();
  }

  function printBilling() {
    window.print();
  }

  onMount(async () => {
    loading = true;
    await fetchVisitData();
    await Promise.all([
      fetchCppt(), fetchDiagnoses(), fetchLabOrders(), fetchRadiologyOrders(),
      fetchPrescriptions(), fetchBills(), fetchDoctorVisits(), fetchConsultations(),
      fetchRoomTransfers(), fetchRooms()
    ]);
    loading = false;
  });
</script>

<svelte:head>
  <title>{patient?.full_name || 'Pasien'} - Rawat Inap</title>
</svelte:head>

{#if loading}
  <div class="flex items-center justify-center py-24">
    <div class="flex flex-col items-center gap-4">
      <div class="w-12 h-12 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
      <p class="text-sm text-gray-500 font-medium">Memuat data rawat inap...</p>
    </div>
  </div>
{:else if !visit}
  <div class="card text-center py-16">
    <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
    </svg>
    <p class="text-lg font-medium text-gray-700">Kunjungan tidak ditemukan</p>
    <button class="btn-primary mt-4" onclick={goBack}>Kembali ke Daftar Rawat Inap</button>
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
      <h1 class="text-xl font-bold text-gray-900">Rawat Inap - Detail Pasien</h1>
      {#if visit.discharge_date}
        <span class="badge badge-info">Sudah Pulang</span>
      {:else}
        <span class="badge badge-success">Sedang Dirawat</span>
      {/if}
    </div>

    <div class="card bg-gradient-to-r from-primary-50 to-blue-50 border-primary-200">
      <div class="flex flex-col md:flex-row md:items-center gap-4">
        <div class="shrink-0 w-14 h-14 rounded-full bg-primary-100 flex items-center justify-center">
          <svg class="w-7 h-7 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
          </svg>
        </div>
        <div class="flex-1">
          <h2 class="text-xl font-bold text-gray-900">{patient?.full_name || '-'}</h2>
          <div class="flex flex-wrap gap-x-6 gap-y-1 mt-1 text-sm text-gray-600">
            <span>No. RM: <strong class="text-gray-900 font-mono">{patient?.no_registration || '-'}</strong></span>
            <span>Umur: <strong class="text-gray-900">{patient?.age ?? '-'} tahun</strong></span>
            <span>Jenis Kelamin: <strong class="text-gray-900">{patient?.gender === 'L' ? 'Laki-laki' : patient?.gender === 'P' ? 'Perempuan' : '-'}</strong></span>
          </div>
        </div>
        <div class="flex flex-wrap gap-3 text-sm">
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">Kamar</p>
            <p class="font-semibold text-gray-900">{room?.name || '-'}</p>
          </div>
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">Bed</p>
            <p class="font-semibold text-gray-900">{bed?.bed_no || '-'}</p>
          </div>
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">Kelas</p>
            <p class="font-semibold text-gray-900">{room?.class || '-'}</p>
          </div>
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">Dokter</p>
            <p class="font-semibold text-gray-900">{doctor?.full_name || '-'}</p>
          </div>
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">Hari ke-</p>
            <p class="font-semibold text-primary-600">{daysStayed} hari</p>
          </div>
        </div>
      </div>
    </div>

    <div class="card p-0">
      <div class="flex overflow-x-auto border-b border-gray-200 scrollbar-thin">
        {#each tabs as tab}
          <button
            class="flex items-center gap-2 px-4 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
              {activeTab === tab.id
                ? 'border-primary-600 text-primary-700 bg-primary-50'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
            onclick={() => activeTab = tab.id}
          >
            {#if tab.icon === 'summary'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25a2.25 2.25 0 0 1-2.25-2.25v-2.25Z" /></svg>
            {:else if tab.icon === 'file-text'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" /></svg>
            {:else if tab.icon === 'activity'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 0 0 6 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0 1 18 16.5h-2.25m-7.5 0h7.5m-7.5 0-1 3m8.5-3 1 3m0 0 .5 1.5m-.5-1.5h-9.5m0 0-.5 1.5" /></svg>
            {:else if tab.icon === 'flask'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" /></svg>
            {:else if tab.icon === 'pill'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" /></svg>
            {:else if tab.icon === 'receipt'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" /></svg>
            {:else if tab.icon === 'user-check'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg>
            {:else if tab.icon === 'users'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 0 0 3.741-.479 3 3 0 0 0-4.682-2.72m.94 3.198.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0 1 12 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 0 1 6 18.719m12 0a5.971 5.971 0 0 0-.941-3.197m0 0A5.995 5.995 0 0 0 12 12.75a5.995 5.995 0 0 0-5.058 2.772m0 0a3 3 0 0 0-4.681 2.72 8.986 8.986 0 0 0 3.74.477m.94-3.197a5.971 5.971 0 0 0-.94 3.197M15 6.75a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm6 3a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-13.5 0a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Z" /></svg>
            {:else if tab.icon === 'bed'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12l8.954-8.955a1.126 1.126 0 0 1 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25" /></svg>
            {:else if tab.icon === 'logout'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15m3 0 3-3m0 0-3-3m3 3H9" /></svg>
            {:else if tab.icon === 'printer'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0 1 10.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0 .229 2.523a1.125 1.125 0 0 1-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0 0 21 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 0 0-1.913-.247M6.34 18H5.25A2.25 2.25 0 0 1 3 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 0 1 1.913-.247m10.5 0a48.536 48.536 0 0 0-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659" /></svg>
            {/if}
            <span class="hidden sm:inline">{tab.label}</span>
          </button>
        {/each}
      </div>

      <div class="p-6">
        {#if activeTab === 'ringkasan'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Ringkasan Rawat Inap</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <div class="space-y-3">
                <h4 class="text-sm font-semibold text-gray-700 uppercase tracking-wide">Informasi Pasien</h4>
                <div class="bg-gray-50 rounded-lg p-4 space-y-2">
                  <div class="flex justify-between"><span class="text-sm text-gray-500">No. RM</span><span class="text-sm font-semibold text-gray-900 font-mono">{patient?.no_registration || '-'}</span></div>
                  <div class="flex justify-between"><span class="text-sm text-gray-500">Nama</span><span class="text-sm font-semibold text-gray-900">{patient?.full_name || '-'}</span></div>
                  <div class="flex justify-between"><span class="text-sm text-gray-500">Umur</span><span class="text-sm font-semibold text-gray-900">{patient?.age ?? '-'} tahun</span></div>
                  <div class="flex justify-between"><span class="text-sm text-gray-500">Jenis Kelamin</span><span class="text-sm font-semibold text-gray-900">{patient?.gender === 'L' ? 'Laki-laki' : 'Perempuan'}</span></div>
                </div>
              </div>
              <div class="space-y-3">
                <h4 class="text-sm font-semibold text-gray-700 uppercase tracking-wide">Informasi Perawatan</h4>
                <div class="bg-gray-50 rounded-lg p-4 space-y-2">
                  <div class="flex justify-between"><span class="text-sm text-gray-500">Tgl Masuk</span><span class="text-sm font-semibold text-gray-900">{formatDate(visit?.admission_date || visit?.visit_date)}</span></div>
                  <div class="flex justify-between"><span class="text-sm text-gray-500">Hari ke-</span><span class="text-sm font-bold text-primary-600">{daysStayed} hari</span></div>
                  <div class="flex justify-between"><span class="text-sm text-gray-500">Kamar</span><span class="text-sm font-semibold text-gray-900">{room?.name || '-'}</span></div>
                  <div class="flex justify-between"><span class="text-sm text-gray-500">Kelas</span><span class="text-sm font-semibold text-gray-900">{room?.class || '-'}</span></div>
                  <div class="flex justify-between"><span class="text-sm text-gray-500">Bed</span><span class="text-sm font-semibold text-gray-900">{bed?.bed_no || '-'}</span></div>
                  <div class="flex justify-between"><span class="text-sm text-gray-500">Dokter</span><span class="text-sm font-semibold text-gray-900">{doctor?.full_name || '-'}</span></div>
                  <div class="flex justify-between"><span class="text-sm text-gray-500">Tipe Bayar</span><span class="text-sm font-semibold text-gray-900">{PAYOR_TYPES[visit?.payor_type] || '-'}</span></div>
                </div>
              </div>
              <div class="space-y-3">
                <h4 class="text-sm font-semibold text-gray-700 uppercase tracking-wide">Diagnosis</h4>
                <div class="bg-gray-50 rounded-lg p-4 space-y-2">
                  {#if diagnoses.length > 0}
                    {#each diagnoses as diag}
                      <div class="flex items-center gap-2">
                        <span class="badge {diag.diagnosis_type === 'primer' ? 'badge-danger' : 'badge-info'} text-[10px]">{diag.diagnosis_type === 'primer' ? 'P' : 'S'}</span>
                        <span class="text-sm text-gray-900">{diag.icd_code} - {diag.icd_name}</span>
                      </div>
                    {/each}
                  {:else}
                    <p class="text-sm text-gray-400">Belum ada diagnosis</p>
                  {/if}
                </div>
              </div>
            </div>

            {#if visit?.discharge_date}
              <div class="bg-blue-50 border border-blue-200 rounded-xl p-5">
                <h4 class="text-sm font-semibold text-blue-700 uppercase tracking-wide mb-3">Informasi Pulang</h4>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="space-y-2">
                    <div class="flex justify-between"><span class="text-sm text-gray-500">Tgl Pulang</span><span class="text-sm font-semibold text-gray-900">{formatDateTime(visit.discharge_date)}</span></div>
                    <div class="flex justify-between"><span class="text-sm text-gray-500">Kondisi</span><span class="text-sm font-semibold text-gray-900">{DISCHARGE_CONDITIONS[visit.discharge_condition] || visit.discharge_condition || '-'}</span></div>
                    <div class="flex justify-between"><span class="text-sm text-gray-500">Diagnosis Akhir</span><span class="text-sm font-semibold text-gray-900">{visit.final_diagnosis || '-'}</span></div>
                  </div>
                  <div class="space-y-2">
                    <div><span class="text-sm text-gray-500">Ringkasan Perawatan</span><p class="text-sm text-gray-900 mt-1">{visit.treatment_summary || '-'}</p></div>
                    <div><span class="text-sm text-gray-500">Obat Pulang</span><p class="text-sm text-gray-900 mt-1">{visit.discharge_medications || '-'}</p></div>
                  </div>
                </div>
              </div>
            {/if}
          </div>

        {:else if activeTab === 'cppt'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Catatan Perkembangan Pasien Terpadu (CPPT/SOAP)</h3>

            {#if cpptList.length > 0}
              <div class="space-y-4">
                {#each cpptList as cppt}
                  <div class="border border-gray-200 rounded-lg overflow-hidden">
                    <div class="bg-gray-50 px-4 py-2 border-b border-gray-200">
                      <p class="text-xs text-gray-500 font-mono">{formatDateTime(cppt.created_at)}</p>
                    </div>
                    <div class="p-4 space-y-3">
                      <div>
                        <p class="text-xs font-semibold text-blue-600 uppercase mb-1">Subyektif</p>
                        <p class="text-sm text-gray-700">{cppt.subyektif || '-'}</p>
                      </div>
                      <div>
                        <p class="text-xs font-semibold text-emerald-600 uppercase mb-1">Obyektif</p>
                        <p class="text-sm text-gray-700">{cppt.obyektif || '-'}</p>
                      </div>
                      <div>
                        <p class="text-xs font-semibold text-amber-600 uppercase mb-1">Assessment</p>
                        <p class="text-sm text-gray-700">{cppt.assessment || '-'}</p>
                      </div>
                      <div>
                        <p class="text-xs font-semibold text-purple-600 uppercase mb-1">Planning</p>
                        <p class="text-sm text-gray-700">{cppt.planning || '-'}</p>
                      </div>
                      {#if cppt.instruksi}
                        <div>
                          <p class="text-xs font-semibold text-red-600 uppercase mb-1">Instruksi</p>
                          <p class="text-sm text-gray-700">{cppt.instruksi}</p>
                        </div>
                      {/if}
                    </div>
                  </div>
                {/each}
              </div>
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Belum ada catatan SOAP</p>
            {/if}

            <div class="border-t border-gray-200 pt-6">
              <h4 class="text-sm font-semibold text-gray-700 mb-3">Tambah Catatan SOAP Baru</h4>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-1">
                  <label class="label">Subyektif</label>
                  <textarea class="input-field h-24 resize-none text-sm" bind:value={newCppt.subyektif} placeholder="Keluhan pasien..."></textarea>
                </div>
                <div class="space-y-1">
                  <label class="label">Obyektif</label>
                  <textarea class="input-field h-24 resize-none text-sm" bind:value={newCppt.obyektif} placeholder="Temuan pemeriksaan..."></textarea>
                </div>
                <div class="space-y-1">
                  <label class="label">Assessment</label>
                  <textarea class="input-field h-24 resize-none text-sm" bind:value={newCppt.assessment} placeholder="Diagnosis/penilaian..."></textarea>
                </div>
                <div class="space-y-1">
                  <label class="label">Planning</label>
                  <textarea class="input-field h-24 resize-none text-sm" bind:value={newCppt.planning} placeholder="Rencana tindak lanjut..."></textarea>
                </div>
              </div>
              <div class="space-y-1 mt-4">
                <label class="label">Instruksi (opsional)</label>
                <textarea class="input-field h-20 resize-none text-sm" bind:value={newCppt.instruksi} placeholder="Instruksi khusus untuk perawat/paramedis..."></textarea>
              </div>
              <div class="flex justify-end mt-4">
                <button class="btn-primary" onclick={saveCppt} disabled={saving}>
                  {#if saving}
                    <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
                  {/if}
                  Simpan Catatan
                </button>
              </div>
            </div>
          </div>

        {:else if activeTab === 'diagnosis'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Diagnosis (ICD-10)</h3>

            <div class="space-y-2">
              <label class="label">Cari Kode ICD-10</label>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                </svg>
                <input type="text" class="input-field pl-10" placeholder="Ketik kode atau nama penyakit..." bind:value={diagnosisSearch} oninput={searchDiagnosis} />
              </div>
              {#if diagnosisResults.length > 0}
                <div class="border border-gray-200 rounded-lg divide-y divide-gray-100 max-h-60 overflow-y-auto">
                  {#each diagnosisResults as icd}
                    <div class="flex items-center justify-between px-4 py-3 hover:bg-gray-50">
                      <div>
                        <span class="font-mono text-sm font-semibold text-primary-700">{icd.code}</span>
                        <span class="text-sm text-gray-700 ml-2">{icd.name}</span>
                      </div>
                      <div class="flex gap-2">
                        <button class="text-xs bg-red-100 text-red-700 px-2 py-1 rounded hover:bg-red-200" onclick={() => addDiagnosis(icd.diagnosis_id, 'primer')}>Primer</button>
                        <button class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded hover:bg-blue-200" onclick={() => addDiagnosis(icd.diagnosis_id, 'sekunder')}>Sekunder</button>
                      </div>
                    </div>
                  {/each}
                </div>
              {/if}
            </div>

            {#if diagnoses.length > 0}
              <div>
                <h4 class="text-sm font-semibold text-gray-700 mb-3">Diagnosis Terdaftar</h4>
                <div class="space-y-2">
                  {#each diagnoses as diag}
                    <div class="flex items-center justify-between bg-gray-50 rounded-lg px-4 py-3">
                      <div class="flex items-center gap-3">
                        <span class="badge {diag.diagnosis_type === 'primer' ? 'badge-danger' : 'badge-info'}">{diag.diagnosis_type === 'primer' ? 'Primer' : 'Sekunder'}</span>
                        <div>
                          <span class="font-mono text-sm font-semibold text-gray-900">{diag.icd_code}</span>
                          <span class="text-sm text-gray-600 ml-2">{diag.icd_name}</span>
                        </div>
                      </div>
                      <button class="text-gray-400 hover:text-red-500 transition-colors" onclick={() => removeDiagnosis(diag.id)}>
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" /></svg>
                      </button>
                    </div>
                  {/each}
                </div>
              </div>
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Belum ada diagnosis terdaftar</p>
            {/if}
          </div>

        {:else if activeTab === 'lab'}
          <div class="space-y-6">
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div class="space-y-4">
                <h3 class="text-lg font-semibold text-gray-900">Laboratorium</h3>
                <div class="space-y-2">
                  <div class="relative">
                    <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                    </svg>
                    <input type="text" class="input-field pl-10" placeholder="Cari tes laboratorium..." bind:value={labSearch} oninput={searchLabTests} />
                  </div>
                  {#if labResults.length > 0}
                    <div class="border border-gray-200 rounded-lg divide-y divide-gray-100 max-h-60 overflow-y-auto">
                      {#each labResults as test}
                        <div class="flex items-center justify-between px-4 py-3 hover:bg-gray-50">
                          <div>
                            <span class="text-sm font-medium text-gray-900">{test.test_name}</span>
                            <span class="badge badge-gray ml-2">{test.category}</span>
                            <span class="text-xs text-gray-500 ml-2">{formatCurrency(test.price)}</span>
                          </div>
                          <button class="btn-success btn-sm text-xs" onclick={() => { orderLab(test.test_name, test.category); labSearch = ''; labResults = []; }}>Pesan</button>
                        </div>
                      {/each}
                    </div>
                  {/if}
                </div>
                {#if labOrders.length > 0}
                  <div class="overflow-x-auto">
                    <table class="w-full">
                      <thead><tr class="table-header">
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tes</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Hasil</th>
                      </tr></thead>
                      <tbody class="divide-y divide-gray-100">
                        {#each labOrders as order, i}
                          <tr class="hover:bg-gray-50">
                            <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                            <td class="table-cell font-medium text-gray-900">{order.test_name}</td>
                            <td class="table-cell">
                              <span class="badge {order.status === 'completed' ? 'badge-success' : order.status === 'ordered' ? 'badge-warning' : 'badge-info'}">
                                {order.status === 'completed' ? 'Selesai' : order.status === 'ordered' ? 'Dipesan' : 'Proses'}
                              </span>
                            </td>
                            <td class="table-cell text-gray-600 max-w-xs truncate">{order.results || '-'}</td>
                          </tr>
                        {/each}
                      </tbody>
                    </table>
                  </div>
                {:else}
                  <p class="text-sm text-gray-400 text-center py-4">Belum ada pesanan lab</p>
                {/if}
              </div>

              <div class="space-y-4">
                <h3 class="text-lg font-semibold text-gray-900">Radiologi</h3>
                <div class="space-y-2">
                  <div class="relative">
                    <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                    </svg>
                    <input type="text" class="input-field pl-10" placeholder="Cari pemeriksaan radiologi..." bind:value={radiologySearch} oninput={searchRadiologyTests} />
                  </div>
                  {#if radiologyResults.length > 0}
                    <div class="border border-gray-200 rounded-lg divide-y divide-gray-100 max-h-60 overflow-y-auto">
                      {#each radiologyResults as exam}
                        <div class="flex items-center justify-between px-4 py-3 hover:bg-gray-50">
                          <div>
                            <span class="text-sm font-medium text-gray-900">{exam.exam_type}</span>
                            {#if exam.description}
                              <span class="text-xs text-gray-500 ml-2">{exam.description}</span>
                            {/if}
                            <span class="text-xs text-gray-500 ml-2">{formatCurrency(exam.price)}</span>
                          </div>
                          <button class="btn-success btn-sm text-xs" onclick={() => { orderRadiology(exam.exam_type, exam.description); radiologySearch = ''; radiologyResults = []; }}>Pesan</button>
                        </div>
                      {/each}
                    </div>
                  {/if}
                </div>
                {#if radiologyOrders.length > 0}
                  <div class="overflow-x-auto">
                    <table class="w-full">
                      <thead><tr class="table-header">
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Jenis</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Hasil</th>
                      </tr></thead>
                      <tbody class="divide-y divide-gray-100">
                        {#each radiologyOrders as order, i}
                          <tr class="hover:bg-gray-50">
                            <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                            <td class="table-cell font-medium text-gray-900">{order.exam_type}</td>
                            <td class="table-cell">
                              <span class="badge {order.status === 'completed' ? 'badge-success' : order.status === 'ordered' ? 'badge-warning' : 'badge-info'}">
                                {order.status === 'completed' ? 'Selesai' : order.status === 'ordered' ? 'Dipesan' : 'Proses'}
                              </span>
                            </td>
                            <td class="table-cell text-gray-600 max-w-xs truncate">{order.results || '-'}</td>
                          </tr>
                        {/each}
                      </tbody>
                    </table>
                  </div>
                {:else}
                  <p class="text-sm text-gray-400 text-center py-4">Belum ada pesanan radiologi</p>
                {/if}
              </div>
            </div>
          </div>

        {:else if activeTab === 'resep'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Resep Obat (Rawat Inap)</h3>

            <div class="border border-gray-200 rounded-lg p-4 space-y-4">
              <h4 class="text-sm font-semibold text-gray-700">Tambah Resep</h4>
              <div class="space-y-2">
                <label class="label">Cari Obat</label>
                <div class="relative">
                  <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                  </svg>
                  <input type="text" class="input-field pl-10" placeholder="Cari nama obat..." bind:value={drugSearch} oninput={searchDrugs} />
                </div>
                {#if drugResults.length > 0}
                  <div class="border border-gray-200 rounded-lg divide-y divide-gray-100 max-h-48 overflow-y-auto">
                    {#each drugResults as drug}
                      <button class="flex items-center justify-between w-full px-4 py-3 hover:bg-gray-50 text-left" onclick={() => selectDrug(drug)}>
                        <div>
                          <span class="text-sm font-medium text-gray-900">{drug.name}</span>
                          <span class="text-xs text-gray-500 ml-2">({drug.unit})</span>
                          <span class="badge badge-gray ml-2">{drug.category}</span>
                        </div>
                      </button>
                    {/each}
                  </div>
                {/if}
              </div>
              {#if newPrescription.drug_id}
                <div class="bg-primary-50 rounded-lg px-4 py-3">
                  <p class="text-sm font-semibold text-primary-700">{newPrescription.drug_name}</p>
                </div>
              {/if}
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div class="space-y-1"><label class="label">Jumlah (Qty)</label><input type="number" class="input-field" bind:value={newPrescription.qty} placeholder="10" /></div>
                <div class="space-y-1"><label class="label">Dosis</label><input type="text" class="input-field" bind:value={newPrescription.dosage} placeholder="500mg" /></div>
                <div class="space-y-1">
                  <label class="label">Frekuensi</label>
                  <select class="select-field" bind:value={newPrescription.frequency}>
                    <option value="">Pilih...</option>
                    <option value="1x1">1x1 sehari</option>
                    <option value="1x2">1x2 sehari</option>
                    <option value="1x3">1x3 sehari</option>
                    <option value="2x1">2x1 dua kali sehari</option>
                    <option value="3x1">3x1 tiga kali sehari</option>
                    <option value="q6h">Setiap 6 jam</option>
                    <option value="q8h">Setiap 8 jam</option>
                    <option value="q12h">Setiap 12 jam</option>
                    <option value="PRN">Saat Diperlukan (PRN)</option>
                  </select>
                </div>
                <div class="space-y-1"><label class="label">Instruksi</label><input type="text" class="input-field" bind:value={newPrescription.instruction} placeholder="Sebelum/Sehabis makan" /></div>
              </div>
              <div class="flex justify-end">
                <button class="btn-primary" onclick={savePrescription} disabled={saving || !newPrescription.drug_id || !newPrescription.qty}>
                  {#if saving}<span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>{/if}
                  Tambah Resep
                </button>
              </div>
            </div>

            {#if prescriptions.length > 0}
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead><tr class="table-header">
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Obat</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Qty</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Dosis</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Frekuensi</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Instruksi</th>
                    <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                  </tr></thead>
                  <tbody class="divide-y divide-gray-100">
                    {#each prescriptions as rx, i}
                      <tr class="hover:bg-gray-50">
                        <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                        <td class="table-cell font-medium text-gray-900">{rx.drug_name}</td>
                        <td class="table-cell text-gray-600">{rx.qty}</td>
                        <td class="table-cell text-gray-600 hidden md:table-cell">{rx.dosage || '-'}</td>
                        <td class="table-cell text-gray-600 hidden md:table-cell">{rx.frequency || '-'}</td>
                        <td class="table-cell text-gray-600 hidden lg:table-cell">{rx.instruction || '-'}</td>
                        <td class="table-cell text-right">
                          <button class="text-gray-400 hover:text-red-500 transition-colors" onclick={() => removePrescription(rx.id)}>
                            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" /></svg>
                          </button>
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Belum ada resep</p>
            {/if}
          </div>

        {:else if activeTab === 'billing'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Billing / Tagihan Rawat Inap</h3>

            <div class="space-y-2">
              <label class="label">Tambah dari Daftar Tarif</label>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                </svg>
                <input type="text" class="input-field pl-10" placeholder="Cari item tarif..." bind:value={tariffSearch} oninput={searchTariffs} />
              </div>
              {#if tariffResults.length > 0}
                <div class="border border-gray-200 rounded-lg divide-y divide-gray-100 max-h-60 overflow-y-auto">
                  {#each tariffResults as tariff}
                    <div class="flex items-center justify-between px-4 py-3 hover:bg-gray-50">
                      <div>
                        <span class="text-sm font-medium text-gray-900">{tariff.name}</span>
                        <span class="badge badge-gray ml-2">{tariff.category}</span>
                        <span class="text-sm font-semibold text-emerald-600 ml-2">{formatCurrency(tariff.price)}</span>
                      </div>
                      <button class="btn-success btn-sm text-xs" onclick={() => addBill(tariff)}>Tambah</button>
                    </div>
                  {/each}
                </div>
              {/if}
            </div>

            <div class="border border-gray-200 rounded-lg p-4 space-y-4">
              <h4 class="text-sm font-semibold text-gray-700">Tambah Biaya Manual</h4>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="space-y-1 md:col-span-2"><label class="label">Deskripsi</label><input type="text" class="input-field" bind:value={newBill.description} placeholder="Deskripsi biaya..." /></div>
                <div class="space-y-1"><label class="label">Jumlah (Rp)</label><input type="number" class="input-field" bind:value={newBill.amount} placeholder="0" /></div>
              </div>
              <div class="space-y-1">
                <label class="label">Tipe Tarif</label>
                <select class="select-field" bind:value={newBill.tariff_type}>
                  <option value="Konsultasi">Konsultasi</option>
                  <option value="Akomodasi">Akomodasi</option>
                  <option value="Laboratorium">Laboratorium</option>
                  <option value="Radiologi">Radiologi</option>
                  <option value="Obat">Obat</option>
                  <option value="Tindakan">Tindakan</option>
                  <option value="Visite Dokter">Visite Dokter</option>
                  <option value="Lainnya">Lainnya</option>
                </select>
              </div>
              <div class="flex justify-end">
                <button class="btn-primary" onclick={addCustomBill} disabled={saving || !newBill.description.trim() || !newBill.amount}>
                  {#if saving}<span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>{/if}
                  Tambah Biaya
                </button>
              </div>
            </div>

            {#if treatmentBills.length > 0}
              <div>
                <h4 class="text-sm font-semibold text-gray-700 mb-3">Ringkasan Per Tipe</h4>
                <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3 mb-4">
                  {#each Object.entries(billByType) as [type, amount]}
                    <div class="bg-gray-50 rounded-lg p-3">
                      <p class="text-xs text-gray-500 uppercase">{type}</p>
                      <p class="text-sm font-bold text-gray-900 mt-1">{formatCurrency(amount)}</p>
                    </div>
                  {/each}
                </div>

                <h4 class="text-sm font-semibold text-gray-700 mb-3">Daftar Tagihan</h4>
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead><tr class="table-header">
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Deskripsi</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tipe</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Jumlah</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                    </tr></thead>
                    <tbody class="divide-y divide-gray-100">
                      {#each treatmentBills as bill, i}
                        <tr class="hover:bg-gray-50">
                          <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                          <td class="table-cell font-medium text-gray-900">{bill.description}</td>
                          <td class="table-cell"><span class="badge badge-gray">{bill.tariff_type}</span></td>
                          <td class="table-cell text-right font-semibold text-gray-900">{formatCurrency(bill.amount)}</td>
                          <td class="table-cell text-right">
                            <button class="text-gray-400 hover:text-red-500 transition-colors" onclick={() => removeBill(bill.id)}>
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" /></svg>
                            </button>
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                    <tfoot>
                      <tr class="border-t-2 border-gray-300">
                        <td colspan="3" class="px-4 py-3 text-sm font-bold text-gray-900 text-right">Total</td>
                        <td class="px-4 py-3 text-sm font-bold text-primary-700 text-right">{formatCurrency(totalBill)}</td>
                        <td class="table-cell"></td>
                      </tr>
                    </tfoot>
                  </table>
                </div>
              </div>
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Belum ada tagihan</p>
            {/if}
          </div>

        {:else if activeTab === 'visite'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Visite Dokter</h3>

            <div class="border border-gray-200 rounded-lg p-4 space-y-4">
              <h4 class="text-sm font-semibold text-gray-700">Catat Visite</h4>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-1">
                  <label class="label">Nama Dokter</label>
                  <input type="text" class="input-field" bind:value={newDoctorVisit.doctor_name} placeholder="Dr. ..." />
                </div>
                <div class="space-y-1">
                  <label class="label">Tipe Visite</label>
                  <select class="select-field" bind:value={newDoctorVisit.visit_type}>
                    <option value="visite">Visite Rutin</option>
                    <option value="konsul">Konsultasi</option>
                    <option value="darurat">Darurat</option>
                  </select>
                </div>
              </div>
              <div class="space-y-1">
                <label class="label">Catatan</label>
                <textarea class="input-field h-24 resize-none text-sm" bind:value={newDoctorVisit.notes} placeholder="Catatan visite dokter..."></textarea>
              </div>
              <div class="flex justify-end">
                <button class="btn-primary" onclick={saveDoctorVisit} disabled={saving || !newDoctorVisit.notes.trim()}>
                  {#if saving}<span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>{/if}
                  Simpan Visite
                </button>
              </div>
            </div>

            {#if doctorVisits.length > 0}
              <div class="space-y-3">
                {#each doctorVisits as dv}
                  <div class="border border-gray-200 rounded-lg overflow-hidden">
                    <div class="bg-gray-50 px-4 py-2 border-b border-gray-200 flex items-center justify-between">
                      <div class="flex items-center gap-3">
                        <span class="badge {dv.visit_type === 'darurat' ? 'badge-danger' : dv.visit_type === 'konsul' ? 'badge-info' : 'badge-success'}">{dv.visit_type === 'darurat' ? 'Darurat' : dv.visit_type === 'konsul' ? 'Konsultasi' : 'Visite'}</span>
                        <span class="text-xs text-gray-500 font-mono">{formatDateTime(dv.visit_date)}</span>
                      </div>
                      <span class="text-sm font-semibold text-gray-700">{dv.doctor_name}</span>
                    </div>
                    <div class="p-4">
                      <p class="text-sm text-gray-700">{dv.notes || '-'}</p>
                    </div>
                  </div>
                {/each}
              </div>
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Belum ada catatan visite dokter</p>
            {/if}
          </div>

        {:else if activeTab === 'konsulen'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Konsulen / Rujukan Spesialis</h3>

            <div class="border border-gray-200 rounded-lg p-4 space-y-4">
              <h4 class="text-sm font-semibold text-gray-700">Ajukan Konsultasi</h4>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-1">
                  <label class="label">Spesialis</label>
                  <input type="text" class="input-field" bind:value={newConsultation.specialist} placeholder="Sp. Jantung, Sp. Syaraf..." />
                </div>
                <div class="space-y-1">
                  <label class="label">Tingkat Urgensi</label>
                  <select class="select-field" bind:value={newConsultation.urgency}>
                    <option value="normal">Normal</option>
                    <option value="urgent">Urgent</option>
                    <option value="emergensi">Emergensi</option>
                  </select>
                </div>
              </div>
              <div class="space-y-1">
                <label class="label">Alasan Konsultasi</label>
                <textarea class="input-field h-24 resize-none text-sm" bind:value={newConsultation.reason} placeholder="Alasan rujukan ke spesialis..."></textarea>
              </div>
              <div class="flex justify-end">
                <button class="btn-primary" onclick={saveConsultation} disabled={saving || !newConsultation.specialist.trim() || !newConsultation.reason.trim()}>
                  {#if saving}<span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>{/if}
                  Ajukan Konsultasi
                </button>
              </div>
            </div>

            {#if consultations.length > 0}
              <div class="space-y-3">
                {#each consultations as cons}
                  <div class="border border-gray-200 rounded-lg px-4 py-3 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                    <div class="flex-1">
                      <div class="flex items-center gap-2 mb-1">
                        <span class="badge {cons.urgency === 'emergensi' ? 'badge-danger' : cons.urgency === 'urgent' ? 'badge-warning' : 'badge-info'}">{cons.urgency === 'emergensi' ? 'Emergensi' : cons.urgency === 'urgent' ? 'Urgent' : 'Normal'}</span>
                        <span class="text-xs text-gray-500 font-mono">{formatDateTime(cons.created_at)}</span>
                      </div>
                      <p class="font-semibold text-gray-900">{cons.specialist}</p>
                      <p class="text-sm text-gray-600 mt-1">{cons.reason}</p>
                    </div>
                    <div class="flex items-center gap-2">
                      <span class="badge {cons.status === 'completed' ? 'badge-success' : cons.status === 'in_progress' ? 'badge-warning' : 'badge-gray'}">
                        {cons.status === 'completed' ? 'Selesai' : cons.status === 'in_progress' ? 'Dikerjakan' : 'Menunggu'}
                      </span>
                      {#if cons.status === 'pending'}
                        <button class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded hover:bg-blue-200" onclick={() => updateConsultationStatus(cons.id, 'in_progress')}>Proses</button>
                      {/if}
                      {#if cons.status === 'in_progress'}
                        <button class="text-xs bg-emerald-100 text-emerald-700 px-2 py-1 rounded hover:bg-emerald-200" onclick={() => updateConsultationStatus(cons.id, 'completed')}>Selesai</button>
                      {/if}
                    </div>
                  </div>
                {/each}
              </div>
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Belum ada permintaan konsultasi</p>
            {/if}
          </div>

        {:else if activeTab === 'kamar'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Mutasi / Pindah Kamar</h3>

            {#if !visit.discharge_date}
              <div class="border border-gray-200 rounded-lg p-4 space-y-4">
                <h4 class="text-sm font-semibold text-gray-700">Pindah Kamar</h4>
                <div class="bg-gray-50 rounded-lg p-3 text-sm text-gray-600">
                  Saat ini: <strong class="text-gray-900">{room?.name || '-'} ({room?.class || '-'})</strong> - Bed: <strong class="text-gray-900">{bed?.bed_no || '-'}</strong>
                </div>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="space-y-1">
                    <label class="label">Ke Kamar</label>
                    <select class="select-field" bind:value={newTransfer.to_room_id} onchange={() => fetchBeds(newTransfer.to_room_id)}>
                      <option value="">Pilih kamar...</option>
                      {#each availableRooms as r}
                        <option value={r.room_id}>{r.name} ({r.class})</option>
                      {/each}
                    </select>
                  </div>
                  <div class="space-y-1">
                    <label class="label">Ke Bed (opsional)</label>
                    <select class="select-field" bind:value={newTransfer.to_bed_id}>
                      <option value="">Pilih bed...</option>
                      {#each availableBeds as b}
                        <option value={b.bed_id}>{b.bed_no}</option>
                      {/each}
                    </select>
                  </div>
                </div>
                <div class="space-y-1">
                  <label class="label">Alasan Pindah</label>
                  <textarea class="input-field h-20 resize-none text-sm" bind:value={newTransfer.reason} placeholder="Alasan mutasi kamar..."></textarea>
                </div>
                <div class="flex justify-end">
                  <button class="btn-primary" onclick={saveRoomTransfer} disabled={saving || !newTransfer.to_room_id || !newTransfer.reason.trim()}>
                    {#if saving}<span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>{/if}
                    Pindahkan
                  </button>
                </div>
              </div>
            {:else}
              <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-center">
                <p class="text-sm text-blue-700">Pasien sudah melakukan discharge. Mutasi kamar tidak tersedia.</p>
              </div>
            {/if}

            {#if roomTransfers.length > 0}
              <div>
                <h4 class="text-sm font-semibold text-gray-700 mb-3">Riwayat Mutasi</h4>
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead><tr class="table-header">
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tanggal</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Dari</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Ke</th>
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Alasan</th>
                    </tr></thead>
                    <tbody class="divide-y divide-gray-100">
                      {#each roomTransfers as tf, i}
                        <tr class="hover:bg-gray-50">
                          <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                          <td class="table-cell text-gray-500 font-mono text-xs">{formatDateTime(tf.transfer_date)}</td>
                          <td class="table-cell text-gray-600">{tf.from_room_name || '-'}</td>
                          <td class="table-cell text-gray-600">{tf.to_room_name || '-'}</td>
                          <td class="table-cell text-gray-600 max-w-xs truncate">{tf.reason}</td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Belum ada riwayat mutasi kamar</p>
            {/if}
          </div>

        {:else if activeTab === 'pulang'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Formulir Pulang (Discharge)</h3>

            {#if visit.discharge_date}
              <div class="bg-blue-50 border border-blue-200 rounded-xl p-5">
                <div class="flex items-center gap-2 mb-3">
                  <svg class="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                  </svg>
                  <h4 class="font-semibold text-blue-800">Pasien Sudah Pulang</h4>
                </div>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                  <div><span class="text-blue-600">Tgl Pulang:</span> <strong>{formatDateTime(visit.discharge_date)}</strong></div>
                  <div><span class="text-blue-600">Kondisi:</span> <strong>{DISCHARGE_CONDITIONS[visit.discharge_condition] || '-'}</strong></div>
                  <div class="md:col-span-2"><span class="text-blue-600">Diagnosis Akhir:</span> <strong>{visit.final_diagnosis || '-'}</strong></div>
                  <div class="md:col-span-2"><span class="text-blue-600">Ringkasan:</span> <p class="mt-1">{visit.treatment_summary || '-'}</p></div>
                  <div class="md:col-span-2"><span class="text-blue-600">Obat Pulang:</span> <p class="mt-1">{visit.discharge_medications || '-'}</p></div>
                </div>
              </div>
            {:else}
              <div class="border border-gray-200 rounded-lg p-4 space-y-4">
                <div class="bg-amber-50 border border-amber-200 rounded-lg p-3">
                  <div class="flex items-start gap-2">
                    <svg class="w-5 h-5 text-amber-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
                    </svg>
                    <p class="text-sm text-amber-700">Pastikan semua tagihan dan dokumen sudah lengkap sebelum melakukan discharge.</p>
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="space-y-1">
                    <label class="label">Kondisi Pulang</label>
                    <select class="select-field" bind:value={dischargeForm.condition}>
                      <option value="semuh">Sembuh</option>
                      <option value="berobat_jalan">Berobat Jalan</option>
                      <option value="rujuk">Rujuk</option>
                      <option value="meninggal">Meninggal</option>
                      <option value="lainnya">Lainnya</option>
                    </select>
                  </div>
                  <div class="space-y-1">
                    <label class="label">Total Tagihan</label>
                    <div class="input-field bg-gray-50 font-bold text-primary-700">{formatCurrency(totalBill)}</div>
                  </div>
                </div>

                <div class="space-y-1">
                  <label class="label">Diagnosis Akhir *</label>
                  <textarea class="input-field h-20 resize-none text-sm" bind:value={dischargeForm.final_diagnosis} placeholder="Diagnosis final saat pasien pulang..."></textarea>
                </div>

                <div class="space-y-1">
                  <label class="label">Ringkasan Perawatan</label>
                  <textarea class="input-field h-28 resize-none text-sm" bind:value={dischargeForm.treatment_summary} placeholder="Ringkasan selama perawatan di rumah sakit..."></textarea>
                </div>

                <div class="space-y-1">
                  <label class="label">Obat Pulang</label>
                  <textarea class="input-field h-24 resize-none text-sm" bind:value={dischargeForm.discharge_medications} placeholder="Daftar obat yang harus dikonsumsi pasca pulang..."></textarea>
                </div>

                <div class="space-y-1">
                  <label class="label">Catatan Tambahan</label>
                  <textarea class="input-field h-20 resize-none text-sm" bind:value={dischargeForm.notes} placeholder="Catatan lainnya untuk pasien..."></textarea>
                </div>

                <div class="flex justify-end">
                  <button class="btn-primary bg-red-600 hover:bg-red-700" onclick={processDischarge} disabled={saving || !dischargeForm.final_diagnosis.trim()}>
                    {#if saving}<span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>{/if}
                    <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15m3 0 3-3m0 0-3-3m3 3H9" />
                    </svg>
                    Proses Pulang
                  </button>
                </div>
              </div>
            {/if}
          </div>

        {:else if activeTab === 'cetak'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Cetak Dokumen</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <button class="card hover:shadow-md transition-shadow text-left group" onclick={printResume}>
                <div class="flex items-center gap-4">
                  <div class="shrink-0 w-12 h-12 rounded-xl bg-blue-100 flex items-center justify-center group-hover:bg-blue-200 transition-colors">
                    <svg class="w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
                    </svg>
                  </div>
                  <div>
                    <p class="font-semibold text-gray-900">Resume Medis</p>
                    <p class="text-sm text-gray-500">Ringkasan rawat inap pasien</p>
                  </div>
                </div>
              </button>

              <button class="card hover:shadow-md transition-shadow text-left group" onclick={printBilling}>
                <div class="flex items-center gap-4">
                  <div class="shrink-0 w-12 h-12 rounded-xl bg-emerald-100 flex items-center justify-center group-hover:bg-emerald-200 transition-colors">
                    <svg class="w-6 h-6 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
                    </svg>
                  </div>
                  <div>
                    <p class="font-semibold text-gray-900">Ringkasan Billing</p>
                    <p class="text-sm text-gray-500">Cetak rincian tagihan</p>
                  </div>
                </div>
              </button>

              <button class="card hover:shadow-md transition-shadow text-left group" onclick={printResume}>
                <div class="flex items-center gap-4">
                  <div class="shrink-0 w-12 h-12 rounded-xl bg-purple-100 flex items-center justify-center group-hover:bg-purple-200 transition-colors">
                    <svg class="w-6 h-6 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" />
                    </svg>
                  </div>
                  <div>
                    <p class="font-semibold text-gray-900">Resep Obat</p>
                    <p class="text-sm text-gray-500">Cetak resep untuk farmasi</p>
                  </div>
                </div>
              </button>

              <button class="card hover:shadow-md transition-shadow text-left group" onclick={printResume}>
                <div class="flex items-center gap-4">
                  <div class="shrink-0 w-12 h-12 rounded-xl bg-amber-100 flex items-center justify-center group-hover:bg-amber-200 transition-colors">
                    <svg class="w-6 h-6 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0 1 10.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0 .229 2.523a1.125 1.125 0 0 1-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0 0 21 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 0 0-1.913-.247M6.34 18H5.25A2.25 2.25 0 0 1 3 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 0 1 1.913-.247m10.5 0a48.536 48.536 0 0 0-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659" />
                    </svg>
                  </div>
                  <div>
                    <p class="font-semibold text-gray-900">Surat Keterangan</p>
                    <p class="text-sm text-gray-500">Cetak surat keterangan dokter</p>
                  </div>
                </div>
              </button>

              <button class="card hover:shadow-md transition-shadow text-left group" onclick={printResume}>
                <div class="flex items-center gap-4">
                  <div class="shrink-0 w-12 h-12 rounded-xl bg-red-100 flex items-center justify-center group-hover:bg-red-200 transition-colors">
                    <svg class="w-6 h-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
                    </svg>
                  </div>
                  <div>
                    <p class="font-semibold text-gray-900">Surat Rujukan</p>
                    <p class="text-sm text-gray-500">Cetak surat rujukan ke RS lain</p>
                  </div>
                </div>
              </button>

              <button class="card hover:shadow-md transition-shadow text-left group" onclick={printResume}>
                <div class="flex items-center gap-4">
                  <div class="shrink-0 w-12 h-12 rounded-xl bg-teal-100 flex items-center justify-center group-hover:bg-teal-200 transition-colors">
                    <svg class="w-6 h-6 text-teal-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0 1 10.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0 .229 2.523a1.125 1.125 0 0 1-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0 0 21 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 0 0-1.913-.247M6.34 18H5.25A2.25 2.25 0 0 1 3 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 0 1 1.913-.247m10.5 0a48.536 48.536 0 0 0-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659" />
                    </svg>
                  </div>
                  <div>
                    <p class="font-semibold text-gray-900">Surat Kematian</p>
                    <p class="text-sm text-gray-500">Cetak surat keterangan kematian</p>
                  </div>
                </div>
              </button>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}
