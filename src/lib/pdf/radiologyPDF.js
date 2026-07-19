import jsPDF from 'jspdf';
import 'jspdf-autotable';

const HOSPITAL = {
  name: 'RUMAH SAKIT BUNGA BANGSA MEDIKA',
  address: 'Jl. Lili, Kembang, Maguwoharjo, Depok, Sleman, DIY',
  phone: '(0274) 123-4567',
};

function formatDate(dateStr) {
  if (!dateStr) return '-';
  const d = new Date(dateStr);
  const day = String(d.getDate()).padStart(2, '0');
  const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
  return `${day} ${months[d.getMonth()]} ${d.getFullYear()}`;
}

function formatDateTime(dateStr) {
  if (!dateStr) return '-';
  const d = new Date(dateStr);
  const day = String(d.getDate()).padStart(2, '0');
  const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  return `${day} ${months[d.getMonth()]} ${d.getFullYear()} ${hh}:${mm}`;
}

function addHospitalHeader(doc) {
  const pageWidth = doc.internal.pageSize.getWidth();
  const centerX = pageWidth / 2;

  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text(HOSPITAL.name, centerX, 15, { align: 'center' });

  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  doc.text(HOSPITAL.address, centerX, 21, { align: 'center' });
  doc.text(`Telp: ${HOSPITAL.phone}`, centerX, 26, { align: 'center' });

  doc.setDrawColor(0);
  doc.setLineWidth(0.5);
  doc.line(20, 30, pageWidth - 20, 30);

  return 35;
}

export function generateRadiologyReport(data) {
  const doc = new jsPDF();
  const pageWidth = doc.internal.pageSize.getWidth();
  const contentWidth = pageWidth - 40;
  let y = addHospitalHeader(doc);

  y += 5;
  doc.setFontSize(13);
  doc.setFont('helvetica', 'bold');
  doc.text('LAPORAN RADIOLOGI', pageWidth / 2, y, { align: 'center' });

  y += 12;
  doc.setFontSize(10);

  const fields = [
    ['Nama Pasien', data.patientName],
    ['No. RM', data.patientNoRM],
    ['Jenis Pemeriksaan', data.examinationType],
    ['Bagian Tubuh', data.bodyPart],
    ['Dokter', data.doctorName],
    ['Tanggal Pemeriksaan', formatDateTime(data.orderDate)],
    ['Tanggal Selesai', formatDateTime(data.completedDate)],
  ];

  fields.forEach(([label, value]) => {
    doc.setFont('helvetica', 'bold');
    doc.text(`${label} :`, 20, y);
    doc.setFont('helvetica', 'normal');
    doc.text(value || '-', 75, y);
    y += 6;
  });

  if (data.clinicalInfo) {
    y += 3;
    doc.setFont('helvetica', 'bold');
    doc.text('Informasi Klinis:', 20, y);
    y += 6;
    doc.setFont('helvetica', 'normal');
    const splitClinical = doc.splitTextToSize(data.clinicalInfo, contentWidth);
    doc.text(splitClinical, 20, y);
    y += splitClinical.length * 5;
  }

  y += 5;
  doc.setFont('helvetica', 'bold');
  doc.text('Hasil Pemeriksaan:', 20, y);
  y += 6;
  doc.setFont('helvetica', 'normal');
  if (data.result) {
    const splitResult = doc.splitTextToSize(data.result, contentWidth);
    doc.text(splitResult, 20, y);
    y += splitResult.length * 5;
  } else {
    doc.text('-', 20, y);
    y += 5;
  }

  y += 5;
  doc.setFont('helvetica', 'bold');
  doc.text('Kesan / Impression:', 20, y);
  y += 6;
  doc.setFont('helvetica', 'normal');
  if (data.impression) {
    const splitImpression = doc.splitTextToSize(data.impression, contentWidth);
    doc.text(splitImpression, 20, y);
    y += splitImpression.length * 5;
  } else {
    doc.text('-', 20, y);
    y += 5;
  }

  y += 20;
  doc.setFont('helvetica', 'normal');
  doc.text('Dokter Radiologi', 20, y);
  doc.text(`${data.doctorName || '-'}`, 20, y + 20);
  doc.line(20, y + 22, 80, y + 22);

  doc.save(`radiologi-${data.patientNoRM || 'draft'}.pdf`);
}
