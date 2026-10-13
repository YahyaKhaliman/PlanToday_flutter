import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../engines/kalkulasi_engine.dart';
import '../../engines/ongkir_engine.dart';
import '../../models/kalkulasi_models.dart';
import '../../models/permintaan_harga_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../widgets/customer_picker_modal.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class PermintaanHargaFormScreen extends ConsumerStatefulWidget {
  final PermintaanHargaDetail? initialDetail;

  const PermintaanHargaFormScreen({super.key, this.initialDetail});

  @override
  ConsumerState<PermintaanHargaFormScreen> createState() =>
      _PermintaanHargaFormScreenState();
}

class _PermintaanHargaFormScreenState
    extends ConsumerState<PermintaanHargaFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Divisi: '1'=Spanduk, '5'=MMT, '4'=Garmen
  String _selectedDivisi = '1';

  final _customerNamaController = TextEditingController();
  String _selectedCustomerKode = '';

  final _barangController = TextEditingController();
  final _qtyController = TextEditingController(text: '100');
  final _budgetController = TextEditingController();
  final _alokasiKotaController = TextEditingController(text: 'Jakarta');
  final _keteranganController = TextEditingController();

  // Spanduk & MMT spesifik
  final _panjangController = TextEditingController(text: '1.0');
  final _lebarController = TextEditingController(text: '1.0');
  String _selectedKain = 'TC Super';
  String _selectedFinishing = 'Obras';
  String _selectedMmtBahan = 'Frontlite 280';

  // Garmen spesifik
  final _biayaPotongController = TextEditingController(text: '1000');
  final _biayaJahitController = TextEditingController(text: '3000');
  final _biayaFinishingController = TextEditingController(text: '500');
  final double _bordirPanjang = 5.0;
  final double _bordirLebar = 5.0;
  double _labaPct = 10.0;
  final double _allowancePct = 5.0;
  final double _ppnPct = 11.0;

  // Image Attachment
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // Hasil Kalkulasi
  double _calculatedPrice = 0.0;
  OngkirCalcResult? _ongkirResult;
  bool _isLoading = false;
  List<Map<String, dynamic>> _customerSoHistory = [];

  final List<Map<String, String>> _divisiOptions = [
    {'kode': '1', 'label': '1 - SPANDUK'},
    {'kode': '5', 'label': '5 - MMT'},
    {'kode': '4', 'label': '4 - GARMEN'},
  ];

  final List<String> _kainSpandukOptions = [
    'TC Super', 'TC Export', 'Tetoron', 'Polyester', 'Satin',
  ];

  final List<String> _finishingSpandukOptions = [
    'Obras', 'Tali Samping', 'Mata Ayam (Ring)', 'Polos',
  ];

  final List<String> _bahanMmtOptions = [
    'Frontlite 280', 'Frontlite 340', 'Frontlite 440', 'Backlite', 'Luster',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialDetail;
    if (d != null) {
      _selectedDivisi = d.divisi.isNotEmpty ? d.divisi : '1';
      _customerNamaController.text = d.cusNama;
      _selectedCustomerKode = d.cusKode;
      _barangController.text = d.nama;
      _qtyController.text = d.jmlOrder > 0 ? d.jmlOrder.toInt().toString() : '100';
      _budgetController.text = d.budget > 0 ? d.budget.toInt().toString() : '';
      _keteranganController.text = d.keterangan;

      if (d.panjang > 0) _panjangController.text = d.panjang.toString();
      if (d.lebar > 0) _lebarController.text = d.lebar.toString();
      if (d.kain.isNotEmpty) _selectedKain = d.kain;
      if (d.finishing.isNotEmpty) _selectedFinishing = d.finishing;

      _calculatedPrice = d.hargaKalkulasi > 0 ? d.hargaKalkulasi : d.harga;
    }
    _recalculate();
  }

  @override
  void dispose() {
    _customerNamaController.dispose();
    _barangController.dispose();
    _qtyController.dispose();
    _budgetController.dispose();
    _alokasiKotaController.dispose();
    _keteranganController.dispose();
    _panjangController.dispose();
    _lebarController.dispose();
    _biayaPotongController.dispose();
    _biayaJahitController.dispose();
    _biayaFinishingController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomerHistory(String cusKode) async {
    if (cusKode.isEmpty) return;
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final history = await repo.getCustomerSoHistory(cusKode);
      if (mounted) {
        setState(() {
          _customerSoHistory = history;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (picked != null && mounted) {
        setState(() => _imageFile = File(picked.path));
      }
    } catch (_) {}
  }

  void _showImageSourceDialog() {
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
              const Text(
                'Pilih Sumber Foto Desain',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Divider(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF4F46E5),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Kamera',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B4D8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF00B4D8),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Galeri Foto',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _recalculate() {
    final qty = double.tryParse(_qtyController.text) ?? 1.0;
    final panjang = double.tryParse(_panjangController.text) ?? 1.0;
    final lebar = double.tryParse(_lebarController.text) ?? 1.0;

    double price = 0.0;

    if (_selectedDivisi == '1') {
      // 1. Spanduk Engine
      price = KalkulasiEngine.calculateSpanduk(
        panjangM: panjang,
        lebarM: lebar,
        kainRatePerM2: _selectedKain == 'TC Export' ? 14000.0 : 12500.0,
        finishingRatePerM: _selectedFinishing == 'Tali Samping' ? 1500.0 : 1000.0,
      );
    } else if (_selectedDivisi == '5') {
      // 2. MMT Engine
      price = KalkulasiEngine.calculateMmt(
        panjangM: panjang,
        lebarM: lebar,
        bahanRatePerM2: _selectedMmtBahan.contains('340') ? 22000.0 : 18000.0,
      );
    } else {
      // 3. Garmen Engine
      final rpPotong = double.tryParse(_biayaPotongController.text) ?? 1000.0;
      final rpJahit = double.tryParse(_biayaJahitController.text) ?? 3000.0;
      final rpFinishing = double.tryParse(_biayaFinishingController.text) ?? 500.0;

      final state = KalkulasiState(
        rencanaOrder: qty,
        rpPotong: rpPotong,
        rpJahit: rpJahit,
        rpFinishing: rpFinishing,
        gridKomponen: [
          const KomponenKainItem(
            komponen: 'Badan & Lengan',
            kg: true,
            harga: 80000,
            babaran: 3.0,
          ),
        ],
        bordir: Dimension8Slots(
          cm: 50.0,
          p1: _bordirPanjang,
          l1: _bordirLebar,
        ),
        persenAllowance: _allowancePct,
        persenLaba: _labaPct,
        persenPpn: _ppnPct,
      );

      final kResult = KalkulasiEngine.calculatePrice(state, qty);
      price = kResult.hargaSesuaiPpn.toDouble();
    }

    // 4. Kalkulasi Ongkir Otomatis
    final oResult = OngkirEngine.hitungOngkirOtomatis(
      alokasi: _alokasiKotaController.text.trim(),
      divisi: _selectedDivisi,
      qty: qty,
    );

    setState(() {
      _calculatedPrice = price;
      _ongkirResult = oResult;
    });
  }

  Future<void> _submit() async {
    if (_customerNamaController.text.trim().isEmpty) {
      AppToast.error(context, 'Customer wajib dipilih terlebih dahulu');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(permintaanHargaRepositoryProvider);
    final ymdFormat = DateFormat('yyyy-MM-dd');

    final qty = double.tryParse(_qtyController.text) ?? 1.0;
    final budget = double.tryParse(_budgetController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
    final panjang = double.tryParse(_panjangController.text) ?? 0.0;
    final lebar = double.tryParse(_lebarController.text) ?? 0.0;

    final payload = {
      'tanggal': ymdFormat.format(DateTime.now()),
      'customer': _customerNamaController.text.trim(),
      'customer_kode': _selectedCustomerKode,
      'divisi': _selectedDivisi,
      'nama': _barangController.text.trim(),
      'jml_order': qty,
      'budget': budget,
      'harga_kalkulasi': _calculatedPrice,
      'harga': _calculatedPrice,
      'ongkir': _ongkirResult?.totalOngkir ?? 0.0,
      'keterangan': _keteranganController.text.trim(),
      'kain': _selectedDivisi == '1' ? _selectedKain : (_selectedDivisi == '5' ? _selectedMmtBahan : 'Cotton Combed 30s'),
      'finishing': _selectedFinishing,
      'panjang': panjang,
      'lebar': lebar,
      'user_create': user?.nama ?? '',
      'sales_kode': user?.salesKode ?? user?.kode ?? '',
      'sales_nama': user?.nama ?? '',
    };

    bool isSuccess = false;
    String targetNomor = widget.initialDetail?.nomor ?? '';

    if (widget.initialDetail != null) {
      isSuccess = await repo.updatePermintaanHarga(targetNomor, payload);
    } else {
      final res = await repo.createPermintaanHarga(payload);
      if (res != null) {
        isSuccess = true;
        targetNomor = res['nomor']?.toString() ?? '';
      }
    }

    // Upload Gambar jika ada
    if (isSuccess && _imageFile != null && targetNomor.isNotEmpty) {
      await repo.uploadImage(targetNomor, _imageFile!);
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (isSuccess) {
        AppToast.success(
          context,
          widget.initialDetail != null
              ? 'Permintaan harga berhasil diperbarui'
              : 'Permintaan harga berhasil disimpan',
        );
        context.pop(true);
      } else {
        AppToast.error(context, 'Gagal menyimpan permintaan harga');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final isEdit = widget.initialDetail != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 650,
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
                            isEdit ? 'Edit Permintaan Harga' : 'Form Permintaan Harga',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEdit
                                ? 'Perbarui spesifikasi & kalkulasi'
                                : 'Kalkulasi HPP & simulasi harga jual',
                            style: const TextStyle(
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

              // 2. FORM BODY
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // DIVISI SELECTOR
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pilih Divisi Produk *',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: _divisiOptions.map((d) {
                                  final isSelected = _selectedDivisi == d['kode'];
                                  return Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        setState(() => _selectedDivisi = d['kode']!);
                                        _recalculate();
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF4F46E5) : const Color.fromRGBO(15, 23, 42, 0.06),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          d['label']!,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // DATA PESANAN & CUSTOMER
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Data Pemesan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Customer Selector
                              InkWell(
                                onTap: () async {
                                  final picked = await showCustomerPickerModal(context);
                                  if (picked != null) {
                                    setState(() {
                                      _customerNamaController.text = picked.nama;
                                      _selectedCustomerKode = picked.kode;
                                    });
                                    _fetchCustomerHistory(picked.kode);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.06)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _customerNamaController.text.isNotEmpty
                                              ? _customerNamaController.text
                                              : 'Pilih Customer Tujuan *',
                                          style: TextStyle(
                                            fontWeight: _customerNamaController.text.isNotEmpty ? FontWeight.w800 : FontWeight.w500,
                                            fontSize: 13,
                                            color: _customerNamaController.text.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Riwayat SO Customer jika ada
                              if (_customerSoHistory.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Katalog Riwayat Harga Customer (${_customerSoHistory.length} Transaksi)',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Item terakhir: ${_customerSoHistory.first['nama_barang'] ?? '-'} (Rp ${formatNumberDisplay(_customerSoHistory.first['harga'])})',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              TextFormField(
                                controller: _barangController,
                                decoration: const InputDecoration(
                                  labelText: 'Nama Barang / Model Desain *',
                                  prefixIcon: Icon(Icons.checkroom_outlined, size: 20),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama barang wajib diisi' : null,
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _qtyController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Jumlah Order (pcs) *',
                                        prefixIcon: Icon(Icons.numbers_outlined, size: 20),
                                      ),
                                      onChanged: (_) => _recalculate(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _budgetController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Budget Customer (Rp)',
                                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _alokasiKotaController,
                                decoration: const InputDecoration(
                                  labelText: 'Tujuan Pengiriman (Kota)',
                                  prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                                ),
                                onChanged: (_) => _recalculate(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // SPESIFIKASI TEKNIS SESUAI DIVISI
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDivisi == '1'
                                    ? 'Spesifikasi Spanduk'
                                    : (_selectedDivisi == '5' ? 'Spesifikasi MMT' : 'Spesifikasi Garmen'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 14),

                              if (_selectedDivisi == '1' || _selectedDivisi == '5') ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _panjangController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'Panjang (m)'),
                                        onChanged: (_) => _recalculate(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _lebarController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'Lebar (m)'),
                                        onChanged: (_) => _recalculate(),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                              ],

                              if (_selectedDivisi == '1') ...[
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedKain,
                                  decoration: const InputDecoration(labelText: 'Jenis Kain Spanduk'),
                                  items: _kainSpandukOptions.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedKain = val);
                                      _recalculate();
                                    }
                                  },
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedFinishing,
                                  decoration: const InputDecoration(labelText: 'Finishing Tepi'),
                                  items: _finishingSpandukOptions.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedFinishing = val);
                                      _recalculate();
                                    }
                                  },
                                ),
                              ],

                              if (_selectedDivisi == '5') ...[
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedMmtBahan,
                                  decoration: const InputDecoration(labelText: 'Bahan Banner MMT'),
                                  items: _bahanMmtOptions.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedMmtBahan = val);
                                      _recalculate();
                                    }
                                  },
                                ),
                              ],

                              if (_selectedDivisi == '4') ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Bordir: ${_bordirPanjang.toStringAsFixed(1)} x ${_bordirLebar.toStringAsFixed(1)} cm', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    Text('Margin: ${_labaPct.toInt()}%', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5), fontSize: 13)),
                                  ],
                                ),
                                Slider(
                                  value: _labaPct,
                                  min: 0,
                                  max: 50,
                                  divisions: 10,
                                  activeColor: const Color(0xFF4F46E5),
                                  onChanged: (v) {
                                    setState(() => _labaPct = v);
                                    _recalculate();
                                  },
                                ),
                              ],
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _keteranganController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Keterangan Tambahan',
                                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // FOTO DESAIN LAMPIRAN
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Foto Desain Lampiran',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _showImageSourceDialog,
                                child: Container(
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
                                  ),
                                  alignment: Alignment.center,
                                  child: _imageFile != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.file(_imageFile!, width: double.infinity, height: 140, fit: BoxFit.cover),
                                        )
                                      : (widget.initialDetail?.gambarUrl.isNotEmpty == true)
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(14),
                                              child: Image.network(
                                                '${ApiConfig.imageReadUrl}${ApiConfig.imageBasePath}/${widget.initialDetail!.gambarUrl}',
                                                width: double.infinity,
                                                height: 140,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: const [
                                                Icon(Icons.add_a_photo_outlined, size: 28, color: Color(0xFF64748B)),
                                                SizedBox(height: 4),
                                                Text('Ambil / Pilih Gambar Desain', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                              ],
                                            ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // HASIL PERHITUNGAN ENGINE CARD
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppShadows.card,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'HASIL REKOMENDASI HARGA KALKULASI',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Harga Rekomendasi:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(
                                    currencyFormat.format(_calculatedPrice),
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                              if (_ongkirResult != null) ...[
                                const Divider(color: Colors.white24, height: 16),
                                Text(
                                  'Ongkir: ${_ongkirResult!.ringkasan} (Rp ${formatNumberDisplay(_ongkirResult!.totalOngkir)})',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        AppButton(
                          text: isEdit ? 'Simpan Perubahan' : 'Kirim Permintaan Harga',
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

  String formatNumberDisplay(dynamic val) {
    final num = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    return num.format(val ?? 0).trim();
  }
}
