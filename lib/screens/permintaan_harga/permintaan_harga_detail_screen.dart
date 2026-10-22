import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/permintaan_harga_model.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/web_safe_network_image.dart';
import '../../widgets/app_reload_button.dart';

const _kShortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

const _kIndonesianMonths = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String _formatDate(String? value) {
  if (value == null || value.trim().isEmpty) return '-';
  try {
    final clean = value.trim().split('T')[0].split(' ')[0];
    final parts = clean.split('-').map(int.parse).toList();
    if (parts.length == 3) {
      final y = parts[0];
      final m = parts[1];
      final d = parts[2];
      if (m >= 1 && m <= 12) {
        return '$d ${_kShortMonths[m - 1]} $y';
      }
    }
    final dt = DateTime.parse(value);
    return '${dt.day} ${_kShortMonths[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return value;
  }
}

String _formatDateTimeLocal(String? value) {
  if (value == null || value.trim().isEmpty) return '-';
  try {
    final dt = DateTime.parse(value).toLocal();
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_kIndonesianMonths[dt.month - 1]} ${dt.year}, $hour:$min';
  } catch (_) {
    return value;
  }
}

String _formatNumber(dynamic n) {
  if (n == null) return '-';
  final num = double.tryParse(n.toString());
  if (num == null) return n.toString();
  return NumberFormat.decimalPattern('id_ID').format(num);
}

class ParsedKetKalkulasi {
  final String? ppnStatus; // 'EXCLUDE' | 'INCLUDE' | null
  final List<String> items;

  ParsedKetKalkulasi({this.ppnStatus, required this.items});
}

ParsedKetKalkulasi parseKetKalkulasi(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return ParsedKetKalkulasi(ppnStatus: null, items: []);
  }

  String? ppnStatus;
  final upperRaw = raw.toUpperCase();
  if (upperRaw.contains('EXC PPN') ||
      upperRaw.contains('EXCLUDE PPN') ||
      upperRaw.contains('EXCPPN') ||
      upperRaw.contains('NON PPN') ||
      upperRaw.contains('NONPPN')) {
    ppnStatus = 'EXCLUDE';
  } else if (upperRaw.contains('INC PPN') ||
      upperRaw.contains('INCLUDE PPN') ||
      upperRaw.contains('INCPPN')) {
    ppnStatus = 'INCLUDE';
  }

  final rawParts = raw
      .split(RegExp(r'[;\n\r]+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  final items = <String>[];
  for (final part in rawParts) {
    var cleaned = part
        .replaceAll(
          RegExp(
            r'\b(EXC|INC|EXCLUDE|INCLUDE|NON)\s*PPN\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'^\b(EXCLUDE|INCLUDE)\b$', caseSensitive: false),
          '',
        )
        .trim();

    if (cleaned.isEmpty) continue;

    if (RegExp(
      r'^\[ALASAN:\s*(.+)\]$',
      caseSensitive: false,
    ).hasMatch(cleaned)) {
      cleaned = cleaned.replaceAllMapped(
        RegExp(r'^\[ALASAN:\s*(.+)\]$', caseSensitive: false),
        (m) => 'Alasan: ${m.group(1)}',
      );
    }

    var formatted = cleaned
        .replaceAll(RegExp(r'\bSTIAP\b', caseSensitive: false), 'Setiap')
        .replaceAll(RegExp(r'\bSTP\b', caseSensitive: false), 'Setiap')
        .replaceAll(RegExp(r'\bTDK\b', caseSensitive: false), 'Tidak')
        .replaceAll(RegExp(r'\bDG\b', caseSensitive: false), 'Dengan')
        .replaceAll(RegExp(r'\bDGN\b', caseSensitive: false), 'Dengan')
        .replaceAll(RegExp(r'\bBLM\b', caseSensitive: false), 'Belum')
        .replaceAll(RegExp(r'\bSDH\b', caseSensitive: false), 'Sudah');

    formatted = formatted.replaceAllMapped(
      RegExp(r'\bHARGA\s*\+?\s*(\d+)', caseSensitive: false),
      (m) => 'Harga +Rp ${_formatNumber(m.group(1))}',
    );

    formatted = formatted.replaceAllMapped(
      RegExp(r'\+\s*(\d{3,})'),
      (m) => '+Rp ${_formatNumber(m.group(1))}',
    );

    items.add(formatted);
  }

  return ParsedKetKalkulasi(ppnStatus: ppnStatus, items: items);
}

class StatusBadgeInfo {
  final Color bg;
  final Color border;
  final Color text;
  final String label;

  StatusBadgeInfo({
    required this.bg,
    required this.border,
    required this.text,
    required this.label,
  });
}

StatusBadgeInfo _statusBadgeStyle(String status) {
  final key = status.trim().toUpperCase();
  final token = PermintaanHargaStatusHelper.getToken(key);
  return StatusBadgeInfo(
    bg: token.unselectedBg,
    border: token.unselectedBorder,
    text: token.base,
    label: key.isNotEmpty ? key : '-',
  );
}

String _getStatusDescription(String status) {
  final key = status.trim().toUpperCase();
  switch (key) {
    case 'BELUM':
      return 'Tidak muncul di kalkulasi harga';
    case 'BELUM DIVERIFIKASI':
      return 'Menunggu verifikasi dari Finance';
    case 'MINTA':
      return 'Sedang dimintakan harga ke Finance';
    case 'CANCEL':
      return 'Dibatalkan';
    case 'WAIT':
      return 'Sudah diproses, menunggu ACC';
    case 'NEGO':
      return 'Permintaan harga dibawah standar kalkulasi sistem';
    case 'DONE':
      return 'Selesai';
    default:
      return '-';
  }
}

String _resolveDivisiLabel(String? kode) {
  final clean = kode?.trim() ?? '';
  switch (clean) {
    case '1':
      return '1 - SPANDUK';
    case '4':
      return '4 - GARMEN';
    case '5':
      return '5 - MMT';
    default:
      return clean.isNotEmpty ? clean : '-';
  }
}

class PermintaanHargaDetailScreen extends ConsumerStatefulWidget {
  final String nomor;

  const PermintaanHargaDetailScreen({super.key, required this.nomor});

  @override
  ConsumerState<PermintaanHargaDetailScreen> createState() =>
      _PermintaanHargaDetailScreenState();
}

class _PermintaanHargaDetailScreenState
    extends ConsumerState<PermintaanHargaDetailScreen> {
  PermintaanHargaDetail? _detail;
  bool _isLoading = false;
  bool _image1Error = false;
  bool _image2Error = false;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _image1Error = false;
      _image2Error = false;
    });
    final repo = ref.read(permintaanHargaRepositoryProvider);
    final data = await repo.getDetail(widget.nomor);

    if (mounted) {
      setState(() {
        _detail = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Permintaan Harga',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Yakin ingin menghapus permintaan harga ${widget.nomor}?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    final repo = ref.read(permintaanHargaRepositoryProvider);
    final success = await repo.deletePermintaanHarga(widget.nomor);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        AppToast.success(context, 'Permintaan harga berhasil dihapus');
        context.pop(true);
      } else {
        AppToast.error(context, 'Gagal menghapus permintaan harga');
      }
    }
  }

  Future<void> _handleEdit() async {
    if (_detail == null) return;
    final refresh = await context.push<bool>(
      '/permintaan-harga/edit',
      extra: _detail,
    );
    if (refresh == true) {
      _fetchDetail();
    }
  }

  String? _resolveImageUrl(int index) {
    if (_detail == null) return null;

    final json = _detail!.rawJson ?? {};
    final candidates = index == 1
        ? [
            json['gambar_1_url'],
            json['gambar1_url'],
            json['img1'],
            json['image1'],
            json['mh_gambar1'],
            json['gambar1'],
            json['mh_img1'],
            json['mh_image1'],
            _detail!.gambar1Url,
            _detail!.gambarUrl,
          ]
        : [
            json['gambar_2_url'],
            json['gambar2_url'],
            json['img2'],
            json['image2'],
            json['mh_gambar2'],
            json['gambar2'],
            json['mh_img2'],
            json['mh_image2'],
            _detail!.gambar2Url,
          ];

    String? picked;
    for (final c in candidates) {
      if (c != null && c.toString().trim().isNotEmpty) {
        picked = c.toString().trim();
        break;
      }
    }

    // Jika tidak ada data foto sama sekali dari server, jangan buat fallback palsu yang memicu 404
    if (picked == null || picked.isEmpty) {
      return null;
    }

    String resolved = picked;

    if (!resolved.startsWith('http://') && !resolved.startsWith('https://')) {
      resolved =
          '${ApiConfig.imageReadUrl}${ApiConfig.imageBasePath}/$resolved';
    }

    // Normalisasi url persis React Native
    resolved = resolved
        .replaceFirst(
          'http://103.94.238.252:3005/image/mintaharga',
          '${ApiConfig.imageReadUrl}${ApiConfig.imageBasePath}',
        )
        .replaceFirst(
          'http://103.94.238.252:8182/image/mintaharga',
          '${ApiConfig.imageReadUrl}${ApiConfig.imageBasePath}',
        );

    // Tambahkan cache-buster persis React Native
    final cacheBuster = _detail!.createdAtFmt.isNotEmpty
        ? _detail!.createdAtFmt.hashCode.abs().toString()
        : DateTime.now().millisecondsSinceEpoch.toString();

    return '$resolved?t=$cacheBuster';
  }

  @override
  Widget build(BuildContext context) {
    final statusNorm = (_detail?.status ?? '').trim().toUpperCase();
    final isBelum = statusNorm == 'BELUM';
    final statusMeta = _statusBadgeStyle(statusNorm);
    final statusDesc = _getStatusDescription(statusNorm);

    final img1 = _resolveImageUrl(1);
    final img2 = _resolveImageUrl(2);
    final showImage1 = img1 != null && !_image1Error;
    final showImage2 = img2 != null && !_image2Error;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: ResponsiveHelper.formWidth(context),
          child: Column(
            children: [
              // 1. TOP APP BAR
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color.fromRGBO(15, 23, 42, 0.08),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(15, 23, 42, 0.03),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Detail Permintaan Harga',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    AppReloadButton(
                      onTap: _fetchDetail,
                      isLoading: _isLoading,
                      tooltip: 'Segarkan data',
                    ),
                  ],
                ),
              ),

              // 2. KONTEN DETAIL
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    : _detail == null
                    ? const Center(
                        child: Text(
                          'Data permintaan harga tidak ditemukan.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // CARD 1: HEADER DOKUMEN & STATUS (Persis React Native)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color.fromRGBO(15, 23, 42, 0.08),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(15, 23, 42, 0.03),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'NOMOR PERMINTAAN',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF64748B),
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _detail!.nomor,
                                              style: const TextStyle(
                                                fontSize: 16.5,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF4F46E5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusMeta.bg,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: statusMeta.border,
                                          ),
                                        ),
                                        child: Text(
                                          statusMeta.label,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                            color: statusMeta.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Status Description Box
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusMeta.bg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: statusMeta.border,
                                      ),
                                    ),
                                    child: Text.rich(
                                      TextSpan(
                                        text: 'Status: ',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: statusMeta.text,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: statusDesc,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: statusMeta.text,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Meta Creator & Timestamp Row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.person_outline_rounded,
                                            size: 14,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _detail!.userCreate.isNotEmpty
                                                ? _detail!.userCreate
                                                : '-',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _formatDateTimeLocal(
                                          _detail!.createdAtFmt.isNotEmpty
                                              ? _detail!.createdAtFmt
                                              : _detail!.tanggal,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // CARD 2: CUSTOMER & PEKERJAAN (Compact Cell Grid)
                            _buildCardSection(
                              title: 'Customer & Pekerjaan',
                              children: [
                                Row(
                                  children: [
                                    _CompactCell(
                                      label: 'Customer',
                                      value: _detail!.cusNama,
                                    ),
                                    const SizedBox(width: 10),
                                    _CompactCell(
                                      label: 'Sales',
                                      value: _detail!.salesNama.isNotEmpty
                                          ? _detail!.salesNama
                                          : '-',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _CompactCell(
                                      label: 'Nama Pekerjaan',
                                      value: _detail!.nama,
                                    ),
                                    const SizedBox(width: 10),
                                    _CompactCell(
                                      label: 'Divisi Tujuan',
                                      value: _resolveDivisiLabel(
                                        _detail!.divisi,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _CompactCell(
                                  label: 'Tanggal Order',
                                  value: _formatDate(
                                    _detail!.dateOrder.isNotEmpty
                                        ? _detail!.dateOrder
                                        : _detail!.tanggal,
                                  ),
                                  fullWidth: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // CARD 3: SPESIFIKASI FISIK (Compact Cell Grid)
                            _buildCardSection(
                              title: 'Spesifikasi Fisik',
                              children: [
                                Row(
                                  children: [
                                    _CompactCell(
                                      label: 'Bahan / Kain',
                                      value: _detail!.kain,
                                    ),
                                    const SizedBox(width: 10),
                                    _CompactCell(
                                      label: 'Gramasi',
                                      value: _detail!.gramasi,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _CompactCell(
                                      label: 'Ukuran (p x l)',
                                      value:
                                          '${_formatNumber(_detail!.panjang)} m x ${_formatNumber(_detail!.lebar)} ${_detail!.divisi == '1' ? 'cm' : 'm'}',
                                    ),
                                    const SizedBox(width: 10),
                                    _CompactCell(
                                      label: 'Ket. Ukuran',
                                      value: _detail!.ukuran,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _CompactCell(
                                      label: 'Rencana Order (Pcs)',
                                      value: _formatNumber(_detail!.jmlOrder),
                                      highlight: true,
                                    ),
                                    const SizedBox(width: 10),
                                    _CompactCell(
                                      label: 'Finishing',
                                      value: _detail!.finishing,
                                    ),
                                  ],
                                ),
                                if (_detail!.sublim.isNotEmpty ||
                                    _detail!.warna.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _CompactCell(
                                        label: 'Sublim',
                                        value: _detail!.sublim,
                                      ),
                                      const SizedBox(width: 10),
                                      _CompactCell(
                                        label: 'Warna',
                                        value: _detail!.warna,
                                      ),
                                    ],
                                  ),
                                ],
                                if (_detail!.divisi == '4' &&
                                    _detail!.workshop.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _CompactCell(
                                    label: 'Workshop',
                                    value:
                                        _detail!.workshop.toUpperCase() == 'P04'
                                        ? 'PREMIUM (P04)'
                                        : 'MEDIUM (P01)',
                                    fullWidth: true,
                                  ),
                                ],
                                if (_detail!.ongkir > 0) ...[
                                  const SizedBox(height: 10),
                                  _CompactCell(
                                    label: 'Ongkos Kirim',
                                    value:
                                        'Rp ${_formatNumber(_detail!.ongkir)} (Luar Pulau Jawa)',
                                    fullWidth: true,
                                  ),
                                ],
                                if (_detail!.keterangan.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Keterangan:',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          _detail!.keterangan,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF1E293B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),

                            // CARD 4: HASIL KALKULASI HARGA (Jika status DONE, NEGO, atau BELUM DIVERIFIKASI)
                            if (statusNorm == 'DONE' ||
                                statusNorm == 'NEGO' ||
                                statusNorm == 'BELUM DIVERIFIKASI' ||
                                statusNorm == 'BELUM_DIVERIFIKASI')
                              _HasilKalkulasiSectionWidget(detail: _detail!),

                            const SizedBox(height: 12),

                            // CARD 5: LAMPIRAN FOTO PRODUK
                            if (showImage1 || showImage2)
                              _buildCardSection(
                                title: 'Lampiran Foto Produk',
                                children: [
                                  if (showImage1 && showImage2)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildImageThumbnail(
                                            title: 'Foto Contoh 1',
                                            imageUrl: img1,
                                            slot: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _buildImageThumbnail(
                                            title: 'Foto Contoh 2',
                                            imageUrl: img2,
                                            slot: 2,
                                          ),
                                        ),
                                      ],
                                    )
                                  else if (showImage1)
                                    _buildImageThumbnail(
                                      title: 'Foto Contoh 1',
                                      imageUrl: img1,
                                      slot: 1,
                                    )
                                  else
                                    _buildImageThumbnail(
                                      title: 'Foto Contoh 2',
                                      imageUrl: img2,
                                      slot: 2,
                                    ),
                                ],
                              )
                            else
                              _buildCardSection(
                                title: 'Lampiran Gambar',
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Tidak ada foto lampiran yang diunggah.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF64748B),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),

              // 3. FLOATING BOTTOM ACTION BUTTONS (HANYA MUNCUL JIKA STATUS BELUM)
              if (isBelum)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color.fromRGBO(15, 23, 42, 0.08)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _handleEdit,
                          child: const Text(
                            'Edit',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _handleDelete,
                          child: const Text(
                            'Hapus',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildImageThumbnail({
    required String title,
    required String? imageUrl,
    required int slot,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: WebSafeNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          if (slot == 1) _image1Error = true;
                          if (slot == 2) _image2Error = true;
                        });
                      }
                    });
                    return const SizedBox.shrink();
                  },
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final size = MediaQuery.of(context).size;
                      final dialogWidth = (size.width * 0.92).clamp(
                        280.0,
                        850.0,
                      );
                      final dialogHeight = (size.height * 0.82).clamp(
                        320.0,
                        720.0,
                      );

                      showDialog(
                        context: context,
                        builder: (ctx) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(12),
                          child: Center(
                            child: Container(
                              width: dialogWidth,
                              height: dialogHeight,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: InteractiveViewer(
                                      minScale: 0.8,
                                      maxScale: 4.0,
                                      child: WebSafeNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.contain,
                                        width: dialogWidth - 32,
                                        height: dialogHeight - 32,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        onPressed: () => Navigator.pop(ctx),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      alignment: Alignment.bottomRight,
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Lihat Foto',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactCell extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool highlight;
  final bool fullWidth;

  const _CompactCell({
    required this.label,
    required this.value,
    this.highlight = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final strVal = (value?.toString() ?? '').trim();
    final textWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          strVal.isNotEmpty ? strVal : '-',
          style: TextStyle(
            fontSize: 13,
            fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            color: highlight
                ? const Color(0xFF4F46E5)
                : const Color(0xFF0F172A),
          ),
          maxLines: fullWidth ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: textWidget);
    }
    return Expanded(child: textWidget);
  }
}

class _HasilKalkulasiSectionWidget extends StatefulWidget {
  final PermintaanHargaDetail detail;

  const _HasilKalkulasiSectionWidget({required this.detail});

  @override
  State<_HasilKalkulasiSectionWidget> createState() =>
      _HasilKalkulasiSectionWidgetState();
}

class _HasilKalkulasiSectionWidgetState
    extends State<_HasilKalkulasiSectionWidget> {
  bool _showBreakdown = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final cleanStatus = d.status.trim().toUpperCase();
    final isNego = cleanStatus == 'NEGO';
    final isBelumVerif =
        cleanStatus == 'BELUM DIVERIFIKASI' ||
        cleanStatus == 'BELUM_DIVERIFIKASI';

    final parsed = parseKetKalkulasi(d.ketKalkulasi);
    final cardBadgeCode = d.nomorKalkulasi.isNotEmpty
        ? d.nomorKalkulasi
        : (isNego ? 'KALS' : 'KAL');
    final userText = isNego
        ? (d.salesNama.isNotEmpty ? d.salesNama : d.userCreate)
        : (d.userKalkulasi.isNotEmpty
              ? d.userKalkulasi
              : (d.userCreate.isNotEmpty ? d.userCreate : '-'));

    final rawSistemKal = d.kalRpSistem > 0
        ? d.kalRpSistem
        : (d.kalkulasiDetail?['hdr']?['kal_rpsistem'] as num?)?.toDouble() ??
              0.0;
    final rawSalesKal = d.kalRpSales > 0
        ? d.kalRpSales
        : (d.kalkulasiDetail?['hdr']?['kal_rpsales'] as num?)?.toDouble() ??
              0.0;
    final ppnVal = d.kalPpn > 0
        ? d.kalPpn
        : (d.kalkulasiDetail?['hdr']?['kal_ppn'] as num?)?.toDouble() ?? 0.0;

    final calculatedFromSistem = rawSistemKal > 0
        ? (ppnVal > 0
              ? (rawSistemKal * (1 + ppnVal / 100)).roundToDouble()
              : rawSistemKal)
        : 0.0;

    final calculatedFromSales = rawSalesKal > 0
        ? (ppnVal > 0
              ? (rawSalesKal * (1 + ppnVal / 100)).roundToDouble()
              : rawSalesKal)
        : 0.0;

    final calcPrice = calculatedFromSistem > 0
        ? calculatedFromSistem
        : (d.hargaKalkulasi > 0 ? d.hargaKalkulasi : 0.0);

    final reqPrice = d.harga > 0
        ? d.harga
        : (calculatedFromSales > 0 ? calculatedFromSales : 0.0);

    final qty = d.jmlOrder > 0 ? d.jmlOrder : 1.0;
    final hasBothPrices = calcPrice > 0 && reqPrice > 0;
    final gap = reqPrice - calcPrice;
    final persenGap = calcPrice > 0 ? (gap / calcPrice) * 100 : 0.0;
    final totalGap = gap * qty;

    final cardBg = isNego
        ? const Color(0xFFFAF5FF)
        : (isBelumVerif ? const Color(0xFFFFF3E0) : const Color(0xFFF0FDF4));
    final cardBorder = isNego
        ? const Color(0xFFE9D5FF)
        : (isBelumVerif ? const Color(0xFFFFCC80) : const Color(0xFFBBF7D0));
    final titleColor = isNego
        ? const Color(0xFF581C87)
        : (isBelumVerif ? const Color(0xFFBF360C) : const Color(0xFF166534));
    final badgeBg = isNego
        ? const Color(0xFFF3E8FF)
        : (isBelumVerif ? const Color(0xFFFFE0B2) : const Color(0xFFDCFCE7));
    final badgeBorder = isNego
        ? const Color(0xFFD8B4FE)
        : (isBelumVerif ? const Color(0xFFFFB74D) : const Color(0xFF86EFAC));
    final badgeText = isNego
        ? const Color(0xFF6B21A8)
        : (isBelumVerif ? const Color(0xFFE65100) : const Color(0xFF15803D));

    final komponenList =
        (d.kalkulasiDetail?['komponen'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final hasKomponen = komponenList.isNotEmpty;

    final dtl = d.kalkulasiDetail?['dtl'] as Map<String, dynamic>?;
    final hasDtl =
        dtl != null && ((dtl['kald_rpjahit'] as num?)?.toDouble() ?? 0) > 0 ||
        ((dtl?['kald_rppotong'] as num?)?.toDouble() ?? 0) > 0 ||
        ((dtl?['kald_rpfinishing'] as num?)?.toDouble() ?? 0) > 0 ||
        ((dtl?['kald_rptenagacetak'] as num?)?.toDouble() ?? 0) > 0;

    final cetak = d.kalkulasiDetail?['cetak'] as Map<String, dynamic>?;
    final dtf = d.kalkulasiDetail?['dtf'] as Map<String, dynamic>?;
    final bordir = d.kalkulasiDetail?['bordir'] as Map<String, dynamic>?;
    final sublim = d.kalkulasiDetail?['sublim'] as Map<String, dynamic>?;
    final polyflex = d.kalkulasiDetail?['polyflex'] as Map<String, dynamic>?;
    final hasVariasi =
        ((cetak?['kald_rpcetak'] as num?)?.toDouble() ?? 0) > 0 ||
        ((dtf?['kald_rpdtf'] as num?)?.toDouble() ?? 0) > 0 ||
        ((bordir?['kald_rpbordir'] as num?)?.toDouble() ?? 0) > 0 ||
        ((sublim?['kald_rpsublim'] as num?)?.toDouble() ?? 0) > 0 ||
        ((polyflex?['kald_rppolyflex'] as num?)?.toDouble() ?? 0) > 0;

    final aksesorisList =
        (d.kalkulasiDetail?['aksesories'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final hasAksesoris = aksesorisList.isNotEmpty;

    final hdr = d.kalkulasiDetail?['hdr'] as Map<String, dynamic>?;
    final hasHdrDetails =
        hdr != null &&
        (((hdr['kal_rpallowance'] as num?)?.toDouble() ?? 0) > 0 ||
            ((hdr['kal_rplaba'] as num?)?.toDouble() ?? 0) > 0 ||
            ((hdr['kal_rpsistem'] as num?)?.toDouble() ?? 0) > 0 ||
            ((hdr['kal_rpsales'] as num?)?.toDouble() ?? 0) > 0);

    final hasAnyBreakdown =
        hasKomponen || hasDtl || hasVariasi || hasAksesoris || hasHdrDetails;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Icon + Title & Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isNego ? Icons.handshake_rounded : Icons.calculate_rounded,
                    size: 18,
                    color: titleColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hasil Kalkulasi Harga',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (parsed.ppnStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: parsed.ppnStatus == 'INCLUDE'
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: parsed.ppnStatus == 'INCLUDE'
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        parsed.ppnStatus == 'INCLUDE' ? 'Inc PPN' : 'Exc PPN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: parsed.ppnStatus == 'INCLUDE'
                              ? const Color(0xFF15803D)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Text(
                      cardBadgeCode,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: badgeText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Compact Meta Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    userText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if (d.dateKalkulasi.isNotEmpty)
                Text(
                  _formatDateTimeLocal(d.dateKalkulasi),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 3. Price Comparison Grid
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isNego
                    ? const Color(0xFFF5D0FE)
                    : (isBelumVerif
                          ? const Color(0xFFFFCC80)
                          : const Color(0xFFBBF7D0)),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KALKULASI HARGA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rp ${_formatNumber(calcPrice)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: const Color(0xFFE2E8F0),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PERMINTAAN HARGA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rp ${_formatNumber(reqPrice)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isNego
                                  ? const Color(0xFF6B21A8)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasBothPrices && gap.abs() >= 1) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selisih: Rp ${_formatNumber(gap.abs())} (${persenGap.abs().toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334155),
                          ),
                        ),
                        if (qty > 1)
                          Text(
                            'Total: Rp ${_formatNumber(totalGap.abs())}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 4. Ongkir
          if (d.ongkir > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Biaya Pengiriman (Ongkir):',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '+Rp ${_formatNumber(d.ongkir)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ],

          // 5. Collapsible Breakdown (Rincian Kalkulasi Lengkap)
          if (hasAnyBreakdown) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _showBreakdown = !_showBreakdown),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isNego
                      ? const Color(0xFFF3E8FF)
                      : (isBelumVerif
                            ? const Color(0xFFFFE0B2)
                            : const Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 16,
                          color: titleColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Rincian Kalkulasi Lengkap',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _showBreakdown
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: titleColor,
                    ),
                  ],
                ),
              ),
            ),
            if (_showBreakdown) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sub 1: Harga Bahan
                    if (hasKomponen) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '1. HARGA BAHAN (Otomatis Sistem)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                            ),
                          ),
                          if (komponenList.length > 1) ...[
                            Builder(
                              builder: (context) {
                                final totalBahan = komponenList.fold<double>(
                                  0.0,
                                  (sum, k) =>
                                      sum +
                                      ((k['kk_pcs'] as num?)?.toDouble() ??
                                          0.0),
                                );
                                if (totalBahan <= 0) return const SizedBox();
                                return Text(
                                  'Total: Rp ${_formatNumber(totalBahan)} / pcs',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF16A34A),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...komponenList.map((k) {
                        final rawKomp =
                            (k['kk_komponen']?.toString() ?? '')
                                .trim()
                                .toUpperCase();
                        final kompLabel = rawKomp == 'BODY'
                            ? (komponenList.length == 1
                                  ? 'Harga Bahan'
                                  : 'Bahan Body')
                            : (rawKomp == 'LENGAN'
                                  ? 'Bahan Lengan'
                                  : (rawKomp == 'RIB'
                                        ? 'Bahan Rib'
                                        : (rawKomp.isEmpty || rawKomp == 'BAHAN'
                                              ? 'Harga Bahan'
                                              : 'Harga Bahan ($rawKomp)')));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    kompLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    'Rp ${_formatNumber(k['kk_pcs'])} / pcs',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${k['kk_jeniskain'] ?? '-'} ${k['kk_warna'] != null ? '(${k['kk_warna']})' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],

                    // Sub 2: Biaya Jahit & Operasional
                    if (hasDtl && dtl != null) ...[
                      const Text(
                        '2. BIAYA JAHIT & OPERASIONAL (Otomatis Sistem)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          children: [
                            if (((dtl['kald_rpjahit'] as num?)?.toDouble() ??
                                    0) >
                                0)
                              _buildBreakdownRow(
                                'Biaya Jahit',
                                'Rp ${_formatNumber(dtl['kald_rpjahit'])}',
                              ),
                            if (((dtl['kald_rppotong'] as num?)?.toDouble() ??
                                    0) >
                                0)
                              _buildBreakdownRow(
                                'Biaya Potong',
                                'Rp ${_formatNumber(dtl['kald_rppotong'])}',
                              ),
                            if (((dtl['kald_rpfinishing'] as num?)
                                        ?.toDouble() ??
                                    0) >
                                0)
                              _buildBreakdownRow(
                                'Biaya Finishing',
                                'Rp ${_formatNumber(dtl['kald_rpfinishing'])}',
                              ),
                            if (((dtl['kald_rptenagacetak'] as num?)
                                        ?.toDouble() ??
                                    0) >
                                0)
                              _buildBreakdownRow(
                                'Tenaga Cetak',
                                'Rp ${_formatNumber(dtl['kald_rptenagacetak'])}',
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Sub 3: Biaya Cetak & Variasi
                    if (hasVariasi) ...[
                      const Text(
                        '3. BIAYA CETAK & VARIASI (Inputan Sales)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          children: [
                            if (((cetak?['kald_rpcetak'] as num?)?.toDouble() ??
                                    0) >
                                0)
                              _buildBreakdownRow(
                                'Sablon Manual',
                                'Rp ${_formatNumber(cetak!['kald_rpcetak'])}',
                              ),
                            if (((dtf?['kald_rpdtf'] as num?)?.toDouble() ??
                                    0) >
                                0)
                              _buildBreakdownRow(
                                'Cetak DTF',
                                'Rp ${_formatNumber(dtf!['kald_rpdtf'])}',
                              ),
                            if (((bordir?['kald_rpbordir'] as num?)
                                        ?.toDouble() ??
                                    0) >
                                0)
                              _buildBreakdownRow(
                                'Bordir Komputer',
                                'Rp ${_formatNumber(bordir!['kald_rpbordir'])}',
                              ),
                            if (((sublim?['kald_rpsublim'] as num?)
                                        ?.toDouble() ??
                                    0) >
                                0)
                              _buildBreakdownRow(
                                'Sublimasi',
                                'Rp ${_formatNumber(sublim!['kald_rpsublim'])}',
                              ),
                            if (((polyflex?['kald_rppolyflex'] as num?)
                                        ?.toDouble() ??
                                    0) >
                                0)
                              _buildBreakdownRow(
                                'Polyflex',
                                'Rp ${_formatNumber(polyflex!['kald_rppolyflex'])}',
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Sub 4: Aksesoris Tambahan
                    if (hasAksesoris) ...[
                      const Text(
                        '4. AKSESORIS TAMBAHAN (Inputan Sales)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          children: aksesorisList
                              .map(
                                (a) => _buildBreakdownRow(
                                  a['ka_aksesories']?.toString() ?? 'Aksesoris',
                                  'Rp ${_formatNumber(a['ka_biaya'])}',
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Sub 5: Allowance & Margin
                    if (hasHdrDetails) ...[
                      const Text(
                        '5. ALLOWANCE & MARGIN (Otomatis Sistem)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          children: [
                            // if (((hdr['kal_rpallowance'] as num?)?.toDouble() ??
                            //         0) >
                            //     0)
                            //   _buildBreakdownRow(
                            //     'Allowance (${hdr['kal_allowance']}%)',
                            //     '+Rp ${_formatNumber(hdr['kal_rpallowance'])}',
                            //   ),
                            // if (((hdr['kal_rplaba'] as num?)?.toDouble() ?? 0) >
                            //     0)
                            //   _buildBreakdownRow(
                            //     'Margin Laba (${hdr['kal_laba']}%)',
                            //     '+Rp ${_formatNumber(hdr['kal_rplaba'])}',
                            //   ),
                            if (((hdr['kal_rpsistem'] as num?)?.toDouble() ??
                                    0) >
                                0)
                              _buildBreakdownRow(
                                'Kalkulasi Sistem (Exc PPN)',
                                'Rp ${_formatNumber(hdr['kal_rpsistem'])}',
                              ),
                            if (((hdr['kal_rpsales'] as num?)?.toDouble() ??
                                    0) >
                                0)
                              _buildBreakdownRow(
                                'Pengajuan Sales (Exc PPN)',
                                'Rp ${_formatNumber(hdr['kal_rpsales'])}',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],

          // 6. Keterangan Kalkulasi Parsed
          if (parsed.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Keterangan:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            ...parsed.items.map((itemText) {
              final isAlasan = itemText.startsWith('Alasan:');
              return Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: isAlasan
                    ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
                    : EdgeInsets.zero,
                decoration: isAlasan
                    ? BoxDecoration(
                        color: isNego
                            ? const Color(0xFFFAF5FF)
                            : (isBelumVerif
                                  ? const Color(0xFFFFF3E0)
                                  : const Color(0xFFF0FDF4)),
                        borderRadius: BorderRadius.circular(4),
                        border: Border(
                          left: BorderSide(
                            color: isNego
                                ? const Color(0xFF6B21A8)
                                : (isBelumVerif
                                      ? const Color(0xFFE65100)
                                      : const Color(0xFF16A34A)),
                            width: 2.5,
                          ),
                        ),
                      )
                    : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isAlasan)
                      Text(
                        '• ',
                        style: TextStyle(
                          fontSize: 12,
                          color: isNego
                              ? const Color(0xFF6B21A8)
                              : (isBelumVerif
                                    ? const Color(0xFFE65100)
                                    : const Color(0xFF15803D)),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        itemText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isAlasan
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isAlasan
                              ? (isNego
                                    ? const Color(0xFF581C87)
                                    : (isBelumVerif
                                          ? const Color(0xFFBF360C)
                                          : const Color(0xFF166534)))
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
