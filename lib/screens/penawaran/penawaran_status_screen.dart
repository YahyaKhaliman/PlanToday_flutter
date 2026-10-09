import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/penawaran_model.dart';
import '../../repositories/penawaran_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class PenawaranStatusUpdateItem {
  final String id;
  String status;
  String ketBatal;
  String ketConfirm;

  PenawaranStatusUpdateItem({
    required this.id,
    required this.status,
    this.ketBatal = '',
    this.ketConfirm = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'ket_batal': ketBatal,
        'ket_confirm': ketConfirm,
      };
}

class PenawaranStatusScreen extends ConsumerStatefulWidget {
  final String nomor;

  const PenawaranStatusScreen({super.key, required this.nomor});

  @override
  ConsumerState<PenawaranStatusScreen> createState() =>
      _PenawaranStatusScreenState();
}

class _PenawaranStatusScreenState extends ConsumerState<PenawaranStatusScreen> {
  bool _isLoading = false;
  bool _isSubmitting = false;

  String _approvalState = '';
  List<PenawaranDetailItem> _details = [];
  final Map<String, PenawaranStatusUpdateItem> _updates = {};

  List<Map<String, String>> _masterBatal = [];
  List<Map<String, String>> _masterConfirm = [];

  final List<String> _statusOptions = ['OPEN', 'BATAL', 'CONFIRM', 'CLOSE'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final repo = ref.read(penawaranRepositoryProvider);
    final detailData = await repo.getPenawaranDetail(widget.nomor);
    final batal = await repo.getMasterPenawaranBatal();
    final confirm = await repo.getMasterPenawaranConfirm();

    if (mounted) {
      final items = detailData?.details ?? [];
      final header = detailData?.header;

      for (final it in items) {
        _updates[it.id] = PenawaranStatusUpdateItem(
          id: it.id,
          status: it.status.isNotEmpty ? it.status : 'OPEN',
        );
      }

      setState(() {
        _details = items;
        _approvalState = header?.approvalState ?? '';
        _masterBatal = batal;
        _masterConfirm = confirm;
        _isLoading = false;
      });
    }
  }

  void _showOptionPicker({
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              ...options.map((opt) {
                return ListTile(
                  title: Text(
                    opt,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelected(opt);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitUpdates() async {
    if (_approvalState == 'WAIT') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Penawaran sedang dalam proses approval (WAIT). Perubahan status dikunci.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Validasi alasan batal wajib diisi jika status BATAL
    for (final it in _updates.values) {
      if (it.status == 'BATAL' && it.ketBatal.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Item dengan status BATAL wajib mengisi alasan pembatalan',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final repo = ref.read(penawaranRepositoryProvider);
    final payloadList = _updates.values.map((u) => u.toJson()).toList();
    final success =
        await repo.updatePenawaranStatusDetail(widget.nomor, payloadList);

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status item penawaran berhasil diperbarui'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui status penawaran'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _approvalState == 'WAIT';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 800,
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
                        children: [
                          Text(
                            'Status Item: ${widget.nomor}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Pembaruan status realisasi item penawaran',
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

              // 2. KONTEN STATUS ITEM
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    : Column(
                        children: [
                          if (isLocked)
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFFCD34D),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: Color(0xFF92400E),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Penawaran sedang menunggu approval (WAIT). Perubahan status item dikunci.',
                                      style: TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: _details.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Tidak ada item barang.',
                                      style: TextStyle(
                                          color: Color(0xFF64748B)),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    itemCount: _details.length,
                                    separatorBuilder: (ctx, i) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final item = _details[index];
                                      final update = _updates[item.id];
                                      final currentStatus =
                                          update?.status ?? 'OPEN';

                                      Color badgeColor = const Color(0xFF4F46E5);
                                      if (currentStatus == 'BATAL') {
                                        badgeColor = const Color(0xFFEF4444);
                                      }
                                      if (currentStatus == 'CONFIRM') {
                                        badgeColor = const Color(0xFF10B981);
                                      }
                                      if (currentStatus == 'CLOSE') {
                                        badgeColor = const Color(0xFF64748B);
                                      }

                                      return AppCard(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.namaBarang,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 15,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${item.qty.toInt()} ${item.satuan}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(
                                                height: 18,
                                                color: Color(0xFFF1F5F9)),

                                            // Status Selector
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Status Item:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: isLocked
                                                      ? null
                                                      : () => _showOptionPicker(
                                                            title:
                                                                'Ubah Status Item',
                                                            options:
                                                                _statusOptions,
                                                            onSelected: (val) {
                                                              setState(() {
                                                                update?.status =
                                                                    val;
                                                                if (val !=
                                                                    'BATAL') {
                                                                  update?.ketBatal =
                                                                      '';
                                                                }
                                                              });
                                                            },
                                                          ),
                                                  child: AppBadge(
                                                    label: currentStatus,
                                                    customColor: badgeColor,
                                                    icon: isLocked
                                                        ? null
                                                        : Icons
                                                            .arrow_drop_down_rounded,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // Alasan Batal jika status BATAL
                                            if (currentStatus == 'BATAL') ...[
                                              const SizedBox(height: 10),
                                              InkWell(
                                                onTap: isLocked
                                                    ? null
                                                    : () => _showOptionPicker(
                                                          title:
                                                              'Pilih Alasan Batal',
                                                          options: _masterBatal
                                                              .map((m) =>
                                                                  m['nama'] ??
                                                                  '')
                                                              .where((s) =>
                                                                  s.isNotEmpty)
                                                              .toList(),
                                                          onSelected: (val) {
                                                            setState(() =>
                                                                update?.ketBatal =
                                                                    val);
                                                          },
                                                        ),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFEF4444)
                                                            .withValues(
                                                                alpha: 0.06),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                      color:
                                                          const Color(0xFFEF4444)
                                                              .withValues(
                                                                  alpha: 0.25),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        update?.ketBatal
                                                                    .isNotEmpty ==
                                                                true
                                                            ? 'Alasan: ${update!.ketBatal}'
                                                            : 'Pilih Alasan Batal *',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: update?.ketBatal
                                                                      .isNotEmpty ==
                                                                  true
                                                              ? const Color(
                                                                  0xFF0F172A)
                                                              : const Color(
                                                                  0xFFEF4444),
                                                        ),
                                                      ),
                                                      const Icon(
                                                        Icons
                                                            .arrow_drop_down_rounded,
                                                        size: 18,
                                                        color:
                                                            Color(0xFFEF4444),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],

                                            // Alasan Confirm jika status CONFIRM
                                            if (currentStatus == 'CONFIRM') ...[
                                              const SizedBox(height: 10),
                                              InkWell(
                                                onTap: isLocked
                                                    ? null
                                                    : () => _showOptionPicker(
                                                          title:
                                                              'Pilih Jenis Konfirmasi',
                                                          options:
                                                              _masterConfirm
                                                                  .map((m) =>
                                                                      m['nama'] ??
                                                                      '')
                                                                  .where((s) =>
                                                                      s.isNotEmpty)
                                                                  .toList(),
                                                          onSelected: (val) {
                                                            setState(() =>
                                                                update?.ketConfirm =
                                                                    val);
                                                          },
                                                        ),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF10B981)
                                                            .withValues(
                                                                alpha: 0.06),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                      color:
                                                          const Color(0xFF10B981)
                                                              .withValues(
                                                                  alpha: 0.25),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        update?.ketConfirm
                                                                    .isNotEmpty ==
                                                                true
                                                            ? 'Konfirmasi: ${update!.ketConfirm}'
                                                            : 'Pilih Konfirmasi',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Color(
                                                              0xFF0F172A),
                                                        ),
                                                      ),
                                                      const Icon(
                                                        Icons
                                                            .arrow_drop_down_rounded,
                                                        size: 18,
                                                        color:
                                                            Color(0xFF10B981),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          if (!isLocked)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  top: BorderSide(
                                    color: Color.fromRGBO(15, 23, 42, 0.08),
                                  ),
                                ),
                              ),
                              child: AppButton(
                                text: 'Simpan Perubahan Status',
                                isLoading: _isSubmitting,
                                onPressed: _submitUpdates,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
