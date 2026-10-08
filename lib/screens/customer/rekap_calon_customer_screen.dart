import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers([String? query]) async {
    setState(() => _isLoading = true);
    final repo = ref.read(customerRepositoryProvider);
    final results = (query != null && query.trim().isNotEmpty)
        ? await repo.searchCustomer(query.trim())
        : await repo.getRekapCalonCustomer();

    if (mounted) {
      setState(() {
        _customers = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calon Customer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchCustomers(_searchController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar dengan Bayangan Halus
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                boxShadow: AppShadows.softCard,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari customer atau kota...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.muted),
                          onPressed: () {
                            _searchController.clear();
                            _fetchCustomers();
                          },
                        )
                      : null,
                ),
                onSubmitted: (query) => _fetchCustomers(query),
              ),
            ),
          ),

          // List Customer
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada data customer',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchCustomers(_searchController.text),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _customers.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final customer = _customers[index];
                            return _CustomerCard(customer: customer);
                          },
                        ),
                      ),
          ),
        ],
      ),
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

  const _CustomerCard({required this.customer});

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;
    final normalizedPhone = cleanPhone.startsWith('0')
        ? '62${cleanPhone.substring(1)}'
        : (cleanPhone.startsWith('62') ? cleanPhone : '62$cleanPhone');
    final uri = Uri.parse('https://wa.me/$normalizedPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
          Text(
            customer.alamat,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          if (customer.kota.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  customer.kota,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (customer.telp.isNotEmpty || customer.cp.isNotEmpty) ...[
            const Divider(height: 18, color: AppColors.border),
            Row(
              children: [
                if (customer.cp.isNotEmpty)
                  Expanded(
                    child: Text(
                      'CP: ${customer.cp}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                if (customer.telp.isNotEmpty)
                  InkWell(
                    onTap: () => _launchWhatsApp(customer.telp),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.wa.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 13, color: AppColors.wa),
                          const SizedBox(width: 4),
                          Text(
                            customer.telp,
                            style: const TextStyle(
                              fontSize: 12,
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
