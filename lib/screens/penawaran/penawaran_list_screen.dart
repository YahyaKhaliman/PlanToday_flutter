import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/penawaran_model.dart';
import '../../repositories/penawaran_repository.dart';
import '../../widgets/app_date_range_picker_modal.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

class PenawaranListScreen extends ConsumerStatefulWidget {
  const PenawaranListScreen({super.key});

  @override
  ConsumerState<PenawaranListScreen> createState() => _PenawaranListScreenState();
}

class _PenawaranListScreenState extends ConsumerState<PenawaranListScreen> {
  final _searchController = TextEditingController();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  List<PenawaranListItem> _penawaranList = [];
  bool _isLoading = false;
  String _selectedStatus = 'ALL';
  String _selectedApproval = 'ALL'; // ALL, APPROVED, UNAPPROVED

  final List<String> _statusFilters = ['ALL', 'OPEN', 'BATAL', 'CLOSE'];
  final List<String> _approvalFilters = ['ALL', 'APPROVED', 'UNAPPROVED'];

  @override
  void initState() {
    super.initState();
    _fetchPenawaran();
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

  Future<void> _fetchPenawaran([String? query]) async {
    setState(() => _isLoading = true);

    final repo = ref.read(penawaranRepositoryProvider);
    final results = await repo.getPenawaranList(
      startDate: _formatYmd(_startDate),
      endDate: _formatYmd(_endDate),
      status: _selectedStatus,
      search: query ?? _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _penawaranList = results;
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
      _fetchPenawaran();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final filteredList = _penawaranList.where((p) {
      if (_selectedApproval == 'APPROVED') return p.isApproved;
      if (_selectedApproval == 'UNAPPROVED') return !p.isApproved;
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
                            'Daftar Penawaran',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Rekap surat penawaran harga',
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
                      onTap: () => _fetchPenawaran(),
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
                                  hintText: 'Cari nomor, customer, atau sales...',
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
                                onSubmitted: (q) => _fetchPenawaran(q),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _searchController.clear();
                                  _fetchPenawaran();
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
                              '${filteredList.length} Data',
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
                                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _selectedStatus = st);
                                    _fetchPenawaran();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Approval Filters
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _approvalFilters.map((ap) {
                            final isSelected = _selectedApproval == ap;
                            Color activeColor = const Color(0xFF4F46E5);
                            if (ap == 'APPROVED') activeColor = const Color(0xFF10B981);
                            if (ap == 'UNAPPROVED') activeColor = const Color(0xFFF59E0B);

                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: Text(ap == 'ALL' ? 'Semua Approval' : ap),
                                selected: isSelected,
                                selectedColor: activeColor,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                ),
                                onSelected: (val) {
                                  if (val) setState(() => _selectedApproval = ap);
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

              // 3. DAFTAR PENAWARAN
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                      )
                    : filteredList.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada data penawaran pada periode ini.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF4F46E5),
                            onRefresh: () => _fetchPenawaran(),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              itemCount: filteredList.length,
                              separatorBuilder: (ctx, i) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = filteredList[index];
                                return _PenawaranCard(
                                  item: item,
                                  currencyFormat: currencyFormat,
                                  onTap: () {
                                    context.push('/penawaran/${item.nomor}');
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
          final refresh = await context.push<bool>('/penawaran/create');
          if (refresh == true) {
            _fetchPenawaran();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _PenawaranCard extends StatelessWidget {
  final PenawaranListItem item;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  const _PenawaranCard({
    required this.item,
    required this.currencyFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor = const Color(0xFF64748B);
    if (item.approvalState == 'ACC') badgeColor = const Color(0xFF10B981);
    if (item.approvalState == 'WAIT') badgeColor = const Color(0xFFF59E0B);
    if (item.approvalState == 'TOLAK') badgeColor = const Color(0xFFEF4444);

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
              if (item.approvalState.isNotEmpty)
                AppBadge(
                  label: item.approvalState,
                  customColor: badgeColor,
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
          if (item.perusahaan.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.perusahaan,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
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
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                currencyFormat.format(item.nominal),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
