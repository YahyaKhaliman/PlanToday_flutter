import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/kurir_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/kurir_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

class KurirMenuScreen extends ConsumerStatefulWidget {
  const KurirMenuScreen({super.key});

  @override
  ConsumerState<KurirMenuScreen> createState() => _KurirMenuScreenState();
}

class _KurirMenuScreenState extends ConsumerState<KurirMenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<KurirRencanaItem> _jadwalList = [];
  List<KurirRencanaItem> _rencanaList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    final repo = ref.read(kurirRepositoryProvider);
    final now = DateTime.now();

    final startStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final endStr =
        '${now.year}-${(now.month + 1).toString().padLeft(2, '0')}-01';

    final jadwal =
        await repo.getJadwalKirim(startDate: startStr, endDate: endStr);
    final rencana =
        await repo.getRencanaKirim(startDate: startStr, endDate: endStr);

    if (mounted) {
      setState(() {
        _jadwalList = jadwal;
        _rencanaList = rencana;
        _isLoading = false;
      });
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi Keluar',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        content: const Text('Apakah Anda yakin ingin keluar dari akun kurir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final initials = (user?.nama ?? 'K')
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join('')
        .toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 1000,
          child: Column(
            children: [
              // 1. HERO PROFILE CARD ALA REACT NATIVE
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                    ),
                    boxShadow: AppShadows.softCard,
                  ),
                  child: Column(
                    children: [
                      // Header Row: Back Button + Brand Logo Centered
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => context.pop(),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color.fromRGBO(15, 23, 42, 0.06),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.chevron_left_rounded,
                                size: 24,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(bounds),
                            child: const Text(
                              'PlanToday',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 38),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Profile Row
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials.isEmpty ? 'K' : initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (user?.nama ?? 'KURIR').toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'KURIR',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•  ${user?.cabang ?? "-"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Quick Actions: Ganti Password & Keluar
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => context.push('/ganti-password'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Center(
                                      child: Text(
                                        'Ganti Password',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color.fromRGBO(239, 68, 68, 0.35),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _confirmLogout,
                              child: const Text(
                                'Keluar',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. TAB CONTROLLER ALA SHADCN PILL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(15, 23, 42, 0.06),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: const Color(0xFF4F46E5),
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    tabs: [
                      Tab(text: 'Jadwal Kirim (${_jadwalList.length})'),
                      Tab(text: 'Rencana Kirim (${_rencanaList.length})'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. TAB CONTENT LIST
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildList(
                            _jadwalList,
                            'Belum ada jadwal pengiriman.',
                          ),
                          _buildList(
                            _rencanaList,
                            'Belum ada rencana pengiriman.',
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        onPressed: () async {
          final refresh = await context.push<bool>('/kurir/tambah');
          if (refresh == true) _fetchData();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildList(List<KurirRencanaItem> items, String emptyMessage) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF4F46E5),
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final isDelivered = item.status == 'SELESAI' || item.realisasi == 'Y';

          return AppCard(
            onTap: () async {
              if (!isDelivered) {
                final refresh = await context.push<bool>(
                  '/kurir/proses',
                  extra: item,
                );
                if (refresh == true) _fetchData();
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.kodePengiriman,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4F46E5),
                        letterSpacing: -0.2,
                      ),
                    ),
                    AppBadge(
                      label: isDelivered ? 'Terkirim' : 'Menunggu',
                      variant: isDelivered
                          ? BadgeVariant.success
                          : BadgeVariant.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (item.receiver.isNotEmpty)
                  Text(
                    'Penerima: ${item.receiver}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                if (item.sender.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Pengirim: ${item.sender}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Divider(height: 18, color: Color(0xFFF1F5F9)),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.tanggalPlan} ${item.jamPlan}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Catatan: ${item.note}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
