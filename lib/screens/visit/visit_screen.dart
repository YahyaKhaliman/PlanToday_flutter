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
import '../../widgets/app_date_range_picker_modal.dart';
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
                            'Rekap Visit',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Riwayat realisasi kunjungan sales',
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
                      onTap: _fetchVisits,
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

              // 2. FILTER RANGE BANNER & STATUS CHIPS
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _selectDateRange,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 16,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${dmyFormat.format(_startDate)} - ${dmyFormat.format(_endDate)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${filteredVisits.length} Kunjungan',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: _statusOptions.map((st) {
                          final isSelected = _selectedStatus == st;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
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
                                if (val) setState(() => _selectedStatus = st);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. DAFTAR KARTU VISIT
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    : filteredVisits.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada data kunjungan pada periode ini.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF4F46E5),
                            onRefresh: _fetchVisits,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              itemCount: filteredVisits.length,
                              separatorBuilder: (ctx, i) =>
                                  const SizedBox(height: 12),
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
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        onPressed: () async {
          final refresh = await context.push<bool>('/visit/tambah');
          if (refresh == true) _fetchVisits();
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
      onTap: () {
        context.push('/visit/edit', extra: visit);
      },
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
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            Row(
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 14,
                  color: Color(0xFF00B4D8),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    visit.cusAlamat,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                visit.tanggal,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (visit.latitude != null && visit.longitude != null) ...[
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pin_drop_rounded, size: 12, color: Color(0xFF4F46E5)),
                      SizedBox(width: 3),
                      Text(
                        'GPS Tercatat',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (visit.note.isNotEmpty) ...[
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Catatan: ${visit.note}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF475569),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isRealized)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(64, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor: const Color(0xFF4F46E5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      context.push('/visit/tambah');
                    },
                    child: const Text(
                      'Check In',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
