import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/permintaan_harga_model.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    final repo = ref.read(permintaanHargaRepositoryProvider);
    final data = await repo.getDetail(widget.nomor);

    if (mounted) {
      setState(() {
        _detail = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 800,
          child: Column(
            children: [
              // 1. TOP HEADER ALA UI-STYLING
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.pop(),
                      child: Container(
                        width: 42,
                        height: 42,
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
                          Icons.chevron_left_rounded,
                          size: 26,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            widget.nomor,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Detail Permintaan Harga',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _fetchDetail,
                      child: Container(
                        width: 42,
                        height: 42,
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
                          Icons.refresh_rounded,
                          size: 20,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // CARD 1: INFO UTAMA & CUSTOMER
                                AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _detail!.nomor,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF4F46E5),
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          Text(
                                            _detail!.tanggal,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _detail!.cusNama,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (_detail!.nama.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Model: ${_detail!.nama}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                      const Divider(
                                          height: 20, color: Color(0xFFF1F5F9)),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Divisi: ${_detail!.divisiNama.isNotEmpty ? _detail!.divisiNama : _detail!.divisi}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (_detail!.salesNama.isNotEmpty ||
                                              _detail!.userCreate.isNotEmpty)
                                            Text(
                                              'Oleh: ${_detail!.salesNama.isNotEmpty ? _detail!.salesNama : _detail!.userCreate}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF4F46E5),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // CARD 2: SPESIFIKASI TEKNIS PESANAN
                                AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Spesifikasi Teknis Pesanan',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const Divider(
                                          height: 20, color: Color(0xFFF1F5F9)),
                                      _InfoRow(
                                        label: 'Jumlah Order',
                                        value:
                                            '${_detail!.jmlOrder.toInt()} pcs',
                                      ),
                                      if (_detail!.kain.isNotEmpty)
                                        _InfoRow(
                                          label: 'Jenis Kain / Bahan',
                                          value: _detail!.kain,
                                        ),
                                      if (_detail!.ukuran.isNotEmpty)
                                        _InfoRow(
                                          label: 'Ukuran',
                                          value: _detail!.ukuran,
                                        ),
                                      if (_detail!.panjang > 0 ||
                                          _detail!.lebar > 0)
                                        _InfoRow(
                                          label: 'Dimensi (P x L)',
                                          value:
                                              '${_detail!.panjang} x ${_detail!.lebar} m',
                                        ),
                                      if (_detail!.gramasi.isNotEmpty)
                                        _InfoRow(
                                          label: 'Gramasi',
                                          value: _detail!.gramasi,
                                        ),
                                      if (_detail!.finishing.isNotEmpty)
                                        _InfoRow(
                                          label: 'Finishing',
                                          value: _detail!.finishing,
                                        ),
                                      if (_detail!.sublim.isNotEmpty)
                                        _InfoRow(
                                          label: 'Sublim',
                                          value: _detail!.sublim,
                                        ),
                                      if (_detail!.warna.isNotEmpty)
                                        _InfoRow(
                                          label: 'Warna',
                                          value: _detail!.warna,
                                        ),
                                      if (_detail!.keterangan.isNotEmpty) ...[
                                        const Divider(
                                            height: 20, color: Color(0xFFF1F5F9)),
                                        Text(
                                          'Catatan: ${_detail!.keterangan}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // CARD 3: RINCIAN NILAI & HASIL KALKULASI
                                AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Rincian Nilai & Kalkulasi',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const Divider(
                                          height: 20, color: Color(0xFFF1F5F9)),
                                      _InfoRow(
                                        label: 'Target Budget Customer',
                                        value: currencyFormat
                                            .format(_detail!.budget),
                                      ),
                                      if (_detail!.hargaKalkulasi > 0)
                                        _InfoRow(
                                          label: 'Hasil Rekomendasi Kalkulasi',
                                          value: currencyFormat
                                              .format(_detail!.hargaKalkulasi),
                                          valueColor: const Color(0xFF4F46E5),
                                          isBold: true,
                                        ),
                                      if (_detail!.ongkir > 0)
                                        _InfoRow(
                                          label: 'Estimasi Ongkir',
                                          value: currencyFormat
                                              .format(_detail!.ongkir),
                                        ),
                                      const Divider(
                                          height: 20, color: Color(0xFFF1F5F9)),
                                      _InfoRow(
                                        label: 'Harga Final Penawaran',
                                        value: _detail!.harga > 0
                                            ? currencyFormat
                                                .format(_detail!.harga)
                                            : (_detail!.hargaKalkulasi > 0
                                                ? currencyFormat.format(
                                                    _detail!.hargaKalkulasi)
                                                : 'Dalam Proses'),
                                        valueColor: const Color(0xFF10B981),
                                        isBold: true,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // CARD 4: GAMBAR LAMPIRAN DESAIN
                                if (_detail!.gambarUrl.isNotEmpty) ...[
                                  AppCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Lampiran Desain / Foto',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Image.network(
                                            '${ApiConfig.imageReadUrl}${ApiConfig.imageBasePath}/${_detail!.gambarUrl}',
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (ctx, err, stack) => Container(
                                              height: 150,
                                              color: const Color(0xFFF1F5F9),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'Gagal memuat gambar',
                                                style: TextStyle(
                                                    color: Color(0xFF64748B)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // CARD 5: TOMBOL AKSI KALKULATOR HARGA
                                AppButton(
                                  text: 'Buka Kalkulator / Hitung Ulang',
                                  icon: Icons.calculate_outlined,
                                  onPressed: () {
                                    context.push('/permintaan-harga/kalkulasi');
                                  },
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
