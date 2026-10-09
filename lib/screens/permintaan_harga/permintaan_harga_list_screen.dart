import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/permintaan_harga_model.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../widgets/app_date_range_picker_modal.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

class PermintaanHargaListScreen extends ConsumerStatefulWidget {
  const PermintaanHargaListScreen({super.key});

  @override
  ConsumerState<PermintaanHargaListScreen> createState() =>
      _PermintaanHargaListScreenState();
}

class _PermintaanHargaListScreenState
    extends ConsumerState<PermintaanHargaListScreen> {
  final _searchController = TextEditingController();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  List<PermintaanHargaItem> _list = [];
  bool _isLoading = false;
  String _selectedStatus = 'ALL';

  final List<String> _statusFilters = [
    'ALL', 'MINTA', 'WAIT', 'DONE', 'BELUM', 'NEGO', 'CANCEL'
  ];

  @override
  void initState() {
    super.initState();
    _fetchList();
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

  Future<void> _fetchList([String? query]) async {
    setState(() => _isLoading = true);

    final repo = ref.read(permintaanHargaRepositoryProvider);
    final results = await repo.getList(
      startDate: _formatYmd(_startDate),
      endDate: _formatYmd(_endDate),
      status: _selectedStatus,
      search: query ?? _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _list = results;
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
      _fetchList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

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
                            'Permintaan Harga',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Daftar permintaan kalkulasi harga',
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
                      onTap: () => _fetchList(),
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
                                  hintText: 'Cari nomor, customer, atau barang...',
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
                                onSubmitted: (q) => _fetchList(q),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _searchController.clear();
                                  _fetchList();
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
                              '${_list.length} Data',
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

                      // Status Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _statusFilters.map((st) {
                            final isSelected = _selectedStatus == st;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: Text(st),
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
                                  if (val) {
                                    setState(() => _selectedStatus = st);
                                    _fetchList();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. DAFTAR PERMINTAAN HARGA
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    : _list.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada data permintaan harga pada periode ini.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF4F46E5),
                            onRefresh: () => _fetchList(),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              itemCount: _list.length,
                              separatorBuilder: (ctx, i) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _list[index];
                                return _PermintaanHargaCard(
                                  item: item,
                                  currencyFormat: currencyFormat,
                                  onTap: () {
                                    context.push('/permintaan-harga/${item.nomor}');
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        onPressed: () async {
          final refresh =
              await context.push<bool>('/permintaan-harga/kalkulasi');
          if (refresh == true) {
            _fetchList();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _PermintaanHargaCard extends StatelessWidget {
  final PermintaanHargaItem item;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  const _PermintaanHargaCard({
    required this.item,
    required this.currencyFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor = const Color(0xFFEF4444);
    if (item.status == 'DONE') badgeColor = const Color(0xFF10B981);
    if (item.status == 'WAIT') badgeColor = const Color(0xFFF59E0B);
    if (item.status == 'NEGO') badgeColor = const Color(0xFF8B5CF6);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.nomor,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Color(0xFF4F46E5),
                  letterSpacing: -0.2,
                ),
              ),
              Row(
                children: [
                  if (item.status.isNotEmpty) ...[
                    AppBadge(
                      label: item.status,
                      customColor: badgeColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    item.tanggal,
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
          if (item.nama.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              '${item.nama} (${item.divisi})',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order: ${item.jmlOrder.toInt()} pcs',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                item.harga > 0
                    ? currencyFormat.format(item.harga)
                    : (item.hargaKalkulasi > 0
                        ? currencyFormat.format(item.hargaKalkulasi)
                        : 'Belum dihitung'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: (item.harga > 0 || item.hargaKalkulasi > 0)
                      ? (item.status == 'DONE'
                          ? const Color(0xFF10B981)
                          : const Color(0xFF0F172A))
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
