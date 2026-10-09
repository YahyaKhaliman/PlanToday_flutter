import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/permintaan_harga_model.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

class PermintaanHargaListScreen extends ConsumerStatefulWidget {
  const PermintaanHargaListScreen({super.key});

  @override
  ConsumerState<PermintaanHargaListScreen> createState() =>
      _PermintaanHargaListScreenState();
}

class _PermintaanHargaListScreenState
    extends ConsumerState<PermintaanHargaListScreen> {
  final _searchController = TextEditingController();
  List<PermintaanHargaItem> _list = [];
  bool _isLoading = false;
  String _selectedStatus = 'ALL';

  final List<String> _statusFilters = ['ALL', 'OPEN', 'PROSES', 'SELESAI'];

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

  Future<void> _fetchList([String? query]) async {
    setState(() => _isLoading = true);

    final repo = ref.read(permintaanHargaRepositoryProvider);
    final results = await repo.getList(
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

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permintaan Harga'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined, color: AppColors.primary),
            tooltip: 'Kalkulator Harga',
            onPressed: () => context.push('/permintaan-harga/kalkulasi'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchList(),
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 1000,
        child: Column(
          children: [
          // Filter & Search
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
                      hintText: 'Cari nomor, customer, atau barang...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.muted),
                              onPressed: () {
                                _searchController.clear();
                                _fetchList();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (q) => _fetchList(q),
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

          // List Items
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada data permintaan harga',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchList(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _list.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 12),
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
    floatingActionButton: FloatingActionButton(
      backgroundColor: AppColors.primary,
      onPressed: () async {
        final refresh = await context.push<bool>('/permintaan-harga/kalkulasi');
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
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
              Row(
                children: [
                  if (item.status.isNotEmpty) ...[
                    AppBadge(
                      label: item.status,
                      variant: item.status == 'SELESAI'
                          ? BadgeVariant.success
                          : (item.status == 'PROSES'
                              ? BadgeVariant.primary
                              : BadgeVariant.warning),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    item.tanggal,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
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
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          if (item.nama.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.nama,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
          const Divider(height: 18, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order: ${item.jmlOrder.toInt()} pcs',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                item.harga > 0
                    ? currencyFormat.format(item.harga)
                    : (item.hargaKalkulasi > 0
                        ? currencyFormat.format(item.hargaKalkulasi)
                        : 'Belum dihitung'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: (item.harga > 0 || item.hargaKalkulasi > 0)
                      ? AppColors.ink
                      : AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
