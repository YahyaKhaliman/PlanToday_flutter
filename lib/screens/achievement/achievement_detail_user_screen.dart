import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/achievement_model.dart';
import '../../repositories/achievement_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';
import 'circular_progress.dart';

class AchievementDetailUserScreen extends ConsumerStatefulWidget {
  final AchievementUserRow userRow;
  final int fromYear;
  final int fromMonth;
  final int toYear;
  final int toMonth;

  const AchievementDetailUserScreen({
    super.key,
    required this.userRow,
    required this.fromYear,
    required this.fromMonth,
    required this.toYear,
    required this.toMonth,
  });

  @override
  ConsumerState<AchievementDetailUserScreen> createState() =>
      _AchievementDetailUserScreenState();
}

class _AchievementDetailUserScreenState
    extends ConsumerState<AchievementDetailUserScreen> {
  List<AchievementMonthlyItem> _monthlyItems = [];
  bool _isLoading = false;

  final List<String> _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  @override
  void initState() {
    super.initState();
    _fetchMonthlyDetail();
  }

  Future<void> _fetchMonthlyDetail() async {
    setState(() => _isLoading = true);

    final repo = ref.read(achievementRepositoryProvider);
    final fromYm =
        '${widget.fromYear}-${widget.fromMonth.toString().padLeft(2, '0')}';
    final toYm =
        '${widget.toYear}-${widget.toMonth.toString().padLeft(2, '0')}';

    final items = await repo.getMonthlyOmsetByUser(
      kode: widget.userRow.kode,
      fromYm: fromYm,
      toYm: toYm,
    );

    if (mounted) {
      setState(() {
        _monthlyItems = items;
        _isLoading = false;
      });
    }
  }

  String _formatRupiahFull(double n) {
    final f = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp.',
      decimalDigits: 0,
    );
    return f.format(n);
  }

  @override
  Widget build(BuildContext context) {
    final fromLabel =
        '${_monthLabels[widget.fromMonth - 1]} ${widget.fromYear}';
    final toLabel = '${_monthLabels[widget.toMonth - 1]} ${widget.toYear}';
    final periodLabel = '$fromLabel — $toLabel';

    final u = widget.userRow;
    final totalAch = u.ach;
    final isTargetMet = totalAch >= 100;
    final selisih = u.realisasi - u.target;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 900,
          child: Column(
            children: [
              // 1. TOP HEADER ALA REACT-NATIVE
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
                            u.nama,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Detail Realisasi Omset',
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
                      onTap: _fetchMonthlyDetail,
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
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // USER SUMMARY CARD 2-KOLOM DENGAN CIRCULAR PROGRESS
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color.fromRGBO(15, 23, 42, 0.08),
                          ),
                          boxShadow: AppShadows.softCard,
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Sisi Kiri: Circular Progress + Chip Status
                                Column(
                                  children: [
                                    CircularProgressAnimated(
                                      size: 84,
                                      strokeWidth: 8,
                                      progress: totalAch,
                                      color: isTargetMet
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF06B6D4),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isTargetMet
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isTargetMet
                                              ? const Color(0xFF86EFAC)
                                              : const Color(0xFFFDE68A),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isTargetMet
                                                ? Icons.check_circle_rounded
                                                : Icons.schedule_rounded,
                                            size: 11,
                                            color: isTargetMet
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFFD97706),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            isTargetMet
                                                ? 'TERCAPAI'
                                                : 'BELUM',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: isTargetMet
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),

                                // Sisi Kanan: Ringkasan Angka
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        periodLabel,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${u.jabatan} • ${u.kode}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const Divider(
                                        height: 16,
                                        color: Color(0xFFF1F5F9),
                                      ),

                                      // Target
                                      _MetricRow(
                                        label: 'Target',
                                        value: _formatRupiahFull(u.target),
                                      ),
                                      const SizedBox(height: 3),

                                      // Realisasi
                                      _MetricRow(
                                        label: 'Realisasi',
                                        value: _formatRupiahFull(u.realisasi),
                                        valueColor: isTargetMet
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF0F172A),
                                      ),
                                      const SizedBox(height: 3),

                                      // Selisih
                                      _MetricRow(
                                        label: 'Selisih',
                                        value: _formatRupiahFull(selisih),
                                        valueColor: selisih < 0
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF16A34A),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // SECTION TITLE BREAKDOWN BULANAN
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          'Rincian Realisasi Bulanan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // MONTHLY BREAKDOWN LIST
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        )
                      else if (_monthlyItems.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Tidak ada rincian bulanan pada periode ini.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._monthlyItems.map((m) {
                          final achPct = m.ach;
                          final isMet = achPct >= 100;
                          Color barColor = const Color(0xFFEF4444);
                          if (achPct >= 80) {
                            barColor = const Color(0xFF10B981);
                          } else if (achPct >= 50) {
                            barColor = const Color(0xFFF59E0B);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        m.bulan.isNotEmpty
                                            ? m.bulan
                                            : 'Bulan ${m.bulanNum} ${m.tahun}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      AppBadge(
                                        label:
                                            '${achPct.toStringAsFixed(1)}%',
                                        customColor: isMet
                                            ? const Color(0xFF10B981)
                                            : barColor,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Target: ${_formatRupiahFull(m.target)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Realisasi: ${_formatRupiahFull(m.realisasi)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: isMet
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Progress Indicator Bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      value: (achPct / 100).clamp(0.0, 1.0),
                                      backgroundColor:
                                          const Color(0xFFE2E8F0),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        barColor,
                                      ),
                                      minHeight: 6,
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
