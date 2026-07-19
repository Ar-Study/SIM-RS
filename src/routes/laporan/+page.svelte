<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatCurrency, formatDate } from '$lib/utils/helpers.js';
  import { PAYOR_TYPES } from '$lib/utils/constants.js';

  let loading = $state(true);
  let activeTab = $state('performance');

  let dateFrom = $state(() => {
    const d = new Date();
    d.setDate(1);
    return d.toISOString().split('T')[0];
  });
  let dateTo = $state(new Date().toISOString().split('T')[0]);

  let totalBeds = $state(0);
  let occupiedBedDays = $state(0);
  let totalBedDays = $state(0);
  let emptyBedDays = $state(0);
  let totalPatientDays = $state(0);
  let totalDischarges = $state(0);

  let monthlyVisits = $state([]);
  let monthlyRevenue = $state([]);
  let rlReport = $state([]);
  let rlType = $state('3.1');
  let rlLoading = $state(false);
  let revenueByDept = $state([]);
  let revenueByPayor = $state([]);
  let revenuePeriod = $state('monthly');

  let summaryCards = $state([]);

  const bor = $derived(totalBedDays > 0 ? ((occupiedBedDays / totalBedDays) * 100).toFixed(1) : '0.0');
  const los = $derived(totalDischarges > 0 ? (totalPatientDays / totalDischarges).toFixed(1) : '0.0');
  const toi = $derived(totalDischarges > 0 ? (emptyBedDays / totalDischarges).toFixed(1) : '0.0');

  const maxMonthlyVisits = $derived.by(() => {
    if (monthlyVisits.length === 0) return 1;
    return Math.max(...monthlyVisits.map(m => m.count), 1);
  });

  const maxMonthlyRevenue = $derived.by(() => {
    if (monthlyRevenue.length === 0) return 1;
    return Math.max(...monthlyRevenue.map(m => m.total), 1);
  });

  async function fetchPerformanceData() {
    loading = true;
    try {
      const now = new Date();
      const firstDay = new Date(now.getFullYear(), now.getMonth(), 1);
      const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0);
      const daysInMonth = lastDay.getDate();

      const [bedsResult, visitsResult, dischargesResult, revenueResult] = await Promise.all([
        supabase
          .from('beds')
          .select('bed_id, is_occupied, is_active')
          .eq('is_active', true),
        supabase
          .from('patient_visitations')
          .select('visit_id, visit_date, visit_type, clinic_id, clinics:clinic_id(name), payor_type, total_cost')
          .gte('visit_date', firstDay.toISOString())
          .lte('visit_date', lastDay.toISOString()),
        supabase
          .from('patient_visitations')
          .select('visit_id, admission_date, discharge_date, visit_date')
          .eq('status_keluar', '1')
          .gte('discharge_date', firstDay.toISOString())
          .lte('discharge_date', lastDay.toISOString()),
        supabase
          .from('billing_invoices')
          .select('net_amount, paid_at, status')
          .eq('status', 'paid')
          .gte('paid_at', firstDay.toISOString())
          .lte('paid_at', lastDay.toISOString())
      ]);

      const activeBeds = bedsResult.data || [];
      totalBeds = activeBeds.length;
      totalBedDays = totalBeds * daysInMonth;
      occupiedBedDays = activeBeds.filter(b => b.is_occupied).length * daysInMonth;
      emptyBedDays = totalBedDays - occupiedBedDays;

      const allVisits = visitsResult.data || [];
      const dischargeData = dischargesResult.data || [];
      totalDischarges = dischargeData.length;
      totalPatientDays = dischargeData.reduce((sum, d) => {
        if (d.admission_date && d.discharge_date) {
          const adm = new Date(d.admission_date);
          const dis = new Date(d.discharge_date);
          return sum + Math.max(1, Math.ceil((dis - adm) / (1000 * 60 * 60 * 24)));
        }
        return sum + 1;
      }, 0);

      const clinicCounts = {};
      allVisits.forEach(v => {
        const name = v.clinics?.name || 'Lainnya';
        clinicCounts[name] = (clinicCounts[name] || 0) + 1;
      });
      summaryCards = Object.entries(clinicCounts)
        .map(([name, count]) => ({ name, count }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 5);

      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      const visitByMonth = {};
      const revenueByMonth = {};

      for (let i = 11; i >= 0; i--) {
        const d = new Date();
        d.setMonth(d.getMonth() - i);
        const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
        visitByMonth[key] = 0;
        revenueByMonth[key] = 0;
      }

      const [allVisitsYearResult, allRevenueYearResult] = await Promise.all([
        supabase
          .from('patient_visitations')
          .select('visit_id, visit_date')
          .gte('visit_date', new Date(new Date().setMonth(new Date().getMonth() - 11)).toISOString()),
        supabase
          .from('billing_invoices')
          .select('net_amount, paid_at')
          .eq('status', 'paid')
          .gte('paid_at', new Date(new Date().setMonth(new Date().getMonth() - 11)).toISOString())
      ]);

      (allVisitsYearResult.data || []).forEach(v => {
        const d = new Date(v.visit_date);
        const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
        if (key in visitByMonth) visitByMonth[key]++;
      });

      (allRevenueYearResult.data || []).forEach(r => {
        const d = new Date(r.paid_at);
        const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
        if (key in revenueByMonth) revenueByMonth[key] += r.net_amount || 0;
      });

      monthlyVisits = Object.entries(visitByMonth).map(([key, count]) => {
        const [y, m] = key.split('-');
        return { label: `${monthNames[parseInt(m) - 1]} ${y.slice(-2)}`, count };
      });

      monthlyRevenue = Object.entries(revenueByMonth).map(([key, total]) => {
        const [y, m] = key.split('-');
        return { label: `${monthNames[parseInt(m) - 1]} ${y.slice(-2)}`, total };
      });

      const payorCounts = {};
      allVisits.forEach(v => {
        const p = v.payor_type || 'personal';
        payorCounts[p] = (payorCounts[p] || 0) + (v.total_cost || 0);
      });
      revenueByPayor = Object.entries(payorCounts).map(([type, total]) => ({
        type: PAYOR_TYPES[type] || type,
        total
      })).sort((a, b) => b.total - a.total);

      const deptRevenue = {};
      allVisits.forEach(v => {
        const dept = v.clinics?.name || 'Lainnya';
        deptRevenue[dept] = (deptRevenue[dept] || 0) + (v.total_cost || 0);
      });
      revenueByDept = Object.entries(deptRevenue).map(([dept, total]) => ({
        dept, total
      })).sort((a, b) => b.total - a.total).slice(0, 8);

    } catch (err) {
      console.error('Performance fetch error:', err);
    } finally {
      loading = false;
    }
  }

  async function fetchRLReport() {
    rlLoading = true;
    rlReport = [];
    try {
      const from = new Date(dateFrom);
      const to = new Date(dateTo);

      if (rlType === '3.1') {
        const { data } = await supabase
          .from('patient_visitations')
          .select('visit_id, visit_date, visit_type, patients:patient_id(gender)')
          .gte('visit_date', from.toISOString())
          .lte('visit_date', to.toISOString());

        const months = {};
        (data || []).forEach(v => {
          const d = new Date(v.visit_date);
          const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
          if (!months[key]) months[key] = { laki: 0, perempuan: 0, total: 0 };
          const gender = v.patients?.gender;
          if (gender === 'L' || gender === 'M') months[key].laki++;
          else months[key].perempuan++;
          months[key].total++;
        });

        rlReport = Object.entries(months).sort((a, b) => b[0].localeCompare(a[0])).map(([month, data]) => ({
          bulan: month, ...data
        }));
      } else if (rlType === '3.2') {
        const { data } = await supabase
          .from('patient_visitations')
          .select('visit_id, visit_date, status_keluar, diagnosis_masuk, clinics:clinic_id(name), rooms:room_id(name, room_classes:class_id(name))')
          .eq('visit_type', 'rawat_inap')
          .gte('visit_date', from.toISOString())
          .lte('visit_date', to.toISOString());

        rlReport = (data || []).map(v => ({
          visit_id: v.visit_id,
          clinic: v.clinics?.name || '-',
          room: v.rooms?.name || '-',
          kelas: v.rooms?.room_classes?.name || '-',
          diagnosis: v.diagnosis_masuk || '-',
          status: v.status_keluar === '1' ? 'Keluar' : 'Masih Dirawat'
        }));
      } else if (rlType === '3.4') {
        const { data } = await supabase
          .from('patient_visitations')
          .select('visit_id, visit_date, patients:patient_id(no_registration)')
          .gte('visit_date', from.toISOString())
          .lte('visit_date', to.toISOString());

        const patientVisits = {};
        (data || []).forEach(v => {
          const reg = v.patients?.no_registration || v.visit_id;
          if (!patientVisits[reg]) patientVisits[reg] = { first: true, count: 0, dates: [] };
          patientVisits[reg].count++;
          patientVisits[reg].dates.push(v.visit_date);
        });

        let baru = 0;
        let ulang = 0;
        Object.values(patientVisits).forEach(pv => {
          if (pv.count === 1) baru++;
          else ulang++;
        });

        rlReport = [{ bulan: `${formatDate(from)} - ${formatDate(to)}`, baru, ulang, total: baru + ulang }];
      } else if (rlType === '5.2') {
        const { data } = await supabase
          .from('patient_visitations')
          .select('visit_id, visit_date, diagnosis_masuk')
          .eq('visit_type', 'rawat_jalan')
          .gte('visit_date', from.toISOString())
          .lte('visit_date', to.toISOString());

        const diagCounts = {};
        (data || []).forEach(v => {
          const diag = v.diagnosis_masuk || 'Tidak Diketahui';
          diagCounts[diag] = (diagCounts[diag] || 0) + 1;
        });

        rlReport = Object.entries(diagCounts)
          .map(([diagnosis, jumlah]) => ({ diagnosis, jumlah }))
          .sort((a, b) => b.jumlah - a.jumlah)
          .slice(0, 10);
      } else if (rlType === '5.3') {
        const { data } = await supabase
          .from('patient_visitations')
          .select('visit_id, visit_date, diagnosis_masuk')
          .gte('visit_date', from.toISOString())
          .lte('visit_date', to.toISOString());

        const diagCounts = {};
        (data || []).forEach(v => {
          const diag = v.diagnosis_masuk || 'Tidak Diketahui';
          diagCounts[diag] = (diagCounts[diag] || 0) + 1;
        });

        rlReport = Object.entries(diagCounts)
          .map(([diagnosis, jumlah]) => ({ diagnosis, jumlah }))
          .sort((a, b) => b.jumlah - a.jumlah)
          .slice(0, 10);
      }
    } catch (err) {
      console.error('RL Report error:', err);
    } finally {
      rlLoading = false;
    }
  }

  async function fetchRevenueData() {
    loading = true;
    try {
      const now = new Date();
      let fromDate;
      if (revenuePeriod === 'daily') {
        fromDate = new Date(now);
        fromDate.setDate(1);
      } else if (revenuePeriod === 'weekly') {
        fromDate = new Date(now);
        fromDate.setDate(now.getDate() - 28);
      } else {
        fromDate = new Date(now);
        fromDate.setMonth(now.getMonth() - 5);
      }

      const { data } = await supabase
        .from('billing_invoices')
        .select('net_amount, paid_at, status, visit_id, patient_visitations:visit_id(payor_type, clinics:clinic_id(name))')
        .eq('status', 'paid')
        .gte('paid_at', fromDate.toISOString())
        .lte('paid_at', now.toISOString());

      const periodRevenue = {};
      const deptRev = {};
      const payorRev = {};

      (data || []).forEach(inv => {
        const d = new Date(inv.paid_at);
        let key;
        if (revenuePeriod === 'daily') {
          key = `${d.getDate()}/${d.getMonth() + 1}`;
        } else if (revenuePeriod === 'weekly') {
          key = `W${Math.ceil(d.getDate() / 7)} ${['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'][d.getMonth()]}`;
        } else {
          key = `${['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'][d.getMonth()]} ${d.getFullYear().toString().slice(-2)}`;
        }
        periodRevenue[key] = (periodRevenue[key] || 0) + (inv.net_amount || 0);

        const dept = inv.patient_visitations?.clinics?.name || 'Lainnya';
        deptRev[dept] = (deptRev[dept] || 0) + (inv.net_amount || 0);

        const payor = inv.patient_visitations?.payor_type || 'personal';
        payorRev[payor] = (payorRev[payor] || 0) + (inv.net_amount || 0);
      });

      monthlyRevenue = Object.entries(periodRevenue).map(([label, total]) => ({ label, total }));
      revenueByDept = Object.entries(deptRev).map(([dept, total]) => ({ dept, total })).sort((a, b) => b.total - a.total);
      revenueByPayor = Object.entries(payorRev).map(([type, total]) => ({
        type: PAYOR_TYPES[type] || type,
        total
      })).sort((a, b) => b.total - a.total);

    } catch (err) {
      console.error('Revenue fetch error:', err);
    } finally {
      loading = false;
    }
  }

  function handleExportPDF() {
    const title = `Laporan RL ${rlType}`;
    let content = `${title}\nPeriode: ${formatDate(dateFrom)} - ${formatDate(dateTo)}\n\n`;

    if (rlReport.length > 0) {
      const headers = Object.keys(rlReport[0]);
      content += headers.join(' | ') + '\n';
      content += headers.map(() => '---').join(' | ') + '\n';
      rlReport.forEach(row => {
        content += headers.map(h => row[h] ?? '-').join(' | ') + '\n';
      });
    } else {
      content += 'Tidak ada data\n';
    }

    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${title.replace(/\s+/g, '_')}.txt`;
    a.click();
    URL.revokeObjectURL(url);
  }

  onMount(async () => {
    await fetchPerformanceData();
  });
</script>

<svelte:head>
  <title>Laporan & Analitik - SIMRS</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Laporan & Analitik</h1>
      <p class="text-sm text-gray-500 mt-1">Dashboard analitik, laporan RL, dan pendapatan</p>
    </div>
  </div>

  <div class="card p-0">
    <div class="flex overflow-x-auto border-b border-gray-200 scrollbar-thin">
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'performance'
            ? 'border-primary-600 text-primary-700 bg-primary-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => activeTab = 'performance'}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />
        </svg>
        Performance
      </button>
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'rl'
            ? 'border-primary-600 text-primary-700 bg-primary-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => { activeTab = 'rl'; if (rlReport.length === 0) fetchRLReport(); }}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
        </svg>
        Laporan RL
      </button>
      <button
        class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
          {activeTab === 'pendapatan'
            ? 'border-primary-600 text-primary-700 bg-primary-50'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
        onclick={() => { activeTab = 'pendapatan'; fetchRevenueData(); }}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        Laporan Pendapatan
      </button>
    </div>

    <div class="p-6">
      {#if activeTab === 'performance'}
        <div class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="bg-gradient-to-br from-blue-500 to-blue-700 rounded-xl p-6 text-white">
              <p class="text-blue-100 text-sm font-medium uppercase tracking-wide">BOR (Bed Occupancy Rate)</p>
              <p class="text-4xl font-bold mt-2">{bor}%</p>
              <p class="text-blue-200 text-xs mt-1">{occupiedBedDays.toLocaleString()} / {totalBedDays.toLocaleString()} hari tempat tidur</p>
            </div>
            <div class="bg-gradient-to-br from-emerald-500 to-emerald-700 rounded-xl p-6 text-white">
              <p class="text-emerald-100 text-sm font-medium uppercase tracking-wide">LOS (Length of Stay)</p>
              <p class="text-4xl font-bold mt-2">{los}</p>
              <p class="text-emerald-200 text-xs mt-1">hari rata-rata per pasien</p>
            </div>
            <div class="bg-gradient-to-br from-amber-500 to-amber-700 rounded-xl p-6 text-white">
              <p class="text-amber-100 text-sm font-medium uppercase tracking-wide">TOI (Turnover Interval)</p>
              <p class="text-4xl font-bold mt-2">{toi}</p>
              <p class="text-amber-200 text-xs mt-1">hari rata-rata kosong per keluar</p>
            </div>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="card">
              <h3 class="text-base font-semibold text-gray-900 mb-4">Kunjungan Bulanan (12 Bulan)</h3>
              {#if loading}
                <div class="flex items-center justify-center py-12">
                  <div class="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
                </div>
              {:else if monthlyVisits.length === 0}
                <p class="text-center text-gray-400 py-8">Belum ada data</p>
              {:else}
                <div class="space-y-2">
                  {#each monthlyVisits as month}
                    {@const barW = Math.round((month.count / maxMonthlyVisits) * 100)}
                    <div class="flex items-center gap-3">
                      <span class="text-xs text-gray-500 w-14 text-right shrink-0">{month.label}</span>
                      <div class="flex-1 bg-gray-100 rounded-full h-6 overflow-hidden">
                        <div class="h-full rounded-full bg-blue-500 flex items-center px-2 transition-all duration-500"
                          style="width: {Math.max(barW, 2)}%">
                          {#if barW > 15}
                            <span class="text-xs font-bold text-white whitespace-nowrap">{month.count}</span>
                          {/if}
                        </div>
                      </div>
                      {#if barW <= 15}
                        <span class="text-xs font-semibold text-gray-600 w-8">{month.count}</span>
                      {/if}
                    </div>
                  {/each}
                </div>
              {/if}
            </div>

            <div class="card">
              <h3 class="text-base font-semibold text-gray-900 mb-4">Pendapatan Bulanan (12 Bulan)</h3>
              {#if loading}
                <div class="flex items-center justify-center py-12">
                  <div class="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
                </div>
              {:else if monthlyRevenue.length === 0}
                <p class="text-center text-gray-400 py-8">Belum ada data</p>
              {:else}
                <div class="space-y-2">
                  {#each monthlyRevenue as month}
                    {@const barW = Math.round((month.total / maxMonthlyRevenue) * 100)}
                    <div class="flex items-center gap-3">
                      <span class="text-xs text-gray-500 w-14 text-right shrink-0">{month.label}</span>
                      <div class="flex-1 bg-gray-100 rounded-full h-6 overflow-hidden">
                        <div class="h-full rounded-full bg-emerald-500 flex items-center px-2 transition-all duration-500"
                          style="width: {Math.max(barW, 2)}%">
                          {#if barW > 20}
                            <span class="text-xs font-bold text-white whitespace-nowrap">{formatCurrency(month.total)}</span>
                          {/if}
                        </div>
                      </div>
                      {#if barW <= 20}
                        <span class="text-xs font-semibold text-gray-600 truncate max-w-[100px]">{formatCurrency(month.total)}</span>
                      {/if}
                    </div>
                  {/each}
                </div>
              {/if}
            </div>
          </div>

          <div class="card">
            <h3 class="text-base font-semibold text-gray-900 mb-4">Top 5 Poli Hari Ini</h3>
            {#if summaryCards.length === 0}
              <p class="text-center text-gray-400 py-6">Belum ada data hari ini</p>
            {:else}
              <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-3">
                {#each summaryCards as sc, i}
                  <div class="bg-gray-50 rounded-lg p-4 text-center">
                    <p class="text-2xl font-bold {i === 0 ? 'text-primary-600' : 'text-gray-900'}">{sc.count}</p>
                    <p class="text-xs text-gray-500 mt-1 truncate">{sc.name}</p>
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        </div>

      {:else if activeTab === 'rl'}
        <div class="space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <h3 class="text-lg font-semibold text-gray-900">Laporan RL (Rekam Medis Laporan)</h3>
            <div class="flex flex-wrap gap-2">
              {#each ['3.1', '3.2', '3.4', '5.2', '5.3'] as rl}
                <button
                  class="px-3 py-1.5 text-sm font-medium rounded-lg transition-colors
                    {rlType === rl ? 'bg-primary-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}"
                  onclick={() => { rlType = rl; fetchRLReport(); }}
                >
                  RL {rl}
                </button>
              {/each}
            </div>
          </div>

          <div class="flex flex-col sm:flex-row gap-3 items-end">
            <div class="space-y-1">
              <label class="label text-xs">Dari Tanggal</label>
              <input type="date" class="input-field text-sm" bind:value={dateFrom} />
            </div>
            <div class="space-y-1">
              <label class="label text-xs">Sampai Tanggal</label>
              <input type="date" class="input-field text-sm" bind:value={dateTo} />
            </div>
            <button class="btn-primary btn-sm" onclick={fetchRLReport}>
              <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
              </svg>
              Tampilkan
            </button>
            <button class="btn-secondary btn-sm" onclick={handleExportPDF}>
              <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
              </svg>
              Export
            </button>
          </div>

          <p class="text-sm text-gray-500">
            {#if rlType === '3.1'}Indikator layanan berdasarkan bulan dan jenis kelamin
            {:else if rlType === '3.2'}Data rawat inap berdasarkan poli, kamar, dan status keluar
            {:else if rlType === '3.4'}Pasien baru vs pasien ulang
            {:else if rlType === '5.2'}Top 10 diagnosis baru rawat jalan
            {:else if rlType === '5.3'}Top 10 diagnosis kunjungan rawat jalan
            {/if}
          </p>

          {#if rlLoading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          {:else if rlReport.length === 0}
            <div class="text-center py-16 text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
              </svg>
              <p class="text-lg font-medium">Tidak ada data</p>
              <p class="text-sm mt-1">Pilih periode dan jenis laporan untuk menampilkan data</p>
            </div>
          {:else}
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="table-header">
                    {#each Object.keys(rlReport[0]) as col}
                      <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase capitalize">{col.replace(/_/g, ' ')}</th>
                    {/each}
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  {#each rlReport as row, i}
                    <tr class="hover:bg-gray-50 transition-colors">
                      {#each Object.keys(row) as col}
                        <td class="table-cell {typeof row[col] === 'number' ? 'font-mono text-right' : ''}">
                          {#if col.includes('total') || col.includes('jumlah')}
                            <span class="font-semibold">{typeof row[col] === 'number' ? row[col].toLocaleString() : row[col]}</span>
                          {:else if typeof row[col] === 'number'}
                            {row[col].toLocaleString()}
                          {:else}
                            {row[col]}
                          {/if}
                        </td>
                      {/each}
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </div>

      {:else if activeTab === 'pendapatan'}
        <div class="space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <h3 class="text-lg font-semibold text-gray-900">Laporan Pendapatan</h3>
            <div class="flex gap-2">
              {#each [
                { value: 'daily', label: 'Harian' },
                { value: 'weekly', label: 'Mingguan' },
                { value: 'monthly', label: 'Bulanan' }
              ] as period}
                <button
                  class="px-3 py-1.5 text-sm font-medium rounded-lg transition-colors
                    {revenuePeriod === period.value ? 'bg-primary-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}"
                  onclick={() => { revenuePeriod = period.value; fetchRevenueData(); }}
                >
                  {period.label}
                </button>
              {/each}
            </div>
          </div>

          {#if loading}
            <div class="flex items-center justify-center py-16">
              <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          {:else}
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div class="card">
                <h4 class="text-base font-semibold text-gray-900 mb-4">Trend Pendapatan</h4>
                {#if monthlyRevenue.length === 0}
                  <p class="text-center text-gray-400 py-8">Belum ada data</p>
                {:else}
                  <div class="space-y-2">
                    {#each monthlyRevenue as month}
                      {@const barW = Math.round((month.total / maxMonthlyRevenue) * 100)}
                      <div class="flex items-center gap-3">
                        <span class="text-xs text-gray-500 w-14 text-right shrink-0">{month.label}</span>
                        <div class="flex-1 bg-gray-100 rounded-full h-6 overflow-hidden">
                          <div class="h-full rounded-full bg-emerald-500 flex items-center px-2 transition-all duration-500"
                            style="width: {Math.max(barW, 2)}%">
                            {#if barW > 25}
                              <span class="text-xs font-bold text-white whitespace-nowrap">{formatCurrency(month.total)}</span>
                            {/if}
                          </div>
                        </div>
                      </div>
                    {/each}
                  </div>
                {/if}
              </div>

              <div class="card">
                <h4 class="text-base font-semibold text-gray-900 mb-4">Pendapatan per Payor</h4>
                {#if revenueByPayor.length === 0}
                  <p class="text-center text-gray-400 py-8">Belum ada data</p>
                {:else}
                  {@const totalPayor = revenueByPayor.reduce((s, p) => s + p.total, 0)}
                  <div class="space-y-4">
                    {#each revenueByPayor as payor}
                      {@const pct = totalPayor > 0 ? ((payor.total / totalPayor) * 100).toFixed(1) : 0}
                      <div class="space-y-1">
                        <div class="flex justify-between text-sm">
                          <span class="font-medium text-gray-700">{payor.type}</span>
                          <span class="text-gray-500">{formatCurrency(payor.total)} ({pct}%)</span>
                        </div>
                        <div class="w-full bg-gray-100 rounded-full h-3">
                          <div class="h-3 rounded-full bg-primary-500 transition-all duration-500"
                            style="width: {pct}%"></div>
                        </div>
                      </div>
                    {/each}
                  </div>
                {/if}
              </div>

              <div class="card lg:col-span-2">
                <h4 class="text-base font-semibold text-gray-900 mb-4">Pendapatan per Departemen</h4>
                {#if revenueByDept.length === 0}
                  <p class="text-center text-gray-400 py-8">Belum ada data</p>
                {:else}
                  <div class="overflow-x-auto">
                    <table class="w-full">
                      <thead>
                        <tr class="table-header">
                          <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                          <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Departemen</th>
                          <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Pendapatan</th>
                          <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">% dari Total</th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-gray-100">
                        {#each revenueByDept as dept, i}
                          {@const totalDept = revenueByDept.reduce((s, d) => s + d.total, 0)}
                          {@const deptPct = totalDept > 0 ? ((dept.total / totalDept) * 100).toFixed(1) : 0}
                          <tr class="hover:bg-gray-50 transition-colors">
                            <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                            <td class="table-cell font-medium text-gray-900">{dept.dept}</td>
                            <td class="table-cell text-right font-semibold text-gray-900">{formatCurrency(dept.total)}</td>
                            <td class="table-cell text-right text-gray-500">{deptPct}%</td>
                          </tr>
                        {/each}
                      </tbody>
                    </table>
                  </div>
                {/if}
              </div>
            </div>
          {/if}
        </div>
      {/if}
    </div>
  </div>
</div>
