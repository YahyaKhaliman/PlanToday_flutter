import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../models/potensi_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/penawaran_repository.dart';
import '../../repositories/potensi_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';
import 'tambah_potensi_sheet.dart';

class PotensiScreen extends ConsumerStatefulWidget {
  const PotensiScreen({super.key});

  @override
  ConsumerState<PotensiScreen> createState() => _PotensiScreenState();
}

class _PotensiScreenState extends ConsumerState<PotensiScreen> {
  final _searchController = TextEditingController();
  List<PotensiListItem> _list = [];
  PotensiKpiSummary? _kpi;
  bool _isLoading = false;
  String _selectedStatus = 'ALL';

  // State Sales (Khusus Manager bisa pilih, non-manager terkunci)
  String _selectedSales = '';
  List<String> _salesList = [];

  final List<String> _statusFilters = ['ALL', 'OPEN', 'CLOSE', 'BATAL'];

  @override
  void initState() {
    super.initState();
    _fetchPotensi();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user?.isManager == true) {
        _loadSalesList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSalesList() async {
    try {
      final repo = ref.read(penawaranRepositoryProvider);
      final rows = await repo.getMasterSales('');
      if (mounted) {
        setState(() {
          _salesList = rows.map((e) => e['nama'] ?? '').where((n) => n.isNotEmpty).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchPotensi([String? query]) async {
    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final isManager = user?.isManager ?? false;

    final repo = ref.read(potensiRepositoryProvider);
    final res = await repo.getPotensiList(
      status: _selectedStatus,
      search: query ?? _searchController.text.trim(),
      sales: isManager && _selectedSales.isNotEmpty
          ? _selectedSales
          : (!isManager ? user?.nama : null),
    );

    if (mounted) {
      setState(() {
        _list = res.list;
        _kpi = res.kpi;
        if (_salesList.isEmpty && isManager) {
          final fromData = res.list
              .map((e) => e.salesNama.trim())
              .where((n) => n.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          if (fromData.isNotEmpty) _salesList = fromData;
        }
        _isLoading = false;
      });
    }
  }

  void _showSalesPicker() {
    String searchKeyword = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _salesList.where((s) {
              return s.toLowerCase().contains(searchKeyword.toLowerCase());
            }).toList();

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
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
                    const SizedBox(height: 8),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Cari sales...',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                setModalState(() => searchKeyword = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.people_outline, color: Color(0xFF4F46E5)),
                            title: const Text(
                              'Semua Sales',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            selected: _selectedSales.isEmpty,
                            trailing: _selectedSales.isEmpty
                                ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedSales = '';
                              });
                              _fetchPotensi();
                            },
                          ),
                          const Divider(height: 1),
                          ...filtered.map((s) {
                            final isSel = _selectedSales == s;
                            return ListTile(
                              leading: const Icon(Icons.person_outline, color: Color(0xFF64748B)),
                              title: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
                              selected: isSel,
                              trailing: isSel
                                  ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                                  : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedSales = s;
                                });
                                _fetchPotensi();
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBatalDialog(PotensiListItem item) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text(
          'Batalkan Potensi',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batalkan potensi ${item.nomor} (${item.customerNama})?'),
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
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(potensiRepositoryProvider);
              final success = await repo.batalPotensi(
                item.nomor,
                reasonController.text.trim(),
              );

              if (mounted) {
                if (success) {
                  AppToast.success(context, 'Potensi dibatalkan');
                  _fetchPotensi();
                } else {
                  AppToast.error(context, 'Gagal membatalkan potensi');
                }
              }
            },
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Potensi Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchPotensi(),
          ),
        ],
      ),
      body: Column(
        children: [
          // KPI Summary Cards
          if (_kpi != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                border: const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _KpiMiniCard(
                      label: 'Total Potensi',
                      value: '${_kpi!.totalCount}',
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiMiniCard(
                      label: 'Closing Rate',
                      value: '${_kpi!.closingRatePct.toStringAsFixed(1)}%',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiMiniCard(
                      label: 'Won / Close',
                      value: '${_kpi!.closeCount}',
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),

          // Search & Filter
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
                      hintText: 'Cari customer, barang, atau sales...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.muted),
                              onPressed: () {
                                _searchController.clear();
                                _fetchPotensi();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (q) => _fetchPotensi(q),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Sales (Manager bisa pilih, Non-Manager terkunci)
                Builder(
                  builder: (context) {
                    final user = ref.watch(authProvider).user;
                    final isManager = user?.isManager ?? false;
                    final displayName = isManager
                        ? (_selectedSales.isEmpty ? 'Semua Sales' : _selectedSales)
                        : (user?.nama.isNotEmpty == true ? user!.nama : 'Sales');

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isManager ? _showSalesPicker : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isManager && _selectedSales.isNotEmpty
                              ? const Color(0xFFEEF2FF)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isManager && _selectedSales.isNotEmpty
                                ? const Color(0xFF4F46E5)
                                : const Color.fromRGBO(15, 23, 42, 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 16,
                              color: isManager && _selectedSales.isNotEmpty
                                  ? const Color(0xFF4F46E5)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isManager && _selectedSales.isNotEmpty
                                      ? const Color(0xFF4F46E5)
                                      : (isManager
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF64748B)),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isManager && _selectedSales.isNotEmpty)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() => _selectedSales = '');
                                  _fetchPotensi();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              )
                            else if (isManager)
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                                color: Color(0xFF64748B),
                              )
                            else
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 14,
                                color: Color(0xFF94A3B8),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusFilters.map((st) {
                      final isSelected = _selectedStatus == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(st),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedStatus = st);
                              _fetchPotensi();
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

          // List Items
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada data potensi',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchPotensi(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _list.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _list[index];
                            return _PotensiCard(
                              item: item,
                              currencyFormat: currencyFormat,
                              onBatal: item.status == 'OPEN'
                                  ? () => _showBatalDialog(item)
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final refresh = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => const TambahPotensiSheet(),
          );
          if (refresh == true) {
            _fetchPotensi();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _KpiMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KpiMiniCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PotensiCard extends StatelessWidget {
  final PotensiListItem item;
  final NumberFormat currencyFormat;
  final VoidCallback? onBatal;

  const _PotensiCard({
    required this.item,
    required this.currencyFormat,
    this.onBatal,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor = StatusColors.wait;
    if (item.status == 'CLOSE') badgeColor = StatusColors.acc;
    if (item.status == 'BATAL') badgeColor = StatusColors.tolak;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  item.nomor,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (item.isRealisasi)
                    const AppBadge(
                      label: 'REALISASI',
                      variant: BadgeVariant.success,
                    ),
                  if (item.tipeSumber.isNotEmpty)
                    AppBadge(
                      label: item.tipeSumber,
                      variant: item.tipeSumber == 'PENAWARAN'
                          ? BadgeVariant.primary
                          : BadgeVariant.neutral,
                      customColor: item.tipeSumber == 'MAP'
                          ? const Color(0xFF0284C7)
                          : null,
                    ),
                  AppBadge(
                    label: item.status,
                    customColor: badgeColor,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.customerNama,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          if (item.namaItem.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.namaItem,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (item.nomorSumber != null && item.nomorSumber!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Doc: ${item.nomorSumber}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (item.status == 'BATAL' && (item.alasanBatal ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Alasan Batal: ${item.alasanBatal}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Divider(height: 18, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales: ${item.salesNama}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                currencyFormat.format(item.harga),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          if (onBatal != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onBatal,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text(
                  'Batalkan',
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
