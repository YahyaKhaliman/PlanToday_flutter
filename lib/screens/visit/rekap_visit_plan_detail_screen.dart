import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class RekapVisitPlanDetailScreen extends ConsumerStatefulWidget {
  final int id;
  final bool canEdit;

  const RekapVisitPlanDetailScreen({
    super.key,
    required this.id,
    this.canEdit = true,
  });

  @override
  ConsumerState<RekapVisitPlanDetailScreen> createState() =>
      _RekapVisitPlanDetailScreenState();
}

class _RekapVisitPlanDetailScreenState
    extends ConsumerState<RekapVisitPlanDetailScreen> {
  final _noteController = TextEditingController();
  Map<String, dynamic>? _detail;
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final repo = ref.read(visitRepositoryProvider);
    final data = await repo.getRekapVisitPlanDetail(widget.id);

    if (mounted) {
      setState(() {
        _detail = data;
        _noteController.text = data?['note']?.toString() ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitNote() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      AppToast.error(context, 'Catatan keperluan tidak boleh kosong');
      return;
    }

    setState(() => _isSubmitting = true);
    final repo = ref.read(visitRepositoryProvider);
    final success = await repo.updateRekapVisitPlanNote(widget.id, note);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        AppToast.success(context, 'Catatan keperluan berhasil diperbarui');
        context.pop(true);
      } else {
        AppToast.error(context, 'Gagal memperbarui catatan');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            'Detail Visit Plan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Rincian jadwal & update keperluan',
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
                      onTap: _loadDetail,
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

              // 2. KONTEN DETAIL
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                      )
                    : _detail == null
                        ? const Center(
                            child: Text(
                              'Data visit plan tidak ditemukan.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _detail!['cus_nama']?.toString() ??
                                            _detail!['cc_nama']?.toString() ??
                                            '-',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (_detail!['cc_alamat'] != null &&
                                          _detail!['cc_alamat']
                                              .toString()
                                              .isNotEmpty)
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
                                                _detail!['cc_alamat'].toString(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const Divider(
                                          height: 20, color: Color(0xFFF1F5F9)),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Kode: ${_detail!['cus_kode'] ?? "-"}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          if (_detail!['tanggal_plan'] != null)
                                            Text(
                                              'Rencana: ${_detail!['tanggal_plan']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF4F46E5),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // FORM UPDATE KEPERLUAN / NOTE
                                AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Keperluan / Agenda Kunjungan',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _noteController,
                                        enabled: widget.canEdit,
                                        maxLines: 4,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Tuliskan agenda atau keperluan kunjungan...',
                                          prefixIcon:
                                              Icon(Icons.notes_rounded, size: 20),
                                        ),
                                      ),
                                      if (widget.canEdit) ...[
                                        const SizedBox(height: 16),
                                        AppButton(
                                          text: 'Simpan Perubahan Note',
                                          isLoading: _isSubmitting,
                                          onPressed: _submitNote,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
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
