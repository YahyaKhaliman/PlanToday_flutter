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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              ...options.map((opt) {
                return ListTile(
                  title: Text(opt, style: const TextStyle(fontWeight: FontWeight.w700)),
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
          content: Text('Penawaran sedang dalam proses approval (WAIT). Perubahan status dikunci.'),
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
            content: Text('Item dengan status BATAL wajib mengisi alasan pembatalan'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final repo = ref.read(penawaranRepositoryProvider);
    final payloadList = _updates.values.map((u) => u.toJson()).toList();
    final success = await repo.updatePenawaranStatusDetail(widget.nomor, payloadList);

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
      appBar: AppBar(
        title: Text('Status Item: ${widget.nomor}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              maxWidth: 800,
              child: Column(
                children: [
                  if (isLocked)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(color: AppColors.warningBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, color: AppColors.warningText, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Penawaran sedang menunggu approval (WAIT). Perubahan status item dikunci.',
                              style: TextStyle(color: AppColors.warningText, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: _details.isEmpty
                        ? const Center(child: Text('Tidak ada item barang', style: TextStyle(color: AppColors.muted)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _details.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _details[index];
                              final update = _updates[item.id];
                              final currentStatus = update?.status ?? 'OPEN';

                              Color badgeColor = AppColors.primary;
                              if (currentStatus == 'BATAL') badgeColor = AppColors.danger;
                              if (currentStatus == 'CONFIRM') badgeColor = AppColors.success;
                              if (currentStatus == 'CLOSE') badgeColor = AppColors.muted;

                              return AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.namaBarang,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink),
                                          ),
                                        ),
                                        Text('${item.qty.toInt()} ${item.satuan}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted)),
                                      ],
                                    ),
                                    const Divider(height: 18, color: AppColors.border),

                                    // Status Selector
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Status Item:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                                        InkWell(
                                          onTap: isLocked
                                              ? null
                                              : () => _showOptionPicker(
                                                    title: 'Ubah Status Item',
                                                    options: _statusOptions,
                                                    onSelected: (val) {
                                                      setState(() {
                                                        update?.status = val;
                                                        if (val != 'BATAL') update?.ketBatal = '';
                                                      });
                                                    },
                                                  ),
                                          child: AppBadge(
                                            label: currentStatus,
                                            customColor: badgeColor,
                                            icon: isLocked ? null : Icons.arrow_drop_down,
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
                                                  title: 'Pilih Alasan Batal',
                                                  options: _masterBatal.map((m) => m['nama'] ?? '').where((s) => s.isNotEmpty).toList(),
                                                  onSelected: (val) {
                                                    setState(() => update?.ketBatal = val);
                                                  },
                                                ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger.withValues(alpha: 0.06),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                update?.ketBatal.isNotEmpty == true ? 'Alasan: ${update!.ketBatal}' : 'Pilih Alasan Batal *',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: update?.ketBatal.isNotEmpty == true ? AppColors.ink : AppColors.danger,
                                                ),
                                              ),
                                              const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.danger),
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
                                                  title: 'Pilih Jenis Konfirmasi',
                                                  options: _masterConfirm.map((m) => m['nama'] ?? '').where((s) => s.isNotEmpty).toList(),
                                                  onSelected: (val) {
                                                    setState(() => update?.ketConfirm = val);
                                                  },
                                                ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withValues(alpha: 0.06),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                update?.ketConfirm.isNotEmpty == true ? 'Konfirmasi: ${update!.ketConfirm}' : 'Pilih Konfirmasi',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                                              ),
                                              const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.success),
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

                  // Footer Simpan Button
                  if (!isLocked)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        border: const Border(top: BorderSide(color: AppColors.border)),
                        boxShadow: AppShadows.card,
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
    );
  }
}
