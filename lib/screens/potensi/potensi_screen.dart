import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/potensi_model.dart';
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

  final List<String> _statusFilters = ['ALL', 'OPEN', 'CLOSE', 'BATAL'];

  @override
  void initState() {
    super.initState();
    _fetchPotensi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPotensi([String? query]) async {
    setState(() => _isLoading = true);

    final repo = ref.read(potensiRepositoryProvider);
    final res = await repo.getPotensiList(
      status: _selectedStatus,
      search: query ?? _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _list = res.list;
        _kpi = res.kpi;
        _isLoading = false;
      });
    }
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Potensi dibatalkan' : 'Gagal membatalkan potensi',
                    ),
                    backgroundColor: success ? AppColors.success : AppColors.danger,
                  ),
                );
                if (success) _fetchPotensi();
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
            children: [
              Text(
                item.nomor,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
              AppBadge(
                label: item.status,
                customColor: badgeColor,
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
              style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500),
            ),
          ],
          const Divider(height: 18, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales: ${item.salesNama}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
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
                label: const Text('Batalkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
