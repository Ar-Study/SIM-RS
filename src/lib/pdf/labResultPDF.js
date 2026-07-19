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

export function generateLabResult(data) {
  const doc = new jsPDF();
  const pageWidth = doc.internal.pageSize.getWidth();
  let y = addHospitalHeader(doc);

  y += 5;
  doc.setFontSize(13);
  doc.setFont('helvetica', 'bold');
  doc.text('HASIL PEMERIKSAAN LABORATORIUM', pageWidth / 2, y, { align: 'center' });

  y += 10;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'bold');
  const leftLabels = ['Nama Pasien', 'No. RM', 'Dokter'];
  const leftValues = [data.patientName, data.patientNoRM, data.doctorName];
  const rightLabels = ['Tanggal Pemeriksaan', 'Selesai'];
  const rightValues = [formatDateTime(data.orderDate), formatDateTime(data.completedDate)];

  leftLabels.forEach((label, i) => {
    doc.text(`${label} :`, 20, y + i * 6);
    doc.setFont('helvetica', 'normal');
    doc.text(leftValues[i] || '-', 65, y + i * 6);
    doc.setFont('helvetica', 'bold');
  });

  rightLabels.forEach((label, i) => {
    doc.text(`${label} :`, 120, y + i * 6);
    doc.setFont('helvetica', 'normal');
    doc.text(rightValues[i] || '-', 165, y + i * 6);
    doc.setFont('helvetica', 'bold');
  });

  y += 22;
  doc.setFont('helvetica', 'bold');
  doc.text('Hasil Pemeriksaan:', 20, y);
  y += 3;

  const items = (data.items || []).map((item) => {
    const flag = item.flag || '';
    let flagText = '';
    let flagColor = [0, 0, 0];
    if (flag === 'high' || flag === 'H') {
      flagText = 'Tinggi';
      flagColor = [231, 76, 60];
    } else if (flag === 'low' || flag === 'L') {
      flagText = 'Rendah';
      flagColor = [52, 152, 219];
    } else if (flag === 'normal' || flag === 'N' || flag === '') {
      flagText = 'Normal';
      flagColor = [39, 174, 96];
    }
    return [
      item.name || '-',
      item.category || '-',
      item.normalValue || '-',
      item.result || '-',
      item.unit || '-',
      flagText,
    ];
  });

  doc.autoTable({
    startY: y,
    head: [['Pemeriksaan', 'Kategori', 'Nilai Normal', 'Hasil', 'Satuan', 'Keterangan']],
    body: items,
    theme: 'grid',
    headStyles: { fillColor: [142, 68, 173], fontSize: 8 },
    bodyStyles: { fontSize: 8 },
    columnStyles: {
      0: { cellWidth: 40 },
      1: { cellWidth: 28 },
      2: { cellWidth: 28 },
      3: { halign: 'center', cellWidth: 22 },
      4: { halign: 'center', cellWidth: 18 },
      5: { halign: 'center', cellWidth: 22 },
    },
    didParseCell: function (hookData) {
      if (hookData.section === 'body' && hookData.column.index === 5) {
        const val = hookData.cell.raw;
        if (val === 'Tinggi') {
          hookData.cell.styles.textColor = [231, 76, 60];
          hookData.cell.styles.fontStyle = 'bold';
        } else if (val === 'Rendah') {
          hookData.cell.styles.textColor = [52, 152, 219];
          hookData.cell.styles.fontStyle = 'bold';
        } else {
          hookData.cell.styles.textColor = [39, 174, 96];
        }
      }
    },
    margin: { left: 20, right: 20 },
  });

  y = doc.lastAutoTable.finalY + 15;
  doc.setFont('helvetica', 'normal');
  doc.text('Dokter Pemeriksa', 20, y);
  doc.text(`${data.doctorName || '-'}`, 20, y + 20);
  doc.line(20, y + 22, 80, y + 22);

  doc.save(`hasil-lab-${data.patientNoRM || 'draft'}.pdf`);
}
