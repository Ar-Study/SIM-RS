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

export function generatePrescription(data) {
  const doc = new jsPDF();
  const pageWidth = doc.internal.pageSize.getWidth();
  let y = addHospitalHeader(doc);

  y += 5;
  doc.setFontSize(13);
  doc.setFont('helvetica', 'bold');
  doc.text('RESEP DOKTER', pageWidth / 2, y, { align: 'center' });

  y += 10;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'bold');
  doc.text('Dokter:', 20, y);
  doc.setFont('helvetica', 'normal');
  doc.text(data.doctorName || '-', 50, y);
  if (data.doctorSpecialty) {
    doc.setFont('helvetica', 'italic');
    doc.text(`(${data.doctorSpecialty})`, 50 + doc.getTextWidth(data.doctorName || '-') + 3, y);
  }

  y += 6;
  doc.setFont('helvetica', 'bold');
  doc.text('Pasien  :', 20, y);
  doc.setFont('helvetica', 'normal');
  doc.text(`${data.patientName || '-'}  (No. RM: ${data.patientNoRM || '-'})`, 50, y);

  y += 6;
  doc.setFont('helvetica', 'bold');
  doc.text('Tanggal :', 20, y);
  doc.setFont('helvetica', 'normal');
  doc.text(formatDate(data.date), 50, y);

  y += 10;
  doc.setFont('helvetica', 'bold');
  doc.text('Obat-obatan:', 20, y);
  y += 3;

  const items = (data.items || []).map((item, idx) => [
    String(idx + 1),
    item.drugName || '-',
    item.dosage || '-',
    item.frequency || '-',
    item.duration || '-',
    item.instruction || '-',
  ]);

  doc.autoTable({
    startY: y,
    head: [['No', 'Nama Obat', 'Dosis', 'Frekuensi', 'Durasi', 'Aturan Pakai']],
    body: items,
    theme: 'grid',
    headStyles: { fillColor: [39, 174, 96], fontSize: 8 },
    bodyStyles: { fontSize: 8 },
    columnStyles: {
      0: { halign: 'center', cellWidth: 10 },
      1: { cellWidth: 40 },
      2: { cellWidth: 25 },
      3: { cellWidth: 25 },
      4: { cellWidth: 20 },
      5: { cellWidth: 55 },
    },
    margin: { left: 20, right: 20 },
  });

  y = doc.lastAutoTable.finalY + 8;

  if (data.notes) {
    doc.setFont('helvetica', 'bold');
    doc.text('Catatan:', 20, y);
    doc.setFont('helvetica', 'normal');
    const splitNotes = doc.splitTextToSize(data.notes, pageWidth - 40);
    doc.text(splitNotes, 20, y + 6);
    y += 6 + splitNotes.length * 5;
  }

  y += 15;
  doc.setFont('helvetica', 'normal');
  doc.text('Dokter Penulis Resep', 20, y);
  doc.text(`${data.doctorName || '-'}`, 20, y + 20);
  doc.line(20, y + 22, 80, y + 22);

  doc.save(`resep-${data.patientNoRM || 'draft'}.pdf`);
}
