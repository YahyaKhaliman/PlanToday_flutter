import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/tracking_model.dart';
import '../../repositories/tracking_repository.dart';
import '../../widgets/app_date_range_picker_modal.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';
import '../../widgets/ui/segmented_bar.dart';

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

class TrackingSpkScreen extends ConsumerStatefulWidget {
  const TrackingSpkScreen({super.key});

  @override
  ConsumerState<TrackingSpkScreen> createState() => _TrackingSpkScreenState();
}

class _TrackingSpkScreenState extends ConsumerState<TrackingSpkScreen> {
  final _searchController = TextEditingController();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

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

  String _formatYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDisplayDate(DateTime d) =>
      '${d.day} ${_kShortMonths[d.month - 1]} ${d.year}';

  Future<void> _fetchData([String? query]) async {
    setState(() => _isLoading = true);

    final repo = ref.read(trackingRepositoryProvider);
    final results = await repo.getTrackingSpkList(
      startDate: _formatYmd(_startDate),
      endDate: _formatYmd(_endDate),
      search: query ?? _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _items = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showAppDateRangePicker(
      context,
      initialStartDate: _startDate,
      initialEndDate: _endDate,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _items.where((i) => i.status == 'OPEN').length;
    final prosesCount = _items.where((i) => i.status == 'PROSES').length;
    final closeCount = _items.where((i) => i.status == 'CLOSE').length;

    final spkSegments = [
      SegmentItem(count: openCount, color: const Color(0xFFEF4444)),
      SegmentItem(count: prosesCount, color: const Color(0xFFF59E0B)),
      SegmentItem(count: closeCount, color: const Color(0xFF10B981)),
    ];

    final filteredItems = _items.where((it) {
      if (_selectedStatus != 'ALL') {
        return it.status == _selectedStatus;
      }
      return true;
    }).toList();

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
                            'Tracking SPK',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pemantauan status pengerjaan SPK',
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
                      onTap: () => _fetchData(),
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

              // 2. SEARCH & FILTER CARD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                    ),
                    boxShadow: AppShadows.softCard,
                  ),
                  child: Column(
                    children: [
                      // Search Box
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color.fromRGBO(15, 23, 42, 0.06),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Cari no SPK, customer, barang...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (q) => _fetchData(q),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _searchController.clear();
                                  _fetchData();
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Date Range Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _selectDateRange,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 15,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_formatDisplayDate(_startDate)} - ${_formatDisplayDate(_endDate)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
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
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${filteredItems.length} Data',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Status Breakdown Chips
                      Row(
                        children: _statusFilters.map((st) {
                          final isSelected = _selectedStatus == st;
                          String countLabel = '';
                          if (st == 'OPEN') countLabel = ' ($openCount)';
                          if (st == 'PROSES') countLabel = ' ($prosesCount)';
                          if (st == 'CLOSE') countLabel = ' ($closeCount)';

                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text('$st$countLabel'),
                              selected: isSelected,
                              selectedColor: const Color(0xFF4F46E5),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w800,
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

                      // Segmented Bar
                      SegmentedBar(segments: spkSegments, height: 6),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. DAFTAR KARTU SPK
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    : filteredItems.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada data tracking SPK pada periode ini.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF4F46E5),
                            onRefresh: () => _fetchData(),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              itemCount: filteredItems.length,
                              separatorBuilder: (ctx, i) =>
                                  const SizedBox(height: 10),
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
      ),
    );
  }
}

class _TrackingSpkCard extends StatelessWidget {
  final TrackingSpkListItem item;

  const _TrackingSpkCard({required this.item});

  @override
  Widget build(BuildContext context) {
    Color badgeColor = const Color(0xFFEF4444);
    if (item.status == 'CLOSE') badgeColor = const Color(0xFF10B981);
    if (item.status == 'PROSES') badgeColor = const Color(0xFFF59E0B);

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
                  color: Color(0xFF4F46E5),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
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
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          if (item.namaBarang.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.namaBarang,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales: ${item.sales}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Realisasi: ${item.realisasiTotal.toInt()} / ${item.qty.toInt()} pcs',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          if (item.qty > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (item.realisasiTotal / item.qty).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
