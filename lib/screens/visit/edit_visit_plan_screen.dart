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
      appBar: AppBar(
        title: const Text('Edit Visit Plan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ResponsiveContainer(
          maxWidth: 600,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Informasi Customer (Read-only)
                      Text(
                        widget.plan.cusNama,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      if (widget.plan.cusAlamat.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.plan.cusAlamat,
                          style: const TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                      ],
                      const Divider(height: 24, color: AppColors.border),

                      // Tanggal Plan
                      const Text(
                        'Tanggal Rencana Kunjungan *',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
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
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dmyFormat.format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                              const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Note / Agenda
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(labelText: 'Tujuan / Agenda Kunjungan *'),
                        maxLines: 2,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Agenda kunjungan wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // Catatan Tambahan
                      TextFormField(
                        controller: _catatanController,
                        decoration: const InputDecoration(labelText: 'Catatan Tambahan'),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                AppButton(
                  text: 'Simpan Perubahan',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
