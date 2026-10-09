import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/potensi_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/potensi_repository.dart';
import '../../widgets/app_date_range_picker_modal.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

class LaporanPotensiScreen extends ConsumerStatefulWidget {
  const LaporanPotensiScreen({super.key});

  @override
  ConsumerState<LaporanPotensiScreen> createState() =>
      _LaporanPotensiScreenState();
}

class _LaporanPotensiScreenState extends ConsumerState<LaporanPotensiScreen> {
  final _searchController = TextEditingController();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  List<PotensiListItem> _rawItems = [];
  bool _isLoading = false;
  String _selectedSales = 'ALL';

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

    final repo = ref.read(potensiRepositoryProvider);
    final results = await repo.getPotensiList(
      startDate: _formatYmd(_startDate),
      endDate: _formatYmd(_endDate),
      search: query ?? _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _rawItems = results.list;
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

  List<String> get _availableSales {
    final set = <String>{};
    for (final it in _rawItems) {
      if (it.salesNama.isNotEmpty) set.add(it.salesNama.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  List<PotensiListItem> get _filteredItems {
    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';

    return _rawItems.where((it) {
      if (isManager && _selectedSales != 'ALL') {
        if (it.salesNama.toLowerCase() != _selectedSales.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // Item aktif adalah item dengan status belum CLOSE dan belum BATAL
  List<PotensiListItem> get _activeItems {
    return _filteredItems.where((it) {
      final s = it.status.toUpperCase();
      return s != 'CLOSE' && s != 'BATAL';
    }).toList();
  }

  double get _totalNominalAktif =>
      _activeItems.fold(0.0, (acc, it) => acc + it.harga);

  void _showSalesPicker() {
    final list = _availableSales;
    if (list.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Sales',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              ListTile(
                title: const Text(
                  'Semua Sales',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: _selectedSales == 'ALL'
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF4F46E5))
                    : null,
                onTap: () {
                  setState(() => _selectedSales = 'ALL');
                  Navigator.pop(ctx);
                },
              ),
              ...list.map((salesName) {
                final isSelected =
                    _selectedSales.toLowerCase() == salesName.toLowerCase();
                return ListTile(
                  title: Text(
                    salesName,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF4F46E5))
                      : null,
                  onTap: () {
                    setState(() => _selectedSales = salesName);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showBatalDialog(PotensiListItem item) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Batalkan Potensi',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Batalkan potensi untuk ${item.customerNama}?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Alasan pembatalan...',
              ),
            ),
          ],
        ),
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
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(potensiRepositoryProvider);
              final success = await repo.batalPotensi(
                item.nomor,
                reasonController.text.trim(),
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Potensi berhasil dibatalkan'
                          : 'Gagal membatalkan potensi',
                    ),
                    backgroundColor:
                        success ? AppColors.success : AppColors.danger,
                  ),
                );
                if (success) _fetchData();
              }
            },
            child: const Text(
              'Batalkan',
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
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';
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
                            'Laporan Potensi',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Rekapitulasi data potensi sales',
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

              // 2. KPI SUMMARY BANNER (Total Nominal Aktif & Jumlah Item)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL NOMINAL AKTIF',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(_totalNominalAktif),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_activeItems.length} Item Aktif',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. SEARCH & FILTER CARD
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
                                      'Cari item, customer, atau nomor doc...',
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

                      // Date Range Selector Row & Sales Filter
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
                          if (isManager && _availableSales.isNotEmpty)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _showSalesPicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _selectedSales == 'ALL'
                                          ? 'Semua Sales'
                                          : _selectedSales,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      size: 16,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
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
                                '${_filteredItems.length} Data',
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

              // 4. DAFTAR KARTU POTENSI
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    : _filteredItems.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada data potensi pada periode ini.',
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
                              itemCount: _filteredItems.length,
                              separatorBuilder: (ctx, i) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _filteredItems[index];
                                final isOpen = item.status == 'OPEN' ||
                                    item.status == 'POTENSI';

                                return _LaporanPotensiCard(
                                  item: item,
                                  currencyFormat: currencyFormat,
                                  onBatal: isOpen
                                      ? () => _showBatalDialog(item)
                                      : null,
                                );
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

class _LaporanPotensiCard extends StatelessWidget {
  final PotensiListItem item;
  final NumberFormat currencyFormat;
  final VoidCallback? onBatal;

  const _LaporanPotensiCard({
    required this.item,
    required this.currencyFormat,
    this.onBatal,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor = const Color(0xFFF59E0B);
    if (item.status == 'CLOSE') badgeColor = const Color(0xFF10B981);
    if (item.status == 'BATAL') badgeColor = const Color(0xFFEF4444);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.nomor,
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
                    label: item.status,
                    customColor: badgeColor,
                  ),
                  if (item.tanggal != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      item.tanggal!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.customerNama,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          if (item.namaItem.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.namaItem,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
          if (item.status == 'BATAL' &&
              (item.alasanBatal ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                'Alasan Batal: ${item.alasanBatal}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales: ${item.salesNama}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                currencyFormat.format(item.harga),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          if (onBatal != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onBatal,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text(
                  'Batalkan Potensi',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
