import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/penawaran_model.dart';
import '../../repositories/penawaran_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

class PenawaranListScreen extends ConsumerStatefulWidget {
  const PenawaranListScreen({super.key});

  @override
  ConsumerState<PenawaranListScreen> createState() => _PenawaranListScreenState();
}

class _PenawaranListScreenState extends ConsumerState<PenawaranListScreen> {
  final _searchController = TextEditingController();
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

  Future<void> _fetchPenawaran([String? query]) async {
    setState(() => _isLoading = true);

    final repo = ref.read(penawaranRepositoryProvider);
    final results = await repo.getPenawaranList(
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

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final filteredList = _penawaranList.where((p) {
      if (_selectedApproval == 'APPROVED') return p.isApproved;
      if (_selectedApproval == 'UNAPPROVED') return !p.isApproved;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Penawaran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchPenawaran(),
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 1000,
        child: Column(
          children: [
            // Search & Filter Bar
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
                        hintText: 'Cari nomor, customer, atau sales...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.muted),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchPenawaran();
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (q) => _fetchPenawaran(q),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status Filter Chips
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
                                _fetchPenawaran();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Approval Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _approvalFilters.map((ap) {
                        final isSelected = _selectedApproval == ap;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(ap == 'ALL' ? 'Semua Approval' : ap),
                            selected: isSelected,
                            selectedColor: ap == 'APPROVED' ? AppColors.success : (ap == 'UNAPPROVED' ? AppColors.warning : AppColors.primary),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
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

            // List Items
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredList.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada data penawaran',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _fetchPenawaran(),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredList.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
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
    Color badgeColor = AppColors.muted;
    if (item.approvalState == 'ACC') badgeColor = StatusColors.acc;
    if (item.approvalState == 'WAIT') badgeColor = StatusColors.wait;
    if (item.approvalState == 'TOLAK') badgeColor = StatusColors.tolak;

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
                  fontSize: 15,
                  color: AppColors.primary,
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
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          if (item.perusahaan.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.perusahaan,
              style: const TextStyle(
                fontSize: 12,
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
                'Sales: ${item.sales}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              Text(
                currencyFormat.format(item.nominal),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
