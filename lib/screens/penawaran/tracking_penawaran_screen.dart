import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/tracking_model.dart';
import '../../repositories/tracking_repository.dart';

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
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
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
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
                          itemCount: _items.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _TrackingPenawaranCard(item: item);
                          },
                        ),
                      ),
          ),
        ],
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Text(
                    item.statusTracking,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
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
            if (item.mapDeadline.isNotEmpty) ...[
              const SizedBox(height: 4),
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
      ),
    );
  }
}
