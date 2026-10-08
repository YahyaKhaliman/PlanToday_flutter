import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/visit_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

class VisitScreen extends ConsumerStatefulWidget {
  const VisitScreen({super.key});

  @override
  ConsumerState<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends ConsumerState<VisitScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  List<VisitModel> _visits = [];
  bool _isLoading = false;
  String _selectedStatus = 'SEMUA'; // SEMUA, SELESAI, BELUM

  final List<String> _statusOptions = ['SEMUA', 'SELESAI', 'BELUM'];

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(visitRepositoryProvider);

    final ymdFormat = DateFormat('yyyy-MM-dd');
    final startStr = ymdFormat.format(_startDate);
    final endStr = ymdFormat.format(_endDate);

    final results = await repo.getVisitList(
      cabang: user?.cabang ?? '',
      sales: user?.nama ?? '',
      startDate: startStr,
      endDate: endStr,
    );

    if (mounted) {
      setState(() {
        _visits = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchVisits();
    }
  }

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
    final dmyFormat = DateFormat('dd MMM yyyy');

    final filteredVisits = _visits.where((v) {
      if (_selectedStatus == 'SELESAI') return v.realisasi == 'Y';
      if (_selectedStatus == 'BELUM') return v.realisasi != 'Y';
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Visit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter Tanggal',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchVisits,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 1000,
        child: Column(
          children: [
            // Filter Range Banner & Status Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                border: const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: _selectDateRange,
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              '${dmyFormat.format(_startDate)} - ${dmyFormat.format(_endDate)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${filteredVisits.length} Kunjungan',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Filter Status Chips (SEMUA, SELESAI, BELUM)
                  Row(
                    children: _statusOptions.map((st) {
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
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedStatus = st);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // List Data
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredVisits.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada data kunjungan pada periode ini',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchVisits,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredVisits.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final visit = filteredVisits[index];
                              return _VisitCard(
                                visit: visit,
                                onWhatsApp: () => _launchWhatsApp(visit.note),
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
          final refresh = await context.push<bool>('/visit/tambah');
          if (refresh == true) {
            _fetchVisits();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final VisitModel visit;
  final VoidCallback? onWhatsApp;

  const _VisitCard({required this.visit, this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    final isRealized = visit.realisasi == 'Y';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  visit.cusNama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              AppBadge(
                label: isRealized ? 'Terealisasi' : 'Belum Realisasi',
                variant: isRealized ? BadgeVariant.success : BadgeVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (visit.cusAlamat.isNotEmpty)
            Text(
              visit.cusAlamat,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                visit.tanggal,
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
              ),
              if (visit.latitude != null && visit.longitude != null) ...[
                const SizedBox(width: 16),
                const Icon(Icons.pin_drop, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                const Text(
                  'GPS Tercatat',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (visit.note.isNotEmpty) ...[
            const Divider(height: 18, color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Catatan: ${visit.note}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (!isRealized)
                  InkWell(
                    onTap: () {
                      context.push('/visit/tambah');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Check In', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
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
