import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/asset_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/penawaran_model.dart';
import '../../repositories/penawaran_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

class PenawaranDetailScreen extends ConsumerStatefulWidget {
  final String nomor;

  const PenawaranDetailScreen({super.key, required this.nomor});

  @override
  ConsumerState<PenawaranDetailScreen> createState() => _PenawaranDetailScreenState();
}

class _PenawaranDetailScreenState extends ConsumerState<PenawaranDetailScreen> {
  PenawaranDetailData? _detailData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    final repo = ref.read(penawaranRepositoryProvider);
    final data = await repo.getPenawaranDetail(widget.nomor);

    if (mounted) {
      setState(() {
        _detailData = data;
        _isLoading = false;
      });
    }
  }

  void _showApproveDialog() {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text(
          'Approval Penawaran',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Setujui penawaran ${widget.nomor}?',
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: 'Catatan approval (opsional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: StatusColors.acc,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 42),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(penawaranRepositoryProvider);
              final success = await repo.approvePenawaran(
                widget.nomor,
                noteController.text.trim(),
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Penawaran disetujui' : 'Gagal menyetujui penawaran',
                    ),
                    backgroundColor: success ? AppColors.success : AppColors.danger,
                  ),
                );
                if (success) _fetchDetail();
              }
            },
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final header = _detailData?.header;
    final items = _detailData?.details ?? [];
    final grandTotal = items.fold<double>(0.0, (acc, curr) => acc + curr.total);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nomor),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: AppColors.primary),
            tooltip: 'Approve',
            onPressed: _showApproveDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              maxWidth: 900,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Kop Surat Perusahaan Dinamis dari Aset
                          if (header != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                              child: Image.asset(
                                AppAssets.getPenawaranKop(header.perusahaanKode),
                                fit: BoxFit.fitWidth,
                                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Header Summary Card
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        header.nomor,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      if (header.approvalState.isNotEmpty)
                                        AppBadge(
                                          label: header.approvalState,
                                          variant: header.approvalState == 'ACC'
                                              ? BadgeVariant.success
                                              : (header.approvalState == 'TOLAK'
                                                  ? BadgeVariant.danger
                                                  : BadgeVariant.warning),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    header.customer,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  if (header.perusahaan.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Perusahaan: ${header.perusahaan}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                  const Divider(height: 18, color: AppColors.border),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Sales: ${header.sales}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'Tanggal: ${header.tanggal}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Section Title
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Text(
                              'Rincian Barang',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Items List
                          if (items.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('Tidak ada rincian barang', style: TextStyle(color: AppColors.muted)),
                              ),
                            )
                          else
                            ...items.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.namaBarang,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.ink,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                          AppBadge(
                                            label: '${item.qty.toInt()} ${item.satuan}',
                                            variant: BadgeVariant.primary,
                                          ),
                                        ],
                                      ),
                                      if (item.bahan.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Bahan: ${item.bahan}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                      const Divider(height: 18, color: AppColors.border),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '@ ${currencyFormat.format(item.harga)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            currencyFormat.format(item.total),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),

                  // Footer Total
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: const Border(top: BorderSide(color: AppColors.border)),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Grand Total:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          currencyFormat.format(grandTotal),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
