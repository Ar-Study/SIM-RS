import jsPDF from 'jspdf';

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

function drawFieldValue(doc, label, value, y, labelWidth = 45) {
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text(`${label} : ${value || '-'}`, 30, y);
  return y + 6;
}

function drawWrappedBody(doc, text, y, indent = 30, maxWidth = 150) {
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  if (text) {
    const lines = doc.splitTextToSize(text, maxWidth);
    doc.text(lines, indent, y);
    y += lines.length * 5.5;
  }
  return y;
}

export function generateSuratKeterangan(data) {
  const doc = new jsPDF();
  const pageWidth = doc.internal.pageSize.getWidth();
  let y = addHospitalHeader(doc);

  y += 8;
  doc.setFontSize(13);
  doc.setFont('helvetica', 'bold');
  doc.text('SURAT KETERANGAN', pageWidth / 2, y, { align: 'center' });
  doc.setFontSize(10);
  doc.text(`No: ${data.letterNo || 'SK/-/2026'}`, pageWidth / 2, y + 6, { align: 'center' });

  y += 14;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  const intro = `Yang bertanda tangan di bawah ini, dokter dari ${HOSPITAL.name}, menerangkan bahwa:`;
  y = drawWrappedBody(doc, intro, y, 30, pageWidth - 60);
  y += 4;

  y = drawFieldValue(doc, 'Nama', data.patientName, y);
  y = drawFieldValue(doc, 'No. RM', data.patientNoRM, y);
  y = drawFieldValue(doc, 'Tanggal Lahir', formatDate(data.dob), y);
  y = drawFieldValue(doc, 'Jenis Kelamin', data.gender, y);
  y = drawFieldValue(doc, 'Alamat', data.address, y);

  y += 6;
  const body = data.keterangan || data.diagnosis || 'Telah diperiksa dan dirawat oleh dokter kami.';
  const conditionText = `Bahwa berdasarkan pemeriksaan pada tanggal ${formatDate(data.visitDate)}, pasien tersebut di atas dinyatakan: ${data.diagnosis || 'dalam keadaan sehat/berobat jalan'}.`;
  y = drawWrappedBody(doc, conditionText, y, 30, pageWidth - 60);
  y += 4;
  y = drawWrappedBody(doc, body, y, 30, pageWidth - 60);
  y += 4;
  y = drawWrappedBody(doc, 'Surat keterangan ini dibuat untuk dipergunakan sebagaimana mestinya.', y, 30, pageWidth - 60);

  y += 18;
  const sigX = pageWidth - 60;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text(`Dokter Penanggung Jawab,`, 20, y);
  doc.text(`${formatDate(data.date)}`, sigX, y, { align: 'center' });
  y += 24;
  doc.line(10, y, 60, y);
  doc.line(sigX - 25, y, sigX + 25, y);
  y += 6;
  doc.text(`${data.doctorName || '-'}`, 20, y);

  doc.save(`surat-keterangan-${data.patientNoRM || 'draft'}.pdf`);
}
