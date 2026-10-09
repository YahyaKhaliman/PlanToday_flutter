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
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/segmented_bar.dart';
import '../../providers/version_provider.dart';
import '../../widgets/web_shortcut_guide_modal.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _selectedVisitPlanDate = DateTime.now();
  bool _isLoading = false;

  // Data states
  List<VisitModel> _visitPlans = [];
  AchievementUserRow? _myAchievement;
  List<PotensiListItem> _potensiItems = [];
  PotensiKpiSummary? _potensiKpi;
  bool _isPotensiExpanded = false;

  List<PermintaanHargaItem> _recentPh = [];
  List<PenawaranListItem> _recentPenawaran = [];
  List<TrackingSpkListItem> _recentSpk = [];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final ymdFormat = DateFormat('yyyy-MM-dd');
    final selectedDateStr = ymdFormat.format(_selectedVisitPlanDate);

    // 1. Visit Plans
    final visitRepo = ref.read(visitRepositoryProvider);
    final visitPlans = await visitRepo.getVisitPlanList(
      cabang: user?.cabang ?? '',
      sales: user?.nama ?? '',
      startDate: selectedDateStr,
      endDate: selectedDateStr,
      isManager: user?.jabatan.toUpperCase() == 'MANAGER',
    );

    // 2. Achievement
    final achRepo = ref.read(achievementRepositoryProvider);
    final now = DateTime.now();
    final achRows = await achRepo.getOmsetRange(
      fromYear: now.year,
      fromMonth: now.month,
      toYear: now.year,
      toMonth: now.month,
    );
    AchievementUserRow? myAch;
    if (achRows.isNotEmpty) {
      myAch = achRows.firstWhere(
        (r) => r.nama.toLowerCase() == (user?.nama ?? '').toLowerCase(),
        orElse: () => achRows.first,
      );
    }

    // 3. Potensi
    final potensiRepo = ref.read(potensiRepositoryProvider);
    final potensiRes = await potensiRepo.getPotensiList();

    // 4. Permintaan Harga
    final phRepo = ref.read(permintaanHargaRepositoryProvider);
    final phList = await phRepo.getList();

    // 5. Penawaran
    final penawaranRepo = ref.read(penawaranRepositoryProvider);
    final penawaranList = await penawaranRepo.getPenawaranList();

    // 6. SPK
    final trackingRepo = ref.read(trackingRepositoryProvider);
    final spkList = await trackingRepo.getTrackingSpkList();

    if (mounted) {
      setState(() {
        _visitPlans = visitPlans;
        _myAchievement = myAch;
        _potensiItems = potensiRes.list;
        _potensiKpi = potensiRes.kpi;
        _recentPh = phList.take(3).toList();
        _recentPenawaran = penawaranList.take(3).toList();
        _recentSpk = spkList.take(3).toList();
        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _formatLongDate(DateTime dt) {
    const days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[dt.weekday % 7]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Konfirmasi Logout', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void _showNotificationModal() {
    final activePhCount = _recentPh.length;
    final activePenawaranCount = _recentPenawaran.length;
    final activeSpkCount = _recentSpk.length;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rincian Status Dokumen',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.request_quote_outlined, color: AppColors.danger, size: 20),
                ),
                title: const Text('Permintaan Harga Aktif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: Text('$activePhCount Dokumen', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/permintaan-harga');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
                ),
                title: const Text('Penawaran Dalam Proses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: Text('$activePenawaranCount Dokumen', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/penawaran');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_outlined, color: AppColors.success, size: 20),
                ),
                title: const Text('SPK Berjalan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: Text('$activeSpkCount Dokumen', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/tracking-spk');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final totalNotificationCount = _recentPh.length + _recentPenawaran.length + _recentSpk.length;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSidebarDrawer(user),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. TOP HEADER ROW (☰ Menu Button + PlanToday Gradient Title + 🔔 Bell Badge)
              _buildTopHeaderRow(totalNotificationCount),

              // 2. MAIN SCROLLABLE DASHBOARD
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _fetchDashboardData,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ResponsiveContainer(
                            maxWidth: 1000,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Welcome Greeting Card
                                _buildWelcomeCard(user),
                                const SizedBox(height: 12),

                                // Quick Stats Strip
                                _buildQuickStatsStrip(),
                                const SizedBox(height: 14),

                                // Widget 1: Visit Plan (Date Stepper + List)
                                _buildVisitPlanWidget(),
                                const SizedBox(height: 14),

                                // Widget 2: Achievement Bulan Ini (Target, Realisasi, Ach Bar)
                                _buildAchievementWidget(currencyFormat),
                                const SizedBox(height: 14),

                                // Widget 3: Potensi Bulan Ini (Accordion Nominal & Items)
                                _buildPotensiWidget(currencyFormat),
                                const SizedBox(height: 14),

                                // Widget 4: Permintaan Harga Terbaru (Red Accent Border)
                                _buildPermintaanHargaWidget(currencyFormat),
                                const SizedBox(height: 14),

                                // Widget 5: Penawaran Terbaru (Blue Accent Border)
                                _buildPenawaranWidget(currencyFormat),
                                const SizedBox(height: 14),

                                // Widget 6: SPK Terbaru (Green Accent Border)
                                _buildSpkWidget(),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= UI SECTION BUILDERS ================= //

  Widget _buildTopHeaderRow(int notificationCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Hamburger Menu Button
          IconButton(
            icon: const Icon(Icons.menu, size: 26, color: AppColors.primary),
            tooltip: 'Buka Menu',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),

          // PlanToday Gradient Brand Title + Small Version Below
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ).createShader(bounds),
                child: const Text(
                  'PlanToday',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final version =
                      ref.watch(versionProvider).currentVersion;
                  return Text(
                    version,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                      letterSpacing: 0.2,
                    ),
                  );
                },
              ),
            ],
          ),

          // Bell Notification Button with dynamic badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, size: 24, color: AppColors.primary),
                tooltip: 'Notifikasi Status',
                onPressed: _showNotificationModal,
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$notificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()},',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  (user?.nama ?? 'User').toUpperCase(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${user?.jabatan ?? "-"} · ${user?.cabang ?? "-"}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Text(
              _formatLongDate(DateTime.now()),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsStrip() {
    return Row(
      children: [
        Expanded(
          child: _QuickStatChip(
            number: '${_recentPh.length}',
            label: 'PH Pending',
            accentColor: AppColors.danger,
            onTap: () => context.push('/permintaan-harga'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickStatChip(
            number: '${_recentPenawaran.length}',
            label: 'Penawaran Open',
            accentColor: AppColors.primary,
            onTap: () => context.push('/penawaran'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickStatChip(
            number: '${_recentSpk.length}',
            label: 'SPK Open',
            accentColor: AppColors.success,
            onTap: () => context.push('/tracking-spk'),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitPlanWidget() {
    final doneCount = _visitPlans.where((vp) => vp.realisasi == 'Y').length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Visit Plan ($doneCount/${_visitPlans.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.push('/visit-plan/tambah'),
                child: const Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 16, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Buat Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stepper Tanggal (Kemarin ◀, Tanggal panjang, Besok ▶)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.primary, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedVisitPlanDate = _selectedVisitPlanDate.subtract(const Duration(days: 1));
                    });
                    _fetchDashboardData();
                  },
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedVisitPlanDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedVisitPlanDate = picked);
                      _fetchDashboardData();
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        _formatLongDate(_selectedVisitPlanDate),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedVisitPlanDate = _selectedVisitPlanDate.add(const Duration(days: 1));
                    });
                    _fetchDashboardData();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Items List
          if (_visitPlans.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: const Text('Tidak ada jadwal visit plan untuk tanggal ini.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            )
          else
            ..._visitPlans.map((vp) {
              final isDone = vp.realisasi == 'Y';
              return InkWell(
                onTap: () {
                  if (isDone) {
                    context.push('/visit/edit', extra: vp);
                  } else {
                    context.push('/visit-plan/edit', extra: vp);
                  }
                },
                borderRadius: BorderRadius.circular(AppRadius.medium),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.soft,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(vp.cusNama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink)),
                            if (vp.cusAlamat.isNotEmpty)
                              Text(vp.cusAlamat, style: const TextStyle(fontSize: 11, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (vp.note.isNotEmpty)
                              Text('Note: ${vp.note}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.ink)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isDone)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('SELESAI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success)),
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(64, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            backgroundColor: AppColors.primary,
                          ),
                          onPressed: () => context.push('/visit/tambah'),
                          child: const Text('Visit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAchievementWidget(NumberFormat currencyFormat) {
    final target = _myAchievement?.target ?? 0.0;
    final realisasi = _myAchievement?.realisasi ?? 0.0;
    final achPct = _myAchievement?.ach ?? (target > 0 ? (realisasi / target) * 100 : 0.0);

    Color achColor = AppColors.danger;
    if (achPct >= 80) {
      achColor = AppColors.success;
    } else if (achPct >= 50) {
      achColor = AppColors.warning;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.stars, size: 18, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('Achievement Bulan Ini', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                ],
              ),
              InkWell(
                onTap: () => context.push('/achievement'),
                child: const Row(
                  children: [
                    Text('Detail', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Target Bulan Ini', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(currencyFormat.format(target), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.ink)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Realisasi Bulan Ini', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(currencyFormat.format(realisasi), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.success)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${achPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: achColor)),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (achPct / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(achColor),
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPotensiWidget(NumberFormat currencyFormat) {
    final totalNominal = _potensiKpi?.totalNominal ?? _potensiItems.fold<double>(0.0, (acc, curr) => acc + curr.harga);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up, size: 18, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('Potensi Bulan Ini', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                ],
              ),
              InkWell(
                onTap: () => context.push('/potensi'),
                child: const Row(
                  children: [
                    Text('Lihat Semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Nominal Potensi', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  Text(currencyFormat.format(totalNominal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _isPotensiExpanded = !_isPotensiExpanded),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isPotensiExpanded ? AppColors.primary.withValues(alpha: 0.1) : AppColors.soft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isPotensiExpanded ? AppColors.primary : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Text('${_potensiItems.length} Item', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      Icon(_isPotensiExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isPotensiExpanded) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: _potensiItems.take(5).map((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.namaItem, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(p.customerNama, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        Text(currencyFormat.format(p.harga), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermintaanHargaWidget(NumberFormat currencyFormat) {
    // Segmen warna untuk distribusi status PH (BELUM, MINTA, WAIT, NEGO, DONE)
    final phSegments = [
      SegmentItem(count: _recentPh.isNotEmpty ? 1 : 0, color: CompanyStatusColors.belum.base),
      SegmentItem(count: _recentPh.length >= 2 ? 1 : 0, color: CompanyStatusColors.minta.base),
      SegmentItem(count: _recentPh.length >= 3 ? 1 : 0, color: CompanyStatusColors.wait.base),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: const Border(
          left: BorderSide(color: AppColors.danger, width: 4),
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Permintaan Harga Terbaru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
              InkWell(
                onTap: () => context.push('/permintaan-harga'),
                child: const Row(
                  children: [
                    Text('Lihat Semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Status Breakdown Chips (shadcn/ui AppBadge style)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge(label: 'BELUM: ${_recentPh.length}', customColor: CompanyStatusColors.belum.base),
              AppBadge(label: 'MINTA: ${_recentPh.isNotEmpty ? 1 : 0}', customColor: CompanyStatusColors.minta.base),
              AppBadge(label: 'WAIT: ${_recentPh.length > 1 ? 1 : 0}', customColor: CompanyStatusColors.wait.base),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Segmented Bar
          SegmentedBar(segments: phSegments, height: 6),
          const SizedBox(height: 10),

          // Recent PH Items
          if (_recentPh.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Belum ada data PH terbaru', style: TextStyle(color: AppColors.muted, fontSize: 12)))
          else
            ..._recentPh.map((ph) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(AppRadius.medium)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ph.nomor, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.primary)),
                          Text(ph.customer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                        ],
                      ),
                    ),
                    AppBadge(label: '${ph.jmlOrder.toInt()} pcs', variant: BadgeVariant.primary),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPenawaranWidget(NumberFormat currencyFormat) {
    final penawaranSegments = [
      SegmentItem(count: _recentPenawaran.isNotEmpty ? 1 : 0, color: AppColors.danger),
      SegmentItem(count: _recentPenawaran.length >= 2 ? 1 : 0, color: AppColors.primary),
      SegmentItem(count: _recentPenawaran.length >= 3 ? 1 : 0, color: AppColors.success),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 4),
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Penawaran Terbaru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
              InkWell(
                onTap: () => context.push('/penawaran'),
                child: const Row(
                  children: [
                    Text('Lihat Semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Status Breakdown Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge(label: 'OPEN: ${_recentPenawaran.isNotEmpty ? 1 : 0}', variant: BadgeVariant.danger),
              AppBadge(label: 'PARSIAL: ${_recentPenawaran.length > 1 ? 1 : 0}', variant: BadgeVariant.primary),
              AppBadge(label: 'CLOSE: ${_recentPenawaran.length > 2 ? 1 : 0}', variant: BadgeVariant.success),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Segmented Bar
          SegmentedBar(segments: penawaranSegments, height: 6),
          const SizedBox(height: 10),

          if (_recentPenawaran.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Belum ada data penawaran terbaru', style: TextStyle(color: AppColors.muted, fontSize: 12)))
          else
            ..._recentPenawaran.map((pen) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(AppRadius.medium)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pen.nomor, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.primary)),
                          Text(pen.customer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                        ],
                      ),
                    ),
                    Text(currencyFormat.format(pen.nominal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.ink)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSpkWidget() {
    final spkSegments = [
      SegmentItem(count: _recentSpk.isNotEmpty ? 1 : 0, color: AppColors.danger),
      SegmentItem(count: _recentSpk.length >= 2 ? 1 : 0, color: AppColors.warning),
      SegmentItem(count: _recentSpk.length >= 3 ? 1 : 0, color: AppColors.success),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: const Border(
          left: BorderSide(color: AppColors.success, width: 4),
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SPK Terbaru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
              InkWell(
                onTap: () => context.push('/tracking-spk'),
                child: const Row(
                  children: [
                    Text('Lihat Semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Status Breakdown Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge(label: 'OPEN: ${_recentSpk.isNotEmpty ? 1 : 0}', variant: BadgeVariant.danger),
              AppBadge(label: 'PROSES: ${_recentSpk.length > 1 ? 1 : 0}', variant: BadgeVariant.warning),
              AppBadge(label: 'CLOSE: ${_recentSpk.length > 2 ? 1 : 0}', variant: BadgeVariant.success),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Segmented Bar
          SegmentedBar(segments: spkSegments, height: 6),
          const SizedBox(height: 10),

          if (_recentSpk.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Belum ada data SPK terbaru', style: TextStyle(color: AppColors.muted, fontSize: 12)))
          else
            ..._recentSpk.map((spk) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(AppRadius.medium)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spk.noSpk, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.primary)),
                          Text(spk.customer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                        ],
                      ),
                    ),
                    AppBadge(label: '${spk.qty.toInt()} pcs', variant: BadgeVariant.success),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ================= SIDEBAR DRAWER BUILDER ================= //

  Widget _buildSidebarDrawer(dynamic user) {
    final initials = (user?.nama ?? 'U').isNotEmpty ? user!.nama.substring(0, 1).toUpperCase() : 'U';

    final menuCategories = [
      {
        'title': 'AKTIVITAS HARIAN',
        'items': [
          {'title': 'Customer', 'route': '/customer', 'icon': Icons.people_alt_outlined},
          {'title': 'Visit Plan', 'route': '/visit-plan', 'icon': Icons.calendar_month_outlined},
          {'title': 'Visit', 'route': '/visit', 'icon': Icons.location_on_outlined},
          {'title': 'Achievement', 'route': '/achievement', 'icon': Icons.emoji_events_outlined},
        ]
      },
      {
        'title': 'PENJUALAN',
        'items': [
          {'title': 'Permintaan Harga', 'route': '/permintaan-harga', 'icon': Icons.request_quote_outlined},
          {'title': 'Penawaran', 'route': '/penawaran', 'icon': Icons.receipt_long_outlined},
        ]
      },
      {
        'title': 'PELACAKAN & LAINNYA',
        'items': [
          {'title': 'Tracking Penawaran', 'route': '/tracking-penawaran', 'icon': Icons.pin_drop_outlined},
          {'title': 'Tracking MAP', 'route': '/tracking-map', 'icon': Icons.map_outlined},
          {'title': 'Tracking SPK', 'route': '/tracking-spk', 'icon': Icons.assignment_outlined},
          {'title': 'Potensi', 'route': '/potensi', 'icon': Icons.trending_up_outlined},
          {'title': 'Pengiriman Kurir', 'route': '/kurir', 'icon': Icons.local_shipping_outlined},
        ]
      },
      {
        'title': 'PENGATURAN',
        'items': [
          {'title': 'Ganti Password', 'route': '/ganti-password', 'icon': Icons.vpn_key_outlined},
        ]
      },
    ];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header Profil User
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.nama ?? 'User', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.ink)),
                        Text('${user?.jabatan ?? "-"} · ${user?.cabang ?? "-"}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: AppColors.danger),
                    tooltip: 'Logout',
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmLogout();
                    },
                  ),
                ],
              ),
            ),

            // Categorized Menu List
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
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.8),
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
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.soft,
                                borderRadius: BorderRadius.circular(AppRadius.medium),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(item['icon'] as IconData, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item['title'] as String,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.ink),
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

            // Tombol Bantuan Pintasan (hanya di Web)
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.pop(context);
                    showShortcutGuide(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shortcut_rounded, size: 16, color: Color(0xFF4F46E5)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cara Buat Pintasan di HP / PC',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF4F46E5)),
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

class _QuickStatChip extends StatelessWidget {
  final String number;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickStatChip({
    required this.number,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.softCard,
        ),
        child: Column(
          children: [
            Text(number, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: accentColor)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted), textAlign: TextAlign.center, maxLines: 1),
            const SizedBox(height: 4),
            Container(height: 3, width: 24, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
          ],
        ),
      ),
    );
  }
}
