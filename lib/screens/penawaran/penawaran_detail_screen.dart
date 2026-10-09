import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Approval Penawaran',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Setujui penawaran ${widget.nomor}?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
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
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            child: const Text('Setujui', style: TextStyle(fontWeight: FontWeight.w800)),
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
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 900,
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
                            'Detail Surat Penawaran',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            await context.push('/penawaran/${widget.nomor}/status');
                            _fetchDetail();
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.rule_folder_outlined,
                              size: 18,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _showApproveDialog,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. KONTEN DETAIL
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Kop Surat Perusahaan
                            if (header != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
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
                                            color: Color(0xFF4F46E5),
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
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (header.perusahaan.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Perusahaan: ${header.perusahaan}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                    const Divider(height: 18, color: Color(0xFFF1F5F9)),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Sales: ${header.sales}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Tanggal: ${header.tanggal}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600,
                                          ),
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
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Items List
                            if (items.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text(
                                    'Tidak ada rincian barang.',
                                    style: TextStyle(color: Color(0xFF64748B)),
                                  ),
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
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF0F172A),
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
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                        const Divider(height: 18, color: Color(0xFFF1F5F9)),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '@ ${currencyFormat.format(item.harga)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              currencyFormat.format(item.total),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
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

              // 3. FOOTER TOTAL CARD
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color.fromRGBO(15, 23, 42, 0.08))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL PENAWARAN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${items.length} Macam Barang',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      currencyFormat.format(grandTotal),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4F46E5),
                        letterSpacing: -0.3,
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
}
