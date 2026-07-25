<script>
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatCurrency, formatDate, formatDateTime } from '$lib/utils/helpers.js';
  import { PAYOR_TYPES } from '$lib/utils/constants.js';

  let visitId = $derived(page.params.visitId);
  let loading = $state(true);
  let saving = $state(false);
  let activeTab = $state('asessment');

  let visit = $state(null);
  let patient = $state(null);
  let clinic = $state(null);
  let doctor = $state(null);

  let cpptList = $state([]);
  let diagnoses = $state([]);
  let labOrders = $state([]);
  let radiologyOrders = $state([]);
  let prescriptions = $state([]);
  let treatmentBills = $state([]);

  let assessment = $state({
    subjective: '',
    objective: '',
    sistolik: '',
    diastolik: '',
    suhu: '',
    nadi: '',
    rr: '',
    gcs: '',
    tb: '',
    bb: '',
    spo2: ''
  });

  let newCppt = $state({
    subyektif: '',
    obyektif: '',
    assessment: '',
    planning: '',
    instruksi: ''
  });

  let diagnosisSearch = $state('');
  let diagnosisResults = $state([]);
  let searchDiagTimeout;

  let labSearch = $state('');
  let labResults = $state([]);

  let radiologySearch = $state('');
  let radiologyResults = $state([]);

  let drugSearch = $state('');
  let drugResults = $state([]);
  let newPrescription = $state({
    drug_id: '',
    drug_name: '',
    qty: '',
    dosage: '',
    frequency: '',
    instruction: ''
  });

  let tariffSearch = $state('');
  let tariffResults = $state([]);
  let newBill = $state({
    description: '',
    tariff_type: 'Konsultasi',
    amount: ''
  });

  const totalBill = $derived(
    treatmentBills.reduce((sum, b) => sum + (b.amount || 0), 0)
  );

  const tabs = [
    { id: 'asessment', label: 'Asessment', icon: 'clipboard-check' },
    { id: 'cppt', label: 'CPPT/SOAP', icon: 'file-text' },
    { id: 'diagnosis', label: 'Diagnosis', icon: 'activity' },
    { id: 'lab', label: 'Laboratorium', icon: 'flask-conical' },
    { id: 'radiologi', label: 'Radiologi', icon: 'scan' },
    { id: 'resep', label: 'Resep', icon: 'pill' },
    { id: 'billing', label: 'Billing/Tarif', icon: 'receipt' },
    { id: 'cetak', label: 'Cetak', icon: 'printer' }
  ];

  async function fetchVisitData() {
    try {
      const { data: visitData, error: visitErr } = await supabase
        .from('patient_visitations')
        .select(`
          *,
          patients:patient_id ( patient_id, full_name, no_registration, date_of_birth, gender, phone, address ),
          clinics:clinic_id ( clinic_id, name ),
          employees:doctor_id ( employee_id, full_name ) 
        `) // REVISI: Menggunakan tabel employees, employee_id, dan fullname
        .eq('visit_id', visitId)
        .maybeSingle();

      if (visitErr) throw visitErr;

      visit = visitData;
      patient = visitData.patients;
      clinic = visitData.clinics;
      
      // REVISI: Mengambil dari properti employees hasil join di atas
      doctor = visitData.employees; 

      if (patient?.date_of_birth) {
        const birth = new Date(patient.date_of_birth);
        const today = new Date();
        let age = today.getFullYear() - birth.getFullYear();
        const m = today.getMonth() - birth.getMonth();
        if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--;
        patient.age = age;
      }

      const { data: assessmentData, error: assessmentErr } = await supabase
        .from('assessments')
        .select('assessment_id, subjective, objective, sistolik, diastolik, suhu, nadi, rr, gcs, tb, bb, spo2')
        .eq('visit_id', visitId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (assessmentErr) throw assessmentErr;

      if (assessmentData) {
        visit = { ...visitData, assessment_id: assessmentData.assessment_id };
        assessment.subjective = assessmentData.subjective || '';
        assessment.objective = assessmentData.objective || '';
        assessment.sistolik = assessmentData.sistolik || '';
        assessment.diastolik = assessmentData.diastolik || '';
        assessment.suhu = assessmentData.suhu || '';
        assessment.nadi = assessmentData.nadi || '';
        assessment.rr = assessmentData.rr || '';
        assessment.gcs = assessmentData.gcs || '';
        assessment.tb = assessmentData.tb || '';
        assessment.bb = assessmentData.bb || '';
        assessment.spo2 = assessmentData.spo2 || '';
      }
    } catch (err) {
      console.error('Fetch visit error:', err);
    }
  }

  async function fetchCppt() {
    try {
      const { data, error } = await supabase
        .from('cppt')
        .select('*')
        .eq('visit_id', visitId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      cpptList = data || [];
    } catch (err) {
      console.error('Fetch CPPT error:', err);
    }
  }

  async function fetchDiagnoses() {
    try {
      const { data, error } = await supabase
        .from('patient_diagnoses')
        .select('id, visit_id, diagnosis_id, diagnosis_type, diagnoses:diagnosis_id ( code, name )')
        .eq('visit_id', visitId);

      if (error) throw error;
      diagnoses = (data || []).map((diag) => ({
        id: diag.id,
        visit_id: diag.visit_id,
        diagnosis_id: diag.diagnosis_id,
        diagnosis_type: diag.diagnosis_type,
        icd_code: (Array.isArray(diag.diagnoses) ? diag.diagnoses[0] : diag.diagnoses)?.code || '-',
        icd_name: (Array.isArray(diag.diagnoses) ? diag.diagnoses[0] : diag.diagnoses)?.name || '-'
      }));
    } catch (err) {
      console.error('Fetch diagnoses error:', err);
    }
  }

  async function fetchLabOrders() {
    try {
      const { data, error } = await supabase
        .from('lab_orders')
        .select('*')
        .eq('visit_id', visitId)
        .order('created_by', { ascending: false });

      if (error) throw error;
      labOrders = data || [];
    } catch (err) {
      console.error('Fetch lab orders error:', err);
    }
  }

  async function fetchRadiologyOrders() {
    try {
      const { data, error } = await supabase
        .from('radiology_orders')
        .select('*')
        .eq('visit_id', visitId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      radiologyOrders = data || [];
    } catch (err) {
      console.error('Fetch radiology orders error:', err);
    }
  }

  async function fetchPrescriptions() {
    try {
      const { data, error } = await supabase
        .from('prescriptions')
        .select('*')
        .eq('visit_id', visitId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      prescriptions = data || [];
    } catch (err) {
      console.error('Fetch prescriptions error:', err);
    }
  }

  async function fetchBills() {
    try {
      const { data, error } = await supabase
        .from('treatment_bills')
        .select('*')
        .eq('visit_id', visitId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      treatmentBills = data || [];
    } catch (err) {
      console.error('Fetch bills error:', err);
    }
  }
  
async function saveAssessment() {
  // Pastikan variabel visitId dan data assessment valid sebelum menembak API
  if (!visitId) {
    console.error('Save assessment error: visitId is required');
    alert('Gagal menyimpan: ID Kunjungan tidak ditemukan.');
    return;
  }

  saving = true;
  try {
    if (visit?.assessment_id) {
      // PROSES UPDATE
      const { error } = await supabase
        .from('assessments')
        .update({
          subjective: assessment.subjective || null,
          objective: assessment.objective || null,
          sistolik: assessment.sistolik ? Number(assessment.sistolik) : null,
          diastolik: assessment.diastolik ? Number(assessment.diastolik) : null,
          suhu: assessment.suhu ? Number(assessment.suhu) : null,
          nadi: assessment.nadi ? Number(assessment.nadi) : null,
          rr: assessment.rr ? Number(assessment.rr) : null,
          gcs: assessment.gcs ? Number(assessment.gcs) : null,
          tb: assessment.tb ? Number(assessment.tb) : null,
          bb: assessment.bb ? Number(assessment.bb) : null,
          spo2: assessment.spo2 ? Number(assessment.spo2) : null
        })
        .eq('assessment_id', visit.assessment_id);

      if (error) throw error;
      alert('Asesmen berhasil diperbarui!');
    } else {
      // PROSES INSERT
      const { data, error } = await supabase
        .from('assessments')
        .insert({
          visit_id: visitId,
          subjective: assessment.subjective || null,
          objective: assessment.objective || null,
          sistolik: assessment.sistolik ? Number(assessment.sistolik) : null,
          diastolik: assessment.diastolik ? Number(assessment.diastolik) : null,
          suhu: assessment.suhu ? Number(assessment.suhu) : null,
          nadi: assessment.nadi ? Number(assessment.nadi) : null,
          rr: assessment.rr ? Number(assessment.rr) : null,
          gcs: assessment.gcs ? Number(assessment.gcs) : null,
          tb: assessment.tb ? Number(assessment.tb) : null,
          bb: assessment.bb ? Number(assessment.bb) : null,
          spo2: assessment.spo2 ? Number(assessment.spo2) : null
        })
        .select()
        .single();

      if (error) throw error;
      
      if (data?.assessment_id) {
        // Amankan penulisan objek untuk memicu reaktivitas Svelte
        visit = { ...visit, assessment_id: data.assessment_id };
        alert('Asesmen baru berhasil disimpan!');
      }
    }
  } catch (err) {
    console.error('Save assessment error:', err);
    alert(`Gagal menyimpan data: ${err.message || err}`);
  } finally {
    saving = false;
  }
}

  async function saveCppt() {
    if (!newCppt.subyektif.trim() && !newCppt.obyektif.trim()) return;
    saving = true;
    try {
      const { error } = await supabase
        .from('cppt')
        .insert({
          visit_id: visitId,
          subyektif: newCppt.subyektif,
          obyektif: newCppt.obyektif,
          assessment: newCppt.assessment,
          planning: newCppt.planning,
          instruksi: newCppt.instruksi
        });

      if (error) throw error;
      newCppt = { subyektif: '', obyektif: '', assessment: '', planning: '', instruksi: '' };
      await fetchCppt();
    } catch (err) {
      console.error('Save CPPT error:', err);
    } finally {
      saving = false;
    }
  }

  async function searchDiagnosis() {
    if (diagnosisSearch.length < 2) { diagnosisResults = []; return; }
    clearTimeout(searchDiagTimeout);
    searchDiagTimeout = setTimeout(async () => {
      try {
        const { data, error } = await supabase
          .from('diagnoses')
          .select('diagnosis_id, code, name')
          .eq('is_active', true)
          .or(`code.ilike.%${diagnosisSearch}%,name.ilike.%${diagnosisSearch}%`)
          .limit(10);

        if (error) throw error;
        diagnosisResults = data || [];
      } catch (err) {
        console.error('Search ICD error:', err);
      }
    }, 300);
  }

  async function addDiagnosis(diagnosisId, type = 'primer') {
    try {
      if (!diagnosisId) return;

      let validId = diagnosisId;
      if (!validId.startsWith('DX-')) {
        validId = `DX-${validId.toUpperCase()}`;
      }

      const exists = diagnoses.find(d => d.diagnosis_id === validId);
      if (exists) return;

      const { error } = await supabase
        .from('patient_diagnoses')
        .insert({
          visit_id: visitId,
          diagnosis_id: validId, // Mengirimkan ID yang sudah valid (Contoh: DX-A09)
          diagnosis_type: type
        });

      if (error) throw error;

      await fetchDiagnoses();
      diagnosisSearch = '';
      diagnosisResults = [];
    } catch (err) {
      console.error('Add diagnosis error:', err);
    }
  }

  async function removeDiagnosis(id) {
    try {
      const { error } = await supabase
        .from('patient_diagnoses')
        .delete()
        .eq('id', id);

      if (error) throw error;
      await fetchDiagnoses();
    } catch (err) {
      console.error('Remove diagnosis error:', err);
    }
  }
  
  async function searchDrugs() {
    if (drugSearch.length < 2) { drugResults = []; return; }
    try {
      const { data, error } = await supabase
        .from('drugs')
        .select('drug_id, name, unit, category')
        .ilike('name', `%${drugSearch}%`)
        .eq('is_active', true)
        .limit(10);

      if (error) throw error;
      drugResults = data || [];
    } catch (err) {
      console.error('Search drugs error:', err);
    }
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
      const { error } = await supabase
        .from('prescriptions')
        .insert({
          visit_id: visitId,
          drug_id: newPrescription.drug_id,
          drug_name: newPrescription.drug_name,
          qty: Number(newPrescription.qty),
          dosage: newPrescription.dosage,
          frequency: newPrescription.frequency,
          instruction: newPrescription.instruction
        });

      if (error) throw error;
      newPrescription = { drug_id: '', drug_name: '', qty: '', dosage: '', frequency: '', instruction: '' };
      await fetchPrescriptions();
    } catch (err) {
      console.error('Save prescription error:', err);
    } finally {
      saving = false;
    }
  }

  async function removePrescription(id) {
    try {
      const { error } = await supabase
        .from('prescriptions')
        .delete()
        .eq('id', id);

      if (error) throw error;
      await fetchPrescriptions();
    } catch (err) {
      console.error('Remove prescription error:', err);
    }
  }

  async function searchTariffs() {
    if (tariffSearch.length < 2) { tariffResults = []; return; }
    try {
      const { data, error } = await supabase
        .from('tariffs')
        .select('tariff_id, name, category, price')
        .ilike('name', `%${tariffSearch}%`)
        .limit(10);

      if (error) throw error;
      tariffResults = data || [];
    } catch (err) {
      console.error('Search tariffs error:', err);
    }
  }

  async function addBill(tariff) {
    try {
      const { error } = await supabase
        .from('treatment_bills')
        .insert({
          visit_id: visitId,
          tariff_id: tariff.tariff_id,
          description: tariff.name,
          tariff_type: tariff.category,
          amount: tariff.price
        });

      if (error) throw error;
      tariffSearch = '';
      tariffResults = [];
      await fetchBills();
    } catch (err) {
      console.error('Add bill error:', err);
    }
  }

  async function addCustomBill() {
    if (!newBill.description.trim() || !newBill.amount) return;
    saving = true;
    try {
      const { error } = await supabase
        .from('treatment_bills')
        .insert({
          visit_id: visitId,
          description: newBill.description,
          tariff_type: newBill.tariff_type,
          amount: Number(newBill.amount)
        });

      if (error) throw error;
      newBill = { description: '', tariff_type: 'Konsultasi', amount: '' };
      await fetchBills();
    } catch (err) {
      console.error('Add custom bill error:', err);
    } finally {
      saving = false;
    }
  }

  async function removeBill(id) {
    try {
      const { error } = await supabase
        .from('treatment_bills')
        .delete()
        .eq('id', id);

      if (error) throw error;
      await fetchBills();
    } catch (err) {
      console.error('Remove bill error:', err);
    }
  }

  async function orderLab(testName, category) {
    try {
      const { error } = await supabase
        .from('lab_orders')
        .insert({
          visit_id: visitId,
          test_name: testName,
          category: category,
          status: 'ordered'
        });

      if (error) throw error;
      await fetchLabOrders();
    } catch (err) {
      console.error('Order lab error:', err);
    }
  }

  async function searchLabTests() {
    if (labSearch.length < 2) { labResults = []; return; }
    try {
      const { data, error } = await supabase
        .from('lab_test_catalog')
        .select('test_id, test_name, category, price')
        .ilike('test_name', `%${labSearch}%`)
        .limit(10);

      if (error) throw error;
      labResults = data || [];
    } catch (err) {
      console.error('Search lab tests error:', err);
    }
  }

  async function orderRadiology(examType, description) {
    try {
      const { error } = await supabase
        .from('radiology_orders')
        .insert({
          visit_id: visitId,
          examination_type: examType,
          clinical_info: description,
          exam_type: examType,
          description: description,
          status: 'ordered'
        });

      if (error) throw error;
      await fetchRadiologyOrders();
    } catch (err) {
      console.error('Order radiology error:', err);
    }
  }

  async function searchRadiologyTests() {
    if (radiologySearch.length < 2) { radiologyResults = []; return; }
    try {
      const { data, error } = await supabase
        .from('radiology_catalog')
        .select('exam_id, exam_type, description, price')
        .ilike('exam_type', `%${radiologySearch}%`)
        .limit(10);

      if (error) throw error;
      radiologyResults = data || [];
    } catch (err) {
      console.error('Search radiology tests error:', err);
    }
  }

  function printPrescription() {
    window.print();
  }

  function printReceipt() {
    window.print();
  }

  function printCppt() {
    window.print();
  }

  function goBack() {
    goto('/rawat-jalan');
  }

  onMount(async () => {
    loading = true;
    await fetchVisitData();
    await Promise.all([
      fetchCppt(),
      fetchDiagnoses(),
      fetchLabOrders(),
      fetchRadiologyOrders(),
      fetchPrescriptions(),
      fetchBills()
    ]);
    loading = false;
  });
</script>

<svelte:head>
  <title>{patient?.full_name || 'Pasien'} - Pemeriksaan Rawat Jalan</title>
</svelte:head>

{#if loading}
  <div class="flex items-center justify-center py-24">
    <div class="flex flex-col items-center gap-4">
      <div class="w-12 h-12 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
      <p class="text-sm text-gray-500 font-medium">Memuat data kunjungan...</p>
    </div>
  </div>
{:else if !visit}
  <div class="card text-center py-16">
    <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
    </svg>
    <p class="text-lg font-medium text-gray-700">Kunjungan tidak ditemukan</p>
    <button class="btn-primary mt-4" onclick={goBack}>Kembali ke Antrian</button>
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
      <h1 class="text-xl font-bold text-gray-900">Pemeriksaan Pasien</h1>
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
            <p class="text-xs text-gray-500">Poli</p>
            <p class="font-semibold text-gray-900">{clinic?.name || '-'}</p>
          </div>
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">Dokter</p>
            <p class="font-semibold text-gray-900">{doctor?.full_name || '-'}</p>
          </div>
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">Tipe</p>
            <p class="font-semibold text-gray-900">{PAYOR_TYPES[visit?.payor_type] || visit?.payor_type || '-'}</p>
          </div>
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">No. Tiket</p>
            <p class="font-semibold text-primary-600 font-mono">{visit?.ticket_no || '-'}</p>
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
            {#if tab.icon === 'clipboard-check'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg>
            {:else if tab.icon === 'file-text'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" /></svg>
            {:else if tab.icon === 'activity'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 0 0 6 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0 1 18 16.5h-2.25m-7.5 0h7.5m-7.5 0-1 3m8.5-3 1 3m0 0 .5 1.5m-.5-1.5h-9.5m0 0-.5 1.5" /></svg>
            {:else if tab.icon === 'flask-conical'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" /></svg>
            {:else if tab.icon === 'scan'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0 1 3.75 9.375v-4.5ZM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 0 1-1.125-1.125v-4.5ZM13.5 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0 1 13.5 9.375v-4.5Z" /><path stroke-linecap="round" stroke-linejoin="round" d="M6.75 6.75h.75v.75h-.75v-.75ZM6.75 16.5h.75v.75h-.75v-.75ZM16.5 6.75h.75v.75h-.75v-.75ZM13.5 13.5h.75v.75h-.75v-.75ZM13.5 19.5h.75v.75h-.75v-.75ZM19.5 13.5h.75v.75h-.75v-.75ZM19.5 19.5h.75v.75h-.75v-.75ZM16.5 16.5h.75v.75h-.75v-.75Z" /></svg>
            {:else if tab.icon === 'pill'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5" /></svg>
            {:else if tab.icon === 'receipt'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" /></svg>
            {:else if tab.icon === 'printer'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0 1 10.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0 .229 2.523a1.125 1.125 0 0 1-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0 0 21 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 0 0-1.913-.247M6.34 18H5.25A2.25 2.25 0 0 1 3 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 0 1 1.913-.247m10.5 0a48.536 48.536 0 0 0-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659" /></svg>
            {/if}
            {tab.label}
          </button>
        {/each}
      </div>

      <div class="p-6">
        {#if activeTab === 'asessment'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Asessment & Tanda Vital</h3>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="space-y-2">
                <p class="label">Subyektif</p>
                <textarea class="input-field h-28 resize-none" bind:value={assessment.subjective} placeholder="Keluhan utama, riwayat penyakit sekarang..."></textarea>
              </div>
              <div class="space-y-2">
                <p class="label">Obyektif</p>
                <textarea class="input-field h-28 resize-none" bind:value={assessment.objective} placeholder="Pemeriksaan fisik, temuan klinis..."></textarea>
              </div>
            </div>

            <div>
              <h4 class="text-sm font-semibold text-gray-700 uppercase tracking-wide mb-3">Tanda Vital</h4>
              <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-4">
                <div class="space-y-1">
                  <p class="label text-xs">Sistolik (mmHg)</p>
                  <input type="number" class="input-field" bind:value={assessment.sistolik} placeholder="120" />
                </div>
                <div class="space-y-1">
                  <p class="label text-xs">Diastolik (mmHg)</p>
                  <input type="number" class="input-field" bind:value={assessment.diastolik} placeholder="80" />
                </div>
                <div class="space-y-1">
                  <p class="label text-xs">Suhu (&deg;C)</p>
                  <input type="number" step="0.1" class="input-field" bind:value={assessment.suhu} placeholder="36.5" />
                </div>
                <div class="space-y-1">
                  <p class="label text-xs">Nadi (/mnt)</p>
                  <input type="number" class="input-field" bind:value={assessment.nadi} placeholder="80" />
                </div>
                <div class="space-y-1">
                  <p class="label text-xs">RR (/mnt)</p>
                  <input type="number" class="input-field" bind:value={assessment.rr} placeholder="20" />
                </div>
                <div class="space-y-1">
                  <p class="label text-xs">GCS</p>
                  <input type="number" class="input-field" bind:value={assessment.gcs} placeholder="15" />
                </div>
                <div class="space-y-1">
                  <p class="label text-xs">TB (cm)</p>
                  <input type="number" step="0.1" class="input-field" bind:value={assessment.tb} placeholder="165" />
                </div>
                <div class="space-y-1">
                  <p class="label text-xs">BB (kg)</p>
                  <input type="number" step="0.1" class="input-field" bind:value={assessment.bb} placeholder="65" />
                </div>
                <div class="space-y-1">
                  <p class="label text-xs">SpO2 (%)</p>
                  <input type="number" class="input-field" bind:value={assessment.spo2} placeholder="98" />
                </div>
              </div>
            </div>

            <div class="flex justify-end">
              <button class="btn-primary" onclick={saveAssessment} disabled={saving}>
                {#if saving}
                  <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
                {/if}
                Simpan Asessment
              </button>
            </div>
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
                  <p class="label">Subyektif</p>
                  <textarea class="input-field h-24 resize-none text-sm" bind:value={newCppt.subyektif} placeholder="Keluhan pasien..."></textarea>
                </div>
                <div class="space-y-1">
                  <p class="label">Obyektif</p>
                  <textarea class="input-field h-24 resize-none text-sm" bind:value={newCppt.obyektif} placeholder="Temuan pemeriksaan..."></textarea>
                </div>
                <div class="space-y-1">
                  <p class="label">Assessment</p>
                  <textarea class="input-field h-24 resize-none text-sm" bind:value={newCppt.assessment} placeholder="Diagnosis/penilaian..."></textarea>
                </div>
                <div class="space-y-1">
                  <p class="label">Planning</p>
                  <textarea class="input-field h-24 resize-none text-sm" bind:value={newCppt.planning} placeholder="Rencana tindak lanjut..."></textarea>
                </div>
              </div>
              <div class="space-y-1 mt-4">
                <p class="label">Instruksi (opsional)</p>
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
              <p class="label">Cari Kode ICD-10</p>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                </svg>
                <input
                  type="text"
                  class="input-field pl-10"
                  placeholder="Ketik kode atau nama penyakit..."
                  bind:value={diagnosisSearch}
                  oninput={searchDiagnosis}
                />
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
                        <button class="text-xs bg-red-100 text-red-700 px-2 py-1 rounded hover:bg-red-200" onclick={() => addDiagnosis(icd.diagnosis_id, 'primer')}>
                          Primer
                        </button>
                        <button class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded hover:bg-blue-200" onclick={() => addDiagnosis(icd.diagnosis_id, 'sekunder')}>
                          Sekunder
                        </button>
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
                        <span class="badge {diag.diagnosis_type === 'primer' ? 'badge-danger' : 'badge-info'}">
                          {diag.diagnosis_type === 'primer' ? 'Primer' : 'Sekunder'}
                        </span>
                        <div>
                          <span class="font-mono text-sm font-semibold text-gray-900">{diag.icd_code}</span>
                          <span class="text-sm text-gray-600 ml-2">{diag.icd_name}</span>
                        </div>
                      </div>
                      <button class="text-gray-400 hover:text-red-500 transition-colors" title="Hapus diagnosis" onclick={() => removeDiagnosis(diag.id)}>
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
                        </svg>
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
            <h3 class="text-lg font-semibold text-gray-900">Laboratorium</h3>

            <div class="space-y-2">
              <p class="label">Pesanan Tes Lab</p>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                </svg>
                <input
                  type="text"
                  class="input-field pl-10"
                  placeholder="Cari tes laboratorium..."
                  bind:value={labSearch}
                  oninput={searchLabTests}
                />
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
                      <button class="btn-success btn-sm text-xs" onclick={() => { orderLab(test.test_name, test.category); labSearch = ''; labResults = []; }}>
                        Pesan
                      </button>
                    </div>
                  {/each}
                </div>
              {/if}
            </div>

            {#if labOrders.length > 0}
              <div>
                <h4 class="text-sm font-semibold text-gray-700 mb-3">Riwayat Pesanan</h4>
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr class="table-header">
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Nama Tes</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Kategori</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Hasil</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100">
                      {#each labOrders as order, i}
                        <tr class="hover:bg-gray-50">
                          <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                          <td class="table-cell font-medium text-gray-900">{order.test_name}</td>
                          <td class="table-cell text-gray-600">{order.category}</td>
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
              </div>
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Belum ada pesanan lab</p>
            {/if}
          </div>

        {:else if activeTab === 'radiologi'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Radiologi</h3>

            <div class="space-y-2">
              <p class="label">Pesan Pemeriksaan Radiologi</p>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                </svg>
                <input
                  type="text"
                  class="input-field pl-10"
                  placeholder="Cari pemeriksaan radiologi..."
                  bind:value={radiologySearch}
                  oninput={searchRadiologyTests}
                />
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
                      <button class="btn-success btn-sm text-xs" onclick={() => { orderRadiology(exam.exam_type, exam.description); radiologySearch = ''; radiologyResults = []; }}>
                        Pesan
                      </button>
                    </div>
                  {/each}
                </div>
              {/if}
            </div>

            {#if radiologyOrders.length > 0}
              <div>
                <h4 class="text-sm font-semibold text-gray-700 mb-3">Riwayat Pesanan</h4>
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr class="table-header">
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Jenis Pemeriksaan</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Deskripsi</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Status</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Hasil</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100">
                      {#each radiologyOrders as order, i}
                        <tr class="hover:bg-gray-50">
                          <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                          <td class="table-cell font-medium text-gray-900">{order.exam_type}</td>
                          <td class="table-cell text-gray-600 hidden md:table-cell">{order.description || '-'}</td>
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
              </div>
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Belum ada pesanan radiologi</p>
            {/if}
          </div>

        {:else if activeTab === 'resep'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Resep Obat</h3>

            <div class="border border-gray-200 rounded-lg p-4 space-y-4">
              <h4 class="text-sm font-semibold text-gray-700">Tambah Resep</h4>

              <div class="space-y-2">
                <p class="label">Cari Obat</p>
                <div class="relative">
                  <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                  </svg>
                  <input
                    type="text"
                    class="input-field pl-10"
                    placeholder="Cari nama obat..."
                    bind:value={drugSearch}
                    oninput={searchDrugs}
                  />
                </div>
                {#if drugResults.length > 0}
                  <div class="border border-gray-200 rounded-lg divide-y divide-gray-100 max-h-48 overflow-y-auto">
                    {#each drugResults as drug}
                      <button
                        class="flex items-center justify-between w-full px-4 py-3 hover:bg-gray-50 text-left"
                        onclick={() => selectDrug(drug)}
                      >
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
                <div class="space-y-1">
                  <p class="label">Jumlah (Qty)</p>
                  <input type="number" class="input-field" bind:value={newPrescription.qty} placeholder="10" />
                </div>
                <div class="space-y-1">
                  <p class="label">Dosis</p>
                  <input type="text" class="input-field" bind:value={newPrescription.dosage} placeholder="500mg" />
                </div>
                <div class="space-y-1">
                  <p class="label">Frekuensi</p>
                  <select class="select-field" bind:value={newPrescription.frequency}>
                    <option value="">Pilih...</option>
                    <option value="1x1">1x1 sehari</option>
                    <option value="1x2">1x2 sehari</option>
                    <option value="1x3">1x3 sehari</option>
                    <option value="2x1">2x1 dua kali sehari</option>
                    <option value="3x1">3x1 tiga kali sehari</option>
                    <option value="PRN">Saat Diperlukan (PRN)</option>
                  </select>
                </div>
                <div class="space-y-1">
                  <p class="label">Instruksi</p>
                  <input type="text" class="input-field" bind:value={newPrescription.instruction} placeholder="Setelah makan" />
                </div>
              </div>

              <div class="flex justify-end">
                <button class="btn-primary" onclick={savePrescription} disabled={saving || !newPrescription.drug_id || !newPrescription.qty}>
                  {#if saving}
                    <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
                  {/if}
                  Tambah Resep
                </button>
              </div>
            </div>

            {#if prescriptions.length > 0}
              <div>
                <h4 class="text-sm font-semibold text-gray-700 mb-3">Daftar Resep</h4>
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr class="table-header">
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Obat</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Qty</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Dosis</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Frekuensi</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Instruksi</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                      </tr>
                    </thead>
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
                            <button class="text-gray-400 hover:text-red-500 transition-colors" title="Hapus resep" onclick={() => removePrescription(rx.id)}>
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
                              </svg>
                            </button>
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Belum ada resep</p>
            {/if}
          </div>

        {:else if activeTab === 'billing'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Billing / Tarif</h3>

            <div class="space-y-2">
              <p class="label">Tambah dari Daftar Tarif</p>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                </svg>
                <input
                  type="text"
                  class="input-field pl-10"
                  placeholder="Cari item tarif..."
                  bind:value={tariffSearch}
                  oninput={searchTariffs}
                />
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
                      <button class="btn-success btn-sm text-xs" onclick={() => addBill(tariff)}>
                        Tambah
                      </button>
                    </div>
                  {/each}
                </div>
              {/if}
            </div>

            <div class="border border-gray-200 rounded-lg p-4 space-y-4">
              <h4 class="text-sm font-semibold text-gray-700">Tambah Biaya Manual</h4>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="space-y-1 md:col-span-2">
                  <p class="label">Deskripsi</p>
                  <input type="text" class="input-field" bind:value={newBill.description} placeholder="Deskripsi biaya..." />
                </div>
                <div class="space-y-1">
                  <p class="label">Jumlah (Rp)</p>
                  <input type="number" class="input-field" bind:value={newBill.amount} placeholder="0" />
                </div>
              </div>
              <div class="space-y-1">
                <p class="label">Tipe Tarif</p>
                <select class="select-field" bind:value={newBill.tariff_type}>
                  <option value="Konsultasi">Konsultasi</option>
                  <option value="Tindakan">Tindakan</option>
                  <option value="Akomodasi">Akomodasi</option>
                  <option value="Laboratorium">Laboratorium</option>
                  <option value="Radiologi">Radiologi</option>
                  <option value="Obat">Obat</option>
                  <option value="BMHP">BMHP</option>
                  <option value="Visite Dokter">Visite Dokter</option>
                  <option value="Lainnya">Lainnya</option>
                </select>
              </div>
              <div class="flex justify-end">
                <button class="btn-primary" onclick={addCustomBill} disabled={saving || !newBill.description.trim() || !newBill.amount}>
                  {#if saving}
                    <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
                  {/if}
                  Tambah Biaya
                </button>
              </div>
            </div>

            {#if treatmentBills.length > 0}
              <div>
                <h4 class="text-sm font-semibold text-gray-700 mb-3">Daftar Tagihan</h4>
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr class="table-header">
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Deskripsi</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Tipe</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Jumlah</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Aksi</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100">
                      {#each treatmentBills as bill, i}
                        <tr class="hover:bg-gray-50">
                          <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                          <td class="table-cell font-medium text-gray-900">{bill.description}</td>
                          <td class="table-cell">
                            <span class="badge badge-gray">{bill.tariff_type}</span>
                          </td>
                          <td class="table-cell text-right font-semibold text-gray-900">{formatCurrency(bill.amount)}</td>
                          <td class="table-cell text-right">
                            <button class="text-gray-400 hover:text-red-500 transition-colors" title="Hapus tagihan" onclick={() => removeBill(bill.id)}>
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
                              </svg>
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

        {:else if activeTab === 'cetak'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Cetak Dokumen</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <button class="card hover:shadow-md transition-shadow text-left group" onclick={printPrescription}>
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

              <button class="card hover:shadow-md transition-shadow text-left group" onclick={printReceipt}>
                <div class="flex items-center gap-4">
                  <div class="shrink-0 w-12 h-12 rounded-xl bg-emerald-100 flex items-center justify-center group-hover:bg-emerald-200 transition-colors">
                    <svg class="w-6 h-6 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
                    </svg>
                  </div>
                  <div>
                    <p class="font-semibold text-gray-900">Kwitansi / Resi</p>
                    <p class="text-sm text-gray-500">Cetak kwitansi tagihan pasien</p>
                  </div>
                </div>
              </button>

              <button class="card hover:shadow-md transition-shadow text-left group" onclick={printCppt}>
                <div class="flex items-center gap-4">
                  <div class="shrink-0 w-12 h-12 rounded-xl bg-blue-100 flex items-center justify-center group-hover:bg-blue-200 transition-colors">
                    <svg class="w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
                    </svg>
                  </div>
                  <div>
                    <p class="font-semibold text-gray-900">CPPT / SOAP</p>
                    <p class="text-sm text-gray-500">Cetak catatan perkembangan pasien</p>
                  </div>
                </div>
              </button>

              <button class="card hover:shadow-md transition-shadow text-left group" onclick={printCppt}>
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
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}
