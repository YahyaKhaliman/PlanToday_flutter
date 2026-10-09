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

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

class TrackingMapScreen extends ConsumerStatefulWidget {
  const TrackingMapScreen({super.key});

  @override
  ConsumerState<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends ConsumerState<TrackingMapScreen> {
  final _searchController = TextEditingController();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  List<TrackingMapListItem> _items = [];
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

  String _formatYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDisplayDate(DateTime d) =>
      '${d.day} ${_kShortMonths[d.month - 1]} ${d.year}';

  Future<void> _fetchData([String? query]) async {
    setState(() => _isLoading = true);

    final repo = ref.read(trackingRepositoryProvider);
    final results = await repo.getTrackingMapList(
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
                            'Tracking MAP',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pelacakan status pengerjaan MAP & surat jalan',
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

              // 2. SEARCH & DATE RANGE CARD
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
                                  hintText:
                                      'Cari nomor MAP, customer, surat jalan...',
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

                      // Date Range Selector Row
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
                              '${_items.length} Data',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. DAFTAR KARTU TRACKING MAP
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    : _items.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada data tracking MAP pada periode ini.',
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
                              itemCount: _items.length,
                              separatorBuilder: (ctx, i) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _TrackingMapCard(item: item);
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

class _TrackingMapCard extends StatelessWidget {
  final TrackingMapListItem item;

  const _TrackingMapCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasSj = item.nomorSj.isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.noMap,
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
                    label: hasSj ? 'SJ SIAP' : 'PROSES MAP',
                    variant:
                        hasSj ? BadgeVariant.success : BadgeVariant.warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.tanggalMap,
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
          if (item.alamat.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.alamat,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          if (item.mspkNama.isNotEmpty)
            Text(
              'Barang: ${item.mspkNama}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          if (hasSj) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 14,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Text(
                  'Surat Jalan: ${item.nomorSj}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
          if (item.sales.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Sales: ${item.sales}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
