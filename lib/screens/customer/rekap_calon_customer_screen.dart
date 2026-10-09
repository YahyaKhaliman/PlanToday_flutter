import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/customer_model.dart';
import '../../repositories/customer_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

class RekapCalonCustomerScreen extends ConsumerStatefulWidget {
  const RekapCalonCustomerScreen({super.key});

  @override
  ConsumerState<RekapCalonCustomerScreen> createState() =>
      _RekapCalonCustomerScreenState();
}

class _RekapCalonCustomerScreenState
    extends ConsumerState<RekapCalonCustomerScreen> {
  final _searchController = TextEditingController();
  List<CustomerModel> _customers = [];
  bool _isLoading = false;

  CustomerModel? _selectedCustomer;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchCustomers(query);
    });
  }

  Future<void> _fetchCustomers([String? query]) async {
    setState(() => _isLoading = true);
    final repo = ref.read(customerRepositoryProvider);
    final q = query?.trim() ?? _searchController.text.trim();

    final results = q.isNotEmpty
        ? await repo.searchCustomer(q)
        : await repo.getRekapCalonCustomer();

    if (mounted) {
      setState(() {
        _customers = results;
        _isLoading = false;
        _selectedCustomer = null;
      });
    }
  }

  Future<void> _launchWhatsApp(String phone, {String? text}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;
    final normalizedPhone = cleanPhone.startsWith('0')
        ? '62${cleanPhone.substring(1)}'
        : (cleanPhone.startsWith('62') ? cleanPhone : '62$cleanPhone');

    final textParam = text != null ? '?text=${Uri.encodeComponent(text)}' : '';
    final uri = Uri.parse('https://wa.me/$normalizedPhone$textParam');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _showRekapWaModal() async {
    final repo = ref.read(customerRepositoryProvider);
    final text = await repo.getRekapCalonCustomerWA(_searchController.text);

    if (!mounted) return;

    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data rekapan WA tidak tersedia'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kirim Rekap Customer via WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.soft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.ink)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wa,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                ),
                icon: const Icon(Icons.chat),
                label: const Text('Buka di WhatsApp'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.wa),
            tooltip: 'Kirim Rekap WA',
            onPressed: _showRekapWaModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _searchController.clear();
              _fetchCustomers();
            },
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 1000,
        child: Column(
          children: [
            // Search Bar persis React Native (icon search, clear button)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      boxShadow: AppShadows.softCard,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Cari nama customer...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchCustomers();
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (q) => _fetchCustomers(q),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isLoading
                        ? 'Memuat data...'
                        : 'Menampilkan: ${_customers.length} data',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                ],
              ),
            ),

            // List Customer
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _customers.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada data customer.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _fetchCustomers(_searchController.text),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _customers.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final customer = _customers[index];
                              final isSelected = _selectedCustomer?.kode == customer.kode &&
                                  customer.kode.isNotEmpty;

                              return _CustomerCard(
                                customer: customer,
                                isSelected: isSelected,
                                onTap: () {
                                  setState(() {
                                    if (_selectedCustomer?.kode == customer.kode) {
                                      _selectedCustomer = null;
                                    } else {
                                      _selectedCustomer = customer;
                                    }
                                  });
                                },
                                onWhatsApp: () => _launchWhatsApp(customer.telp),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      // Floating Bottom Actions saat customer dipilih
      bottomNavigationBar: _selectedCustomer != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                boxShadow: AppShadows.card,
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCustomer!.nama,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Kode: ${_selectedCustomer!.kode.isNotEmpty ? _selectedCustomer!.kode : "-"}',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedCustomer!.telp.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.chat, color: AppColors.wa),
                      tooltip: 'WhatsApp',
                      onPressed: () => _launchWhatsApp(_selectedCustomer!.telp),
                    ),
                  ],
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    onPressed: () async {
                      final refresh = await context.push<bool>(
                        '/customer/edit',
                        extra: _selectedCustomer,
                      );
                      if (refresh == true) {
                        _fetchCustomers();
                      }
                    },
                  ),
                ],
              ),
            )
          : null,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final refresh = await context.push<bool>('/customer/tambah');
          if (refresh == true) {
            _fetchCustomers();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onWhatsApp;

  const _CustomerCard({
    required this.customer,
    required this.isSelected,
    required this.onTap,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: isSelected ? const Color(0xFFF4F4FD) : AppColors.card,
      border: isSelected
          ? Border.all(color: AppColors.primary, width: 1.5)
          : Border.all(color: AppColors.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  customer.nama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (customer.kode.isNotEmpty)
                AppBadge(
                  label: customer.kode,
                  variant: BadgeVariant.primary,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.place, size: 14, color: AppColors.accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${customer.kota.isNotEmpty ? "${customer.kota} • " : ""}${customer.alamat}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (customer.telp.isNotEmpty || customer.cp.isNotEmpty) ...[
            const Divider(height: 18, color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (customer.cp.isNotEmpty)
                  Text(
                    'CP: ${customer.cp}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                if (customer.telp.isNotEmpty)
                  InkWell(
                    onTap: onWhatsApp,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.wa.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.wa),
                          const SizedBox(width: 4),
                          Text(
                            customer.telp,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.wa,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
