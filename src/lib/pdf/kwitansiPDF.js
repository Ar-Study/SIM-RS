import jsPDF from 'jspdf';
import 'jspdf-autotable';

const HOSPITAL = {
  name: 'RUMAH SAKIT BUNGA BANGSA MEDIKA',
  address: 'Jl. Lili, Kembang, Maguwoharjo, Depok, Sleman, DIY',
  phone: '(0274) 123-4567',
};

function formatCurrency(amount) {
  if (amount == null) return 'Rp 0';
  const num = Number(amount);
  return 'Rp ' + num.toLocaleString('id-ID');
}

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

export function generateKwitansi(data) {
  const doc = new jsPDF();
  const pageWidth = doc.internal.pageSize.getWidth();
  let y = addHospitalHeader(doc);

  y += 5;
  doc.setFontSize(13);
  doc.setFont('helvetica', 'bold');
  doc.text('KWITANSI / TANDA BUKTI PEMBAYARAN', pageWidth / 2, y, { align: 'center' });

  y += 10;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text(`No. Kwitansi : ${data.invoiceId || '-'}`, 20, y);
  doc.text(`Tanggal     : ${formatDate(data.paymentDate || data.visitDate)}`, 20, y + 6);

  y += 18;
  doc.setFont('helvetica', 'bold');
  doc.text('Data Pasien', 20, y);
  doc.setFont('helvetica', 'normal');
  y += 6;
  doc.text(`Nama  : ${data.patientName || '-'}`, 20, y);
  doc.text(`No.RM : ${data.patientNoRM || '-'}`, 20, y + 5);
  doc.text(`Tgl Periksa : ${formatDate(data.visitDate)}`, 120, y);

  y += 16;
  doc.setFont('helvetica', 'bold');
  doc.text('Rincian Biaya', 20, y);
  y += 3;

  const items = (data.items || []).map((item, idx) => [
    String(idx + 1),
    item.description || '-',
    String(item.qty || 0),
    formatCurrency(item.price),
    formatCurrency(item.total),
  ]);

  doc.autoTable({
    startY: y,
    head: [['No', 'Deskripsi', 'Qty', 'Harga', 'Subtotal']],
    body: items,
    theme: 'grid',
    headStyles: { fillColor: [41, 128, 185], fontSize: 9 },
    bodyStyles: { fontSize: 9 },
    columnStyles: {
      0: { halign: 'center', cellWidth: 12 },
      1: { cellWidth: 80 },
      2: { halign: 'center', cellWidth: 18 },
      3: { halign: 'right', cellWidth: 35 },
      4: { halign: 'right', cellWidth: 35 },
    },
    margin: { left: 20, right: 20 },
  });

  y = doc.lastAutoTable.finalY + 8;

  const summaryX = 110;
  doc.setFont('helvetica', 'normal');
  doc.text('Total', summaryX, y);
  doc.text(formatCurrency(data.totalAmount), pageWidth - 20, y, { align: 'right' });

  if (data.discount) {
    y += 6;
    doc.text('Diskon', summaryX, y);
    doc.text(`-${formatCurrency(data.discount)}`, pageWidth - 20, y, { align: 'right' });
  }

  y += 7;
  doc.setDrawColor(0);
  doc.setLineWidth(0.3);
  doc.line(summaryX, y - 3, pageWidth - 20, y - 3);
  doc.setFont('helvetica', 'bold');
  doc.text('TOTAL BAYAR', summaryX, y);
  doc.text(formatCurrency(data.netAmount || data.totalAmount), pageWidth - 20, y, { align: 'right' });

  y += 10;
  doc.setFont('helvetica', 'normal');
  doc.text(`Metode Pembayaran : ${data.paymentMethod || '-'}`, 20, y);
  doc.text(`Tanggal Bayar     : ${formatDate(data.paymentDate)}`, 20, y + 6);

  y += 25;
  const sigX = pageWidth - 60;
  doc.setFont('helvetica', 'normal');
  doc.text('Yang Menerima', 20, y);
  doc.text('Kasir', sigX, y, { align: 'center' });
  y += 20;
  doc.line(10, y, 55, y);
  doc.line(sigX - 25, y, sigX + 25, y);

  doc.save(`kwitansi-${data.invoiceId || 'draft'}.pdf`);
}
