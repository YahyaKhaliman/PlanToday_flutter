import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/permintaan_harga_model.dart';
import '../../repositories/permintaan_harga_repository.dart';

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
      appBar: AppBar(
        title: Text(widget.nomor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDetail,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(
                  child: Text(
                    'Data permintaan harga tidak ditemukan',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.softCard,
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _detail!.nomor,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  _detail!.tanggal,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _detail!.cusNama,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            if (_detail!.nama.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Barang: ${_detail!.nama}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Rincian Spesifikasi & Kalkulasi Card
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.softCard,
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Spesifikasi Pesanan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const Divider(height: 22, color: AppColors.border),
                            _InfoRow(
                              label: 'Jumlah Order',
                              value: '${_detail!.jmlOrder.toInt()} pcs',
                            ),
                            if (_detail!.kain.isNotEmpty)
                              _InfoRow(
                                label: 'Bahan / Kain',
                                value: _detail!.kain,
                              ),
                            _InfoRow(
                              label: 'Harga Target / Budget',
                              value: currencyFormat.format(_detail!.budget),
                            ),
                            _InfoRow(
                              label: 'Harga Penawaran',
                              value: _detail!.harga > 0
                                    ? currencyFormat.format(_detail!.harga)
                                    : 'Dalam Proses',
                              valueColor: AppColors.primary,
                              isBold: true,
                            ),
                            if (_detail!.keterangan.isNotEmpty) ...[
                              const Divider(height: 22, color: AppColors.border),
                              Text(
                                'Catatan: ${_detail!.keterangan}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Gambar Lampiran
                      if (_detail!.gambarUrl.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppShadows.softCard,
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lampiran Desain / Foto',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.medium),
                                child: Image.network(
                                  '${ApiConfig.imageReadUrl}${ApiConfig.imageBasePath}/${_detail!.gambarUrl}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    height: 150,
                                    color: AppColors.soft,
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Gagal memuat gambar',
                                      style: TextStyle(
                                          color: AppColors.muted),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
