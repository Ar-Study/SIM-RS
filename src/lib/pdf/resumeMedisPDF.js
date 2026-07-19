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

function drawSectionTitle(doc, title, y) {
  doc.setFontSize(11);
  doc.setFont('helvetica', 'bold');
  doc.text(title, 20, y);
  doc.setLineWidth(0.3);
  doc.line(20, y + 1.5, doc.internal.pageSize.getWidth() - 20, y + 1.5);
  return y + 7;
}

function drawFieldValue(doc, label, value, y, labelWidth = 50) {
  doc.setFontSize(10);
  doc.setFont('helvetica', 'bold');
  doc.text(label, 20, y);
  doc.setFont('helvetica', 'normal');
  doc.text(value || '-', 20 + labelWidth, y);
  return y + 6;
}

function drawWrappedField(doc, label, value, y, maxWidth) {
  doc.setFontSize(10);
  doc.setFont('helvetica', 'bold');
  doc.text(label, 20, y);
  y += 6;
  doc.setFont('helvetica', 'normal');
  if (value) {
    const lines = doc.splitTextToSize(value, maxWidth || doc.internal.pageSize.getWidth() - 40);
    doc.text(lines, 20, y);
    y += lines.length * 5;
  } else {
    doc.text('-', 20, y);
    y += 5;
  }
  return y;
}

export function generateResumeMedis(data) {
  const doc = new jsPDF();
  const pageWidth = doc.internal.pageSize.getWidth();
  let y = addHospitalHeader(doc);

  y += 5;
  doc.setFontSize(13);
  doc.setFont('helvetica', 'bold');
  doc.text('RESUME MEDIS', pageWidth / 2, y, { align: 'center' });

  y += 12;
  y = drawSectionTitle(doc, 'Data Pasien', y);
  y = drawFieldValue(doc, 'Nama', data.patientName, y);
  y = drawFieldValue(doc, 'No. RM', data.patientNoRM, y);
  y = drawFieldValue(doc, 'NIK', data.nik, y);
  y = drawFieldValue(doc, 'Tanggal Lahir', formatDate(data.dob), y);
  y = drawFieldValue(doc, 'Jenis Kelamin', data.gender, y);
  y = drawFieldValue(doc, 'Tanggal Kunjungan', formatDate(data.visitDate), y);

  y += 3;
  y = drawSectionTitle(doc, 'Diagnosa', y);
  y = drawWrappedField(doc, 'Diagnosa:', data.diagnosis, y);

  y += 3;
  y = drawSectionTitle(doc, 'Tindakan / Perawatan', y);
  y = drawWrappedField(doc, 'Tindakan:', data.treatment, y);

  y += 3;
  y = drawSectionTitle(doc, 'Obat-obatan', y);
  y = drawWrappedField(doc, 'Obat:', data.medications, y);

  y += 3;
  y = drawSectionTitle(doc, 'Kondisi Pulang', y);
  y = drawWrappedField(doc, 'Kondisi:', data.dischargeCondition, y);

  y += 15;
  const sigX = pageWidth - 60;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text('Dokter Penulis Resume', 20, y);
  doc.text('Pasien / Keluarga', sigX, y, { align: 'center' });
  y += 20;
  doc.line(10, y, 55, y);
  doc.line(sigX - 25, y, sigX + 25, y);
  y += 6;
  doc.text(`${data.doctorName || '-'}`, 20, y);

  doc.save(`resume-medis-${data.patientNoRM || 'draft'}.pdf`);
}
