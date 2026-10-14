import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants/asset_constants.dart';
import '../models/penawaran_model.dart';

class PenawaranPdfService {
  static final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static const _kShortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  static String _formatDate(String ymd) {
    if (ymd.isEmpty) return '-';
    try {
      final clean = ymd.trim().split('T')[0].split(' ')[0];
      final parts = clean.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null && m >= 1 && m <= 12) {
          return '$d ${_kShortMonths[m - 1]} $y';
        }
      }
      final dt = DateTime.parse(clean);
      return '${dt.day} ${_kShortMonths[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return ymd;
    }
  }

  static Future<void> exportPenawaran({
    required PenawaranHeader header,
    required List<PenawaranDetailItem> details,
  }) async {
    // 1. Muat font Unicode (agar karakter khusus/bullet tidak menyebabkan crash)
    pw.Font? regularFont;
    pw.Font? boldFont;
    try {
      regularFont = await PdfGoogleFonts.robotoRegular();
      boldFont = await PdfGoogleFonts.robotoBold();
    } catch (_) {
      try {
        regularFont = await PdfGoogleFonts.openSansRegular();
        boldFont = await PdfGoogleFonts.openSansBold();
      } catch (_) {}
    }

    final theme = regularFont != null && boldFont != null
        ? pw.ThemeData.withFont(base: regularFont, bold: boldFont)
        : pw.ThemeData.base();

    final pdf = pw.Document(theme: theme);

    // 2. Load Kop Asset Image jika ada
    pw.MemoryImage? kopImage;
    try {
      final assetPath = AppAssets.getPenawaranKop(header.perusahaanKode);
      final bytes = await rootBundle.load(assetPath);
      kopImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final grandTotal =
        details.fold<double>(0.0, (acc, curr) => acc + curr.total);
    final upLabel = header.up.trim().isNotEmpty ? header.up.trim() : '-';
    final ttdName =
        header.ttd.trim().isNotEmpty ? header.ttd.trim() : 'Pimpinan';
    final ttdJabatan = header.ttdJabatan.trim().isNotEmpty
        ? header.ttdJabatan.trim()
        : 'Manager';
    final isSigned = header.digitalSign.toUpperCase() == 'Y' ||
        header.approvalState.toUpperCase() == 'ACC';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // KOP SURAT
            if (kopImage != null)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                height: 72,
                child: pw.Image(kopImage, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.only(bottom: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          header.perusahaan.isNotEmpty
                              ? header.perusahaan
                              : 'PT. MADANI PRODUCTION',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Dusun Demen RT 003 RW 001, Kel. Jeron, Kec. Nogosari, Kab. Boyolali, Jawa Tengah',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.Text(
                          'Telp 0271-7889327 | m.officer@madaniproduction.co.id',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'OUR SERVICES :',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text('- GARMENT & TEXTILE',
                            style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('- MANUAL PRINTING',
                            style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('- DIGITAL PRINTING',
                            style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
              ),

            // METADATA WRAPPER
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 6, bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Sisi Kiri: Customer
                  pw.Expanded(
                    flex: 6,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: PdfColors.grey600, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Kepada Yth :',
                              style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text(
                            header.customer.isNotEmpty ? header.customer : '-',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (header.customerAlamat.isNotEmpty)
                            pw.Text(header.customerAlamat,
                                style: const pw.TextStyle(fontSize: 8.5)),
                          if (header.customerKota.isNotEmpty)
                            pw.Text(header.customerKota,
                                style: const pw.TextStyle(fontSize: 8.5)),
                          pw.SizedBox(height: 3),
                          pw.Text('Up. $upLabel',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              )),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  // Sisi Kanan: No, Tanggal, Perihal
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetaRow('Tanggal', _formatDate(header.tanggal)),
                        _buildMetaRow('Perihal', 'Penawaran Harga'),
                        _buildMetaRow('No', header.nomor),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // PENGANTAR
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                'Dengan Hormat,\nBersama dengan surat ini kami perusahaan yang bergerak di bidang garment, manual printing dan digital printing mengajukan penawaran harga untuk item-item barang tersebut di bawah ini:',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),

            // TABEL RINCIAN BARANG
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.6),
              columnWidths: {
                0: const pw.FixedColumnWidth(24), // No
                1: const pw.FlexColumnWidth(3),   // Nama
                2: const pw.FlexColumnWidth(2),   // Bahan
                3: const pw.FlexColumnWidth(1.6), // Ukuran
                4: const pw.FixedColumnWidth(38), // Satuan
                5: const pw.FixedColumnWidth(32), // Qty
                6: const pw.FlexColumnWidth(1.8), // Harga
                7: const pw.FlexColumnWidth(2),   // Total
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('No', isHeader: true, align: pw.TextAlign.center),
                    _buildTableCell('Nama Barang', isHeader: true),
                    _buildTableCell('Bahan', isHeader: true),
                    _buildTableCell('Ukuran', isHeader: true),
                    _buildTableCell('Satuan', isHeader: true, align: pw.TextAlign.center),
                    _buildTableCell('Qty', isHeader: true, align: pw.TextAlign.center),
                    _buildTableCell('Harga', isHeader: true, align: pw.TextAlign.right),
                    _buildTableCell('Total', isHeader: true, align: pw.TextAlign.right),
                  ],
                ),
                // Table Rows
                ...details.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final item = entry.value;
                  final dimen = item.panjang > 0 || item.lebar > 0
                      ? '${item.panjang.toInt()} x ${item.lebar.toInt()} cm'
                      : (item.ukuran.isNotEmpty ? item.ukuran : '-');

                  return pw.TableRow(
                    children: [
                      _buildTableCell('$index', align: pw.TextAlign.center),
                      _buildTableCell(item.namaBarang),
                      _buildTableCell(item.bahan.isNotEmpty ? item.bahan : '-'),
                      _buildTableCell(dimen),
                      _buildTableCell(item.satuan.isNotEmpty ? item.satuan : 'pcs', align: pw.TextAlign.center),
                      _buildTableCell('${item.qty.toInt()}', align: pw.TextAlign.center),
                      _buildTableCell(_currencyFormat.format(item.harga), align: pw.TextAlign.right),
                      _buildTableCell(_currencyFormat.format(item.total), align: pw.TextAlign.right),
                    ],
                  );
                }),
                // Total Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Container(),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(4),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text('TOTAL',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          )),
                    ),
                    pw.Container(),
                    pw.Container(),
                    pw.Container(),
                    pw.Container(),
                    pw.Container(),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(4),
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        _currencyFormat.format(grandTotal),
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // TAX NOTE & CLOSING
            pw.SizedBox(height: 6),
            pw.Text(
              header.statusHarga == 1
                  ? '* Catatan: Harga sudah termasuk PPN'
                  : '* Catatan: Harga belum termasuk PPN',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey800,
              ),
            ),
            if (header.note.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFEF9C3), // Soft yellow
                ),
                child: pw.Text(
                  'Note: ${header.note}',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
            ],
            pw.SizedBox(height: 6),
            pw.Text(
              'Demikian penawaran harga ini kami sampaikan, atas perhatian dan kerjasamanya kami ucapkan terima kasih.',
              style: const pw.TextStyle(fontSize: 9),
            ),

            // TANDA TANGAN (SIGNATURE)
            pw.SizedBox(height: 18),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Kiri: Hormat Kami
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Hormat kami,',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 44),
                    pw.Text(
                      header.sales.isNotEmpty ? header.sales : 'Bagian Sales',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    pw.Text('Marketing / Sales Representative',
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                // Kanan: Mengetahui / Menyetujui
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Mengetahui / Menyetujui,',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 4),
                    if (isSigned)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                              color: PdfColors.green700, width: 1.2),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              'DIGITALLY APPROVED',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green800,
                              ),
                            ),
                            if (header.digitalSignDate.isNotEmpty)
                              pw.Text(
                                header.digitalSignDate,
                                style: const pw.TextStyle(
                                  fontSize: 6.5,
                                  color: PdfColors.green900,
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      pw.SizedBox(height: 36),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      ttdName,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    pw.Text(ttdJabatan, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final safeName = header.nomor.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final pdfBytes = await pdf.save();

    // Di Flutter Web: Gunakan sharePdf agar langsung ter-download ke folder Unduhan browser
    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Penawaran_$safeName.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Penawaran_$safeName.pdf',
      );
    }
  }

  static pw.Widget _buildMetaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 60,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 8.5)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      alignment: align == pw.TextAlign.center
          ? pw.Alignment.center
          : (align == pw.TextAlign.right
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
