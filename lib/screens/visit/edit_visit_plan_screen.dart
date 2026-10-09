import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/visit_model.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class EditVisitPlanScreen extends ConsumerStatefulWidget {
  final VisitModel plan;

  const EditVisitPlanScreen({super.key, required this.plan});

  @override
  ConsumerState<EditVisitPlanScreen> createState() =>
      _EditVisitPlanScreenState();
}

class _EditVisitPlanScreenState extends ConsumerState<EditVisitPlanScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late final TextEditingController _noteController;
  late final TextEditingController _catatanController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _noteController = TextEditingController(text: p.note);
    _catatanController = TextEditingController(text: p.catatan);

    try {
      _selectedDate = DateFormat('yyyy-MM-dd').parse(p.tanggal);
    } catch (_) {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.plan.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID rencana kunjungan tidak valid'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final ymd = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final repo = ref.read(visitRepositoryProvider);

    final success = await repo.updateVisitPlan(
      id: widget.plan.id!,
      tanggalPlan: ymd,
      note: _noteController.text.trim(),
      catatan: _catatanController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perubahan rencana kunjungan berhasil disimpan'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui visit plan'),
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
                            'Edit Visit Plan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Perbarui jadwal kunjungan sales',
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
                              // Customer Info (Read-only)
                              Text(
                                widget.plan.cusNama,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (widget.plan.cusAlamat.isNotEmpty) ...[
                                const SizedBox(height: 4),
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
                                        widget.plan.cusAlamat,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),

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
                                    firstDate: DateTime(2020),
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

                              // Agenda Kunjungan
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
                                  hintText: 'Agenda yang direncanakan...',
                                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Agenda kunjungan wajib diisi'
                                        : null,
                              ),
                              const SizedBox(height: 14),

                              // Catatan Tambahan (Opsional)
                              const Text(
                                'Catatan Tambahan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _catatanController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  hintText: 'Catatan tambahan jika ada...',
                                  prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Tombol Simpan Perubahan
                              AppButton(
                                text: 'Simpan Perubahan',
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
