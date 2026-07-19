<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { generateId, formatCurrency } from '$lib/utils/helpers.js';
  import { ROLES, DRUG_CATEGORIES, TARIFF_TYPES } from '$lib/utils/constants.js';

  let activeTab = $state('karyawan');
  let loading = $state(false);
  let searchQuery = $state('');

  let showModal = $state(false);
  let modalMode = $state('add');
  let modalEntity = $state('');
  let formData = $state({});
  let formErrors = $state({});
  let saving = $state(false);

  let showDeleteModal = $state(false);
  let deleteTarget = $state(null);
  let deleteEntity = $state('');
  let deleting = $state(false);

  let employees = $state([]);
  let clinics = $state([]);
  let roomClasses = $state([]);
  let rooms = $state([]);
  let beds = $state([]);
  let drugs = $state([]);
  let tariffs = $state([]);
  let diagnoses = $state([]);
  let profiles = $state([]);

  const tabs = [
    { id: 'karyawan', label: 'Karyawan', icon: 'users' },
    { id: 'poli', label: 'Poli', icon: 'building' },
    { id: 'kamar', label: 'Kamar & Bed', icon: 'bed' },
    { id: 'obat', label: 'Obat', icon: 'pill' },
    { id: 'tarif', label: 'Tarif', icon: 'tag' },
    { id: 'diagnosis', label: 'Diagnosis', icon: 'activity' },
    { id: 'profil', label: 'User / Profil', icon: 'user' }
  ];

  const filteredEmployees = $derived(
  searchQuery
    ? employees.filter(e =>
        e.fullname?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        e.employee_id?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        e.role?.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : employees
);

  const filteredClinics = $derived(
    searchQuery
      ? clinics.filter(c =>
          c.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          c.clinic_id?.toLowerCase().includes(searchQuery.toLowerCase())
        )
      : clinics
  );

  const filteredRoomClasses = $derived(
    searchQuery
      ? roomClasses.filter(r =>
          r.name?.toLowerCase().includes(searchQuery.toLowerCase())
        )
      : roomClasses
  );

  const filteredRooms = $derived(
    searchQuery
      ? rooms.filter(r =>
          r.room_number?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          r.room_id?.toLowerCase().includes(searchQuery.toLowerCase())
        )
      : rooms
  );

  const filteredBeds = $derived(
    searchQuery
      ? beds.filter(b =>
          b.bed_number?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          b.bed_id?.toLowerCase().includes(searchQuery.toLowerCase())
        )
      : beds
  );

  const filteredDrugs = $derived(
    searchQuery
      ? drugs.filter(d =>
          d.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          d.drug_id?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          d.category?.toLowerCase().includes(searchQuery.toLowerCase())
        )
      : drugs
  );

  const filteredTariffs = $derived(
    searchQuery
      ? tariffs.filter(t =>
          t.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          t.tariff_id?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          t.category?.toLowerCase().includes(searchQuery.toLowerCase())
        )
      : tariffs
  );

  const filteredDiagnoses = $derived(
    searchQuery
      ? diagnoses.filter(d =>
          d.code?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          d.name?.toLowerCase().includes(searchQuery.toLowerCase())
        )
      : diagnoses
  );

  const filteredProfiles = $derived(
    searchQuery
      ? profiles.filter(p =>
          p.fullname?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          p.email?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          p.role?.toLowerCase().includes(searchQuery.toLowerCase())
        )
      : profiles
  );

  const roomOptions = $derived(
    rooms.map(r => {
      const rc = roomClasses.find(rc => rc.class_id === r.class_id);
      return { ...r, className: rc?.name || '-' };
    })
  );

  const filteredRoomOptions = $derived(
    searchQuery
      ? roomOptions.filter(r =>
          r.room_number?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          r.className?.toLowerCase().includes(searchQuery.toLowerCase())
        )
      : roomOptions
  );

  function switchTab(tabId) {
    activeTab = tabId;
    searchQuery = '';
  }

  function sortByText(items, key) {
    return [...items].sort((left, right) => {
      const leftValue = (left?.[key] || '').toString().toLowerCase();
      const rightValue = (right?.[key] || '').toString().toLowerCase();
      return leftValue.localeCompare(rightValue, 'id');
    });
  }

  async function fetchAll() {
    loading = true;
    try {
      // 1. Fetch data Karyawan
      const empRes = await supabase.from('employees').select('*');
      
      // DEBUG: Cek isi objek response dari Supabase di konsol browser
      console.log('Respon Karyawan:', { data: empRes.data, error: empRes.error });

      if (empRes.error) {
        console.error('Error Employees:', empRes.error.message);
      }
      
      if (empRes.data) {
        // Sort langsung di tempat (inline) menggunakan kolom 'fullname' yang baru
        employees = [...empRes.data].sort((a, b) => 
          (a.fullname || '').toString().localeCompare((b.fullname || '').toString(), 'id')
        );
        console.log('State employees setelah di-assign:', employees);
      }

      // 2. Fetch data Poli
      const clinRes = await supabase.from('clinics').select('*');
      if (clinRes.data) {
        clinics = [...clinRes.data].sort((a, b) => 
          (a.name || '').toString().localeCompare((b.name || '').toString(), 'id')
        );
      }

      // 3. Fetch data Kelas Kamar
      const rcRes = await supabase.from('room_classes').select('*');
      if (rcRes.data) {
        roomClasses = [...rcRes.data].sort((a, b) => 
          (a.name || '').toString().localeCompare((b.name || '').toString(), 'id')
        );
      }

      // 4. Fetch data Kamar
      const roomRes = await supabase.from('rooms').select('*');
      if (roomRes.data) {
        rooms = [...roomRes.data].sort((a, b) => 
          (a.room_number || '').toString().localeCompare((b.room_number || '').toString(), 'id')
        );
      }

      // 5. Fetch data Bed
      const bedRes = await supabase.from('beds').select('*');
      if (bedRes.data) {
        beds = [...bedRes.data].sort((a, b) => 
          (a.bed_number || '').toString().localeCompare((b.bed_number || '').toString(), 'id')
        );
      }

      // 6. Fetch data Obat
      const drugRes = await supabase.from('drugs').select('*');
      if (drugRes.data) {
        drugs = [...drugRes.data].sort((a, b) => 
          (a.name || '').toString().localeCompare((b.name || '').toString(), 'id')
        );
      }

      // 7. Fetch data Tarif
      const tariffRes = await supabase.from('tariffs').select('*');
      if (tariffRes.data) {
        tariffs = [...tariffRes.data].sort((a, b) => 
          (a.name || '').toString().localeCompare((b.name || '').toString(), 'id')
        );
      }

      // 8. Fetch data Diagnosis
      const diagRes = await supabase.from('diagnoses').select('*');
      if (diagRes.data) {
        diagnoses = [...diagRes.data].sort((a, b) => 
          (a.code || '').toString().localeCompare((b.code || '').toString(), 'id')
        );
      }

      // 9. Fetch data Profil
      const profRes = await supabase.from('profiles').select('*');
      if (profRes.data) {
        profiles = [...profRes.data].sort((a, b) => 
          (a.full_name || '').toString().localeCompare((b.full_name || '').toString(), 'id')
        );
      }

    } catch (err) {
      console.error('Fetch error global:', err);
    } finally {
      loading = false;
    }
  }


  function openAddModal(entity) {
    modalEntity = entity;
    modalMode = 'add';
    formErrors = {};
    formData = getDefaultFormData(entity);
    showModal = true;
  }

  function openEditModal(entity, item) {
    modalEntity = entity;
    modalMode = 'edit';
    formErrors = {};
    formData = { ...item };
    showModal = true;
  }

  function closeModal() {
    showModal = false;
    formData = {};
    formErrors = {};
  }

  function openDeleteModal(entity, item) {
    deleteEntity = entity;
    deleteTarget = item;
    showDeleteModal = true;
  }

  function closeDeleteModal() {
    showDeleteModal = false;
    deleteTarget = null;
    deleteEntity = '';
  }

  function getDefaultFormData(entity) {
    switch (entity) {
      case 'karyawan':
        return {
          employee_id: generateId('EMP'),
          fullname: '',
          role: 'doctor',
          gender: '',
          phone: '',
          email: '',
          specialization: '',
          department: '',
          is_dpjp: false,
          satusehat_practitioner_id: '',
          is_active: true
        };
      case 'poli':
        return { clinic_id: generateId('POL'), name: '', description: '', is_active: true };
      case 'room_class':
        return { class_id: generateId('CLS'), name: '', description: '', base_price: 0 };
      case 'room':
        return { room_id: generateId('RM'), room_number: '', class_id: '', clinic_id: '', floor: '1', is_active: true };
      case 'bed':
        return { bed_id: generateId('BD'), bed_number: '', room_id: '', is_occupied: false, is_active: true };
      case 'obat':
        return { drug_id: generateId('DRG'), name: '', category: 'Lainnya', unit: 'tablet', buy_price: 0, sell_price: 0, stock: 0, min_stock: 10, expiry_date: '', manufacturer: '', is_active: true };
      case 'tarif':
        return { tariff_id: generateId('TRF'), name: '', category: 'Konsultasi', description: '', price: 0, is_active: true };
      case 'diagnosis':
        return { diagnosis_id: generateId('DX'), code: '', name: '', description: '', category: '' };
      case 'profil':
        return { fullname: '', email: '', password: 'Password123!', role: 'doctor', phone: '' };
      default:
        return {};
    }
  }

  function validateForm() {
    const errors = {};
    switch (modalEntity) {
      case 'karyawan':
        if (!formData.fullname?.trim()) errors.fullname = 'Nama wajib diisi';
        if (!formData.role) errors.role = 'Role wajib dipilih';
        if (formData.gender && !['L', 'P'].includes(formData.gender)) errors.gender = 'Gender tidak valid';
        if (!formData.phone?.trim()) errors.phone = 'Telepon wajib diisi';
        break;
      case 'poli':
        if (!formData.name?.trim()) errors.name = 'Nama poli wajib diisi';
        break;
      case 'room_class':
        if (!formData.name?.trim()) errors.name = 'Nama kelas wajib diisi';
        if (!formData.base_price || formData.base_price < 0) errors.base_price = 'Harga harus valid';
        break;
      case 'room':
        if (!formData.room_number?.trim()) errors.room_number = 'Nomor kamar wajib diisi';
        if (!formData.class_id) errors.class_id = 'Kelas wajib dipilih';
        if (!formData.clinic_id) errors.clinic_id = 'Poli wajib dipilih';
        break;
      case 'bed':
        if (!formData.bed_number?.trim()) errors.bed_number = 'Nomor bed wajib diisi';
        if (!formData.room_id) errors.room_id = 'Kamar wajib dipilih';
        break;
      case 'obat':
        if (!formData.name?.trim()) errors.name = 'Nama obat wajib diisi';
        if (!formData.category) errors.category = 'Kategori wajib dipilih';
        if (!formData.unit?.trim()) errors.unit = 'Satuan wajib diisi';
        if (formData.sell_price < 0) errors.sell_price = 'Harga harus valid';
        break;
      case 'tarif':
        if (!formData.name?.trim()) errors.name = 'Nama tarif wajib diisi';
        if (!formData.category) errors.category = 'Kategori wajib dipilih';
        if (formData.price < 0) errors.price = 'Harga harus valid';
        break;
      case 'diagnosis':
        if (!formData.code?.trim()) errors.code = 'Kode ICD wajib diisi';
        if (!formData.name?.trim()) errors.name = 'Nama diagnosis wajib diisi';
        break;
      case 'profil':
        if (!formData.fullname?.trim()) errors.fullname = 'Nama wajib diisi';
        if (modalMode === 'add') {
          if (!formData.email?.trim()) errors.email = 'Email wajib diisi';
          if (!formData.password?.trim()) errors.password = 'Password wajib diisi';
        }
        if (!formData.role) errors.role = 'Role wajib dipilih';
        break;
    }
    formErrors = errors;
    return Object.keys(errors).length === 0;
  }

  async function handleSave() {
    if (!validateForm()) return;
    saving = true;
    try {
      const tableMap = {
        karyawan: 'employees',
        poli: 'clinics',
        room_class: 'room_classes',
        room: 'rooms',
        bed: 'beds',
        obat: 'drugs',
        tarif: 'tariffs',
        diagnosis: 'diagnoses',
        profil: 'profiles'
      };

      const table = tableMap[modalEntity];
      if (!table) return;

      if (modalEntity === 'profil' && modalMode === 'add') {
        const { data: { session: adminSession } } = await supabase.auth.getSession();
        const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
          email: formData.email,
          password: formData.password || 'Password123!',
          options: { data: { fullname: formData.fullname, role: formData.role } }
        });
        if (signUpError) throw signUpError;
        if (!signUpData.user) throw new Error('Gagal membuat user');

        if (adminSession) {
          const { error: restoreError } = await supabase.auth.setSession({
            access_token: adminSession.access_token,
            refresh_token: adminSession.refresh_token
          });
          if (restoreError) throw restoreError;
        }

        const { error: profileError } = await supabase.from('profiles').insert({
          id: signUpData.user.id,
          fullname: formData.fullname,
          email: formData.email,
          phone: formData.phone || null,
          role: formData.role,
          is_active: true
        });
        if (profileError) throw profileError;
      } else if (modalMode === 'add') {
        const payload = { ...formData };
        if (modalEntity === 'karyawan') {
          payload.gender = payload.gender || null;
          payload.specialization = payload.specialization || null;
          payload.department = payload.department || null;
          payload.satusehat_practitioner_id = payload.satusehat_practitioner_id || null;
        }
        if (modalEntity === 'room') {
          payload.clinic_id = payload.clinic_id || null;
        }
        if (modalEntity === 'obat') {
          payload.expiry_date = payload.expiry_date || null;
          payload.manufacturer = payload.manufacturer || null;
        }
        if (modalEntity === 'profil') {
          delete payload.password;
        }
        const { error } = await supabase.from(table).insert(payload);
        if (error) throw error;
      } else {
        const idField = {
          karyawan: 'employee_id',
          poli: 'clinic_id',
          room_class: 'class_id',
          room: 'room_id',
          bed: 'bed_id',
          obat: 'drug_id',
          tarif: 'tariff_id',
          diagnosis: 'diagnosis_id',
          profil: 'id'
        }[modalEntity];

        const { error } = await supabase
          .from(table)
          .update(
            modalEntity === 'karyawan'
              ? {
                  ...formData,
                  gender: formData.gender || null,
                  specialization: formData.specialization || null,
                  department: formData.department || null,
                  satusehat_practitioner_id: formData.satusehat_practitioner_id || null
                }
              : modalEntity === 'room'
                ? { ...formData, clinic_id: formData.clinic_id || null }
                : modalEntity === 'obat'
                  ? {
                      ...formData,
                      expiry_date: formData.expiry_date || null,
                      manufacturer: formData.manufacturer || null
                    }
                  : formData
          )
          .eq(idField, formData[idField]);
        if (error) throw error;
      }

      closeModal();
      await fetchAll();
    } catch (err) {
      console.error('Save error:', err);
      alert('Gagal menyimpan data: ' + (err.message || 'Unknown error'));
    } finally {
      saving = false;
    }
  }

  async function handleDelete() {
    if (!deleteTarget) return;
    deleting = true;
    try {
      const tableMap = {
        karyawan: 'employees',
        poli: 'clinics',
        room_class: 'room_classes',
        room: 'rooms',
        bed: 'beds',
        obat: 'drugs',
        tarif: 'tariffs',
        diagnosis: 'diagnoses',
        profil: 'profiles'
      };

      const idField = {
        karyawan: 'employee_id',
        poli: 'clinic_id',
        room_class: 'class_id',
        room: 'room_id',
        bed: 'bed_id',
        obat: 'drug_id',
        tarif: 'tariff_id',
        diagnosis: 'diagnosis_id',
        profil: 'id'
      }[deleteEntity];

      const table = tableMap[deleteEntity];
      const { error } = await supabase
        .from(table)
        .delete()
        .eq(idField, deleteTarget[idField]);
      if (error) throw error;

      closeDeleteModal();
      await fetchAll();
    } catch (err) {
      console.error('Delete error:', err);
      alert('Gagal menghapus data: ' + (err.message || 'Unknown error'));
    } finally {
      deleting = false;
    }
  }

  function getRoleBadge(role) {
    const colorMap = {
      admin: 'badge-danger',
      doctor: 'badge-info',
      nurse: 'badge-success',
      pharmacist: 'badge-warning',
      registration: 'badge-gray',
      lab_tech: 'badge-gray',
      radiology_tech: 'badge-gray',
      cashier: 'badge-gray',
      warehouse: 'badge-gray',
      igd: 'badge-warning'
    };
    return colorMap[role] || 'badge-gray';
  }

  function getRoleLabel(role) {
    return ROLES[role] || role;
  }

  function getRoomClassLabel(classId) {
    const rc = roomClasses.find(r => r.class_id === classId);
    return rc?.name || '-';
  }

  function getClinicLabel(clinicId) {
    const clinic = clinics.find(c => c.clinic_id === clinicId);
    return clinic?.name || '-';
  }

  function getRoomLabel(roomId) {
    const r = rooms.find(rm => rm.room_id === roomId);
    return r ? r.room_number : '-';
  }

  onMount(fetchAll);
</script>

<svelte:head>
  <title>Master Data - Admin SIMRS</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Master Data</h1>
      <p class="text-sm text-gray-500 mt-1">Kelola data master sistem rumah sakit</p>
    </div>
  </div>

  <div class="card p-0 overflow-hidden">
    <div class="flex overflow-x-auto border-b border-gray-200 scrollbar-thin">
      {#each tabs as tab}
        <button
          class="flex items-center gap-2 px-4 py-3 text-sm font-medium whitespace-nowrap transition-colors border-b-2
            {activeTab === tab.id
              ? 'border-primary-600 text-primary-600 bg-primary-50'
              : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
          onclick={() => switchTab(tab.id)}
        >
          {#if tab.icon === 'users'}
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" />
            </svg>
          {:else if tab.icon === 'building'}
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" />
            </svg>
          {:else if tab.icon === 'bed'}
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5m8.25 3v6.75m0 0l-3-3m3 3l3-3M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
            </svg>
          {:else if tab.icon === 'pill'}
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0112 15a9.065 9.065 0 00-6.23.693L5 14.5m14.8.8l1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0112 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5" />
            </svg>
          {:else if tab.icon === 'tag'}
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z" />
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 6h.008v.008H6V6z" />
            </svg>
          {:else if tab.icon === 'activity'}
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5" />
            </svg>
          {:else if tab.icon === 'user'}
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
            </svg>
          {/if}
          <span class="hidden sm:inline">{tab.label}</span>
        </button>
      {/each}
    </div>

    <div class="p-4 md:p-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
        <div class="relative flex-1 max-w-md">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
          </svg>
          <input
            type="text"
            class="input-field pl-10"
            placeholder="Cari data..."
            bind:value={searchQuery}
          />
        </div>
        {#if activeTab === 'kamar'}
          <div class="flex gap-2">
            <button class="btn-primary btn-sm" onclick={() => openAddModal('room_class')}>
              <svg class="w-4 h-4 inline mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Kelas Kamar
            </button>
            <button class="btn-primary btn-sm" onclick={() => openAddModal('room')}>
              <svg class="w-4 h-4 inline mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Kamar
            </button>
            <button class="btn-primary btn-sm" onclick={() => openAddModal('bed')}>
              <svg class="w-4 h-4 inline mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Bed
            </button>
          </div>
        {:else}
          <button class="btn-primary btn-sm" onclick={() => openAddModal(activeTab)}>
            <svg class="w-4 h-4 inline mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
            </svg>
            Tambah
          </button>
        {/if}
      </div>

      {#if loading}
        <div class="flex items-center justify-center py-20">
          <div class="flex flex-col items-center gap-3">
            <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            <p class="text-sm text-gray-500">Memuat data...</p>
          </div>
        </div>
      {:else}

        <!-- ===================== KARYAWAN TAB ===================== -->
        {#if activeTab === 'karyawan'}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="table-header">
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">ID</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Nama</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Role</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Telepon</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Email</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Status</th>
                  <th class="table-header px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredEmployees as emp}
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="table-cell font-mono text-xs text-gray-400">{emp.employee_id}</td>
                    <td class="table-cell font-medium text-gray-900">{emp.fullname}</td>
                    <td class="table-cell">
                      <span class="badge {getRoleBadge(emp.role)}">{getRoleLabel(emp.role)}</span>
                    </td>
                    <td class="table-cell text-gray-600 hidden md:table-cell">{emp.phone || '-'}</td>
                    <td class="table-cell text-gray-600 hidden lg:table-cell">{emp.email || '-'}</td>
                    <td class="table-cell">
                      <span class="badge {emp.is_active ? 'badge-success' : 'badge-danger'}">
                        {emp.is_active ? 'Aktif' : 'Nonaktif'}
                      </span>
                    </td>
                    <td class="table-cell">
                      <div class="flex items-center justify-center gap-1">
                        <button
                          class="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors"
                          onclick={() => openEditModal('karyawan', emp)}
                          title="Edit"
                        >
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                          </svg>
                        </button>
                        <button
                          class="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                          onclick={() => openDeleteModal('karyawan', emp)}
                          title="Hapus"
                        >
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                          </svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                {:else}
                  <tr>
                    <td colspan="7" class="table-cell text-center py-12 text-gray-400">
                      <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" />
                      </svg>
                      Tidak ada data karyawan
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
          <p class="text-xs text-gray-400 mt-3">Menampilkan {filteredEmployees.length} dari {employees.length} karyawan</p>

        <!-- ===================== POLI TAB ===================== -->
        {:else if activeTab === 'poli'}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="table-header">
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">ID</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Nama Poli</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Deskripsi</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Status</th>
                  <th class="table-header px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredClinics as clin}
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="table-cell font-mono text-xs text-gray-400">{clin.clinic_id}</td>
                    <td class="table-cell font-medium text-gray-900">{clin.name}</td>
                    <td class="table-cell text-gray-600 hidden md:table-cell max-w-xs truncate">{clin.description || '-'}</td>
                    <td class="table-cell">
                      <span class="badge {clin.is_active ? 'badge-success' : 'badge-danger'}">
                        {clin.is_active ? 'Aktif' : 'Nonaktif'}
                      </span>
                    </td>
                    <td class="table-cell">
                      <div class="flex items-center justify-center gap-1">
                        <button class="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" onclick={() => openEditModal('poli', clin)} title="Edit">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                          </svg>
                        </button>
                        <button class="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" onclick={() => openDeleteModal('poli', clin)} title="Hapus">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                          </svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                {:else}
                  <tr>
                    <td colspan="5" class="table-cell text-center py-12 text-gray-400">
                      <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" />
                      </svg>
                      Tidak ada data poli
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
          <p class="text-xs text-gray-400 mt-3">Menampilkan {filteredClinics.length} dari {clinics.length} poli</p>

        <!-- ===================== KAMAR & BED TAB ===================== -->
        {:else if activeTab === 'kamar'}
          <div class="space-y-8">
            <!-- Kelas Kamar Section -->
            <div>
              <h3 class="text-sm font-semibold text-gray-700 uppercase tracking-wide mb-3 flex items-center gap-2">
                <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z" />
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 6h.008v.008H6V6z" />
                </svg>
                Kelas Kamar
              </h3>
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead>
                    <tr class="table-header">
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">ID</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Nama Kelas</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Deskripsi</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Harga Dasar</th>
                      <th class="table-header px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Aksi</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    {#each filteredRoomClasses as rc}
                      <tr class="hover:bg-gray-50 transition-colors">
                        <td class="table-cell font-mono text-xs text-gray-400">{rc.class_id}</td>
                        <td class="table-cell font-medium text-gray-900">{rc.name}</td>
                        <td class="table-cell text-gray-600 hidden md:table-cell">{rc.description || '-'}</td>
                        <td class="table-cell text-gray-700">{formatCurrency(rc.base_price)}</td>
                        <td class="table-cell">
                          <div class="flex items-center justify-center gap-1">
                            <button class="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" onclick={() => openEditModal('room_class', rc)} title="Edit">
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                              </svg>
                            </button>
                            <button class="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" onclick={() => openDeleteModal('room_class', rc)} title="Hapus">
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                              </svg>
                            </button>
                          </div>
                        </td>
                      </tr>
                    {:else}
                      <tr>
                        <td colspan="5" class="table-cell text-center py-8 text-gray-400">Belum ada data kelas kamar</td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            </div>

            <!-- Kamar Section -->
            <div>
              <h3 class="text-sm font-semibold text-gray-700 uppercase tracking-wide mb-3 flex items-center gap-2">
                <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" />
                </svg>
                Daftar Kamar
              </h3>
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead>
                    <tr class="table-header">
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">ID</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">No. Kamar</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Kelas</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Poli</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Lantai</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Status</th>
                      <th class="table-header px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Aksi</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    {#each filteredRooms as room}
                      <tr class="hover:bg-gray-50 transition-colors">
                        <td class="table-cell font-mono text-xs text-gray-400">{room.room_id}</td>
                        <td class="table-cell font-medium text-gray-900">{room.room_number}</td>
                        <td class="table-cell text-gray-600">{getRoomClassLabel(room.class_id)}</td>
                        <td class="table-cell text-gray-600 hidden md:table-cell">{getClinicLabel(room.clinic_id)}</td>
                        <td class="table-cell text-gray-600 hidden lg:table-cell">{room.floor || '-'}</td>
                        <td class="table-cell">
                          <span class="badge {room.is_active ? 'badge-success' : 'badge-danger'}">
                            {room.is_active ? 'Aktif' : 'Nonaktif'}
                          </span>
                        </td>
                        <td class="table-cell">
                          <div class="flex items-center justify-center gap-1">
                            <button class="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" onclick={() => openEditModal('room', room)} title="Edit">
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                              </svg>
                            </button>
                            <button class="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" onclick={() => openDeleteModal('room', room)} title="Hapus">
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                              </svg>
                            </button>
                          </div>
                        </td>
                      </tr>
                    {:else}
                      <tr>
                        <td colspan="7" class="table-cell text-center py-8 text-gray-400">Belum ada data kamar</td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            </div>

            <!-- Bed Section -->
            <div>
              <h3 class="text-sm font-semibold text-gray-700 uppercase tracking-wide mb-3 flex items-center gap-2">
                <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5m8.25 3v6.75m0 0l-3-3m3 3l3-3M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
                </svg>
                Daftar Bed
              </h3>
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead>
                    <tr class="table-header">
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">ID</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">No. Bed</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Kamar</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Terisi</th>
                      <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Status</th>
                      <th class="table-header px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Aksi</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    {#each filteredBeds as bed}
                      <tr class="hover:bg-gray-50 transition-colors">
                        <td class="table-cell font-mono text-xs text-gray-400">{bed.bed_id}</td>
                        <td class="table-cell font-medium text-gray-900">{bed.bed_number}</td>
                        <td class="table-cell text-gray-600">{getRoomLabel(bed.room_id)}</td>
                        <td class="table-cell">
                          <span class="badge {bed.is_occupied ? 'badge-warning' : 'badge-success'}">
                            {bed.is_occupied ? 'Terisi' : 'Kosong'}
                          </span>
                        </td>
                        <td class="table-cell">
                          <span class="badge {bed.is_active ? 'badge-success' : 'badge-danger'}">
                            {bed.is_active ? 'Aktif' : 'Nonaktif'}
                          </span>
                        </td>
                        <td class="table-cell">
                          <div class="flex items-center justify-center gap-1">
                            <button class="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" onclick={() => openEditModal('bed', bed)} title="Edit">
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                              </svg>
                            </button>
                            <button class="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" onclick={() => openDeleteModal('bed', bed)} title="Hapus">
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                              </svg>
                            </button>
                          </div>
                        </td>
                      </tr>
                    {:else}
                      <tr>
                        <td colspan="6" class="table-cell text-center py-8 text-gray-400">Belum ada data bed</td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            </div>
          </div>

        <!-- ===================== OBAT TAB ===================== -->
        {:else if activeTab === 'obat'}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="table-header">
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">ID</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Nama Obat</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Kategori</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Satuan</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Harga Beli</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Harga Jual</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Stok</th>
                  <th class="table-header px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredDrugs as drug}
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="table-cell font-mono text-xs text-gray-400">{drug.drug_id}</td>
                    <td class="table-cell font-medium text-gray-900">{drug.name}</td>
                    <td class="table-cell text-gray-600 hidden md:table-cell">
                      <span class="badge badge-gray">{drug.category}</span>
                    </td>
                    <td class="table-cell text-gray-600">{drug.unit}</td>
                    <td class="table-cell text-gray-600 hidden lg:table-cell">{formatCurrency(drug.buy_price)}</td>
                    <td class="table-cell text-gray-700 font-medium">{formatCurrency(drug.sell_price)}</td>
                    <td class="table-cell">
                      <span class="badge {(drug.stock || 0) > 0 ? 'badge-success' : 'badge-danger'}">
                        {drug.stock || 0}
                      </span>
                    </td>
                    <td class="table-cell">
                      <div class="flex items-center justify-center gap-1">
                        <button class="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" onclick={() => openEditModal('obat', drug)} title="Edit">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                          </svg>
                        </button>
                        <button class="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" onclick={() => openDeleteModal('obat', drug)} title="Hapus">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                          </svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                {:else}
                  <tr>
                    <td colspan="8" class="table-cell text-center py-12 text-gray-400">
                      <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0112 15a9.065 9.065 0 00-6.23.693L5 14.5m14.8.8l1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0112 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5" />
                      </svg>
                      Tidak ada data obat
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
          <p class="text-xs text-gray-400 mt-3">Menampilkan {filteredDrugs.length} dari {drugs.length} obat</p>

        <!-- ===================== TARIF TAB ===================== -->
        {:else if activeTab === 'tarif'}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="table-header">
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">ID</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Nama Tarif</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Kategori</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Deskripsi</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Harga</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Status</th>
                  <th class="table-header px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredTariffs as tariff}
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="table-cell font-mono text-xs text-gray-400">{tariff.tariff_id}</td>
                    <td class="table-cell font-medium text-gray-900">{tariff.name}</td>
                    <td class="table-cell text-gray-600 hidden md:table-cell">
                      <span class="badge badge-info">{tariff.category}</span>
                    </td>
                    <td class="table-cell text-gray-600 hidden lg:table-cell max-w-xs truncate">{tariff.description || '-'}</td>
                    <td class="table-cell text-gray-700 font-medium">{formatCurrency(tariff.price)}</td>
                    <td class="table-cell">
                      <span class="badge {tariff.is_active ? 'badge-success' : 'badge-danger'}">
                        {tariff.is_active ? 'Aktif' : 'Nonaktif'}
                      </span>
                    </td>
                    <td class="table-cell">
                      <div class="flex items-center justify-center gap-1">
                        <button class="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" onclick={() => openEditModal('tarif', tariff)} title="Edit">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                          </svg>
                        </button>
                        <button class="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" onclick={() => openDeleteModal('tarif', tariff)} title="Hapus">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                          </svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                {:else}
                  <tr>
                    <td colspan="7" class="table-cell text-center py-12 text-gray-400">
                      <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z" />
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 6h.008v.008H6V6z" />
                      </svg>
                      Tidak ada data tarif
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
          <p class="text-xs text-gray-400 mt-3">Menampilkan {filteredTariffs.length} dari {tariffs.length} tarif</p>

        <!-- ===================== DIAGNOSIS TAB ===================== -->
        {:else if activeTab === 'diagnosis'}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="table-header">
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Kode ICD</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Nama Diagnosis</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Kategori</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Deskripsi</th>
                  <th class="table-header px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredDiagnoses as diag}
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="table-cell font-mono text-sm font-semibold text-primary-700">{diag.code}</td>
                    <td class="table-cell font-medium text-gray-900">{diag.name}</td>
                    <td class="table-cell text-gray-600 hidden md:table-cell">
                      {#if diag.category}
                        <span class="badge badge-gray">{diag.category}</span>
                      {:else}
                        -
                      {/if}
                    </td>
                    <td class="table-cell text-gray-600 hidden lg:table-cell max-w-xs truncate">{diag.description || '-'}</td>
                    <td class="table-cell">
                      <div class="flex items-center justify-center gap-1">
                        <button class="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" onclick={() => openEditModal('diagnosis', diag)} title="Edit">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                          </svg>
                        </button>
                        <button class="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" onclick={() => openDeleteModal('diagnosis', diag)} title="Hapus">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                          </svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                {:else}
                  <tr>
                    <td colspan="5" class="table-cell text-center py-12 text-gray-400">
                      <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5" />
                      </svg>
                      Tidak ada data diagnosis
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
          <p class="text-xs text-gray-400 mt-3">Menampilkan {filteredDiagnoses.length} dari {diagnoses.length} diagnosis</p>

        <!-- ===================== USER/PROFIL TAB ===================== -->
        {:else if activeTab === 'profil'}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="table-header">
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">ID</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Nama</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Email</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Role</th>
                  <th class="table-header px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Telepon</th>
                  <th class="table-header px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredProfiles as prof}
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="table-cell font-mono text-xs text-gray-400 truncate max-w-[120px]">{prof.id}</td>
                    <td class="table-cell font-medium text-gray-900">{prof.full_name || '-'}</td>
                    <td class="table-cell text-gray-600 hidden md:table-cell">{prof.email || '-'}</td>
                    <td class="table-cell">
                      <span class="badge {getRoleBadge(prof.role)}">{getRoleLabel(prof.role)}</span>
                    </td>
                    <td class="table-cell text-gray-600 hidden lg:table-cell">{prof.phone || '-'}</td>
                    <td class="table-cell">
                      <div class="flex items-center justify-center gap-1">
                        <button class="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" onclick={() => openEditModal('profil', prof)} title="Edit">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                          </svg>
                        </button>
                        <button class="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" onclick={() => openDeleteModal('profil', prof)} title="Hapus">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                          </svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                {:else}
                  <tr>
                    <td colspan="6" class="table-cell text-center py-12 text-gray-400">
                      <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
                      </svg>
                      Tidak ada data profil
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
          <p class="text-xs text-gray-400 mt-3">Menampilkan {filteredProfiles.length} dari {profiles.length} profil</p>
        {/if}
      {/if}
    </div>
  </div>
</div>

<!-- ===================== ADD/EDIT MODAL ===================== -->
{#if showModal}
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
    <div class="fixed inset-0 bg-black/50 transition-opacity" onclick={closeModal}></div>
    <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto scrollbar-thin">
      <div class="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 rounded-t-2xl flex items-center justify-between z-10">
        <h3 class="text-lg font-semibold text-gray-900">
          {modalMode === 'add' ? 'Tambah' : 'Edit'}
          {#if modalEntity === 'karyawan'}Data Karyawan
          {:else if modalEntity === 'poli'}Data Poli
          {:else if modalEntity === 'room_class'}Kelas Kamar
          {:else if modalEntity === 'room'}Data Kamar
          {:else if modalEntity === 'bed'}Data Bed
          {:else if modalEntity === 'obat'}Data Obat
          {:else if modalEntity === 'tarif'}Data Tarif
          {:else if modalEntity === 'diagnosis'}Data Diagnosis
          {:else if modalEntity === 'profil'}Data Profil
          {/if}
        </h3>
        <button class="p-2 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors" onclick={closeModal}>
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div class="p-6 space-y-4">

        <!-- Karyawan Form -->
        {#if modalEntity === 'karyawan'}
          <div>
            <label class="label">ID Karyawan</label>
            <input type="text" class="input-field bg-gray-50" bind:value={formData.employee_id} readonly />
          </div>
          <div>
            <label class="label">Nama Lengkap <span class="text-red-500">*</span></label>
            <input type="text" class="input-field" class:border-red-500={formErrors.full_name} placeholder="Masukkan nama lengkap" bind:value={formData.full_name} />
            {#if formErrors.full_name}<p class="text-xs text-red-500 mt-1">{formErrors.full_name}</p>{/if}
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="label">Gender</label>
              <select class="select-field" bind:value={formData.gender}>
                <option value="">-- Pilih Gender --</option>
                <option value="L">Laki-laki</option>
                <option value="P">Perempuan</option>
              </select>
            </div>
            <div>
              <label class="label">No. Telepon <span class="text-red-500">*</span></label>
              <input type="text" class="input-field" class:border-red-500={formErrors.phone} placeholder="08xxxxxxxxxx" bind:value={formData.phone} />
              {#if formErrors.phone}<p class="text-xs text-red-500 mt-1">{formErrors.phone}</p>{/if}
            </div>
          </div>
          <div>
            <label class="label">Role <span class="text-red-500">*</span></label>
            <select class="select-field" class:border-red-500={formErrors.role} bind:value={formData.role}>
              {#each Object.entries(ROLES) as [value, label]}
                <option value={value}>{label}</option>
              {/each}
            </select>
            {#if formErrors.role}<p class="text-xs text-red-500 mt-1">{formErrors.role}</p>{/if}
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="label">Email</label>
              <input type="email" class="input-field" placeholder="email@rs.com" bind:value={formData.email} />
            </div>
            <div>
              <label class="label">Spesialisasi</label>
              <input type="text" class="input-field" placeholder="Contoh: Anak, Penyakit Dalam" bind:value={formData.specialization} />
            </div>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="label">Departemen</label>
              <input type="text" class="input-field" placeholder="Contoh: Rawat Jalan" bind:value={formData.department} />
            </div>
            <div>
              <label class="label">ID Praktisi SATUSEHAT</label>
              <input type="text" class="input-field" placeholder="Opsional" bind:value={formData.satusehat_practitioner_id} />
            </div>
          </div>
          <div class="flex items-center gap-3">
            <label class="label mb-0">DPJP</label>
            <button
              class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors
                {formData.is_dpjp ? 'bg-primary-600' : 'bg-gray-300'}"
              onclick={() => formData.is_dpjp = !formData.is_dpjp}
            >
              <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform
                {formData.is_dpjp ? 'translate-x-6' : 'translate-x-1'}"></span>
            </button>
          </div>
          <div class="flex items-center gap-3">
            <label class="label mb-0">Status Aktif</label>
            <button
              class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors
                {formData.is_active ? 'bg-primary-600' : 'bg-gray-300'}"
              onclick={() => formData.is_active = !formData.is_active}
            >
              <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform
                {formData.is_active ? 'translate-x-6' : 'translate-x-1'}"></span>
            </button>
          </div>

        <!-- Poli Form -->
        {:else if modalEntity === 'poli'}
          <div>
            <label class="label">ID Poli</label>
            <input type="text" class="input-field bg-gray-50" bind:value={formData.clinic_id} readonly />
          </div>
          <div>
            <label class="label">Nama Poli <span class="text-red-500">*</span></label>
            <input type="text" class="input-field" class:border-red-500={formErrors.name} placeholder="Contoh: Poli Umum" bind:value={formData.name} />
            {#if formErrors.name}<p class="text-xs text-red-500 mt-1">{formErrors.name}</p>{/if}
          </div>
          <div>
            <label class="label">Deskripsi</label>
            <textarea class="input-field" rows="3" placeholder="Deskripsi poli..." bind:value={formData.description}></textarea>
          </div>
          <div class="flex items-center gap-3">
            <label class="label mb-0">Status Aktif</label>
            <button
              class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors
                {formData.is_active ? 'bg-primary-600' : 'bg-gray-300'}"
              onclick={() => formData.is_active = !formData.is_active}
            >
              <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform
                {formData.is_active ? 'translate-x-6' : 'translate-x-1'}"></span>
            </button>
          </div>

        <!-- Room Class Form -->
        {:else if modalEntity === 'room_class'}
          <div>
            <label class="label">ID Kelas</label>
            <input type="text" class="input-field bg-gray-50" bind:value={formData.class_id} readonly />
          </div>
          <div>
            <label class="label">Nama Kelas <span class="text-red-500">*</span></label>
            <input type="text" class="input-field" class:border-red-500={formErrors.name} placeholder="Contoh: Kelas I, Kelas II, VIP" bind:value={formData.name} />
            {#if formErrors.name}<p class="text-xs text-red-500 mt-1">{formErrors.name}</p>{/if}
          </div>
          <div>
            <label class="label">Deskripsi</label>
            <textarea class="input-field" rows="2" placeholder="Deskripsi kelas kamar..." bind:value={formData.description}></textarea>
          </div>
          <div>
            <label class="label">Harga Dasar per Malam <span class="text-red-500">*</span></label>
            <input type="number" class="input-field" class:border-red-500={formErrors.base_price} placeholder="0" min="0" bind:value={formData.base_price} />
            {#if formErrors.base_price}<p class="text-xs text-red-500 mt-1">{formErrors.base_price}</p>{/if}
          </div>

        <!-- Room Form -->
        {:else if modalEntity === 'room'}
          <div>
            <label class="label">ID Kamar</label>
            <input type="text" class="input-field bg-gray-50" bind:value={formData.room_id} readonly />
          </div>
          <div>
            <label class="label">Nomor Kamar <span class="text-red-500">*</span></label>
            <input type="text" class="input-field" class:border-red-500={formErrors.room_number} placeholder="Contoh: 101, A-201" bind:value={formData.room_number} />
            {#if formErrors.room_number}<p class="text-xs text-red-500 mt-1">{formErrors.room_number}</p>{/if}
          </div>
          <div>
            <label class="label">Kelas Kamar <span class="text-red-500">*</span></label>
            <select class="select-field" class:border-red-500={formErrors.class_id} bind:value={formData.class_id}>
              <option value="">-- Pilih Kelas --</option>
              {#each roomClasses as rc}
                <option value={rc.class_id}>{rc.name}</option>
              {/each}
            </select>
            {#if formErrors.class_id}<p class="text-xs text-red-500 mt-1">{formErrors.class_id}</p>{/if}
          </div>
          <div>
            <label class="label">Poli</label>
            <select class="select-field" bind:value={formData.clinic_id}>
              <option value="">-- Opsional --</option>
              {#each clinics as clinic}
                <option value={clinic.clinic_id}>{clinic.name}</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Lantai</label>
            <input type="text" class="input-field" placeholder="Contoh: 1, 2, 3" bind:value={formData.floor} />
          </div>
          <div class="flex items-center gap-3">
            <label class="label mb-0">Status Aktif</label>
            <button
              class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors
                {formData.is_active ? 'bg-primary-600' : 'bg-gray-300'}"
              onclick={() => formData.is_active = !formData.is_active}
            >
              <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform
                {formData.is_active ? 'translate-x-6' : 'translate-x-1'}"></span>
            </button>
          </div>

        <!-- Bed Form -->
        {:else if modalEntity === 'bed'}
          <div>
            <label class="label">ID Bed</label>
            <input type="text" class="input-field bg-gray-50" bind:value={formData.bed_id} readonly />
          </div>
          <div>
            <label class="label">Nomor Bed <span class="text-red-500">*</span></label>
            <input type="text" class="input-field" class:border-red-500={formErrors.bed_number} placeholder="Contoh: 01, 02" bind:value={formData.bed_number} />
            {#if formErrors.bed_number}<p class="text-xs text-red-500 mt-1">{formErrors.bed_number}</p>{/if}
          </div>
          <div>
            <label class="label">Kamar <span class="text-red-500">*</span></label>
            <select class="select-field" class:border-red-500={formErrors.room_id} bind:value={formData.room_id}>
              <option value="">-- Pilih Kamar --</option>
              {#each roomOptions as room}
                <option value={room.room_id}>{room.room_number} ({room.className})</option>
              {/each}
            </select>
            {#if formErrors.room_id}<p class="text-xs text-red-500 mt-1">{formErrors.room_id}</p>{/if}
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div class="flex items-center gap-3">
              <label class="label mb-0">Terisi</label>
              <button
                class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors
                  {formData.is_occupied ? 'bg-amber-500' : 'bg-gray-300'}"
                onclick={() => formData.is_occupied = !formData.is_occupied}
              >
                <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform
                  {formData.is_occupied ? 'translate-x-6' : 'translate-x-1'}"></span>
              </button>
            </div>
            <div class="flex items-center gap-3">
              <label class="label mb-0">Aktif</label>
              <button
                class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors
                  {formData.is_active ? 'bg-primary-600' : 'bg-gray-300'}"
                onclick={() => formData.is_active = !formData.is_active}
              >
                <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform
                  {formData.is_active ? 'translate-x-6' : 'translate-x-1'}"></span>
              </button>
            </div>
          </div>

        <!-- Obat Form -->
        {:else if modalEntity === 'obat'}
          <div>
            <label class="label">ID Obat</label>
            <input type="text" class="input-field bg-gray-50" bind:value={formData.drug_id} readonly />
          </div>
          <div>
            <label class="label">Nama Obat <span class="text-red-500">*</span></label>
            <input type="text" class="input-field" class:border-red-500={formErrors.name} placeholder="Nama obat" bind:value={formData.name} />
            {#if formErrors.name}<p class="text-xs text-red-500 mt-1">{formErrors.name}</p>{/if}
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="label">Kategori <span class="text-red-500">*</span></label>
              <select class="select-field" class:border-red-500={formErrors.category} bind:value={formData.category}>
                {#each DRUG_CATEGORIES as cat}
                  <option value={cat}>{cat}</option>
                {/each}
              </select>
              {#if formErrors.category}<p class="text-xs text-red-500 mt-1">{formErrors.category}</p>{/if}
            </div>
            <div>
              <label class="label">Satuan <span class="text-red-500">*</span></label>
              <select class="select-field" class:border-red-500={formErrors.unit} bind:value={formData.unit}>
                <option value="tablet">Tablet</option>
                <option value="kapul">Kapsul</option>
                <option value="botol">Botol</option>
                <option value="ampul">Ampul</option>
                <option value="vial">Vial</option>
                <option value="sachet">Sachet</option>
                <option value="tube">Tube</option>
                <option value="strip">Strip</option>
                <option value="box">Box</option>
                <option value="ml">ml</option>
                <option value="mg">mg</option>
                <option value="pcs">Pcs</option>
                <option value="lembar">Lembar</option>
              </select>
              {#if formErrors.unit}<p class="text-xs text-red-500 mt-1">{formErrors.unit}</p>{/if}
            </div>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="label">Harga Beli</label>
              <input type="number" class="input-field" placeholder="0" min="0" bind:value={formData.buy_price} />
            </div>
            <div>
              <label class="label">Harga Jual <span class="text-red-500">*</span></label>
              <input type="number" class="input-field" class:border-red-500={formErrors.sell_price} placeholder="0" min="0" bind:value={formData.sell_price} />
              {#if formErrors.sell_price}<p class="text-xs text-red-500 mt-1">{formErrors.sell_price}</p>{/if}
            </div>
          </div>
          <div>
            <label class="label">Stok</label>
            <input type="number" class="input-field" placeholder="0" min="0" bind:value={formData.stock} />
          </div>
          <div class="flex items-center gap-3">
            <label class="label mb-0">Status Aktif</label>
            <button
              class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors
                {formData.is_active ? 'bg-primary-600' : 'bg-gray-300'}"
              onclick={() => formData.is_active = !formData.is_active}
            >
              <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform
                {formData.is_active ? 'translate-x-6' : 'translate-x-1'}"></span>
            </button>
          </div>

        <!-- Tarif Form -->
        {:else if modalEntity === 'tarif'}
          <div>
            <label class="label">ID Tarif</label>
            <input type="text" class="input-field bg-gray-50" bind:value={formData.tariff_id} readonly />
          </div>
          <div>
            <label class="label">Nama Tarif <span class="text-red-500">*</span></label>
            <input type="text" class="input-field" class:border-red-500={formErrors.name} placeholder="Nama tarif / layanan" bind:value={formData.name} />
            {#if formErrors.name}<p class="text-xs text-red-500 mt-1">{formErrors.name}</p>{/if}
          </div>
          <div>
            <label class="label">Kategori <span class="text-red-500">*</span></label>
            <select class="select-field" class:border-red-500={formErrors.category} bind:value={formData.category}>
              {#each TARIFF_TYPES as cat}
                <option value={cat}>{cat}</option>
              {/each}
            </select>
            {#if formErrors.category}<p class="text-xs text-red-500 mt-1">{formErrors.category}</p>{/if}
          </div>
          <div>
            <label class="label">Deskripsi</label>
            <textarea class="input-field" rows="2" placeholder="Deskripsi tarif..." bind:value={formData.description}></textarea>
          </div>
          <div>
            <label class="label">Harga <span class="text-red-500">*</span></label>
            <input type="number" class="input-field" class:border-red-500={formErrors.price} placeholder="0" min="0" bind:value={formData.price} />
            {#if formErrors.price}<p class="text-xs text-red-500 mt-1">{formErrors.price}</p>{/if}
          </div>
          <div class="flex items-center gap-3">
            <label class="label mb-0">Status Aktif</label>
            <button
              class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors
                {formData.is_active ? 'bg-primary-600' : 'bg-gray-300'}"
              onclick={() => formData.is_active = !formData.is_active}
            >
              <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform
                {formData.is_active ? 'translate-x-6' : 'translate-x-1'}"></span>
            </button>
          </div>

        <!-- Diagnosis Form -->
        {:else if modalEntity === 'diagnosis'}
          <div>
            <label class="label">ID Diagnosis</label>
            <input type="text" class="input-field bg-gray-50" bind:value={formData.diagnosis_id} readonly />
          </div>
          <div>
            <label class="label">Kode ICD-10 <span class="text-red-500">*</span></label>
            <input type="text" class="input-field" class:border-red-500={formErrors.code} placeholder="Contoh: A00, J18.9" bind:value={formData.code} />
            {#if formErrors.code}<p class="text-xs text-red-500 mt-1">{formErrors.code}</p>{/if}
          </div>
          <div>
            <label class="label">Nama Diagnosis <span class="text-red-500">*</span></label>
            <input type="text" class="input-field" class:border-red-500={formErrors.name} placeholder="Nama penyakit / diagnosis" bind:value={formData.name} />
            {#if formErrors.name}<p class="text-xs text-red-500 mt-1">{formErrors.name}</p>{/if}
          </div>
          <div>
            <label class="label">Kategori</label>
            <input type="text" class="input-field" placeholder="Contoh: Penyakit Menular, Kardiovaskular" bind:value={formData.category} />
          </div>
          <div>
            <label class="label">Deskripsi</label>
            <textarea class="input-field" rows="3" placeholder="Deskripsi diagnosis..." bind:value={formData.description}></textarea>
          </div>

        <!-- Profil Form -->
        {:else if modalEntity === 'profil'}
          {#if modalMode === 'edit'}
            <div>
              <label class="label">ID User</label>
              <input type="text" class="input-field bg-gray-50" value={formData.id} readonly />
            </div>
          {/if}
          <div>
            <label class="label">Nama Lengkap <span class="text-red-500">*</span></label>
            <input type="text" class="input-field" class:border-red-500={formErrors.full_name} placeholder="Nama lengkap" bind:value={formData.full_name} />
            {#if formErrors.full_name}<p class="text-xs text-red-500 mt-1">{formErrors.full_name}</p>{/if}
          </div>
          <div>
            <label class="label">Email <span class="text-red-500">*</span></label>
            <input type="email" class="input-field" class:border-red-500={formErrors.email} placeholder="email@rs.com" bind:value={formData.email} readonly={modalMode === 'edit'} />
            {#if formErrors.email}<p class="text-xs text-red-500 mt-1">{formErrors.email}</p>{/if}
          </div>
          {#if modalMode === 'add'}
            <div>
              <label class="label">Password <span class="text-red-500">*</span></label>
              <input type="password" class="input-field" class:border-red-500={formErrors.password} placeholder="Minimal 6 karakter" bind:value={formData.password} />
              {#if formErrors.password}<p class="text-xs text-red-500 mt-1">{formErrors.password}</p>{/if}
            </div>
          {/if}
          <div>
            <label class="label">Role <span class="text-red-500">*</span></label>
            <select class="select-field" class:border-red-500={formErrors.role} bind:value={formData.role}>
              {#each Object.entries(ROLES) as [value, label]}
                <option value={value}>{label}</option>
              {/each}
            </select>
            {#if formErrors.role}<p class="text-xs text-red-500 mt-1">{formErrors.role}</p>{/if}
          </div>
          <div>
            <label class="label">Telepon</label>
            <input type="text" class="input-field" placeholder="08xxxxxxxxxx" bind:value={formData.phone} />
          </div>
        {/if}
      </div>

      <div class="sticky bottom-0 bg-white border-t border-gray-200 px-6 py-4 rounded-b-2xl flex items-center justify-end gap-3">
        <button class="btn-secondary" onclick={closeModal} disabled={saving}>
          Batal
        </button>
        <button class="btn-primary flex items-center gap-2" onclick={handleSave} disabled={saving}>
          {#if saving}
            <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
          {/if}
          {saving ? 'Menyimpan...' : 'Simpan'}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- ===================== DELETE CONFIRMATION MODAL ===================== -->
{#if showDeleteModal}
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
    <div class="fixed inset-0 bg-black/50 transition-opacity" onclick={closeDeleteModal}></div>
    <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-md p-6">
      <div class="flex flex-col items-center text-center">
        <div class="w-14 h-14 rounded-full bg-red-100 flex items-center justify-center mb-4">
          <svg class="w-7 h-7 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
          </svg>
        </div>
        <h3 class="text-lg font-semibold text-gray-900 mb-2">Hapus Data?</h3>
        <p class="text-sm text-gray-500 mb-6">
          Anda yakin ingin menghapus
          <span class="font-semibold text-gray-700">
            {#if deleteTarget}
              {#if deleteEntity === 'karyawan'}{deleteTarget.full_name}
              {:else if deleteEntity === 'poli'}{deleteTarget.name}
              {:else if deleteEntity === 'room_class'}{deleteTarget.name}
              {:else if deleteEntity === 'room'}Kamar {deleteTarget.room_number}
              {:else if deleteEntity === 'bed'}Bed {deleteTarget.bed_number}
              {:else if deleteEntity === 'obat'}{deleteTarget.name}
              {:else if deleteEntity === 'tarif'}{deleteTarget.name}
              {:else if deleteEntity === 'diagnosis'}{deleteTarget.code} - {deleteTarget.name}
              {:else if deleteEntity === 'profil'}{deleteTarget.full_name}
              {/if}
            {/if}
          </span>?
          Tindakan ini tidak dapat dibatalkan.
        </p>
        <div class="flex items-center gap-3 w-full">
          <button class="btn-secondary flex-1" onclick={closeDeleteModal} disabled={deleting}>
            Batal
          </button>
          <button class="btn-danger flex-1 flex items-center justify-center gap-2" onclick={handleDelete} disabled={deleting}>
            {#if deleting}
              <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
            {/if}
            {deleting ? 'Menghapus...' : 'Hapus'}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
