import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/tracking_model.dart';
import '../../repositories/tracking_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';
import '../../widgets/ui/segmented_bar.dart';

class TrackingSpkScreen extends ConsumerStatefulWidget {
  const TrackingSpkScreen({super.key});

  @override
  ConsumerState<TrackingSpkScreen> createState() => _TrackingSpkScreenState();
}

class _TrackingSpkScreenState extends ConsumerState<TrackingSpkScreen> {
  final _searchController = TextEditingController();
  List<TrackingSpkListItem> _items = [];
  bool _isLoading = false;
  String _selectedStatus = 'ALL'; // ALL, OPEN, PROSES, CLOSE

  final List<String> _statusFilters = ['ALL', 'OPEN', 'PROSES', 'CLOSE'];

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
    final results = await repo.getTrackingSpkList(
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
    final openCount = _items.where((i) => i.status == 'OPEN').length;
    final prosesCount = _items.where((i) => i.status == 'PROSES').length;
    final closeCount = _items.where((i) => i.status == 'CLOSE').length;

    final spkSegments = [
      SegmentItem(count: openCount, color: AppColors.danger),
      SegmentItem(count: prosesCount, color: AppColors.warning),
      SegmentItem(count: closeCount, color: AppColors.success),
    ];

    final filteredItems = _items.where((it) {
      if (_selectedStatus != 'ALL') {
        return it.status == _selectedStatus;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking SPK'),
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
                        hintText: 'Cari no SPK, customer, barang...',
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
                      if (st == 'PROSES') countLabel = ' ($prosesCount)';
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
                  SegmentedBar(segments: spkSegments, height: 6),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredItems.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada data tracking SPK',
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
                              return _TrackingSpkCard(item: item);
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

class _TrackingSpkCard extends StatelessWidget {
  final TrackingSpkListItem item;

  const _TrackingSpkCard({required this.item});

  @override
  Widget build(BuildContext context) {
    Color badgeColor = AppColors.danger;
    if (item.status == 'CLOSE') badgeColor = AppColors.success;
    if (item.status == 'PROSES') badgeColor = AppColors.warning;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.noSpk,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
              Row(
                children: [
                  AppBadge(
                    label: item.status.isNotEmpty ? item.status : 'OPEN',
                    customColor: badgeColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.tanggalSpk,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
                  ),
                ],
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
          if (item.namaBarang.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.namaBarang,
              style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500),
            ),
          ],
          const Divider(height: 18, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales: ${item.sales}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
              AppBadge(
                label: 'Qty: ${item.qty.toInt()} pcs',
                variant: BadgeVariant.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
