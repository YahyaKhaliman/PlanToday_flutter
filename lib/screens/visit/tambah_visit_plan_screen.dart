import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/customer_picker_modal.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class TambahVisitPlanScreen extends ConsumerStatefulWidget {
  final CustomerModel? initialCustomer;

  const TambahVisitPlanScreen({super.key, this.initialCustomer});

  @override
  ConsumerState<TambahVisitPlanScreen> createState() =>
      _TambahVisitPlanScreenState();
}

class _TambahVisitPlanScreenState extends ConsumerState<TambahVisitPlanScreen> {
  final _formKey = GlobalKey<FormState>();

  CustomerModel? _selectedCustomer;
  DateTime _selectedDate = DateTime.now();
  final _noteController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.initialCustomer;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectCustomer() async {
    final selected = await showCustomerPickerModal(context);
    if (selected != null && mounted) {
      setState(() => _selectedCustomer = selected);
    }
  }

  Future<void> _submit() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer harus dipilih terlebih dahulu'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final ymdFormat = DateFormat('yyyy-MM-dd');
    final todayYmd = ymdFormat.format(DateTime.now());
    final planYmd = ymdFormat.format(_selectedDate);

    if (planYmd.compareTo(todayYmd) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal plan tidak boleh tanggal yang sudah lewat'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(visitRepositoryProvider);

    final success = await repo.createVisitPlan(
      cusKode: _selectedCustomer!.kode,
      user: user?.nama ?? '',
      tanggalPlan: planYmd,
      note: _noteController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rencana kunjungan berhasil dijadwalkan'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuat visit plan'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dmyFormat = DateFormat('dd MMMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 600,
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
                            'Buat Visit Plan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Jadwalkan rencana kunjungan sales baru',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. FORM KONTEN
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Rencana Kunjungan Baru',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Pilih Customer
                              const Text(
                                'Customer *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _selectCustomer,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color.fromRGBO(15, 23, 42, 0.06),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedCustomer?.nama ??
                                              'Ketuk untuk pilih customer...',
                                          style: TextStyle(
                                            color: _selectedCustomer != null
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFF64748B),
                                            fontWeight: _selectedCustomer != null
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_drop_down_rounded,
                                        color: Color(0xFF64748B),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Tanggal Plan
                              const Text(
                                'Tanggal Rencana Kunjungan *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime.now().subtract(
                                      const Duration(days: 1),
                                    ),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedDate = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color.fromRGBO(15, 23, 42, 0.06),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dmyFormat.format(_selectedDate),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Note / Agenda
                              const Text(
                                'Agenda Kunjungan *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _noteController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Contoh: Follow up penawaran spanduk...',
                                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Agenda kunjungan wajib diisi'
                                        : null,
                              ),
                              const SizedBox(height: 20),

                              // Tombol Simpan
                              AppButton(
                                text: 'Jadwalkan Visit Plan',
                                isLoading: _isLoading,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
