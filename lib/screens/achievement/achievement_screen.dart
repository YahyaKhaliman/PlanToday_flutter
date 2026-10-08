import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/achievement_model.dart';
import '../../repositories/achievement_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

class AchievementScreen extends ConsumerStatefulWidget {
  const AchievementScreen({super.key});

  @override
  ConsumerState<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends ConsumerState<AchievementScreen> {
  late int _selectedYear;
  late int _selectedMonth;

  List<AchievementUserRow> _rows = [];
  bool _isLoading = false;

  final List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _fetchAchievement();
  }

  Future<void> _fetchAchievement() async {
    setState(() => _isLoading = true);

    final repo = ref.read(achievementRepositoryProvider);
    final results = await repo.getOmsetRange(
      fromYear: _selectedYear,
      fromMonth: _selectedMonth,
      toYear: _selectedYear,
      toMonth: _selectedMonth,
    );

    if (mounted) {
      setState(() {
        _rows = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Hitung akumulasi tim
    final totalTarget = _rows.fold<double>(0.0, (acc, r) => acc + r.target);
    final totalRealisasi =
        _rows.fold<double>(0.0, (acc, r) => acc + r.realisasi);
    final totalAchPct = totalTarget > 0 ? (totalRealisasi / totalTarget) * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievement Omset'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAchievement,
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 1000,
        child: Column(
          children: [
          // Periode Selector Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              border: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_monthNames[_selectedMonth - 1]} $_selectedYear',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<int>(
                  icon: const Icon(Icons.tune, color: AppColors.primary),
                  tooltip: 'Ganti Bulan',
                  onSelected: (m) {
                    setState(() => _selectedMonth = m);
                    _fetchAchievement();
                  },
                  itemBuilder: (_) => List.generate(12, (i) {
                    return PopupMenuItem(
                      value: i + 1,
                      child: Text(_monthNames[i]),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Ringkasan Total Tim Card dengan Gradien & Shadow Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PENCAPAIAN OMSET KESELURUHAN',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormat.format(totalTarget),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Realisasi',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormat.format(totalRealisasi),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (totalAchPct / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Ach: ${totalAchPct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List Achievement Tiap Sales
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada data omset pada periode ini',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchAchievement,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _rows.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            return _AchievementUserCard(
                              row: row,
                              currencyFormat: currencyFormat,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    ),
  );
}
}

class _AchievementUserCard extends StatelessWidget {
  final AchievementUserRow row;
  final NumberFormat currencyFormat;

  const _AchievementUserCard({
    required this.row,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final achPct = row.ach;
    final isTargetMet = achPct >= 100;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  row.nama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              AppBadge(
                label: '${achPct.toStringAsFixed(1)}%',
                variant: isTargetMet ? BadgeVariant.success : BadgeVariant.primary,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${row.jabatan} • Kode: ${row.kode}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
          ),
          const Divider(height: 18, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Target',
                      style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(row.target),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Realisasi',
                      style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(row.realisasi),
                    style: TextStyle(
                      fontSize: 13,
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
    );
  }
}
