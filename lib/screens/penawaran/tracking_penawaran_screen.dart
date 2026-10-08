import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/tracking_model.dart';
import '../../repositories/tracking_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';
import '../../widgets/ui/segmented_bar.dart';

class TrackingPenawaranScreen extends ConsumerStatefulWidget {
  const TrackingPenawaranScreen({super.key});

  @override
  ConsumerState<TrackingPenawaranScreen> createState() =>
      _TrackingPenawaranScreenState();
}

class _TrackingPenawaranScreenState
    extends ConsumerState<TrackingPenawaranScreen> {
  final _searchController = TextEditingController();
  List<TrackingPenawaranListItem> _items = [];
  bool _isLoading = false;
  String _selectedStatus = 'ALL'; // ALL, OPEN, PARSIAL, CLOSE

  final List<String> _statusFilters = ['ALL', 'OPEN', 'PARSIAL', 'CLOSE'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData([String? query]) async {
    setState(() => _isLoading = true);

    final repo = ref.read(trackingRepositoryProvider);
    final results = await repo.getTrackingPenawaranList(
      search: query ?? _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _items = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _items.where((i) => i.statusTracking == 'OPEN').length;
    final parsialCount = _items.where((i) => i.statusTracking == 'PARSIAL').length;
    final closeCount = _items.where((i) => i.statusTracking == 'CLOSE').length;

    final trackingSegments = [
      SegmentItem(count: openCount, color: AppColors.danger),
      SegmentItem(count: parsialCount, color: AppColors.primary),
      SegmentItem(count: closeCount, color: AppColors.success),
    ];

    final filteredItems = _items.where((it) {
      if (_selectedStatus != 'ALL') {
        return it.statusTracking == _selectedStatus;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Penawaran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchData(),
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 1000,
        child: Column(
          children: [
            // Search & Filter Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      boxShadow: AppShadows.softCard,
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari penawaran, customer, sales...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.muted),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchData();
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (q) => _fetchData(q),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status Breakdown Chips
                  Row(
                    children: _statusFilters.map((st) {
                      final isSelected = _selectedStatus == st;
                      String countLabel = '';
                      if (st == 'OPEN') countLabel = ' ($openCount)';
                      if (st == 'PARSIAL') countLabel = ' ($parsialCount)';
                      if (st == 'CLOSE') countLabel = ' ($closeCount)';

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text('$st$countLabel'),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedStatus = st);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Segmented Distribution Bar
                  SegmentedBar(segments: trackingSegments, height: 6),
                ],
              ),
            ),

            // List Items
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredItems.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada data tracking penawaran',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _fetchData(),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: filteredItems.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              return _TrackingPenawaranCard(item: item);
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

class _TrackingPenawaranCard extends StatelessWidget {
  final TrackingPenawaranListItem item;

  const _TrackingPenawaranCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isOpen = item.statusTracking == 'OPEN';
    final isParsial = item.statusTracking == 'PARSIAL';

    Color badgeColor = StatusColors.acc;
    if (isOpen) badgeColor = StatusColors.wait;
    if (isParsial) badgeColor = AppColors.primary;

    final progressPct = item.totalItem > 0
        ? (item.totalItemMap / item.totalItem) * 100
        : 0.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.noPenawaran,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
              AppBadge(
                label: item.statusTracking,
                customColor: badgeColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.customer,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Sales: ${item.sales} • Tgl: ${item.tanggalPenawaran}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
          ),
          const Divider(height: 18, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item MAP: ${item.totalItemMap} / ${item.totalItem}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if (item.noMap.isNotEmpty)
                Text(
                  'No MAP: ${item.noMap}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Mini progress bar for MAP Items
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (progressPct / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
              minHeight: 4,
            ),
          ),

          if (item.mapDeadline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  'Deadline: ${item.mapDeadline}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
