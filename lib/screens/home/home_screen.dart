import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/achievement_model.dart';
import '../../models/penawaran_model.dart';
import '../../models/permintaan_harga_model.dart';
import '../../models/potensi_model.dart';
import '../../models/tracking_model.dart';
import '../../models/visit_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/achievement_repository.dart';
import '../../repositories/penawaran_repository.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../repositories/potensi_repository.dart';
import '../../repositories/tracking_repository.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/web_shortcut_guide_modal.dart';

const _kIndonesianMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

const _kIndonesianDays = [
  'Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu',
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  DateTime _selectedVisitPlanDate = DateTime.now();
  bool _isLoading = true;

  // Selected Months for the 3 modules
  int _phMonth = DateTime.now().month;
  int _phYear = DateTime.now().year;

  int _penawaranMonth = DateTime.now().month;
  int _penawaranYear = DateTime.now().year;

  int _spkMonth = DateTime.now().month;
  int _spkYear = DateTime.now().year;

  // Status Counts
  Map<String, int> _phStatusCounts = {
    'BELUM': 0, 'MINTA': 0, 'WAIT': 0, 'NEGO': 0, 'DONE': 0, 'CANCEL': 0,
  };
  Map<String, int> _penawaranStatusCounts = {
    'OPEN': 0, 'PARSIAL': 0, 'CLOSE': 0,
  };
  Map<String, int> _spkStatusCounts = {
    'BELUM': 0, 'PROSES': 0, 'SUDAH': 0,
  };

  int _unapprovedPenawaranCount = 0;

  // Data states
  List<VisitModel> _visitPlans = [];
  AchievementUserRow? _myAchievement;
  List<PotensiListItem> _rawPotensiItems = [];
  String _selectedPotensiSales = 'ALL';
  bool _isPotensiExpanded = false;

  List<PermintaanHargaItem> _recentPh = [];
  List<TrackingPenawaranListItem> _recentPenawaran = [];
  List<TrackingSpkListItem> _recentSpk = [];

  // Computed Totals for Quick Stats
  int get _totalActivePH =>
      (_phStatusCounts['BELUM'] ?? 0) +
      (_phStatusCounts['MINTA'] ?? 0) +
      (_phStatusCounts['WAIT'] ?? 0);

  int get _totalActivePenawaran =>
      (_penawaranStatusCounts['OPEN'] ?? 0) +
      (_penawaranStatusCounts['PARSIAL'] ?? 0);

  int get _totalActiveSpk =>
      (_spkStatusCounts['BELUM'] ?? 0) +
      (_spkStatusCounts['PROSES'] ?? 0);

  int get _grandTotalNotifications {
    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';
    return _totalActivePH +
        _totalActivePenawaran +
        _totalActiveSpk +
        (isManager ? _unapprovedPenawaranCount : 0);
  }

  // Filtered Potensi
  List<String> get _availablePotensiSales {
    final set = <String>{};
    for (final it in _rawPotensiItems) {
      if (it.salesNama.isNotEmpty) set.add(it.salesNama.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  void _showPotensiSalesPicker() {
    final list = _availablePotensiSales;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Sales (Potensi)',
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
              const Divider(height: 12),
              ListTile(
                title: const Text('Semua Sales', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: _selectedPotensiSales == 'ALL'
                    ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                    : null,
                onTap: () {
                  setState(() => _selectedPotensiSales = 'ALL');
                  Navigator.pop(ctx);
                },
              ),
              ...list.map((salesName) {
                final isSelected = _selectedPotensiSales.toLowerCase() == salesName.toLowerCase();
                return ListTile(
                  title: Text(salesName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                      : null,
                  onTap: () {
                    setState(() => _selectedPotensiSales = salesName);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  List<PotensiListItem> get _filteredPotensiItems {
    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';

    return _rawPotensiItems.where((it) {
      final s = it.status.toUpperCase();
      final isOpen = s == 'OPEN' || s == 'POTENSI' || s.isEmpty;
      if (!isOpen) return false;

      if (isManager && _selectedPotensiSales != 'ALL') {
        final sal = it.salesNama;
        return sal.toLowerCase() == _selectedPotensiSales.toLowerCase();
      }
      return true;
    }).toList();
  }

  double get _totalNominalPotensi =>
      _filteredPotensiItems.fold(0.0, (acc, it) => acc + it.harga);

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  String _formatYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _getRangeStart(int month, int year) =>
      '$year-${month.toString().padLeft(2, '0')}-01';

  String _getRangeEnd(int month, int year) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';

    final selectedDateStr = _formatYmd(_selectedVisitPlanDate);
    final phStart = _getRangeStart(_phMonth, _phYear);
    final phEnd = _getRangeEnd(_phMonth, _phYear);
    final penStart = _getRangeStart(_penawaranMonth, _penawaranYear);
    final penEnd = _getRangeEnd(_penawaranMonth, _penawaranYear);
    final spkStart = _getRangeStart(_spkMonth, _spkYear);
    final spkEnd = _getRangeEnd(_spkMonth, _spkYear);

    final now = DateTime.now();
    final curStart = _getRangeStart(now.month, now.year);
    final curEnd = _getRangeEnd(now.month, now.year);

    final visitRepo = ref.read(visitRepositoryProvider);
    final achRepo = ref.read(achievementRepositoryProvider);
    final phRepo = ref.read(permintaanHargaRepositoryProvider);
    final trackingRepo = ref.read(trackingRepositoryProvider);
    final potensiRepo = ref.read(potensiRepositoryProvider);
    final penawaranRepo = ref.read(penawaranRepositoryProvider);

    try {
      final results = await Future.wait([
        // 0: visit plan
        visitRepo.getVisitPlanList(
          cabang: user?.cabang ?? '',
          sales: user?.nama ?? '',
          startDate: selectedDateStr,
          endDate: selectedDateStr,
          isManager: isManager,
        ),
        // 1: ph counts
        phRepo.getStatusCounts(startDate: phStart, endDate: phEnd),
        // 2: ph recent list
        phRepo.getList(startDate: phStart, endDate: phEnd),
        // 3: penawaran counts
        trackingRepo.getTrackingPenawaranStatusCounts(startDate: penStart, endDate: penEnd),
        // 4: penawaran recent list
        trackingRepo.getTrackingPenawaranList(startDate: penStart, endDate: penEnd),
        // 5: spk counts
        trackingRepo.getTrackingSpkStatusCounts(startDate: spkStart, endDate: spkEnd),
        // 6: spk recent list
        trackingRepo.getTrackingSpkList(startDate: spkStart, endDate: spkEnd),
        // 7: achievement range
        achRepo.getOmsetRange(
          fromYear: now.year,
          fromMonth: now.month,
          toYear: now.year,
          toMonth: now.month,
        ),
        // 8: potensi list
        potensiRepo.getPotensiList(startDate: curStart, endDate: curEnd),
        // 9: unapproved penawaran for manager
        isManager
            ? penawaranRepo.getPenawaranList(approvalStatus: 'UNAPPROVED', limit: 100)
            : Future.value(<PenawaranListItem>[]),
      ]);

      if (mounted) {
        final visitList = results[0] as List<VisitModel>;
        final phCounts = results[1] as Map<String, int>;
        final phList = results[2] as List<PermintaanHargaItem>;
        final penCounts = results[3] as Map<String, int>;
        final penList = results[4] as List<TrackingPenawaranListItem>;
        final spkCounts = results[5] as Map<String, int>;
        final spkList = results[6] as List<TrackingSpkListItem>;
        final achRows = results[7] as List<AchievementUserRow>;
        final potensiRes = results[8] as PotensiResult;
        final unapprovedList = results[9] as List<PenawaranListItem>;

        AchievementUserRow? myAch;
        if (achRows.isNotEmpty) {
          if (isManager) {
            final totalTarget = achRows.fold<double>(0, (acc, r) => acc + r.target);
            final totalReal = achRows.fold<double>(0, (acc, r) => acc + r.realisasi);
            final achPct = totalTarget > 0 ? (totalReal / totalTarget) * 100 : 0.0;
            myAch = AchievementUserRow(
              kode: 'ALL',
              nama: 'Rekap Semua User',
              target: totalTarget,
              realisasi: totalReal,
              ach: achPct.clamp(0, 500),
            );
          } else {
            myAch = achRows.firstWhere(
              (r) => r.nama.toLowerCase() == (user?.nama ?? '').toLowerCase(),
              orElse: () => achRows.first,
            );
          }
        }

        setState(() {
          _visitPlans = visitList;
          _phStatusCounts = phCounts;
          _recentPh = phList.take(3).toList();
          _penawaranStatusCounts = penCounts;
          _recentPenawaran = penList.take(3).toList();
          _spkStatusCounts = spkCounts;
          _recentSpk = spkList.take(3).toList();
          _myAchievement = myAch;
          _rawPotensiItems = potensiRes.list;
          _unapprovedPenawaranCount = unapprovedList.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatLongDate(DateTime dt) {
    final dayName = _kIndonesianDays[dt.weekday % 7];
    final monthName = _kIndonesianMonths[dt.month - 1];
    return '$dayName, ${dt.day} $monthName ${dt.year}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi,';
    if (hour < 15) return 'Selamat Siang,';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  void _showMonthYearPicker({
    required String target,
    required int currentMonth,
    required int currentYear,
    required void Function(int m, int y) onApply,
  }) {
    int tempMonth = currentMonth;
    int tempYear = currentYear;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Periode ($target)',
                      style: const TextStyle(
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
                            child: Text(_kIndonesianMonths[i]),
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
                            child: Text(y.toString()),
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
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onApply(tempMonth, tempYear);
                    },
                    child: const Text(
                      'Terapkan',
                      style: TextStyle(fontWeight: FontWeight.w800),
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

  void _showStatusDetailModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
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
                    'Rincian Status Dokumen',
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
              const Divider(height: 12),
              _buildModalRow(
                title: 'Permintaan Harga',
                activeCount: _totalActivePH,
                color: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/permintaan-harga');
                },
              ),
              _buildModalRow(
                title: 'Penawaran',
                activeCount: _totalActivePenawaran,
                color: const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/penawaran');
                },
              ),
              _buildModalRow(
                title: 'Tracking SPK',
                activeCount: _totalActiveSpk,
                color: const Color(0xFF10B981),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/tracking-spk');
                },
              ),
              if (_unapprovedPenawaranCount > 0)
                _buildModalRow(
                  title: 'Penawaran Belum Disetujui',
                  activeCount: _unapprovedPenawaranCount,
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/penawaran/status');
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalRow({
    required String title,
    required int activeCount,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.06)),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            '$activeCount Aktif',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F9FF),
      drawer: _buildSidebarDrawer(user),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchDashboardData,
          color: const Color(0xFF4F46E5),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: ResponsiveContainer(
              maxWidth: 540,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TOP BAR NAVIGASI (Persis Screenshot Image 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tombol Hamburger Menu
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.08),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.menu_rounded,
                            size: 22,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),

                      // Logo PlanToday Gradient Text
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        child: const Text(
                          'PlanToday',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Tombol Notifikasi Lonceng + Badge Merah
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _showStatusDetailModal,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color.fromRGBO(15, 23, 42, 0.08),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.notifications,
                                size: 22,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            if (_grandTotalNotifications > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    '$_grandTotalNotifications',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isLoading) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: const LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // 2. KARTU PROFIL / SAMBUTAN (Persis Screenshot Image 1)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color.fromRGBO(15, 23, 42, 0.08),
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getGreeting(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              _formatLongDate(DateTime.now()),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (user?.nama ?? 'User').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${user?.jabatan ?? "-"} · ${user?.cabang ?? "-"}'.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. TIGA KARTU QUICK STATS SEJAJAR (Persis Screenshot Image 1)
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickStatCard(
                          number: '$_totalActivePH',
                          label: 'PH Pending',
                          color: const Color(0xFFEF4444),
                          onTap: () => context.push('/permintaan-harga'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickStatCard(
                          number: '$_totalActivePenawaran',
                          label: 'Penawaran Open',
                          color: const Color(0xFF3B82F6),
                          onTap: () => context.push('/penawaran'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickStatCard(
                          number: '$_totalActiveSpk',
                          label: 'SPK Open',
                          color: const Color(0xFF10B981),
                          onTap: () => context.push('/tracking-spk'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4. KARTU VISIT PLAN (Persis Screenshot Image 1)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color.fromRGBO(15, 23, 42, 0.08),
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Visit Plan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 14),

                        // Navigator Tanggal Stepper (< [icon] Tanggal >)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    _selectedVisitPlanDate =
                                        _selectedVisitPlanDate.subtract(
                                      const Duration(days: 1),
                                    );
                                  });
                                  _fetchDashboardData();
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.chevron_left_rounded,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: Color(0xFF4F46E5),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatLongDate(_selectedVisitPlanDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    _selectedVisitPlanDate =
                                        _selectedVisitPlanDate.add(
                                      const Duration(days: 1),
                                    );
                                  });
                                  _fetchDashboardData();
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Empty State / List Visit Plan
                        if (_visitPlans.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Tidak ada jadwal visit plan untuk tanggal ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: _visitPlans.map((vp) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color.fromRGBO(15, 23, 42, 0.06),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vp.cusNama,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            vp.note.isNotEmpty ? vp.note : vp.cusAlamat,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (vp.realisasi?.toUpperCase() == 'Y')
                                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                            : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        (vp.realisasi?.toUpperCase() == 'Y') ? 'SUDAH' : 'BELUM',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: (vp.realisasi?.toUpperCase() == 'Y')
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. KARTU ACHIEVEMENT BULAN INI (Persis Screenshot Image 1 & 5)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color.fromRGBO(15, 23, 42, 0.08),
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.stars_rounded,
                                  size: 20,
                                  color: Color(0xFF6366F1),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Achievement Bulan Ini',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => context.push('/achievement'),
                              child: const Row(
                                children: [
                                  Text(
                                    'Detail',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Dua Kartu Target vs Realisasi
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color.fromRGBO(15, 23, 42, 0.06),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Target Bulan Ini',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currencyFormat.format(
                                        _myAchievement?.target ?? 0,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color.fromRGBO(15, 23, 42, 0.06),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Realisasi Bulan Ini',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currencyFormat.format(
                                        _myAchievement?.realisasi ?? 0,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF10B981),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Persentase & Progress Bar
                        Row(
                          children: [
                            Text(
                              '${(_myAchievement?.ach ?? 0).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: ((_myAchievement?.ach ?? 0) / 100)
                                      .clamp(0.0, 1.0),
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 6. KARTU POTENSI BULAN INI (Persis Screenshot Image 5)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color.fromRGBO(15, 23, 42, 0.08),
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.trending_up_rounded,
                                  size: 20,
                                  color: Color(0xFF4F46E5),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Potensi Bulan Ini',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => context.push('/potensi'),
                              child: const Row(
                                children: [
                                  Text(
                                    'Lihat Semua',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Filter Sales (untuk role Manager)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _showPotensiSalesPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color.fromRGBO(15, 23, 42, 0.06),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Filter Sales',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _selectedPotensiSales == 'ALL'
                                          ? 'Semua Sales'
                                          : _selectedPotensiSales,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Nominal Total & Button Toggle Dropdown Item
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Nominal Potensi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat.format(_totalNominalPotensi),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF4F46E5),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _isPotensiExpanded = !_isPotensiExpanded;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _isPotensiExpanded
                                      ? const Color(0xFFEEF2FF)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isPotensiExpanded
                                        ? const Color(0xFF4F46E5)
                                        : const Color.fromRGBO(15, 23, 42, 0.06),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '${_filteredPotensiItems.length} Item',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _isPotensiExpanded
                                            ? const Color(0xFF4F46E5)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Icon(
                                      _isPotensiExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: _isPotensiExpanded
                                          ? const Color(0xFF4F46E5)
                                          : const Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // List Item Accordion jika dibuka
                        if (_isPotensiExpanded) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          ..._filteredPotensiItems.take(5).map((pItem) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pItem.namaItem,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          pItem.customerNama,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    currencyFormat.format(pItem.harga),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 7. PERMINTAAN HARGA TERBARU (Persis Screenshot Image 4 — Left Stripe Merah)
                  _buildStripeModuleCard(
                    stripeColor: const Color(0xFFEF4444),
                    title: 'Permintaan Harga Terbaru',
                    periodText:
                        '${_kIndonesianMonths[_phMonth - 1]} $_phYear',
                    onSelectPeriod: () {
                      _showMonthYearPicker(
                        target: 'PH',
                        currentMonth: _phMonth,
                        currentYear: _phYear,
                        onApply: (m, y) {
                          setState(() {
                            _phMonth = m;
                            _phYear = y;
                          });
                          _fetchDashboardData();
                        },
                      );
                    },
                    onViewAll: () => context.push('/permintaan-harga'),
                    chips: [
                      _buildChip(
                        'MINTA: ${_phStatusCounts['MINTA'] ?? 0}',
                        bg: const Color(0xFFFEE2E2),
                        border: const Color(0xFFFCA5A5),
                        text: const Color(0xFFDC2626),
                      ),
                      _buildChip(
                        'WAIT: ${_phStatusCounts['WAIT'] ?? 0}',
                        bg: const Color(0xFFDCFCE7),
                        border: const Color(0xFF86EFAC),
                        text: const Color(0xFF16A34A),
                      ),
                      _buildChip(
                        'DONE: ${_phStatusCounts['DONE'] ?? 0}',
                        bg: const Color(0xFFF1F5F9),
                        border: const Color(0xFFCBD5E1),
                        text: const Color(0xFF475569),
                      ),
                    ],
                    segmentedBar: _buildSegmentedBar([
                      _Segment(
                        count: _phStatusCounts['MINTA'] ?? 0,
                        color: const Color(0xFFEF4444),
                      ),
                      _Segment(
                        count: _phStatusCounts['WAIT'] ?? 0,
                        color: const Color(0xFF10B981),
                      ),
                      _Segment(
                        count: _phStatusCounts['DONE'] ?? 0,
                        color: const Color(0xFF1E293B),
                      ),
                    ]),
                    items: _recentPh.map((ph) {
                      return _buildRecentItemBox(
                        code: ph.nomor,
                        date: ph.tanggal,
                        customer: ph.customer,
                        detail: '${ph.nama} (${ph.divisi})',
                        status: ph.status,
                        statusColor: const Color(0xFFDC2626),
                        statusBg: const Color(0xFFFEE2E2),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // 8. PENAWARAN TERBARU (Persis Screenshot Image 3 — Left Stripe Biru)
                  _buildStripeModuleCard(
                    stripeColor: const Color(0xFF3B82F6),
                    title: 'Penawaran Terbaru',
                    periodText:
                        '${_kIndonesianMonths[_penawaranMonth - 1]} $_penawaranYear',
                    onSelectPeriod: () {
                      _showMonthYearPicker(
                        target: 'Penawaran',
                        currentMonth: _penawaranMonth,
                        currentYear: _penawaranYear,
                        onApply: (m, y) {
                          setState(() {
                            _penawaranMonth = m;
                            _penawaranYear = y;
                          });
                          _fetchDashboardData();
                        },
                      );
                    },
                    onViewAll: () => context.push('/penawaran'),
                    chips: [
                      _buildChip(
                        'OPEN: ${_penawaranStatusCounts['OPEN'] ?? 0}',
                        bg: const Color(0xFFFEE2E2),
                        border: const Color(0xFFFCA5A5),
                        text: const Color(0xFFDC2626),
                      ),
                      _buildChip(
                        'PARSIAL: ${_penawaranStatusCounts['PARSIAL'] ?? 0}',
                        bg: const Color(0xFFDBEAFE),
                        border: const Color(0xFF93C5FD),
                        text: const Color(0xFF2563EB),
                      ),
                      _buildChip(
                        'CLOSE: ${_penawaranStatusCounts['CLOSE'] ?? 0}',
                        bg: const Color(0xFFDCFCE7),
                        border: const Color(0xFF86EFAC),
                        text: const Color(0xFF16A34A),
                      ),
                    ],
                    segmentedBar: _buildSegmentedBar([
                      _Segment(
                        count: _penawaranStatusCounts['OPEN'] ?? 0,
                        color: const Color(0xFFEF4444),
                      ),
                      _Segment(
                        count: _penawaranStatusCounts['PARSIAL'] ?? 0,
                        color: const Color(0xFF3B82F6),
                      ),
                      _Segment(
                        count: _penawaranStatusCounts['CLOSE'] ?? 0,
                        color: const Color(0xFF10B981),
                      ),
                    ]),
                    items: _recentPenawaran.map((pen) {
                      final hasItems = pen.totalItem > 0;
                      final progress = hasItems
                          ? (pen.totalItemMap / pen.totalItem).clamp(0.0, 1.0)
                          : 0.0;
                      return _buildRecentItemBox(
                        code: pen.noPenawaran,
                        date: pen.tanggalPenawaran,
                        customer: pen.customer,
                        detail:
                            '${pen.totalItemMap} dari ${pen.totalItem} item MAP',
                        status: pen.statusTracking,
                        statusColor: const Color(0xFFDC2626),
                        statusBg: const Color(0xFFFEE2E2),
                        progress: progress,
                        progressColor: const Color(0xFFEF4444),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // 9. SPK TERBARU (Persis Screenshot Image 2 — Left Stripe Hijau)
                  _buildStripeModuleCard(
                    stripeColor: const Color(0xFF10B981),
                    title: 'SPK Terbaru',
                    periodText:
                        '${_kIndonesianMonths[_spkMonth - 1]} $_spkYear',
                    onSelectPeriod: () {
                      _showMonthYearPicker(
                        target: 'SPK',
                        currentMonth: _spkMonth,
                        currentYear: _spkYear,
                        onApply: (m, y) {
                          setState(() {
                            _spkMonth = m;
                            _spkYear = y;
                          });
                          _fetchDashboardData();
                        },
                      );
                    },
                    onViewAll: () => context.push('/tracking-spk'),
                    chips: [
                      _buildChip(
                        'OPEN: ${_spkStatusCounts['BELUM'] ?? 0}',
                        bg: const Color(0xFFFEE2E2),
                        border: const Color(0xFFFCA5A5),
                        text: const Color(0xFFDC2626),
                      ),
                      _buildChip(
                        'PROSES: ${_spkStatusCounts['PROSES'] ?? 0}',
                        bg: const Color(0xFFFEF3C7),
                        border: const Color(0xFFFCD34D),
                        text: const Color(0xFFD97706),
                      ),
                      _buildChip(
                        'CLOSE: ${_spkStatusCounts['SUDAH'] ?? 0}',
                        bg: const Color(0xFFDCFCE7),
                        border: const Color(0xFF86EFAC),
                        text: const Color(0xFF16A34A),
                      ),
                    ],
                    segmentedBar: _buildSegmentedBar([
                      _Segment(
                        count: _spkStatusCounts['BELUM'] ?? 0,
                        color: const Color(0xFFEF4444),
                      ),
                      _Segment(
                        count: _spkStatusCounts['PROSES'] ?? 0,
                        color: const Color(0xFFF59E0B),
                      ),
                      _Segment(
                        count: _spkStatusCounts['SUDAH'] ?? 0,
                        color: const Color(0xFF10B981),
                      ),
                    ]),
                    items: _recentSpk.map((spk) {
                      final ord = spk.qty;
                      final real = spk.realisasiTotal;
                      final progress =
                          ord > 0 ? (real / ord).clamp(0.0, 1.0) : 0.0;
                      return _buildRecentItemBox(
                        code: spk.noSpk,
                        date: spk.tanggalSpk,
                        customer: spk.namaBarang,
                        detail:
                            'Realisasi: ${real.toInt()} / ${ord.toInt()}',
                        status: spk.status.isEmpty ? 'OPEN' : spk.status,
                        statusColor: const Color(0xFFDC2626),
                        statusBg: const Color(0xFFFEE2E2),
                        progress: progress,
                        progressColor: const Color(0xFFEF4444),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── WIDGET HELPER: 3 KARTU QUICK STATS
  Widget _buildQuickStatCard({
    required String number,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 84,
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
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    number,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            // Garis Aksen Bawah (Bottom Curve Highlight)
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── WIDGET HELPER: KARTU MODUL BER-STRIPE KIRI
  Widget _buildStripeModuleCard({
    required Color stripeColor,
    required String title,
    required String periodText,
    required VoidCallback onSelectPeriod,
    required VoidCallback onViewAll,
    required List<Widget> chips,
    required Widget segmentedBar,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color.fromRGBO(15, 23, 42, 0.08),
        ),
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        children: [
          // Stripe Vertikal Kiri Melengkung
          Positioned(
            left: 0,
            top: 14,
            bottom: 14,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: stripeColor,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    GestureDetector(
                      onTap: onViewAll,
                      child: const Row(
                        children: [
                          Text(
                            'Lihat Semua',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Color(0xFF4F46E5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Periode Pill Selector
                Row(
                  children: [
                    const Text(
                      'Periode: ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    GestureDetector(
                      onTap: onSelectPeriod,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              periodText,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            const Icon(
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
                const SizedBox(height: 12),

                // Chips Row
                Row(
                  children: chips.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: c,
                  )).toList(),
                ),
                const SizedBox(height: 10),

                // Segmented Progress Bar
                segmentedBar,
                const SizedBox(height: 12),

                // Item List
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Belum ada data terbaru.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  )
                else
                  Column(children: items),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    String label, {
    required Color bg,
    required Color border,
    required Color text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }

  Widget _buildSegmentedBar(List<_Segment> segments) {
    final total = segments.fold<int>(0, (acc, s) => acc + s.count);
    if (total == 0) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(99),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Row(
          children: segments.where((s) => s.count > 0).map((s) {
            return Expanded(
              flex: s.count,
              child: Container(color: s.color),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecentItemBox({
    required String code,
    required String date,
    required String customer,
    required String detail,
    required String status,
    required Color statusColor,
    required Color statusBg,
    double? progress,
    Color? progressColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color.fromRGBO(15, 23, 42, 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                code,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4F46E5),
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            customer,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressColor ?? const Color(0xFFEF4444),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── SIDEBAR DRAWER MENU
  Widget _buildSidebarDrawer(dynamic user) {
    final initials = (user?.nama ?? 'U')
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join('')
        .toUpperCase();

    final menuCategories = [
      {
        'title': 'AKTIVITAS HARIAN',
        'items': [
          {'title': 'Customer', 'icon': Icons.people_outline, 'route': '/customer'},
          {'title': 'Visit Plan', 'icon': Icons.calendar_today_outlined, 'route': '/visit-plan'},
          {'title': 'Visit', 'icon': Icons.place_outlined, 'route': '/visit'},
          {'title': 'Achievement', 'icon': Icons.stars_outlined, 'route': '/achievement'},
        ],
      },
      {
        'title': 'PENJUALAN',
        'items': [
          {'title': 'Permintaan Harga', 'icon': Icons.monetization_on_outlined, 'route': '/permintaan-harga'},
          {'title': 'Penawaran', 'icon': Icons.receipt_outlined, 'route': '/penawaran'},
        ],
      },
      {
        'title': 'PELACAKAN & LAINNYA',
        'items': [
          {'title': 'Tracking Penawaran', 'icon': Icons.push_pin_outlined, 'route': '/tracking-penawaran'},
          {'title': 'Tracking MAP', 'icon': Icons.map_outlined, 'route': '/tracking-map'},
          {'title': 'Tracking SPK', 'icon': Icons.assignment_outlined, 'route': '/tracking-spk'},
          {'title': 'Potensi', 'icon': Icons.trending_up_outlined, 'route': '/potensi'},
        ],
      },
      {
        'title': 'PENGATURAN',
        'items': [
          {'title': 'Ganti Password', 'icon': Icons.vpn_key_outlined, 'route': '/ganti-password'},
        ],
      },
    ];

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header Profil
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials.isEmpty ? 'U' : initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (user?.nama ?? 'User').toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${user?.jabatan ?? "-"} · ${user?.cabang ?? "-"}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                    onPressed: () {
                      Navigator.pop(context);
                      ref.read(authProvider.notifier).logout();
                    },
                  ),
                ],
              ),
            ),

            // Menu Items Grid
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: menuCategories.map((cat) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          cat['title'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.2,
                        children: (cat['items'] as List).map<Widget>((item) {
                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              context.push(item['route'] as String);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color.fromRGBO(15, 23, 42, 0.06),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 18,
                                    color: const Color(0xFF4F46E5),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }).toList(),
              ),
            ),

            // Tombol Bantuan Pintasan (Web Only)
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.pop(context);
                    showShortcutGuide(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.shortcut_rounded,
                          size: 16,
                          color: Color(0xFF4F46E5),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cara Buat Pintasan di HP / PC',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Color(0xFF4F46E5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment {
  final int count;
  final Color color;
  const _Segment({required this.count, required this.color});
}
