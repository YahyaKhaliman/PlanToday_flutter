import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/achievement_model.dart';
import '../../repositories/achievement_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

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
    final toYm = '${widget.toYear}-${widget.toMonth.toString().padLeft(2, '0')}';

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

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final fromLabel =
        '${_monthLabels[widget.fromMonth - 1]} ${widget.fromYear}';
    final toLabel = '${_monthLabels[widget.toMonth - 1]} ${widget.toYear}';
    final periodLabel = '$fromLabel — $toLabel';

    final u = widget.userRow;
    final totalAch = u.ach;
    final isTargetMet = totalAch >= 100;

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail: ${u.nama}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMonthlyDetail,
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 900,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. HEADER USER SUMMARY CARD
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            u.nama,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        AppBadge(
                          label: '${totalAch.toStringAsFixed(1)}%',
                          variant: isTargetMet ? BadgeVariant.success : BadgeVariant.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${u.jabatan} • Kode: ${u.kode}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Periode: $periodLabel',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.border),

                    // Metrics Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Target', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              currencyFormat.format(u.target),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Realisasi', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              currencyFormat.format(u.realisasi),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: isTargetMet ? AppColors.success : AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. SECTION TITLE BREAKDOWN BULANAN
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Rincian Realisasi Bulanan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink),
                ),
              ),
              const SizedBox(height: 8),

              // 3. MONTHLY BREAKDOWN LIST
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_monthlyItems.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Tidak ada rincian bulanan', style: TextStyle(color: AppColors.muted)),
                  ),
                )
              else
                ..._monthlyItems.map((m) {
                  final achPct = m.ach;
                  final isMet = achPct >= 100;
                  Color barColor = AppColors.danger;
                  if (achPct >= 80) {
                    barColor = AppColors.success;
                  } else if (achPct >= 50) {
                    barColor = AppColors.warning;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                m.bulan.isNotEmpty ? m.bulan : 'Bulan ${m.bulanNum} ${m.tahun}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
                              ),
                              AppBadge(
                                label: '${achPct.toStringAsFixed(1)}%',
                                customColor: isMet ? AppColors.success : barColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Target: ${currencyFormat.format(m.target)}', style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
                              Text('Realisasi: ${currencyFormat.format(m.realisasi)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isMet ? AppColors.success : AppColors.ink)),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Progress Indicator
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (achPct / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
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
    );
  }
}
