import jsPDF from 'jspdf';

function formatDate(dateStr) {
  if (!dateStr) return '-';
  const d = new Date(dateStr);
  const day = String(d.getDate()).padStart(2, '0');
  const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  return `${day} ${months[d.getMonth()]} ${d.getFullYear()} ${hh}:${mm}`;
}

export function generateTiket(data) {
  const ticketWidth = 80;
  const ticketHeight = 140;
  const doc = new jsPDF({
    orientation: 'portrait',
    unit: 'mm',
    format: [ticketWidth, ticketHeight],
  });

  const centerX = ticketWidth / 2;
  let y = 8;

  doc.setFontSize(9);
  doc.setFont('helvetica', 'bold');
  doc.text('RS BUNGA BANGSA MEDIKA', centerX, y, { align: 'center' });

  y += 5;
  doc.setFontSize(7);
  doc.setFont('helvetica', 'normal');
  doc.text('Jl. Lili, Kembang, Maguwoharjo', centerX, y, { align: 'center' });
  y += 4;
  doc.text('Depok, Sleman, DIY', centerX, y, { align: 'center' });

  y += 3;
  doc.setLineWidth(0.3);
  doc.line(5, y, ticketWidth - 5, y);

  y += 6;
  doc.setFontSize(16);
  doc.setFont('helvetica', 'bold');
  doc.text(data.ticketNo || '-', centerX, y, { align: 'center' });

  y += 8;
  doc.setFontSize(14);
  doc.text(`No. ${data.queuePosition || '-'}`, centerX, y, { align: 'center' });

  y += 6;
  doc.setLineWidth(0.2);
  doc.line(5, y, ticketWidth - 5, y);

  y += 6;
  doc.setFontSize(7);
  doc.setFont('helvetica', 'normal');
  const fields = [
    ['Nama', data.patientName],
    ['Klinik', data.clinic],
    ['Dokter', data.doctor],
    ['Tanggal', formatDate(data.date)],
  ];

  fields.forEach(([label, value]) => {
    doc.setFont('helvetica', 'bold');
    doc.text(`${label}:`, 5, y);
    doc.setFont('helvetica', 'normal');
    doc.text(value || '-', 22, y);
    y += 5;
  });

  y += 2;
  doc.line(5, y, ticketWidth - 5, y);

  y += 5;
  doc.setFontSize(7);
  doc.setFont('helvetica', 'italic');
  doc.text('Simpan tiket ini dengan baik.', centerX, y, { align: 'center' });
  y += 4;
  doc.text('Harap hadir sebelum jadwal', centerX, y, { align: 'center' });

  doc.save(`tiket-${data.ticketNo || 'draft'}.pdf`);
}
