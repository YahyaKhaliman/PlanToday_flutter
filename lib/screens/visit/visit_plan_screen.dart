import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/visit_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';

class VisitPlanScreen extends ConsumerStatefulWidget {
  const VisitPlanScreen({super.key});

  @override
  ConsumerState<VisitPlanScreen> createState() => _VisitPlanScreenState();
}

class _VisitPlanScreenState extends ConsumerState<VisitPlanScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  List<VisitModel> _plans = [];
  bool _isLoading = false;
  String _selectedStatus = 'SEMUA'; // SEMUA, SELESAI, BELUM

  final List<String> _statusOptions = ['SEMUA', 'SELESAI', 'BELUM'];

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(visitRepositoryProvider);

    final ymdFormat = DateFormat('yyyy-MM-dd');
    final startStr = ymdFormat.format(_startDate);
    final endStr = ymdFormat.format(_endDate);

    final results = await repo.getVisitPlanList(
      cabang: user?.cabang ?? '',
      sales: user?.nama ?? '',
      startDate: startStr,
      endDate: endStr,
      isManager: user?.jabatan.toUpperCase() == 'MANAGER',
    );

    if (mounted) {
      setState(() {
        _plans = results;
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
      _fetchPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dmyFormat = DateFormat('dd MMM yyyy');

    final filteredPlans = _plans.where((p) {
      if (_selectedStatus == 'SELESAI') return p.realisasi == 'Y';
      if (_selectedStatus == 'BELUM') return p.realisasi != 'Y';
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter Tanggal',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPlans,
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
                color: AppColors.accent.withValues(alpha: 0.08),
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
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text(
                              '${dmyFormat.format(_startDate)} - ${dmyFormat.format(_endDate)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
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
                          '${filteredPlans.length} Rencana',
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
                  // Filter Status Chips
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

            // List Items
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredPlans.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada rencana visit pada periode ini',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchPlans,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredPlans.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final plan = filteredPlans[index];
                              return _PlanCard(plan: plan);
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
            _fetchPlans();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final VisitModel plan;

  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final isDone = plan.realisasi == 'Y';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  plan.cusNama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              AppBadge(
                label: isDone ? 'SELESAI' : plan.tanggal,
                variant: isDone ? BadgeVariant.success : BadgeVariant.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (plan.cusAlamat.isNotEmpty)
            Text(
              plan.cusAlamat,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          if (plan.note.isNotEmpty) ...[
            const Divider(height: 18, color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Agenda: ${plan.note}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (!isDone)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(64, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: () {
                      context.push('/visit/tambah');
                    },
                    child: const Text('Visit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
