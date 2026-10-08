import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/kurir_model.dart';
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
    final endStr = '${now.year}-${(now.month + 1).toString().padLeft(2, '0')}-01';

    final jadwal = await repo.getJadwalKirim(startDate: startStr, endDate: endStr);
    final rencana = await repo.getRencanaKirim(startDate: startStr, endDate: endStr);

    if (mounted) {
      setState(() {
        _jadwalList = jadwal;
        _rencanaList = rencana;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengiriman Kurir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(text: 'Jadwal Kirim (${_jadwalList.length})'),
            Tab(text: 'Rencana Kirim (${_rencanaList.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              maxWidth: 1000,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_jadwalList, 'Belum ada jadwal pengiriman'),
                  _buildList(_rencanaList, 'Belum ada rencana pengiriman'),
                ],
              ),
            ),
    );
  }

  Widget _buildList(List<KurirRencanaItem> items, String emptyMessage) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final isDelivered = item.status == 'SELESAI' || item.realisasi == 'Y';

          return AppCard(
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
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    AppBadge(
                      label: isDelivered ? 'Terkirim' : 'Menunggu',
                      variant: isDelivered ? BadgeVariant.success : BadgeVariant.warning,
                    ),
                  ],
                ),
                  const SizedBox(height: 8),
                  if (item.receiver.isNotEmpty)
                    Text(
                      'Penerima: ${item.receiver}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  if (item.sender.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Pengirim: ${item.sender}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const Divider(height: 18, color: AppColors.border),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        '${item.tanggalPlan} ${item.jamPlan}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
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
                        color: AppColors.ink,
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
