import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/penawaran_repository.dart';
import '../../widgets/customer_picker_modal.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class DraftDetailItem {
  final TextEditingController namaBarangController;
  final TextEditingController bahanController;
  final TextEditingController ukuranController;
  final TextEditingController panjangController;
  final TextEditingController lebarController;
  final TextEditingController qtyController;
  final TextEditingController hargaController;

  DraftDetailItem()
      : namaBarangController = TextEditingController(),
        bahanController = TextEditingController(),
        ukuranController = TextEditingController(),
        panjangController = TextEditingController(text: '0'),
        lebarController = TextEditingController(text: '0'),
        qtyController = TextEditingController(text: '1'),
        hargaController = TextEditingController(text: '0');

  double get total {
    final q = double.tryParse(qtyController.text) ?? 0.0;
    final h = double.tryParse(
            hargaController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0.0;
    return q * h;
  }

  void dispose() {
    namaBarangController.dispose();
    bahanController.dispose();
    ukuranController.dispose();
    panjangController.dispose();
    lebarController.dispose();
    qtyController.dispose();
    hargaController.dispose();
  }
}

class PenawaranCreateScreen extends ConsumerStatefulWidget {
  const PenawaranCreateScreen({super.key});

  @override
  ConsumerState<PenawaranCreateScreen> createState() =>
      _PenawaranCreateScreenState();
}

class _PenawaranCreateScreenState extends ConsumerState<PenawaranCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  String _selectedDivisi = '1';
  String _selectedTipe = 'Medium';
  String _selectedPerusahaanKode = 'KP';

  CustomerModel? _selectedCustomer;
  final _keteranganController = TextEditingController();
  final _noteController = TextEditingController();

  final List<DraftDetailItem> _items = [];
  bool _isLoading = false;

  final List<Map<String, String>> _divisiOptions = [
    {'kode': '1', 'label': '1 - SPANDUK'},
    {'kode': '4', 'label': '4 - GARMEN'},
    {'kode': '5', 'label': '5 - MMT'},
  ];

  final List<String> _tipeOptions = ['Medium', 'Premium'];

  final List<Map<String, String>> _perusahaanOptions = [
    {'kode': 'KP', 'label': 'KENCANA PRINT'},
    {'kode': 'JA', 'label': 'JAYA ABADI MULIA'},
    {'kode': 'MD', 'label': 'MADANI PRODUCTION'},
  ];

  @override
  void initState() {
    super.initState();
    _addItemRow();
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    _noteController.dispose();
    for (final it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  void _addItemRow() {
    setState(() {
      _items.add(DraftDetailItem());
    });
  }

  void _removeItemRow(int index) {
    if (_items.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 item barang'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
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
          content: Text('Customer wajib dipilih terlebih dahulu'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    for (int i = 0; i < _items.length; i++) {
      if (_items[i].namaBarangController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nama barang pada baris ke-${i + 1} wajib diisi'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(penawaranRepositoryProvider);
    final ymdFormat = DateFormat('yyyy-MM-dd');

    final detailsPayload = _items.map((it) {
      final q = double.tryParse(it.qtyController.text) ?? 1.0;
      final h = double.tryParse(
              it.hargaController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
          0.0;
      final p = double.tryParse(it.panjangController.text) ?? 0.0;
      final l = double.tryParse(it.lebarController.text) ?? 0.0;

      return {
        'nama_barang': it.namaBarangController.text.trim(),
        'bahan': it.bahanController.text.trim(),
        'ukuran': it.ukuranController.text.trim(),
        'panjang': p,
        'lebar': l,
        'satuan': 'pcs',
        'qty': q,
        'harga': h,
      };
    }).toList();

    final payload = {
      'tanggal': ymdFormat.format(_selectedDate),
      'divisi': _selectedDivisi,
      'tipe': _selectedTipe,
      'perusahaan_kode': _selectedPerusahaanKode,
      'customer_kode': _selectedCustomer!.kode,
      'customer': _selectedCustomer!.nama,
      'sales_kode': user?.salesKode ?? user?.kode ?? '',
      'sales': user?.nama ?? '',
      'keterangan': _keteranganController.text.trim(),
      'note': _noteController.text.trim(),
      'details': detailsPayload,
    };

    final success = await repo.createPenawaran(payload);

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Surat penawaran harga berhasil dibuat'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Gagal membuat penawaran. Periksa koneksi ke server.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dmyFormat = DateFormat('dd MMMM yyyy');

    final grandTotal = _items.fold<double>(0.0, (acc, it) => acc + it.total);

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
                        children: const [
                          Text(
                            'Buat Penawaran Harga',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Form penerbitan surat penawaran baru',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // INFORMASI UTAMA DOKUMEN
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Informasi Dokumen Penawaran',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Tanggal Penawaran
                              const Text(
                                'Tanggal Penawaran *',
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
                                      color:
                                          const Color.fromRGBO(15, 23, 42, 0.06),
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

                              // Customer Selector
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
                                      color:
                                          const Color.fromRGBO(15, 23, 42, 0.06),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedCustomer?.nama ??
                                              'Pilih customer tujuan penawaran...',
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

                              // Baris Pilihan Divisi & Tipe
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Divisi *',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: _selectedDivisi,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          items: _divisiOptions.map((d) {
                                            return DropdownMenuItem(
                                              value: d['kode'],
                                              child: Text(
                                                d['label']!,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(
                                                  () => _selectedDivisi = val);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Tipe *',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: _selectedTipe,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          items: _tipeOptions.map((t) {
                                            return DropdownMenuItem(
                                              value: t,
                                              child: Text(
                                                t,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _selectedTipe = val);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Perusahaan Dropdown (Kop Surat)
                              const Text(
                                'Kop Surat Perusahaan *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedPerusahaanKode,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: _perusahaanOptions.map((p) {
                                  return DropdownMenuItem(
                                    value: p['kode'],
                                    child: Text(
                                      p['label']!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(
                                        () => _selectedPerusahaanKode = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 14),

                              TextFormField(
                                controller: _keteranganController,
                                decoration: const InputDecoration(
                                  labelText: 'Keterangan Penawaran',
                                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // RINCIAN BARANG PENAWARAN (DYNAMIC MULTI-ROW)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Rincian Barang (${_items.length} Item)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addItemRow,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'Tambah Baris',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        ..._items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Item #${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                      if (_items.length > 1)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: Color(0xFFEF4444),
                                          ),
                                          tooltip: 'Hapus Baris',
                                          onPressed: () => _removeItemRow(index),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  TextFormField(
                                    controller: item.namaBarangController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nama Barang / Model *',
                                      prefixIcon: Icon(Icons.checkroom_outlined, size: 20),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: item.bahanController,
                                          decoration: const InputDecoration(
                                            labelText: 'Bahan',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          controller: item.ukuranController,
                                          decoration: const InputDecoration(
                                            labelText: 'Ukuran',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: item.qtyController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Qty (pcs)',
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: item.hargaController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Harga Satuan (Rp)',
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20, color: Color(0xFFF1F5F9)),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Subtotal:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        currencyFormat.format(item.total),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        // GRAND TOTAL FOOTER CARD
                        AppCard(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Penawaran:',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                currencyFormat.format(grandTotal),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4F46E5),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        AppButton(
                          text: 'Simpan & Buat Penawaran',
                          isLoading: _isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 24),
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
