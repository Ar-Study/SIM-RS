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
  const time = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  return `${formatDate(dateStr)} ${time} WIB`;
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

function drawWrappedText(doc, label, value, y, indent = 20, labelWidth = 55) {
  const pageWidth = doc.internal.pageSize.getWidth();
  doc.setFontSize(10);
  if (label) {
    doc.setFont('helvetica', 'bold');
    doc.text(label, indent, y);
  }
  doc.setFont('helvetica', 'normal');
  const maxWidth = pageWidth - indent - 20 - (label ? labelWidth : 0);
  const text = value || '-';
  const lines = doc.splitTextToSize(text, maxWidth);
  if (label) {
    doc.text(lines, indent + labelWidth, y);
  } else {
    doc.text(lines, indent, y);
  }
  return y + Math.max(lines.length, 1) * 5;
}

export function generateCppt(data) {
  const doc = new jsPDF();
  const pageWidth = doc.internal.pageSize.getWidth();
  let y = addHospitalHeader(doc);

  y += 5;
  doc.setFontSize(13);
  doc.setFont('helvetica', 'bold');
  doc.text('CATATAN PERKEMBANGAN PASIEN TERINTEGRASI', pageWidth / 2, y, { align: 'center' });
  doc.setFontSize(10);
  doc.text('(CPPT / SOAP)', pageWidth / 2, y + 5, { align: 'center' });

  y += 12;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'bold');
  doc.text('Nama Pasien:', 20, y);
  doc.setFont('helvetica', 'normal');
  doc.text(`${data.patientName || '-'}  (No. RM: ${data.patientNoRM || '-'})`, 55, y);

  y += 6;
  doc.setFont('helvetica', 'bold');
  doc.text('Tanggal:', 20, y);
  doc.setFont('helvetica', 'normal');
  doc.text(`${formatDate(data.visitDate)}`, 55, y);

  y += 6;
  doc.setFont('helvetica', 'bold');
  doc.text('Dokter:', 20, y);
  doc.setFont('helvetica', 'normal');
  doc.text(`${data.doctorName || '-'}`, 55, y);

  const entries = data.entries || [];
  if (entries.length === 0) {
    doc.text('Belum ada catatan CPPT.', 20, y + 10);
  }

  entries.forEach((entry, idx) => {
    const startY = y;
    if (y > 250) {
      doc.addPage();
      y = 40;
    }
    y += 8;
    doc.setFontSize(9);
    doc.setFont('helvetica', 'bold');
    doc.text(`CPPT ke-${idx + 1}  •  ${formatDateTime(entry.created_at)}`, 20, y);
    doc.setLineWidth(0.2);
    doc.line(20, y + 1.5, pageWidth - 20, y + 1.5);
    y += 5;
    y = drawWrappedText(doc, 'S (Subyektif):', entry.subyektif, y);
    y = drawWrappedText(doc, 'O (Obyektif):', entry.obyektif, y);
    y = drawWrappedText(doc, 'A (Assesment):', entry.assessment, y);
    y = drawWrappedText(doc, 'P (Planning):', entry.planning, y);
    y = drawWrappedText(doc, 'Instruksi:', entry.instruksi, y);
    y += 2;
  });

  y += 12;
  const sigX = pageWidth - 60;
  if (y > 260) {
    doc.addPage();
    y = 40;
  }
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text('Dokter Pemeriksa', 20, y);
  y += 20;
  doc.line(10, y, 55, y);
  y += 6;
  doc.text(`${data.doctorName || '-'}`, 20, y);

  doc.save(`cppt-${data.patientNoRM || 'draft'}.pdf`);
}
