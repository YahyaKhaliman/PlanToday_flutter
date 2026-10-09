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

const _kMonthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

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

  void _showMonthYearPicker() {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pilih Periode Bulan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: tempMonth,
                        decoration: const InputDecoration(labelText: 'Bulan'),
                        items: List.generate(12, (i) {
                          return DropdownMenuItem(
                            value: i + 1,
                            child: Text(
                              _kMonthNames[i],
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) setModalState(() => tempMonth = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: tempYear,
                        decoration: const InputDecoration(labelText: 'Tahun'),
                        items: [2024, 2025, 2026, 2027].map((y) {
                          return DropdownMenuItem(
                            value: y,
                            child: Text(
                              y.toString(),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => tempYear = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedMonth = tempMonth;
                        _selectedYear = tempYear;
                      });
                      _fetchAchievement();
                    },
                    child: const Text(
                      'Terapkan',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Akumulasi Tim
    final totalTarget = _rows.fold<double>(0.0, (acc, r) => acc + r.target);
    final totalRealisasi =
        _rows.fold<double>(0.0, (acc, r) => acc + r.realisasi);
    final totalAchPct =
        totalTarget > 0 ? (totalRealisasi / totalTarget) * 100 : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 1000,
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
                        children: const [
                          Text(
                            'Achievement Omset',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Target vs realisasi omset penjualan',
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
                      onTap: _fetchAchievement,
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

              // 2. PERIODE SELECTOR BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                    ),
                    boxShadow: AppShadows.softCard,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_kMonthNames[_selectedMonth - 1]} $_selectedYear',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _showMonthYearPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: const [
                              Text(
                                'Ganti Bulan',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 16,
                                color: Color(0xFF4F46E5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. RINGKASAN TOTAL TIM (GRADIENT BANNER)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
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
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Target',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
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
                              const Text(
                                'Realisasi',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
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
                      const SizedBox(height: 14),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: (totalAchPct / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 7,
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
              const SizedBox(height: 12),

              // 4. DAFTAR ACHIEVEMENT TIAP SALES
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    : _rows.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada data omset pada periode ini.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF4F46E5),
                            onRefresh: _fetchAchievement,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              itemCount: _rows.length,
                              separatorBuilder: (ctx, i) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final row = _rows[index];
                                return _AchievementUserCard(
                                  row: row,
                                  currencyFormat: currencyFormat,
                                  onTap: () {
                                    context.push('/achievement/detail', extra: {
                                      'userRow': row,
                                      'fromYear': _selectedYear,
                                      'fromMonth': _selectedMonth,
                                      'toYear': _selectedYear,
                                      'toMonth': _selectedMonth,
                                    });
                                  },
                                );
                              },
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

class _AchievementUserCard extends StatelessWidget {
  final AchievementUserRow row;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  const _AchievementUserCard({
    required this.row,
    required this.currencyFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final achPct = row.ach;
    final isTargetMet = achPct >= 100;

    return AppCard(
      onTap: onTap,
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
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppBadge(
                label: '${achPct.toStringAsFixed(1)}%',
                variant:
                    isTargetMet ? BadgeVariant.success : BadgeVariant.primary,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${row.jabatan} • Kode: ${row.kode}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(row.target),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Realisasi',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(row.realisasi),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isTargetMet
                          ? const Color(0xFF10B981)
                          : const Color(0xFF0F172A),
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
