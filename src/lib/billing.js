import { supabase } from '$lib/supabase.js';

export async function addTreatmentBill({
  visit_id,
  description,
  tariff_type = 'Tindakan',
  unit_price = 0,
  qty = 1,
  tariff_id = null,
  source_type = null,
  source_id = null
}) {
  if (!visit_id || !description) return null;

  if (source_type && source_id) {
    const { data: existing } = await supabase
      .from('treatment_bills')
      .select('id')
      .eq('visit_id', visit_id)
      .eq('source_type', source_type)
      .eq('source_id', String(source_id))
      .maybeSingle();
    if (existing) return existing;
  }

  const price = Number(unit_price) || 0;
  const quantity = Number(qty) || 1;
  const { data, error } = await supabase
    .from('treatment_bills')
    .insert({
      visit_id,
      tariff_id,
      quantity: quantity,
      unit_price: price,
      amount: price * quantity,
      tariff_type,
      description,
      source_type,
      source_id: source_id != null ? String(source_id) : null
    })
    .select()
    .single();

  if (error) console.error('Add treatment bill error:', error);
  return data || null;
}

export async function removeBillBySource(visit_id, source_type, source_id) {
  if (!source_type || source_id == null) return;
  const { error } = await supabase
    .from('treatment_bills')
    .delete()
    .eq('visit_id', visit_id)
    .eq('source_type', source_type)
    .eq('source_id', String(source_id));
  if (error) console.error('Remove treatment bill error:', error);
}

export async function addConsultationBill(visit_id, clinic_id) {
  if (!visit_id) return null;
  try {
    const { data, error } = await supabase
      .from('tariffs')
      .select('tariff_id, name, clinic_id, price')
      .eq('category', 'Konsultasi')
      .eq('is_active', true);
    if (error) throw error;

    let chosen = null;
    if (data?.length) {
      chosen = data.find(t => clinic_id && t.clinic_id === clinic_id)
        || data.find(t => !t.clinic_id)
        || data[0];
    }

    return addTreatmentBill({
      visit_id,
      description: chosen?.name || 'Konsultasi Dokter',
      tariff_type: 'Konsultasi',
      unit_price: chosen?.price || 0,
      tariff_id: chosen?.tariff_id || null,
      source_type: 'konsultasi',
      source_id: visit_id
    });
  } catch (err) {
    console.error('Add consultation bill error:', err);
    return null;
  }
}

export async function addLabBill(visit_id, testName, orderId) {
  if (!visit_id || !testName) return null;
  try {
    const { data: test } = await supabase
      .from('lab_test_catalog')
      .select('price')
      .ilike('test_name', testName)
      .limit(1)
      .maybeSingle();

    return addTreatmentBill({
      visit_id,
      description: testName,
      tariff_type: 'Laboratorium',
      unit_price: test?.price || 0,
      source_type: 'lab',
      source_id: orderId
    });
  } catch (err) {
    console.error('Add lab bill error:', err);
    return null;
  }
}

export async function addRadiologyBill(visit_id, examType, orderId) {
  if (!visit_id || !examType) return null;
  try {
    const { data: exam } = await supabase
      .from('radiology_catalog')
      .select('price')
      .ilike('exam_type', examType)
      .limit(1)
      .maybeSingle();

    return addTreatmentBill({
      visit_id,
      description: examType,
      tariff_type: 'Radiologi',
      unit_price: exam?.price || 0,
      source_type: 'radiology',
      source_id: orderId
    });
  } catch (err) {
    console.error('Add radiology bill error:', err);
    return null;
  }
}

export async function addDrugBill(visit_id, drugId, drugName, qty, prescriptionId) {
  if (!visit_id) return null;
  try {
    let price = 0;
    if (drugId) {
      const { data: drug } = await supabase
        .from('drugs')
        .select('sell_price')
        .eq('drug_id', drugId)
        .maybeSingle();
      price = drug?.sell_price || 0;
    }

    return addTreatmentBill({
      visit_id,
      description: drugName || 'Obat',
      tariff_type: 'Obat',
      unit_price: price,
      qty,
      source_type: 'prescription',
      source_id: prescriptionId
    });
  } catch (err) {
    console.error('Add drug bill error:', err);
    return null;
  }
}
