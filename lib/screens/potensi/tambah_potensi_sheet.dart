import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/potensi_kandidat_model.dart';
import '../../repositories/potensi_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class TambahPotensiSheet extends ConsumerStatefulWidget {
  const TambahPotensiSheet({super.key});

  @override
  ConsumerState<TambahPotensiSheet> createState() => _TambahPotensiSheetState();
}

class _TambahPotensiSheetState extends ConsumerState<TambahPotensiSheet> {
  final _searchController = TextEditingController();

  List<PotensiKandidatItem> _allKandidat = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  String _selectedTab = 'ALL'; // ALL, PENAWARAN, MAP
  final Map<String, PotensiKandidatItem> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _fetchKandidat();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchKandidat() async {
    setState(() => _isLoading = true);

    final repo = ref.read(potensiRepositoryProvider);
    final results = await repo.getPotensiKandidatList();

    if (mounted) {
      setState(() {
        _allKandidat = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitBatch() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada item yang dipilih untuk disimpan'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final repo = ref.read(potensiRepositoryProvider);
    final payloadList = _selectedItems.values.map((it) => it.toBatchPayload()).toList();

    final success = await repo.createPotensiBatch(payloadList);

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil menambahkan ${_selectedItems.length} item ke daftar potensi'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan data potensi ke server'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Filter berdasarkan tab aktif dan teks pencarian
    final q = _searchController.text.trim().toLowerCase();
    final filteredList = _allKandidat.where((it) {
      if (_selectedTab == 'PENAWARAN' && it.tipeSumber != 'PENAWARAN') return false;
      if (_selectedTab == 'MAP' && it.tipeSumber != 'MAP') return false;

      if (q.isNotEmpty) {
        final matchNama = it.namaItem.toLowerCase().contains(q);
        final matchCustomer = (it.customerNama ?? '').toLowerCase().contains(q);
        final matchDoc = (it.penNomor ?? it.mspkNomor ?? '').toLowerCase().contains(q);
        return matchNama || matchCustomer || matchDoc;
      }
      return true;
    }).toList();

    // Hitung jumlah per tab
    final penawaranCount = _allKandidat.where((it) => it.tipeSumber == 'PENAWARAN').length;
    final mapCount = _allKandidat.where((it) => it.tipeSumber == 'MAP').length;

    // Hitung total nominal yang dicentang
    final selectedTotalNominal = _selectedItems.values.fold<double>(0.0, (acc, it) => acc + it.harga);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tambah Potensi Baru',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Search Box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari nama barang, customer, no penawaran/MAP...',
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.muted),
                        onPressed: () => setState(() => _searchController.clear()),
                      )
                    : null,
              ),
            ),
          ),

          // Category Filter Chips (SEMUA, PENAWARAN, MAP)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Semua (${_allKandidat.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('PENAWARAN', 'Penawaran ($penawaranCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('MAP', 'MAP ($mapCount)'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // List Items
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada kandidat potensi tersedia',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredList.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          final isChecked = _selectedItems.containsKey(item.itemKey);

                          return AppCard(
                            onTap: () {
                              setState(() {
                                if (isChecked) {
                                  _selectedItems.remove(item.itemKey);
                                } else {
                                  _selectedItems[item.itemKey] = item;
                                }
                              });
                            },
                            color: isChecked ? const Color(0xFFF4F4FD) : AppColors.card,
                            border: isChecked
                                ? Border.all(color: AppColors.primary, width: 1.5)
                                : Border.all(color: AppColors.border),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: isChecked,
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedItems[item.itemKey] = item;
                                      } else {
                                        _selectedItems.remove(item.itemKey);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          AppBadge(
                                            label: item.tipeSumber,
                                            variant: item.tipeSumber == 'PENAWARAN'
                                                ? BadgeVariant.primary
                                                : BadgeVariant.success,
                                          ),
                                          Text(
                                            currencyFormat.format(item.harga),
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.ink),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.namaItem,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Doc: ${item.penNomor ?? item.mspkNomor ?? "-"} • ${item.customerNama ?? ""}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.salesNama != null && item.salesNama!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text('Sales: ${item.salesNama}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Bar Simpan Batch
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedItems.length} Item Dipilih',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink),
                    ),
                    Text(
                      currencyFormat.format(selectedTotalNominal),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: 'Simpan ke Potensi',
                  isLoading: _isSubmitting,
                  onPressed: _selectedItems.isNotEmpty ? _submitBatch : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String tabKey, String label) {
    final isSelected = _selectedTab == tabKey;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedTab = tabKey);
      },
    );
  }
}
