<script>
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatCurrency, formatDate, formatDateTime } from '$lib/utils/helpers.js';
  import { TRIAGE_LEVELS, PAYOR_TYPES, TARIFF_TYPES } from '$lib/utils/constants.js';

  let visitId = $derived(page.params.visitId);
  let loading = $state(true);
  let saving = $state(false);
  let activeTab = $state('triage');

  let visit = $state(null);
  let patient = $state(null);
  let doctor = $state(null);
  let now = $state(new Date());
  let timer;

  let cpptList = $state([]);
  let diagnoses = $state([]);
  let labOrders = $state([]);
  let radiologyOrders = $state([]);
  let prescriptions = $state([]);
  let treatmentBills = $state([]);
  let tindakanList = $state([]);

  let triage = $state({
    level: '',
    score: '',
    notes: ''
  });

  let assessment = $state({
    chief_complaint: '',
    anamnesis: '',
    physical_exam: '',
    sistolik: '',
    diastolik: '',
    suhu: '',
    nadi: '',
    rr: '',
    gcs: '',
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
    tariff_type: 'Tindakan',
    amount: ''
  });

  let newTindakan = $state({
    procedure_name: '',
    notes: '',
    operator: ''
  });

  let disposition = $state({
    type: '',
    target_room: '',
    target_bed: '',
    referral_hospital: '',
    referral_notes: '',
    discharge_notes: ''
  });

  let rooms = $state([]);

  const totalBill = $derived(
    treatmentBills.reduce((sum, b) => sum + (b.amount || 0), 0)
  );

  const timeElapsed = $derived.by(() => {
    if (!visit?.visit_date) return '-';
    const diff = Math.floor((now - new Date(visit.visit_date)) / 1000);
    const h = Math.floor(diff / 3600);
    const m = Math.floor((diff % 3600) / 60);
    const s = diff % 60;
    if (h > 0) return `${h}j ${m}m ${s}s`;
    return `${m}m ${s}s`;
  });

  const triageEntries = Object.entries(TRIAGE_LEVELS);

  const triageButtonStyles = {
    resuscitation: 'bg-red-800 hover:bg-red-900 ring-red-800',
    emergency: 'bg-red-500 hover:bg-red-600 ring-red-500',
    urgent: 'bg-orange-500 hover:bg-orange-600 ring-orange-500',
    less_urgent: 'bg-yellow-500 hover:bg-yellow-600 ring-yellow-500 text-gray-900',
    non_urgent: 'bg-green-500 hover:bg-green-600 ring-green-500'
  };

  const tabs = [
    { id: 'triage', label: 'Triage' },
    { id: 'asessment', label: 'Asessment' },
    { id: 'cppt', label: 'CPPT/SOAP' },
    { id: 'diagnosis', label: 'Diagnosis' },
    { id: 'tindakan', label: 'Tindakan' },
    { id: 'lab', label: 'Lab' },
    { id: 'radiologi', label: 'Radiologi' },
    { id: 'resep', label: 'Resep' },
    { id: 'billing', label: 'Billing' },
    { id: 'disposition', label: 'Disposition' }
  ];

  async function fetchVisitData() {
    try {
      const { data: visitData, error: visitErr } = await supabase
        .from('patient_visitations')
        .select(`
          *,
          patients:patient_id ( patient_id, full_name, no_registration, date_of_birth, gender, phone, address ),
          doctors:doctor_id ( doctor_id, full_name )
        `)
        .eq('visit_id', visitId)
        .single();

      if (visitErr) throw visitErr;
      visit = visitData;
      patient = visitData.patients;
      doctor = visitData.doctors;

      if (patient?.date_of_birth) {
        const birth = new Date(patient.date_of_birth);
        const today = new Date();
        let age = today.getFullYear() - birth.getFullYear();
        const m = today.getMonth() - birth.getMonth();
        if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--;
        patient.age = age;
      }

      if (visit?.triage_level) {
        triage.level = visit.triage_level;
        triage.score = visit.triage_score || '';
        triage.notes = visit.triage_notes || '';
      }

      if (visit?.assessment_id) {
        const { data: assessData } = await supabase
          .from('assessments')
          .select('*')
          .eq('assessment_id', visit.assessment_id)
          .single();
        if (assessData) {
          assessment.chief_complaint = assessData.chief_complaint || visit.chief_complaint || '';
          assessment.anamnesis = assessData.anamnesis || '';
          assessment.physical_exam = assessData.physical_exam || '';
          assessment.subjective = assessData.subjective || '';
          assessment.objective = assessData.objective || '';
          assessment.sistolik = assessData.sistolik || '';
          assessment.diastolik = assessData.diastolik || '';
          assessment.suhu = assessData.suhu || '';
          assessment.nadi = assessData.nadi || '';
          assessment.rr = assessData.rr || '';
          assessment.gcs = assessData.gcs || '';
          assessment.spo2 = assessData.spo2 || '';
        }
      } else {
        assessment.chief_complaint = visit.chief_complaint || '';
      }

      if (visit?.disposition_type) {
        disposition.type = visit.disposition_type;
        disposition.target_room = visit.disposition_target_room || '';
        disposition.target_bed = visit.disposition_target_bed || '';
        disposition.referral_hospital = visit.disposition_referral_hospital || '';
        disposition.referral_notes = visit.disposition_referral_notes || '';
        disposition.discharge_notes = visit.disposition_discharge_notes || '';
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
        .select('id, diagnosis_type, diagnosis_id, diagnoses:diagnosis_id ( code, name )')
        .eq('visit_id', visitId);
      if (error) throw error;
      diagnoses = (data || []).map((diag) => ({
        id: diag.id,
        diagnosis_id: diag.diagnosis_id,
        diagnosis_type: diag.diagnosis_type,
        icd_code: diag.diagnoses?.code || '-',
        icd_name: diag.diagnoses?.name || '-'
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
        .order('created_at', { ascending: false });
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

  async function fetchRooms() {
    try {
      const { data, error } = await supabase
        .from('rooms')
        .select('room_id, name, room_type, beds:beds(bed_id, bed_number, is_available)')
        .eq('is_active', true)
        .order('name');
      if (error) throw error;
      rooms = data || [];
    } catch (err) {
      console.error('Fetch rooms error:', err);
    }
  }

  async function saveTriage() {
    saving = true;
    try {
      const { error } = await supabase
        .from('patient_visitations')
        .update({
          triage_level: triage.level,
          triage_score: triage.score ? Number(triage.score) : null,
          triage_notes: triage.notes
        })
        .eq('visit_id', visitId);
      if (error) throw error;
      visit = { ...visit, triage_level: triage.level, triage_score: triage.score, triage_notes: triage.notes };
    } catch (err) {
      console.error('Save triage error:', err);
    } finally {
      saving = false;
    }
  }

  async function saveAssessment() {
    saving = true;
    try {
      if (visit?.assessment_id) {
        const { error } = await supabase
          .from('assessments')
          .update({
            chief_complaint: assessment.chief_complaint,
            anamnesis: assessment.anamnesis,
            physical_exam: assessment.physical_exam,
            sistolik: assessment.sistolik ? Number(assessment.sistolik) : null,
            diastolik: assessment.diastolik ? Number(assessment.diastolik) : null,
            suhu: assessment.suhu ? Number(assessment.suhu) : null,
            nadi: assessment.nadi ? Number(assessment.nadi) : null,
            rr: assessment.rr ? Number(assessment.rr) : null,
            gcs: assessment.gcs ? Number(assessment.gcs) : null,
            spo2: assessment.spo2 ? Number(assessment.spo2) : null
          })
          .eq('assessment_id', visit.assessment_id);
        if (error) throw error;
      } else {
        const { data, error } = await supabase
          .from('assessments')
          .insert({
            visit_id: visitId,
            chief_complaint: assessment.chief_complaint,
            anamnesis: assessment.anamnesis,
            physical_exam: assessment.physical_exam,
            sistolik: assessment.sistolik ? Number(assessment.sistolik) : null,
            diastolik: assessment.diastolik ? Number(assessment.diastolik) : null,
            suhu: assessment.suhu ? Number(assessment.suhu) : null,
            nadi: assessment.nadi ? Number(assessment.nadi) : null,
            rr: assessment.rr ? Number(assessment.rr) : null,
            gcs: assessment.gcs ? Number(assessment.gcs) : null,
            spo2: assessment.spo2 ? Number(assessment.spo2) : null
          })
          .select()
          .single();
        if (error) throw error;
        visit = { ...visit, assessment_id: data.assessment_id };
      }

      await supabase
        .from('patient_visitations')
        .update({ chief_complaint: assessment.chief_complaint })
        .eq('visit_id', visitId);
    } catch (err) {
      console.error('Save assessment error:', err);
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
      const exists = diagnoses.find(d => d.diagnosis_id === diagnosisId);
      if (exists) return;
      const { error } = await supabase
        .from('patient_diagnoses')
        .insert({
          visit_id: visitId,
          diagnosis_id: diagnosisId,
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
        const { data, error } = await supabase.from('diagnoses').select('diagnosis_id, code, name')
          .eq('is_active', true)
      if (error) throw error;
      await fetchDiagnoses();
    } catch (err) {
      console.error('Remove diagnosis error:', err);
    }
  }

  async function addDiagnosis(diagnosisId, type = 'primer') {
    if (!newTindakan.procedure_name.trim()) return;
      if (diagnoses.find(d => d.diagnosis_id === diagnosisId)) return;
    try {
        visit_id: visitId,
        diagnosis_id: diagnosisId,
        diagnosis_type: type
        .from('tindakan')
        .insert({
          visit_id: visitId,
          procedure_name: newTindakan.procedure_name,
          notes: newTindakan.notes,
          operator: newTindakan.operator,
          performed_at: new Date().toISOString()
        });
      if (error) throw error;
      newTindakan = { procedure_name: '', notes: '', operator: '' };
      await fetchTindakan();
    } catch (err) {
      console.error('Save tindakan error:', err);
    } finally {
      saving = false;
    }
  }

  async function fetchTindakan() {
    try {
      const { data, error } = await supabase
        .from('tindakan')
        .select('*')
        .eq('visit_id', visitId)
        .order('created_at', { ascending: false });
      if (error) throw error;
      tindakanList = data || [];
    } catch (err) {
      console.error('Fetch tindakan error:', err);
    }
  }

  async function removeTindakan(id) {
    try {
      const { error } = await supabase
        .from('tindakan')
        .delete()
        .eq('id', id);
      if (error) throw error;
      await fetchTindakan();
    } catch (err) {
      console.error('Remove tindakan error:', err);
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

  async function orderRadiology(examType, description) {
    try {
      const { error } = await supabase
        .from('radiology_orders')
        .insert({
          visit_id: visitId,
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
        .select('tariff_id, name, tariff_type, price')
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
          description: tariff.name,
          tariff_type: tariff.tariff_type,
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
      newBill = { description: '', tariff_type: 'Tindakan', amount: '' };
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

  async function saveDisposition() {
    saving = true;
    try {
      const updateData = {
        disposition_type: disposition.type,
        disposition_target_room: disposition.target_room,
        disposition_target_bed: disposition.target_bed,
        disposition_referral_hospital: disposition.referral_hospital,
        disposition_referral_notes: disposition.referral_notes,
        disposition_discharge_notes: disposition.discharge_notes
      };
      if (disposition.type === 'meninggal' || disposition.type === 'pulang') {
        updateData.status_keluar = '1';
        updateData.status_periksa = '1';
      }
      const { error } = await supabase
        .from('patient_visitations')
        .update(updateData)
        .eq('visit_id', visitId);
      if (error) throw error;
      visit = { ...visit, ...updateData };
    } catch (err) {
      console.error('Save disposition error:', err);
    } finally {
      saving = false;
    }
  }

  function goBack() {
    goto('/igd');
  }

  function printDocument() {
    window.print();
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
      fetchBills(),
      fetchTindakan(),
      fetchRooms()
    ]);
    loading = false;

    timer = setInterval(() => {
      now = new Date();
    }, 1000);

    return () => clearInterval(timer);
  });
</script>

<svelte:head>
  <title>IGD - {patient?.full_name || 'Pasien'}</title>
</svelte:head>

{#if loading}
  <div class="flex items-center justify-center py-24">
    <div class="flex flex-col items-center gap-4">
      <div class="w-12 h-12 border-4 border-red-200 border-t-red-600 rounded-full animate-spin"></div>
      <p class="text-sm text-gray-500 font-medium">Memuat data IGD...</p>
    </div>
  </div>
{:else if !visit}
  <div class="card text-center py-16">
    <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
    </svg>
    <p class="text-lg font-medium text-gray-700">Kunjungan IGD tidak ditemukan</p>
    <button class="btn-danger mt-4" onclick={goBack}>Kembali ke IGD</button>
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
      <h1 class="text-xl font-bold text-red-700">Pemeriksaan IGD</h1>
      {#if visit.status_keluar === '1'}
        <span class="badge badge-info">Selesai</span>
      {:else}
        <span class="badge badge-danger flex items-center gap-1">
          <span class="w-2 h-2 bg-red-500 rounded-full animate-pulse"></span>
          Aktif
        </span>
      {/if}
    </div>

    <div class="card bg-gradient-to-r from-red-50 to-orange-50 border-red-200">
      <div class="flex flex-col md:flex-row md:items-center gap-4">
        <div class="shrink-0 w-14 h-14 rounded-full bg-red-100 flex items-center justify-center">
          <svg class="w-7 h-7 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
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
            <p class="text-xs text-gray-500">Dokter</p>
            <p class="font-semibold text-gray-900">{doctor?.full_name || '-'}</p>
          </div>
          <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
            <p class="text-xs text-gray-500">Jam Datang</p>
            <p class="font-semibold text-gray-900">{formatDateTime(visit?.visit_date)}</p>
          </div>
          <div class="bg-white rounded-lg px-4 py-2 border border-red-200">
            <p class="text-xs text-red-600">Lama Di IGD</p>
            <p class="font-bold text-red-700 font-mono">{timeElapsed}</p>
          </div>
          {#if visit?.triage_level}
            {@const tb = Object.entries(TRIAGE_LEVELS).find(([k]) => k === visit.triage_level)}
            {#if tb}
              <div class="bg-white rounded-lg px-4 py-2 border border-gray-200">
                <p class="text-xs text-gray-500">Triage</p>
                <p class="font-semibold {tb[1].color} text-xs mt-0.5">{tb[1].name}</p>
              </div>
            {/if}
          {/if}
        </div>
      </div>
    </div>

    <div class="card p-0">
      <div class="flex overflow-x-auto border-b border-gray-200 scrollbar-thin">
        {#each tabs as tab}
          <button
            class="flex items-center gap-1.5 px-3 py-3 text-xs font-medium whitespace-nowrap border-b-2 transition-colors
              {activeTab === tab.id
                ? 'border-red-600 text-red-700 bg-red-50'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
            onclick={() => activeTab = tab.id}
          >
            {tab.label}
          </button>
        {/each}
      </div>

      <div class="p-6">
        {#if activeTab === 'triage'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Penilaian Triage</h3>

            <div>
              <label class="label mb-2">Level Triage</label>
              <div class="flex flex-wrap gap-3">
                {#each triageEntries as [key, cfg]}
                  <button
                    class="px-5 py-3 rounded-lg text-sm font-bold transition-all
                      {triage.level === key
                        ? triageButtonStyles[key] + ' text-white ring-2 ring-offset-2'
                        : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
                    onclick={() => triage.level = key}
                  >
                    {cfg.name}
                    <span class="block text-[10px] font-normal mt-0.5 opacity-80">Prioritas {cfg.priority}</span>
                  </button>
                {/each}
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="space-y-1">
                <label class="label">Skor Triage (opsional)</label>
                <input type="number" class="input-field" bind:value={triage.score} placeholder="Contoh: ESI 1-5" />
              </div>
              <div class="space-y-1">
                <label class="label">Catatan Triage</label>
                <input type="text" class="input-field" bind:value={triage.notes} placeholder="Catatan penilaian triage..." />
              </div>
            </div>

            <div class="flex justify-end">
              <button class="btn-danger" onclick={saveTriage} disabled={saving || !triage.level}>
                {#if saving}
                  <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
                {/if}
                Simpan Triage
              </button>
            </div>
          </div>

        {:else if activeTab === 'asessment'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Asessment & Tanda Vital</h3>

            <div class="space-y-2">
              <label class="label">Keluhan Utama (Chief Complaint)</label>
              <input type="text" class="input-field" bind:value={assessment.chief_complaint} placeholder="Keluhan utama pasien..." />
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="space-y-2">
                <label class="label">Anamnesis (Riwayat)</label>
                <textarea class="input-field h-28 resize-none" bind:value={assessment.anamnesis} placeholder="Riwayat penyakit sekarang, riwayat penyakit dahulu..."></textarea>
              </div>
              <div class="space-y-2">
                <label class="label">Pemeriksaan Fisik</label>
                <textarea class="input-field h-28 resize-none" bind:value={assessment.physical_exam} placeholder="Temuan pemeriksaan fisik..."></textarea>
              </div>
            </div>

            <div>
              <h4 class="text-sm font-semibold text-gray-700 uppercase tracking-wide mb-3">Tanda Vital</h4>
              <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-7 gap-4">
                <div class="space-y-1">
                  <label class="label text-xs">Sistolik (mmHg)</label>
                  <input type="number" class="input-field" bind:value={assessment.sistolik} placeholder="120" />
                </div>
                <div class="space-y-1">
                  <label class="label text-xs">Diastolik (mmHg)</label>
                  <input type="number" class="input-field" bind:value={assessment.diastolik} placeholder="80" />
                </div>
                <div class="space-y-1">
                  <label class="label text-xs">Suhu (&deg;C)</label>
                  <input type="number" step="0.1" class="input-field" bind:value={assessment.suhu} placeholder="36.5" />
                </div>
                <div class="space-y-1">
                  <label class="label text-xs">Nadi (/mnt)</label>
                  <input type="number" class="input-field" bind:value={assessment.nadi} placeholder="80" />
                </div>
                <div class="space-y-1">
                  <label class="label text-xs">RR (/mnt)</label>
                  <input type="number" class="input-field" bind:value={assessment.rr} placeholder="20" />
                </div>
                <div class="space-y-1">
                  <label class="label text-xs">GCS</label>
                  <input type="number" class="input-field" bind:value={assessment.gcs} placeholder="15" />
                </div>
                <div class="space-y-1">
                  <label class="label text-xs">SpO2 (%)</label>
                  <input type="number" class="input-field" bind:value={assessment.spo2} placeholder="98" />
                </div>
              </div>
            </div>

            <div class="flex justify-end">
              <button class="btn-danger" onclick={saveAssessment} disabled={saving}>
                {#if saving}
                  <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
                {/if}
                Simpan Asessment
              </button>
            </div>
          </div>

        {:else if activeTab === 'cppt'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">CPPT / SOAP</h3>

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
                <button class="btn-danger" onclick={saveCppt} disabled={saving}>
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
                        <span class="font-mono text-sm font-semibold text-red-700">{icd.code}</span>
                        <span class="text-sm text-gray-700 ml-2">{icd.name}</span>
                      </div>
                      <div class="flex gap-2">
                        <button class="text-xs bg-red-100 text-red-700 px-2 py-1 rounded hover:bg-red-200" onclick={() => addDiagnosis(icd.code, icd.name, 'primer')}>
                          Primer
                        </button>
                        <button class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded hover:bg-blue-200" onclick={() => addDiagnosis(icd.code, icd.name, 'sekunder')}>
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
                      <button class="text-gray-400 hover:text-red-500 transition-colors" onclick={() => removeDiagnosis(diag.id)}>
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

        {:else if activeTab === 'tindakan'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Tindakan Darurat</h3>

            <div class="border border-gray-200 rounded-lg p-4 space-y-4">
              <h4 class="text-sm font-semibold text-gray-700">Tambah Tindakan</h4>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="space-y-1 md:col-span-2">
                  <label class="label">Nama Tindakan</label>
                  <input type="text" class="input-field" bind:value={newTindakan.procedure_name} placeholder="Contoh: Intubasi, Resusitasi, Chest tube..." />
                </div>
                <div class="space-y-1">
                  <label class="label">Operator / Pelaksana</label>
                  <input type="text" class="input-field" bind:value={newTindakan.operator} placeholder="Nama dokter/perawat" />
                </div>
              </div>
              <div class="space-y-1">
                <label class="label">Catatan</label>
                <textarea class="input-field h-20 resize-none text-sm" bind:value={newTindakan.notes} placeholder="Detail tindakan, hasil, komplikasi..."></textarea>
              </div>
              <div class="flex justify-end">
                <button class="btn-danger" onclick={saveTindakan} disabled={saving || !newTindakan.procedure_name.trim()}>
                  {#if saving}
                    <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
                  {/if}
                  Simpan Tindakan
                </button>
              </div>
            </div>

            {#if tindakanList.length > 0}
              <div>
                <h4 class="text-sm font-semibold text-gray-700 mb-3">Daftar Tindakan</h4>
                <div class="space-y-2">
                  {#each tindakanList as t}
                    <div class="flex items-start justify-between bg-gray-50 rounded-lg px-4 py-3">
                      <div class="flex-1 min-w-0">
                        <p class="font-medium text-gray-900">{t.procedure_name}</p>
                        {#if t.operator}
                          <p class="text-xs text-gray-500 mt-0.5">Operator: {t.operator}</p>
                        {/if}
                        {#if t.notes}
                          <p class="text-sm text-gray-600 mt-1">{t.notes}</p>
                        {/if}
                        <p class="text-xs text-gray-400 font-mono mt-1">{formatDateTime(t.performed_at || t.created_at)}</p>
                      </div>
                      <button class="text-gray-400 hover:text-red-500 transition-colors shrink-0 ml-3" onclick={() => removeTindakan(t.id)}>
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>
                  {/each}
                </div>
              </div>
            {:else}
              <p class="text-sm text-gray-400 text-center py-6">Belum ada tindakan tercatat</p>
            {/if}
          </div>

        {:else if activeTab === 'lab'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Laboratorium Darurat</h3>

            <div class="space-y-2">
              <label class="label">Pesan Tes Lab</label>
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
                      <button class="btn-danger btn-sm text-xs" onclick={() => { orderLab(test.test_name, test.category); labSearch = ''; labResults = []; }}>
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
                            <span class="badge {order.status === 'completed' ? 'badge-success' : order.status === 'ordered' ? 'badge-danger' : 'badge-info'}">
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
            <h3 class="text-lg font-semibold text-gray-900">Radiologi Darurat</h3>

            <div class="space-y-2">
              <label class="label">Pesan Pemeriksaan Radiologi</label>
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
                      <button class="btn-danger btn-sm text-xs" onclick={() => { orderRadiology(exam.exam_type, exam.description); radiologySearch = ''; radiologyResults = []; }}>
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
                            <span class="badge {order.status === 'completed' ? 'badge-success' : order.status === 'ordered' ? 'badge-danger' : 'badge-info'}">
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
            <h3 class="text-lg font-semibold text-gray-900">Resep Obat Darurat</h3>

            <div class="border border-gray-200 rounded-lg p-4 space-y-4">
              <h4 class="text-sm font-semibold text-gray-700">Tambah Resep</h4>

              <div class="space-y-2">
                <label class="label">Cari Obat</label>
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
                <div class="bg-red-50 rounded-lg px-4 py-3">
                  <p class="text-sm font-semibold text-red-700">{newPrescription.drug_name}</p>
                </div>
              {/if}

              <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div class="space-y-1">
                  <label class="label">Jumlah (Qty)</label>
                  <input type="number" class="input-field" bind:value={newPrescription.qty} placeholder="10" />
                </div>
                <div class="space-y-1">
                  <label class="label">Dosis</label>
                  <input type="text" class="input-field" bind:value={newPrescription.dosage} placeholder="500mg" />
                </div>
                <div class="space-y-1">
                  <label class="label">Frekuensi</label>
                  <select class="select-field" bind:value={newPrescription.frequency}>
                    <option value="">Pilih...</option>
                    <option value="1x1">1x1 sehari</option>
                    <option value="1x2">1x2 sehari</option>
                    <option value="1x3">1x3 sehari</option>
                    <option value="2x1">2x1 dua kali sehari</option>
                    <option value="3x1">3x1 tiga kali sehari</option>
                    <option value="IV">Intravena (IV)</option>
                    <option value="IM">Intramuskular (IM)</option>
                    <option value="PRN">Saat Diperlukan (PRN)</option>
                  </select>
                </div>
                <div class="space-y-1">
                  <label class="label">Instruksi</label>
                  <input type="text" class="input-field" bind:value={newPrescription.instruction} placeholder="Setelah makan" />
                </div>
              </div>

              <div class="flex justify-end">
                <button class="btn-danger" onclick={savePrescription} disabled={saving || !newPrescription.drug_id || !newPrescription.qty}>
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
                            <button class="text-gray-400 hover:text-red-500 transition-colors" onclick={() => removePrescription(rx.id)}>
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
            <h3 class="text-lg font-semibold text-gray-900">Billing IGD</h3>

            <div class="space-y-2">
              <label class="label">Tambah dari Daftar Tarif</label>
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
                        <span class="badge badge-gray ml-2">{tariff.tariff_type}</span>
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
                  <label class="label">Deskripsi</label>
                  <input type="text" class="input-field" bind:value={newBill.description} placeholder="Deskripsi biaya..." />
                </div>
                <div class="space-y-1">
                  <label class="label">Jumlah (Rp)</label>
                  <input type="number" class="input-field" bind:value={newBill.amount} placeholder="0" />
                </div>
              </div>
              <div class="space-y-1">
                <label class="label">Tipe Tarif</label>
                <select class="select-field" bind:value={newBill.tariff_type}>
                  {#each TARIFF_TYPES as ttype}
                    <option value={ttype}>{ttype}</option>
                  {/each}
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
                            <button class="text-gray-400 hover:text-red-500 transition-colors" onclick={() => removeBill(bill.id)}>
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
                        <td class="px-4 py-3 text-sm font-bold text-red-700 text-right">{formatCurrency(totalBill)}</td>
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

        {:else if activeTab === 'disposition'}
          <div class="space-y-6">
            <h3 class="text-lg font-semibold text-gray-900">Disposisi Pasien</h3>

            <div>
              <label class="label mb-2">Tujuan Disposisi</label>
              <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
                <button
                  class="rounded-lg border-2 p-4 text-center transition-all
                    {disposition.type === 'rawat_inap'
                      ? 'border-red-500 bg-red-50 text-red-700'
                      : 'border-gray-200 hover:border-gray-300 text-gray-700'}"
                  onclick={() => disposition.type = 'rawat_inap'}
                >
                  <svg class="w-6 h-6 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5m8.25 3v6.75m0 0l-3-3m3 3l3-3M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
                  </svg>
                  <p class="text-sm font-semibold">Rawat Inap</p>
                </button>
                <button
                  class="rounded-lg border-2 p-4 text-center transition-all
                    {disposition.type === 'rawat_jalan'
                      ? 'border-red-500 bg-red-50 text-red-700'
                      : 'border-gray-200 hover:border-gray-300 text-gray-700'}"
                  onclick={() => disposition.type = 'rawat_jalan'}
                >
                  <svg class="w-6 h-6 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <p class="text-sm font-semibold">Rawat Jalan</p>
                </button>
                <button
                  class="rounded-lg border-2 p-4 text-center transition-all
                    {disposition.type === 'rujuk'
                      ? 'border-red-500 bg-red-50 text-red-700'
                      : 'border-gray-200 hover:border-gray-300 text-gray-700'}"
                  onclick={() => disposition.type = 'rujuk'}
                >
                  <svg class="w-6 h-6 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m9.86-2.06a4.5 4.5 0 00-1.242-7.244l-4.5-4.5a4.5 4.5 0 00-6.364 6.364L4.34 8.374" />
                  </svg>
                  <p class="text-sm font-semibold">Rujuk</p>
                </button>
                <button
                  class="rounded-lg border-2 p-4 text-center transition-all
                    {disposition.type === 'meninggal'
                      ? 'border-red-500 bg-red-50 text-red-700'
                      : 'border-gray-200 hover:border-gray-300 text-gray-700'}"
                  onclick={() => disposition.type = 'meninggal'}
                >
                  <svg class="w-6 h-6 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
                  </svg>
                  <p class="text-sm font-semibold">Meninggal</p>
                </button>
                <button
                  class="rounded-lg border-2 p-4 text-center transition-all
                    {disposition.type === 'pulang'
                      ? 'border-red-500 bg-red-50 text-red-700'
                      : 'border-gray-200 hover:border-gray-300 text-gray-700'}"
                  onclick={() => disposition.type = 'pulang'}
                >
                  <svg class="w-6 h-6 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25" />
                  </svg>
                  <p class="text-sm font-semibold">Pulang</p>
                </button>
              </div>
            </div>

            {#if disposition.type === 'rawat_inap'}
              <div class="border border-gray-200 rounded-lg p-4 space-y-4 bg-gray-50">
                <h4 class="text-sm font-semibold text-gray-700">Pilih Kamar & Tempat Tidur</h4>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="space-y-1">
                    <label class="label">Kamar</label>
                    <select class="select-field" bind:value={disposition.target_room}>
                      <option value="">Pilih Kamar...</option>
                      {#each rooms as room}
                        <option value={room.room_id}>{room.name} ({room.room_type})</option>
                      {/each}
                    </select>
                  </div>
                  <div class="space-y-1">
                    <label class="label">Nomor Tempat Tidur</label>
                    <input type="text" class="input-field" bind:value={disposition.target_bed} placeholder="Nomor tempat tidur" />
                  </div>
                </div>
              </div>
            {/if}

            {#if disposition.type === 'rujuk'}
              <div class="border border-gray-200 rounded-lg p-4 space-y-4 bg-gray-50">
                <h4 class="text-sm font-semibold text-gray-700">Surat Rujukan</h4>
                <div class="space-y-2">
                  <label class="label">Rumah Sakit Tujuan</label>
                  <input type="text" class="input-field" bind:value={disposition.referral_hospital} placeholder="Nama RS tujuan rujukan..." />
                </div>
                <div class="space-y-2">
                  <label class="label">Catatan Rujukan</label>
                  <textarea class="input-field h-24 resize-none" bind:value={disposition.referral_notes} placeholder="Alasan rujukan, kondisi pasien, dll..."></textarea>
                </div>
              </div>
            {/if}

            {#if disposition.type === 'pulang'}
              <div class="border border-gray-200 rounded-lg p-4 space-y-4 bg-gray-50">
                <h4 class="text-sm font-semibold text-gray-700">Catatan Pulang</h4>
                <div class="space-y-2">
                  <label class="label">Instruksi Pulang</label>
                  <textarea class="input-field h-24 resize-none" bind:value={disposition.discharge_notes} placeholder="Instruksi pasien pulang, kontrol, obat lanjutan..."></textarea>
                </div>
              </div>
            {/if}

            {#if disposition.type === 'meninggal'}
              <div class="border border-red-200 rounded-lg p-4 space-y-4 bg-red-50">
                <h4 class="text-sm font-semibold text-red-700">Catatan Kematian</h4>
                <div class="space-y-2">
                  <label class="label">Keterangan</label>
                  <textarea class="input-field h-24 resize-none" bind:value={disposition.discharge_notes} placeholder="Waktu meninggal, kondisi, dll..."></textarea>
                </div>
              </div>
            {/if}

            {#if disposition.type}
              <div class="flex justify-end">
                <button class="btn-danger" onclick={saveDisposition} disabled={saving}>
                  {#if saving}
                    <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
                  {/if}
                  Simpan Disposisi
                </button>
              </div>
            {/if}
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}
