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

function splitTicketNumber(ticketNo) {
  const raw = String(ticketNo || '-');
  if (raw.length <= 3) return { prefix: '', suffix: raw };
  return { prefix: raw.slice(0, -3), suffix: raw.slice(-3) };
}

export function generateTiket(data) {
  const ticketWidth = 80;
  const ticketHeight = 145;
  const doc = new jsPDF({
    orientation: 'portrait',
    unit: 'mm',
    format: [ticketWidth, ticketHeight],
  });

  const centerX = ticketWidth / 2;
  let y = 8;

  doc.setFontSize(9);
  doc.setFont('helvetica', 'bold');
  doc.text('SIMRS - ANJUNGAN MANDIRI', centerX, y, { align: 'center' });

  y += 4.5;
  doc.setFontSize(7);
  doc.setFont('helvetica', 'normal');
  doc.text('Sistem Informasi Manajemen Rumah Sakit', centerX, y, { align: 'center' });

  y += 3.5;
  doc.setLineWidth(0.3);
  doc.line(5, y, ticketWidth - 5, y);

  const { prefix, suffix } = splitTicketNumber(data.ticketNo);

  y += 6;
  doc.setFontSize(7);
  doc.setFont('helvetica', 'bold');
  doc.text('NOMOR ANTREAN', centerX, y, { align: 'center' });

  if (prefix) {
    y += 5;
    doc.setFontSize(9);
    doc.setFont('helvetica', 'normal');
    doc.text(prefix, centerX, y, { align: 'center' });
  }

  y += 11;
  doc.setFontSize(28);
  doc.setFont('helvetica', 'bold');
  doc.text(suffix, centerX, y, { align: 'center' });

  if (data.queuePosition) {
    y += 6;
    doc.setFontSize(9);
    doc.setFont('helvetica', 'normal');
    doc.text(`Urutan Poli: No. ${data.queuePosition}`, centerX, y, { align: 'center' });
  }

  y += 5;
  doc.setLineWidth(0.2);
  doc.line(5, y, ticketWidth - 5, y);

  y += 6;
  doc.setFontSize(7);
  const fields = [
    ['Nama', data.patientName],
    ['No. RM', data.noRm],
    ['Klinik', data.clinic],
    ['Dokter', data.doctor],
    ['Jam', data.slot],
    ['Tanggal', formatDate(data.date)],
  ].filter(([, val]) => val);

  fields.forEach(([label, value]) => {
    doc.setFont('helvetica', 'bold');
    doc.text(`${label}:`, 5, y);
    doc.setFont('helvetica', 'normal');
    doc.text(String(value || '-'), 22, y);
    y += 5;
  });

  y += 2;
  doc.line(5, y, ticketWidth - 5, y);

  y += 5;
  doc.setFontSize(7);
  doc.setFont('helvetica', 'italic');
  doc.text('Simpan tiket ini dengan baik.', centerX, y, { align: 'center' });
  y += 4;
  doc.text('Harap hadir sebelum jadwal pemeriksaan.', centerX, y, { align: 'center' });

  doc.save(`antrean-${data.ticketNo || 'draft'}.pdf`);
}

/** Render a PNG queue ticket onto an offscreen canvas and trigger browser download. */
export function generateTiketImage(data) {
  const width = 640;
  const height = 920;
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  // Background
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, width, height);

  // Header band
  ctx.fillStyle = '#1d4ed8';
  ctx.fillRect(0, 0, width, 130);

  ctx.fillStyle = '#ffffff';
  ctx.textAlign = 'center';
  ctx.font = 'bold 28px sans-serif';
  ctx.fillText('SIMRS', width / 2, 56);
  ctx.font = '18px sans-serif';
  ctx.fillStyle = '#dbeafe';
  ctx.fillText('Anjungan Pasien Mandiri', width / 2, 92);

  // Dashed ticket box
  ctx.strokeStyle = '#cbd5e1';
  ctx.lineWidth = 3;
  ctx.setLineDash([10, 8]);
  ctx.strokeRect(48, 170, width - 96, 310);
  ctx.setLineDash([]);

  ctx.fillStyle = '#64748b';
  ctx.font = 'bold 18px sans-serif';
  ctx.fillText('NOMOR ANTREAN', width / 2, 220);

  const { prefix, suffix } = splitTicketNumber(data.ticketNo);
  if (prefix) {
    ctx.fillStyle = '#94a3b8';
    ctx.font = '600 26px monospace';
    ctx.fillText(prefix, width / 2, 278);
  }

  ctx.fillStyle = '#1d4ed8';
  ctx.font = 'bold 132px monospace';
  ctx.fillText(suffix, width / 2, prefix ? 415 : 385);

  // Details
  const details = [
    ['Nama Pasien', data.patientName || '-'],
    ['No. RM', data.noRm || '-'],
    ['Klinik / Poli', data.clinic || '-'],
    ['Dokter', data.doctor || '-'],
    ['Jam Layanan', data.slot || '-'],
    ['Tanggal', formatDate(data.date)],
  ];

  let y = 540;
  ctx.font = '20px sans-serif';
  for (const [label, value] of details) {
    ctx.textAlign = 'left';
    ctx.fillStyle = '#64748b';
    ctx.fillText(label, 56, y);

    ctx.textAlign = 'right';
    ctx.fillStyle = '#0f172a';
    ctx.font = 'bold 20px sans-serif';
    ctx.fillText(String(value).slice(0, 32), width - 56, y);
    ctx.font = '20px sans-serif';

    ctx.strokeStyle = '#f1f5f9';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(56, y + 16);
    ctx.lineTo(width - 56, y + 16);
    ctx.stroke();

    y += 48;
  }

  // Footer note
  ctx.textAlign = 'center';
  ctx.fillStyle = '#64748b';
  ctx.font = 'italic 16px sans-serif';
  ctx.fillText('Simpan tiket ini dan harap hadir sebelum jadwal.', width / 2, 875);

  const link = document.createElement('a');
  link.download = `antrean-${data.ticketNo || 'tiket'}.png`;
  link.href = canvas.toDataURL('image/png');
  link.click();
}
