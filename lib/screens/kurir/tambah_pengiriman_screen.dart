import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/kurir_repository.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class TambahPengirimanScreen extends ConsumerStatefulWidget {
  const TambahPengirimanScreen({super.key});

  @override
  ConsumerState<TambahPengirimanScreen> createState() =>
      _TambahPengirimanScreenState();
}

class _TambahPengirimanScreenState extends ConsumerState<TambahPengirimanScreen> {
  final _formKey = GlobalKey<FormState>();

  final _senderController = TextEditingController();
  final _receiverController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _senderController.dispose();
    _receiverController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatHm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final today = DateTime.now();
    final todayYmd = _formatYmd(today);
    final planYmd = _formatYmd(_selectedDate);

    if (planYmd.compareTo(todayYmd) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal rencana tidak boleh sebelum hari ini'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(kurirRepositoryProvider);

    final payload = {
      'sender': _senderController.text.trim(),
      'receiver': _receiverController.text.trim(),
      'note': _noteController.text.trim(),
      'tanggal_plan': planYmd,
      'jam_plan': _formatHm(_selectedTime),
      'status': 'ready',
      'user': user?.nama ?? '',
      'cabang': user?.cabang ?? '',
    };

    final success = await repo.createPengiriman(payload);

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal pengiriman kurir berhasil dibuat'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuat pengiriman kurir'),
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
                            'Tambah Pengiriman',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Form pembuatan jadwal antar kurir baru',
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
                                'Data Pengiriman',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Pengirim
                              TextFormField(
                                controller: _senderController,
                                decoration: const InputDecoration(
                                  labelText: 'Pengirim / Asal Barang *',
                                  prefixIcon: Icon(Icons.outbox_rounded, size: 20),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Pengirim wajib diisi'
                                        : null,
                              ),
                              const SizedBox(height: 14),

                              // Penerima
                              TextFormField(
                                controller: _receiverController,
                                decoration: const InputDecoration(
                                  labelText: 'Penerima / Tujuan Barang *',
                                  prefixIcon: Icon(Icons.move_to_inbox_rounded, size: 20),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Penerima wajib diisi'
                                        : null,
                              ),
                              const SizedBox(height: 14),

                              // Baris Tanggal & Jam
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Tanggal Kirim *',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
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
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color.fromRGBO(15, 23, 42, 0.06),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  dmyFormat.format(_selectedDate),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 15,
                                                  color: Color(0xFF4F46E5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Jam Kirim *',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: () async {
                                            final picked = await showTimePicker(
                                              context: context,
                                              initialTime: _selectedTime,
                                            );
                                            if (picked != null) {
                                              setState(() => _selectedTime = picked);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color.fromRGBO(15, 23, 42, 0.06),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  _formatHm(_selectedTime),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.schedule_rounded,
                                                  size: 16,
                                                  color: Color(0xFF4F46E5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Catatan Pengiriman
                              TextFormField(
                                controller: _noteController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Catatan / Deskripsi Barang',
                                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Tombol Simpan
                              AppButton(
                                text: 'Simpan Jadwal Pengiriman',
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
