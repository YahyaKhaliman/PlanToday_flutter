import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/utils/app_toast.dart';
import '../../engines/ongkir_engine.dart';
import '../../models/permintaan_harga_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../widgets/customer_picker_modal.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class _DecimalTextInputFormatter extends TextInputFormatter {
  const _DecimalTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '.');
    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final isValid = RegExp(r'^\d*\.?\d*$').hasMatch(text);
    if (!isValid) {
      return oldValue;
    }
    final selectionIndex = newValue.selection.baseOffset;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: selectionIndex <= text.length ? selectionIndex : text.length,
      ),
    );
  }
}

const _decimalInputFormatter = _DecimalTextInputFormatter();

String _formatNumberDisplay(num? value) {
  if (value == null) return '0';
  final f = NumberFormat('#,###', 'id_ID');
  return f.format(value);
}

double _toNumDecimal(String val) {
  final normalized = val
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^0-9.]'), '');
  if (normalized.isEmpty) return 0.0;
  final firstDot = normalized.indexOf('.');
  final safe = firstDot == -1
      ? normalized
      : normalized.substring(0, firstDot + 1) +
            normalized.substring(firstDot + 1).replaceAll('.', '');
  return double.tryParse(safe) ?? 0.0;
}

int _toNumCurrency(String val) {
  final cleaned = val.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(cleaned) ?? 0;
}

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

  // Wizard Step: 1 = Spesifikasi, 2 = Kalkulasi, 3 = Review & Pengajuan
  int _currentStep = 1;

  bool get _isEditMode => widget.initialDetail != null;

  // Divisi: '1'=SPANDUK, '5'=MMT, '4'=GARMEN
  String _selectedDivisi = '1';

  // Customer & Sales
  final _customerNamaController = TextEditingController();
  String _selectedCustomerKode = '';
  List<Map<String, dynamic>> _customerSoHistory = [];
  bool _isSoHistoryExpanded = false;
  String _soSearchKeyword = '';

  // Data Umum Pekerjaan
  final _barangController = TextEditingController();
  final _qtyController = TextEditingController();
  DateTime _rencanaOrderDate = DateTime.now();
  final _keteranganController = TextEditingController();

  // Pra-Order (Opsional)
  String _praOrderNomor = '';
  Map<String, dynamic>? _selectedPraOrderDetail;

  // SPANDUK (Divisi 1)
  String _spandukMetode = 'MANUAL'; // 'MANUAL' | 'MACHINE'
  double _spandukLebar = 90.0; // cm
  String _spandukJenisKain = 'POLYESTER 50/36';
  final _panjangController = TextEditingController(); // mtr
  final _lebarController = TextEditingController(
    text: '90',
  ); // cm untuk spanduk, mtr untuk MMT
  final List<int> _spandukFinishingIds = [];
  Map<String, dynamic>? _spandukResult;
  bool _spandukLoading = false;
  String _spandukCalculatedParams = '';

  // MMT (Divisi 5)
  String _mmtKategori = 'VYNIL'; // 'VYNIL' | 'HI-RES' | 'STICKER'
  String _mmtBahanKode = '260';
  final String _mmtToppingKode = '';
  final _mmtToppingQtyController = TextEditingController(text: '1');
  bool _mmtIsNetto = false;
  final _mmtAlasanNettoController = TextEditingController();
  bool _mmtSelongsongVert = false;
  bool _mmtSelongsongHoriz = false;
  Map<String, dynamic>? _mmtResult;
  bool _mmtLoading = false;
  String _mmtCalculatedParams = '';

  // GARMEN (Divisi 4)
  String _garmenKodeModel = 'KH-0001'; // 'KH-0001' | 'KH-0002'
  String _garmenJenisKain = 'PE SINGLE 24';

  String _garmenWarna = 'muda'; // 'muda' | 'sedang' | 'tua' | 'khusus'
  String _garmenWorkshop = 'MEDIUM'; // 'MEDIUM' | 'PREMIUM'
  String _garmenKategoriKain = 'pe';
  final _ukuranController = TextEditingController();
  final _gramasiController = TextEditingController();
  final _finishingController = TextEditingController();
  String _mhSublim = '';

  List<Map<String, dynamic>> _garmenKainList = [];
  bool _garmenLoadingKain = false;
  List<Map<String, dynamic>> _garmenTambahanMaster = [];
  List<Map<String, dynamic>> _garmenCetakMaster = [];
  final List<Map<String, dynamic>> _garmenSelectedTambahan = [];
  final List<Map<String, dynamic>> _garmenSelectedCetak = [];
  Map<String, dynamic>? _garmenCalcResult;
  bool _garmenLoadingCalc = false;
  String _garmenCalculatedParams = '';

  // Accordion Tabel Strata Referensi
  bool _showSpandukStrataTabel = false;
  bool _showMmtStrataTabel = false;
  bool _showGarmenStrataTabel = false;

  // Kalkulator DTF / Bordir Garmen
  final _dtfBordirPanjangController = TextEditingController();
  final _dtfBordirLebarController = TextEditingController();
  final _dtfTarifCmController = TextEditingController();
  final _bordirTarifCmController = TextEditingController();

  // Helper gramasi dan sablon desc
  static String getGramasiByKain(String kainName) {
    final k = kainName.toUpperCase();
    final rangeMatch = RegExp(r'(\d{2,3}\s*-\s*\d{2,3})').firstMatch(k);
    if (rangeMatch != null) {
      return '${rangeMatch.group(1)!.replaceAll(RegExp(r'\s+'), '')} GR';
    }
    if (k.contains('30S') || k.contains('30 S')) return '140-150 GR';
    if (k.contains('24S') || k.contains('24 S')) return '175-185 GR';
    if (k.contains('20S') || k.contains('20 S')) return '190-200 GR';
    if (k.contains('LACOST') || k.contains('LACOSTE')) return '220-230 GR';
    if (k.contains('TC COM 28') || k.contains('TC 28')) return '150-160 GR';
    if (k.contains('DRYFIT') || k.contains('DRIFIT')) return '150-160 GR';
    if (k.contains('HYGIT') || k.contains('HYGET')) return '110-120 GR';
    if (k.contains('PE 20') || k.contains('PE 24')) return '170-180 GR';
    if (k.contains('PE 30')) return '130-140 GR';
    return '';
  }

  static String getSablonUkuranDesc(String ketStr) {
    final upper = ketStr.toUpperCase();
    if (RegExp(r'\bA3\b').hasMatch(upper)) return '29.7 × 42 cm';
    if (RegExp(r'\bA4\b').hasMatch(upper)) return '21 × 29.7 cm';
    if (RegExp(r'\bA5\b').hasMatch(upper)) return '14.8 × 21 cm';
    return '';
  }

  // --- SPANDUK MASTER OPTIONS GETTERS & HANDLERS (Identik React Native) ---
  List<String> get _availableSpandukMetode {
    final spandukList = _masterOptions?['spanduk'] as List<dynamic>?;
    if (spandukList != null && spandukList.isNotEmpty) {
      final list = spandukList
          .map((s) => s['metode']?.toString().trim().toUpperCase() ?? '')
          .where((m) => m.isNotEmpty)
          .toSet()
          .toList();
      if (list.isNotEmpty) return list;
    }
    return ['MANUAL', 'MACHINE'];
  }

  List<String> get _availableSpandukKain {
    final spandukList = _masterOptions?['spanduk'] as List<dynamic>?;
    if (spandukList != null && spandukList.isNotEmpty) {
      final filtered = spandukList
          .where(
            (s) =>
                (s['metode']?.toString().trim().toUpperCase() ?? '') ==
                _spandukMetode.toUpperCase(),
          )
          .map((s) => s['jenis_kain']?.toString().trim() ?? '')
          .where((k) => k.isNotEmpty)
          .toSet()
          .toList();
      if (filtered.isNotEmpty) return filtered;
    }
    if (_spandukMetode.toUpperCase() == 'MACHINE') {
      return ['POLYESTER 50/36', 'OPTIC 70/40'];
    }
    return ['POLYESTER 50/36', 'OPTIC 70/40', 'TC 60/44'];
  }

  List<double> get _availableSpandukLebar {
    final selectedKain = _spandukJenisKain.trim().toUpperCase();
    final spandukList = _masterOptions?['spanduk'] as List<dynamic>?;
    if (spandukList != null && spandukList.isNotEmpty) {
      final filtered = spandukList
          .where((s) {
            final m = s['metode']?.toString().trim().toUpperCase() ?? '';
            final k = s['jenis_kain']?.toString().trim().toUpperCase() ?? '';
            return m == _spandukMetode.toUpperCase() && k == selectedKain;
          })
          .map((s) {
            final leb = s['lebar'];
            if (leb is num) return leb.toDouble();
            return double.tryParse(leb?.toString() ?? '') ?? 0.0;
          })
          .where((l) => l > 0)
          .toSet()
          .toList();
      filtered.sort();
      if (filtered.isNotEmpty) return filtered;
    }
    return [90.0, 115.0];
  }

  void _handleSelectSpandukMetode(String metode) {
    setState(() {
      _spandukMetode = metode;
      final availableKain = _availableSpandukKain;
      if (!availableKain.any(
        (k) => k.toUpperCase() == _spandukJenisKain.toUpperCase(),
      )) {
        if (availableKain.isNotEmpty) {
          _spandukJenisKain = availableKain.first;
        }
      }
      final availableLebar = _availableSpandukLebar;
      if (!availableLebar.contains(_spandukLebar)) {
        if (availableLebar.isNotEmpty) {
          _spandukLebar = availableLebar.first;
          _lebarController.text = _spandukLebar.toInt().toString();
        }
      }
    });
  }

  void _handleSelectSpandukKain(String kain) {
    setState(() {
      _spandukJenisKain = kain;
      final availableLebar = _availableSpandukLebar;
      if (!availableLebar.contains(_spandukLebar)) {
        if (availableLebar.isNotEmpty) {
          _spandukLebar = availableLebar.first;
          _lebarController.text = _spandukLebar.toInt().toString();
        }
      }
    });
  }

  // Master Lookup Options dari Server
  Map<String, dynamic>? _masterOptions;

  // Pengiriman & Ongkos Kirim
  String _alokasiOngkir = 'Tanpa Ongkir';

  final _namaDaerahKirimController = TextEditingController();
  bool _isCustomOngkir = false;
  final _customOngkirValController = TextEditingController();

  // PPN 11% & Keterangan Kalkulasi
  bool _includePpn = true;
  final _keteranganKalkulasiController = TextEditingController(text: 'INC PPN');

  // Harga Pengajuan & Penyesuaian Sales
  int _hargaKalkulasi = 0;
  final _hargaMintaController = TextEditingController();
  final _alasanPengajuanController = TextEditingController();

  // Foto Lampiran
  Uint8List? _imageBytes;
  String? _imageName;
  int? _imageSizeBytes;
  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initFromInitialData();
    _qtyController.addListener(_onDimensionOrQtyChanged);
    _panjangController.addListener(_onDimensionOrQtyChanged);
    _lebarController.addListener(_onDimensionOrQtyChanged);
    _customOngkirValController.addListener(_onDimensionOrQtyChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMasterOptions();
    });
  }

  void _onDimensionOrQtyChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initFromInitialData() {
    final d = widget.initialDetail;
    if (d == null) return;

    _selectedDivisi = d.divisi.isNotEmpty ? d.divisi : '1';
    _customerNamaController.text = d.cusNama;
    _selectedCustomerKode = d.cusKode;
    _barangController.text = d.nama;
    if (d.jmlOrder > 0) _qtyController.text = d.jmlOrder.toInt().toString();

    if (d.tanggal.isNotEmpty) {
      try {
        _rencanaOrderDate = DateTime.parse(d.tanggal);
      } catch (_) {}
    }

    if (d.panjang > 0) _panjangController.text = d.panjang.toString();
    if (d.lebar > 0) {
      if (_selectedDivisi == '1') {
        _spandukLebar = d.lebar > 10 ? d.lebar : d.lebar * 100;
        _lebarController.text = _spandukLebar.toInt().toString();
      } else {
        _lebarController.text = d.lebar.toString();
      }
    }

    if (d.kain.isNotEmpty) {
      if (_selectedDivisi == '1') {
        _spandukJenisKain = d.kain;
      } else if (_selectedDivisi == '4') {
        _garmenJenisKain = d.kain;
      }
    }

    _keteranganController.text = d.keterangan;

    // Deteksi ongkir dari initial
    if (d.ongkir > 0) {
      _alokasiOngkir = 'Custom';
      _isCustomOngkir = true;
      _customOngkirValController.text = d.ongkir.toInt().toString();
    }

    // Deteksi PPN & Keterangan Kalkulasi
    final rawKet = d.ketKalkulasi;
    if (rawKet.isNotEmpty) {
      _keteranganKalkulasiController.text = rawKet;
      _includePpn = rawKet.toUpperCase().contains('INC PPN');
    }

    // Ekstrak Alasan Pengajuan jika ada: [ALASAN: ...]
    final matchAlasan = RegExp(
      r'\[ALASAN:\s*([^\]]+)\]',
      caseSensitive: false,
    ).firstMatch(rawKet);
    if (matchAlasan != null && matchAlasan.groupCount >= 1) {
      _alasanPengajuanController.text = matchAlasan.group(1)?.trim() ?? '';
    }

    // Ekstrak Netto jika ada
    final matchNetto = RegExp(
      r'\[NETTO:\s*([^\]]+)\]',
      caseSensitive: false,
    ).firstMatch(rawKet);
    if (matchNetto != null && matchNetto.groupCount >= 1) {
      _mmtIsNetto = true;
      _mmtAlasanNettoController.text = matchNetto.group(1)?.trim() ?? '';
    }

    // Deteksi Selongsong
    final upperKet = rawKet.toUpperCase();
    if (upperKet.contains('SELONGSONG (V & H)') ||
        (upperKet.contains('SELONGSONG') &&
            upperKet.contains('V') &&
            upperKet.contains('H'))) {
      _mmtSelongsongVert = true;
      _mmtSelongsongHoriz = true;
    } else if (upperKet.contains('SELONGSONG V') ||
        upperKet.contains('SELONGSONG VERTIKAL')) {
      _mmtSelongsongVert = true;
    } else if (upperKet.contains('SELONGSONG H') ||
        upperKet.contains('SELONGSONG HORIZONTAL')) {
      _mmtSelongsongHoriz = true;
    }

    if (d.ukuran.isNotEmpty) _ukuranController.text = d.ukuran;
    if (d.gramasi.isNotEmpty) _gramasiController.text = d.gramasi;
    if (d.finishing.isNotEmpty) _finishingController.text = d.finishing;
    if (d.sublim.isNotEmpty) _mhSublim = d.sublim;
    if (d.warna.isNotEmpty) _garmenWarna = d.warna.toLowerCase();
    if (d.proNomor.isNotEmpty) _praOrderNomor = d.proNomor;

    _hargaKalkulasi = (d.hargaKalkulasi > 0 ? d.hargaKalkulasi : d.kalRpSistem)
        .toInt();
    if (d.harga > 0) {
      _hargaMintaController.text = d.harga.toInt().toString();
    } else if (_hargaKalkulasi > 0) {
      _hargaMintaController.text = _hargaKalkulasi.toString();
    }

    if (d.cusKode.isNotEmpty) {
      _fetchCustomerHistory(d.cusKode);
    }
  }

  @override
  void dispose() {
    _qtyController.removeListener(_onDimensionOrQtyChanged);
    _panjangController.removeListener(_onDimensionOrQtyChanged);
    _lebarController.removeListener(_onDimensionOrQtyChanged);
    _customOngkirValController.removeListener(_onDimensionOrQtyChanged);
    _customerNamaController.dispose();
    _barangController.dispose();
    _qtyController.dispose();
    _keteranganController.dispose();
    _panjangController.dispose();
    _lebarController.dispose();
    _ukuranController.dispose();
    _gramasiController.dispose();
    _finishingController.dispose();
    _mmtToppingQtyController.dispose();
    _mmtAlasanNettoController.dispose();
    _dtfBordirPanjangController.dispose();
    _dtfBordirLebarController.dispose();
    _dtfTarifCmController.dispose();
    _bordirTarifCmController.dispose();
    _namaDaerahKirimController.dispose();
    _customOngkirValController.dispose();
    _keteranganKalkulasiController.dispose();
    _hargaMintaController.dispose();
    _alasanPengajuanController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterOptions() async {
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final opts = await repo.getKalkulasiOptions();
      if (mounted && opts != null) {
        setState(() {
          _masterOptions = opts;

          if (_selectedDivisi == '1') {
            final availableKain = _availableSpandukKain;
            if (!availableKain.any(
              (k) => k.toUpperCase() == _spandukJenisKain.toUpperCase(),
            )) {
              if (availableKain.isNotEmpty) {
                _spandukJenisKain = availableKain.first;
              }
            }
            final availableLebar = _availableSpandukLebar;
            if (!availableLebar.contains(_spandukLebar)) {
              if (availableLebar.isNotEmpty) {
                _spandukLebar = availableLebar.first;
                _lebarController.text = _spandukLebar.toInt().toString();
              }
            }

            final initialFinishing = widget.initialDetail?.finishing;
            final tambahanOpts = opts['spandukTambahan'] as List<dynamic>?;
            if (initialFinishing != null &&
                initialFinishing.isNotEmpty &&
                tambahanOpts != null &&
                tambahanOpts.isNotEmpty) {
              final rawFinish = initialFinishing.toLowerCase();
              final matched = tambahanOpts
                  .where(
                    (it) =>
                        rawFinish.contains(it['nama'].toString().toLowerCase()),
                  )
                  .map(
                    (it) => it['id'] is int
                        ? it['id'] as int
                        : int.tryParse(it['id'].toString()) ?? 0,
                  )
                  .where((id) => id > 0)
                  .toList();
              if (matched.isNotEmpty) {
                _spandukFinishingIds.clear();
                _spandukFinishingIds.addAll(matched);
              }
            }
          }
        });
      }
      if (_selectedDivisi == '4') {
        _loadGarmenLookups();
      }
    } catch (_) {}
  }

  Future<void> _loadGarmenLookups() async {
    setState(() => _garmenLoadingKain = true);
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final kain = await repo.getJenisKainLookup(_garmenKodeModel);
      final tambahan = await repo.getTambahanLookup();
      final cetak = await repo.getCetakLookup();
      if (mounted) {
        setState(() {
          _garmenKainList = kain;
          _garmenTambahanMaster = tambahan;
          _garmenCetakMaster = cetak;
          _garmenLoadingKain = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _garmenLoadingKain = false);
    }
  }

  Future<void> _fetchCustomerHistory(String cusKode) async {
    if (cusKode.isEmpty) return;
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final list = await repo.getCustomerSoHistory(cusKode);
      if (mounted) {
        setState(() {
          _customerSoHistory = list;
        });
      }
    } catch (_) {}
  }

  // --- LOGIC ONGKIR & SYNC KETERANGAN ---
  OngkirCalcResult get _currentOngkirResult {
    final qty = _toNumCurrency(_qtyController.text);
    final panjang = _toNumDecimal(_panjangController.text);
    final lebar = _toNumDecimal(_lebarController.text);
    final customVal = _toNumCurrency(_customOngkirValController.text);

    return OngkirEngine.hitungOngkirOtomatis(
      alokasi: _alokasiOngkir,
      divisi: _selectedDivisi,
      panjang: panjang,
      lebar: lebar,
      qty: qty.toDouble(),
      sublim: _mhSublim.isNotEmpty ? _mhSublim : _garmenWorkshop,
      customNominal: customVal,
      isCustom: _isCustomOngkir || _alokasiOngkir.toLowerCase() == 'custom',
    );
  }

  void _syncOngkirKet(String daerah) {
    final trimmed = daerah.trim();
    final regex = RegExp(
      r'(?:[;,.\s]*\b(?:include\s+)?(?:ongkir\s+)?kirim\s+ke\s+[^,;\n]+|[;,.\s]*\b(?:include\s+)?ongkir\s+ke\s+[^,;\n]+)',
      caseSensitive: false,
    );
    String cleanKet = _keteranganController.text.replaceAll(regex, '').trim();
    cleanKet = cleanKet.replaceAll(RegExp(r'^[;,.\s]+|[;,.\s]+$'), '');

    if (trimmed.isEmpty || trimmed.toLowerCase() == 'tanpa ongkir') {
      _keteranganController.text = cleanKet;
    } else {
      final inc = 'Include kirim ke $trimmed';
      _keteranganController.text = cleanKet.isEmpty ? inc : '$cleanKet; $inc';
    }
  }

  void _syncSelongsongKet(bool vert, bool horiz) {
    final hasSelongsong = vert || horiz;
    String current = _keteranganController.text.trim();
    if (hasSelongsong) {
      if (!current.toLowerCase().contains('plus selongsong')) {
        _keteranganController.text = current.isEmpty
            ? 'Plus Selongsong'
            : '$current, Plus Selongsong';
      }
    } else {
      current = current.replaceAll(
        RegExp(r',?\s*Plus Selongsong', caseSensitive: false),
        '',
      );
      current = current.replaceAll(RegExp(r'^,\s*'), '').trim();
      _keteranganController.text = current;
    }
  }

  // --- LOGIC TOGGLE PPN REAKTIF ---
  void _handleTogglePpn() {
    setState(() {
      _includePpn = !_includePpn;
      final clean = _keteranganKalkulasiController.text
          .replaceAll(
            RegExp(r'^(INC|EXC)\s*PPN[;,]?\s*', caseSensitive: false),
            '',
          )
          .trim();
      _keteranganKalkulasiController.text = _includePpn
          ? (_cleanKet(clean).isEmpty ? 'INC PPN;' : 'INC PPN; $clean')
          : (_cleanKet(clean).isEmpty ? 'EXC PPN;' : 'EXC PPN; $clean');

      // Update harga kalkulasi reaktif
      final ongkirPcs = _currentOngkirResult.ongkirPerPcs;
      int rawDpp = 0;
      if (_selectedDivisi == '1' && _spandukResult != null) {
        final base =
            (_spandukResult!['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0;
        rawDpp = (base + ongkirPcs).round();
      } else if (_selectedDivisi == '5' && _mmtResult != null) {
        final base = (_mmtResult!['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0;
        rawDpp = (base + ongkirPcs).round();
      } else if (_selectedDivisi == '4' && _garmenCalcResult != null) {
        final base =
            (_garmenCalcResult!['hargaUpPerPcs'] ??
                    _garmenCalcResult!['hargaJualRevisi'] ??
                    _garmenCalcResult!['hargaJualPerPcs'] ??
                    _garmenCalcResult!['hargaJual'] ??
                    0)
                .toDouble();
        rawDpp = (base + ongkirPcs).round();
      } else if (_hargaKalkulasi > 0) {
        rawDpp = _includePpn
            ? _hargaKalkulasi
            : (_hargaKalkulasi / 1.11).round();
      }

      if (rawDpp > 0) {
        _hargaKalkulasi = _includePpn ? (rawDpp * 1.11).round() : rawDpp;
        if (_hargaMintaController.text.isEmpty ||
            _hargaMintaController.text == '0') {
          _hargaMintaController.text = _hargaKalkulasi.toString();
        }
      }
    });
  }

  String _cleanKet(String s) =>
      s.trim().replaceAll(RegExp(r'^[;,.\s]+|[;,.\s]+$'), '');

  // --- DETEKSI STALE CALCULATION ---
  bool get _isSpandukStale {
    if (_spandukResult == null || _spandukCalculatedParams.isEmpty) {
      return false;
    }
    final currentKey =
        '${_panjangController.text}|${_qtyController.text}|$_spandukMetode|$_spandukLebar|$_spandukJenisKain|${_spandukFinishingIds.join(',')}|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
    return _spandukCalculatedParams != currentKey;
  }

  bool get _isMmtStale {
    if (_mmtResult == null || _mmtCalculatedParams.isEmpty) {
      return false;
    }
    final currentKey =
        '${_panjangController.text}|${_lebarController.text}|${_qtyController.text}|$_mmtKategori|$_mmtBahanKode|$_mmtToppingKode|${_mmtToppingQtyController.text}|$_mmtIsNetto|$_mmtSelongsongVert|$_mmtSelongsongHoriz|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
    return _mmtCalculatedParams != currentKey;
  }

  bool get _isGarmenStale {
    if (_garmenCalcResult == null || _garmenCalculatedParams.isEmpty) {
      return false;
    }
    final tambahanKey = _garmenSelectedTambahan
        .map((t) => '${t['ket']}:${t['tarif']}')
        .join(';');
    final cetakKey = _garmenSelectedCetak
        .map((c) => '${c['jenis']}:${c['ket']}:${c['biaya']}')
        .join(';');
    final currentKey =
        '$_garmenKodeModel|$_garmenJenisKain|$_garmenWarna|${_qtyController.text}|$_garmenWorkshop|$tambahanKey|$cetakKey|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
    return _garmenCalculatedParams != currentKey;
  }

  // --- API EXECUTION KALKULASI ---
  Future<void> _executeHitungSpanduk() async {
    final numPanjang = _toNumDecimal(_panjangController.text);
    final numLebar = _spandukLebar;
    final numQty = _toNumCurrency(_qtyController.text);

    if (numPanjang <= 0 || numLebar <= 0 || numQty <= 0) {
      AppToast.error(
        context,
        'Panjang, Lebar, dan Jumlah Order wajib diisi dengan benar',
      );
      return;
    }

    final totalLuasM2 = numPanjang * (numLebar / 100.0) * numQty;
    final isManualAllowed = numQty >= 100 || totalLuasM2 >= 500;
    if (_spandukMetode == 'MANUAL' && !isManualAllowed) {
      AppToast.error(
        context,
        'Cetak Spanduk Manual minimal 100 pcs atau total luas 500 m² (saat ini: $numQty pcs / ${totalLuasM2.toStringAsFixed(1)} m²). Silakan gunakan metode Cetak Machine.',
      );
      return;
    }

    setState(() => _spandukLoading = true);
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final res = await repo.calculateSpanduk({
        'metode': _spandukMetode,
        'lebar': numLebar,
        'jenisKain': _spandukJenisKain,
        'panjang': numPanjang,
        'qty': numQty,
        'finishingIds': _spandukFinishingIds,
      });

      if (res != null && mounted) {
        final base = (res['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0;
        final hrgDenganOngkir = base + _currentOngkirResult.ongkirPerPcs;
        final finalHrg = _includePpn
            ? (hrgDenganOngkir * 1.11).round()
            : hrgDenganOngkir.round();

        setState(() {
          _spandukResult = res;
          _spandukCalculatedParams =
              '${_panjangController.text}|${_qtyController.text}|$_spandukMetode|$_spandukLebar|$_spandukJenisKain|${_spandukFinishingIds.join(',')}|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
          _hargaKalkulasi = finalHrg;
          if (_hargaMintaController.text.isEmpty ||
              _hargaMintaController.text == '0') {
            _hargaMintaController.text = finalHrg.toString();
          }

          String finishingSpec = '';
          final items = res['finishing']?['items'] as List<dynamic>?;
          if (items != null && items.isNotEmpty) {
            finishingSpec =
                ' + ${items.map((it) => it['nama'].toString()).join(' + ')}';
          }
          final spec =
              'Spanduk $_spandukMetode $_spandukJenisKain L${_spandukLebar.toInt()}cm$finishingSpec';
          _keteranganKalkulasiController.text = _includePpn
              ? 'INC PPN; $spec'
              : 'EXC PPN; $spec';
        });
        AppToast.success(context, 'Kalkulasi Spanduk berhasil');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Gagal menghitung kalkulasi spanduk: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _spandukLoading = false);
      }
    }
  }

  Future<void> _executeHitungMmt() async {
    final numPanjang = _toNumDecimal(_panjangController.text);
    final numLebar = _toNumDecimal(_lebarController.text);
    final numQty = _toNumCurrency(_qtyController.text);

    if (numPanjang <= 0 || numLebar <= 0 || numQty <= 0) {
      AppToast.error(
        context,
        'Panjang, Lebar, dan Jumlah Order wajib diisi dengan benar',
      );
      return;
    }

    setState(() => _mmtLoading = true);
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final res = await repo.calculateMmt({
        'kategori': _mmtKategori,
        'bahanKode': _mmtBahanKode,
        'panjang': numPanjang,
        'lebar': numLebar,
        'qty': numQty,
        'toppingKode': _mmtToppingKode,
        'toppingQty': _toNumCurrency(_mmtToppingQtyController.text),
        'isNetto': _mmtIsNetto,
        'selongsongVertical': _mmtSelongsongVert,
        'selongsongHorizontal': _mmtSelongsongHoriz,
      });

      if (res != null && mounted) {
        final base = (res['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0;
        final hrgDenganOngkir = base + _currentOngkirResult.ongkirPerPcs;
        final finalHrg = _includePpn
            ? (hrgDenganOngkir * 1.11).round()
            : hrgDenganOngkir.round();

        setState(() {
          _mmtResult = res;
          _mmtCalculatedParams =
              '${_panjangController.text}|${_lebarController.text}|${_qtyController.text}|$_mmtKategori|$_mmtBahanKode|$_mmtToppingKode|${_mmtToppingQtyController.text}|$_mmtIsNetto|$_mmtSelongsongVert|$_mmtSelongsongHoriz|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
          _hargaKalkulasi = finalHrg;
          if (_hargaMintaController.text.isEmpty ||
              _hargaMintaController.text == '0') {
            _hargaMintaController.text = finalHrg.toString();
          }

          final nettoSpec = _mmtIsNetto
              ? (_mmtAlasanNettoController.text.trim().isNotEmpty
                    ? ' (Netto - Alasan: ${_mmtAlasanNettoController.text.trim()})'
                    : ' (Netto)')
              : '';
          String selText = '';
          if (_mmtSelongsongVert && _mmtSelongsongHoriz) {
            selText = ' + Plus Selongsong (V & H)';
          } else if (_mmtSelongsongVert) {
            selText = ' + Plus Selongsong Vertikal';
          } else if (_mmtSelongsongHoriz) {
            selText = ' + Plus Selongsong Horizontal';
          }
          final topName = res['topping']?['nama'] ?? _mmtToppingKode;
          final topText = (topName != null && topName.toString().isNotEmpty)
              ? ' + Top: $topName'
              : '';
          final spec =
              'MMT $_mmtKategori $_mmtBahanKode$nettoSpec$topText$selText';

          _keteranganKalkulasiController.text = _includePpn
              ? 'INC PPN; $spec'
              : 'EXC PPN; $spec';
        });
        AppToast.success(context, 'Kalkulasi MMT berhasil');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Gagal menghitung kalkulasi MMT: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _mmtLoading = false);
      }
    }
  }

  Future<void> _executeHitungGarmen() async {
    final numQty = _toNumCurrency(_qtyController.text);
    if (numQty <= 0) {
      AppToast.error(context, 'Jumlah Order wajib diisi');
      return;
    }

    setState(() => _garmenLoadingCalc = true);
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final res = await repo.calculateGarmen({
        'kodeModel': _garmenKodeModel,
        'jenisKain': _garmenJenisKain,
        'warna': _garmenWarna,
        'qty': numQty,
        'tambahanList': _garmenSelectedTambahan,
        'cetakList': _garmenSelectedCetak,
        'workshop': _garmenWorkshop,
      });

      if (res != null && mounted) {
        final base =
            (res['hargaUpPerPcs'] ??
                    res['hargaJualRevisi'] ??
                    res['hargaJualPerPcs'] ??
                    res['hargaJual'] ??
                    0)
                .toDouble();
        final hrgDenganOngkir = base + _currentOngkirResult.ongkirPerPcs;
        final finalHrg = _includePpn
            ? (hrgDenganOngkir * 1.11).round()
            : hrgDenganOngkir.round();

        setState(() {
          _garmenCalcResult = res;
          final tambahanKey = _garmenSelectedTambahan
              .map((t) => '${t['ket']}:${t['tarif']}')
              .join(';');
          final cetakKey = _garmenSelectedCetak
              .map((c) => '${c['jenis']}:${c['ket']}:${c['biaya']}')
              .join(';');
          _garmenCalculatedParams =
              '$_garmenKodeModel|$_garmenJenisKain|$_garmenWarna|${_qtyController.text}|$_garmenWorkshop|$tambahanKey|$cetakKey|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
          _hargaKalkulasi = finalHrg;
          if (_hargaMintaController.text.isEmpty ||
              _hargaMintaController.text == '0') {
            _hargaMintaController.text = finalHrg.toString();
          }

          final spec =
              'Garmen $_garmenKodeModel $_garmenJenisKain ($_garmenWarna) $_garmenWorkshop';
          _keteranganKalkulasiController.text = _includePpn
              ? 'INC PPN; $spec'
              : 'EXC PPN; $spec';
        });
        AppToast.success(context, 'Kalkulasi Garmen berhasil');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Gagal menghitung kalkulasi Garmen: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _garmenLoadingCalc = false);
      }
    }
  }

  // --- PRA-ORDER INTEGRATION ---
  void _showPraOrderPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PraOrderPickerSheet(
        onSelect: (item) async {
          final no =
              item['nomor']?.toString() ?? item['pro_nomor']?.toString() ?? '';
          await _applySelectedPraOrder(no, item);
        },
      ),
    );
  }

  Future<void> _applySelectedPraOrder(
    String nomor,
    Map<String, dynamic> fallback,
  ) async {
    final repo = ref.read(permintaanHargaRepositoryProvider);
    Map<String, dynamic>? detail;
    try {
      detail = await repo.getPraOrderDetail(nomor);
    } catch (_) {}
    final data = detail ?? fallback;

    setState(() {
      _praOrderNomor = nomor;
      _selectedPraOrderDetail = data;

      final cusNama =
          data['cusNama']?.toString() ??
          data['cus_nama']?.toString() ??
          data['customer']?.toString() ??
          '';
      final cusKode =
          data['cusKode']?.toString() ??
          data['cus_kode']?.toString() ??
          data['customer_kode']?.toString() ??
          '';
      if (cusNama.isNotEmpty) _customerNamaController.text = cusNama;
      if (cusKode.isNotEmpty) _selectedCustomerKode = cusKode;

      final div = data['divisi']?.toString() ?? '';
      if (div.isNotEmpty) {
        _selectedDivisi = div;
        if (div == '4') _loadGarmenLookups();
      }

      final namaPekerjaan =
          data['namaPekerjaan']?.toString() ??
          data['nama_pekerjaan']?.toString() ??
          data['nama']?.toString() ??
          '';
      if (namaPekerjaan.isNotEmpty) _barangController.text = namaPekerjaan;

      final qty =
          (data['rencanaOrder'] as num?)?.toDouble() ??
          (data['qtyRencana'] as num?)?.toDouble() ??
          (data['rencana_order'] as num?)?.toDouble() ??
          (data['jml_order'] as num?)?.toDouble() ??
          0;
      if (qty > 0) _qtyController.text = qty.toInt().toString();

      final kain = data['kain']?.toString() ?? '';
      if (kain.isNotEmpty) {
        if (_selectedDivisi == '1') {
          _spandukJenisKain = kain;
        } else if (_selectedDivisi == '4') {
          _garmenJenisKain = kain;
        }
      }

      final finishing = data['finishing']?.toString() ?? '';
      if (finishing.isNotEmpty) _finishingController.text = finishing;

      final ukuran = data['ukuran']?.toString() ?? '';
      if (ukuran.isNotEmpty) _ukuranController.text = ukuran;

      final List<String> ketParts = [];
      final spesifikasi = data['spesifikasi']?.toString() ?? '';
      final keterangan = data['keterangan']?.toString() ?? '';
      final deadline =
          data['catatanDeadline']?.toString() ??
          data['catatan_deadline']?.toString() ??
          '';

      if (spesifikasi.isNotEmpty) ketParts.add('Spesifikasi: $spesifikasi');
      if (keterangan.isNotEmpty) ketParts.add('Ket: $keterangan');
      if (deadline.isNotEmpty) ketParts.add('Deadline: $deadline');

      if (ketParts.isNotEmpty) {
        final combined = ketParts.join(' | ');
        _keteranganController.text = _keteranganController.text.isEmpty
            ? combined
            : '${_keteranganController.text}\n$combined';
      }
    });

    if (_selectedCustomerKode.isNotEmpty) {
      _fetchCustomerHistory(_selectedCustomerKode);
    }
    if (mounted) {
      AppToast.success(context, 'Data Pra-Order $nomor berhasil diterapkan');
    }
  }

  void _clearPraOrder() {
    setState(() {
      _praOrderNomor = '';
      _selectedPraOrderDetail = null;
    });
    AppToast.info(context, 'Kaitan Pra Order dilepas');
  }

  // --- IMAGE PICKER ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = picked.name;
          _imageSizeBytes = bytes.length;
        });
        if (mounted) AppToast.success(context, 'Foto berhasil dipilih');
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'Gagal memilih foto');
    }
  }

  // --- STEP TRANSITION ---
  void _goToStep2() {
    if (_customerNamaController.text.trim().isEmpty) {
      AppToast.error(context, 'Customer wajib dipilih terlebih dahulu');
      return;
    }
    if (_barangController.text.trim().isEmpty) {
      AppToast.error(context, 'Nama pekerjaan / barang wajib diisi');
      return;
    }
    final qty = _toNumCurrency(_qtyController.text);
    if (qty <= 0) {
      AppToast.error(context, 'Jumlah order (pcs) harus lebih besar dari 0');
      return;
    }

    setState(() => _currentStep = 2);

    // Auto trigger kalkulasi pertama kali jika belum pernah dihitung
    if (_selectedDivisi == '1' && _spandukResult == null) {
      _executeHitungSpanduk();
    } else if (_selectedDivisi == '5' && _mmtResult == null) {
      _executeHitungMmt();
    } else if (_selectedDivisi == '4' && _garmenCalcResult == null) {
      _executeHitungGarmen();
    }
  }

  void _goToStep3() {
    if (_selectedDivisi == '5' &&
        _mmtIsNetto &&
        _mmtAlasanNettoController.text.trim().isEmpty) {
      AppToast.error(
        context,
        'Mohon isi alasan penggunaan Harga Netto terlebih dahulu',
      );
      return;
    }
    final finalHarga = _toNumCurrency(_hargaMintaController.text);
    if (_hargaKalkulasi > 0 &&
        finalHarga < _hargaKalkulasi &&
        _alasanPengajuanController.text.trim().isEmpty) {
      AppToast.warning(
        context,
        'Harga pengajuan di bawah rekomendasi sistem (Status: NEGO). Mohon isi alasan pengajuan harga.',
      );
      return;
    }
    setState(() => _currentStep = 3);
  }

  // --- SUBMIT FINAL ---
  Future<void> _showConfirmSubmitDialog({required bool isBypass}) async {
    final qty = _toNumCurrency(_qtyController.text);
    int finalHargaPengajuan = _toNumCurrency(_hargaMintaController.text);
    if (finalHargaPengajuan == 0 && _hargaKalkulasi > 0) {
      finalHargaPengajuan = _hargaKalkulasi;
    }

    final int unitCalc = isBypass ? 0 : _hargaKalkulasi;
    final bool isUnderCalc = unitCalc > 0 && finalHargaPengajuan < unitCalc;
    final int diff = unitCalc - finalHargaPengajuan;
    final int totalDiff = diff * qty;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                _isEditMode
                    ? 'Konfirmasi Perubahan'
                    : 'Konfirmasi Permintaan Harga',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Box Ringkasan Data
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildConfirmRow(
                      'Customer',
                      _customerNamaController.text.isNotEmpty
                          ? _customerNamaController.text
                          : '-',
                    ),
                    const SizedBox(height: 6),
                    _buildConfirmRow(
                      'Pekerjaan',
                      _barangController.text.isNotEmpty
                          ? _barangController.text
                          : '-',
                    ),
                    const SizedBox(height: 6),
                    _buildConfirmRow(
                      'Jumlah Order',
                      '${_formatNumberDisplay(qty)} Pcs',
                    ),
                    const SizedBox(height: 6),
                    _buildConfirmRow(
                      'Harga Permintaan',
                      'Rp ${_formatNumberDisplay(finalHargaPengajuan)} /pcs',
                      valueColor: const Color(0xFF059669),
                      isBold: true,
                    ),
                    if (_currentOngkirResult.totalOngkir > 0) ...[
                      const SizedBox(height: 6),
                      _buildConfirmRow(
                        'Ongkir',
                        'Rp ${_formatNumberDisplay(_currentOngkirResult.totalOngkir)}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Keterangan Status DONE / WAIT / MINTA / NEGO
              if (unitCalc <= 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'STATUS: BELUM',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF334155),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Permintaan harga dibuat tanpa kalkulasi, akan melalui MO terlebih dahulu.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (isUnderCalc)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'STATUS: NEGO (Memerlukan Persetujuan)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Harga permintaan harga lebih rendah Rp ${_formatNumberDisplay(diff)}/pcs ( - Rp ${_formatNumberDisplay(totalDiff)} ) dari kalkulasi harga.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'STATUS: DONE (Otomatis Disetujui)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF15803D),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Harga permintaan memenuhi atau di atas standar kalkulasi sistem.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Konfirmasi',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await _executeSubmit(isDirectBypass: isBypass);
    }
  }

  Widget _buildConfirmRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Future<void> _executeSubmit({required bool isDirectBypass}) async {
    setState(() => _isSubmitting = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(permintaanHargaRepositoryProvider);
    final ymdFormat = DateFormat('yyyy-MM-dd');

    final qty = _toNumCurrency(_qtyController.text);
    int finalHargaPengajuan = _toNumCurrency(_hargaMintaController.text);
    if (finalHargaPengajuan == 0 && _hargaKalkulasi > 0) {
      finalHargaPengajuan = _hargaKalkulasi;
    }

    final int finalHargaKalkulasi = isDirectBypass ? 0 : _hargaKalkulasi;

    // Susun String ket_kalkulasi sesuai spesifikasi React Native
    String finalKetKalkulasi = _keteranganKalkulasiController.text.trim();
    if (_selectedDivisi == '5' &&
        _mmtIsNetto &&
        _mmtAlasanNettoController.text.trim().isNotEmpty) {
      final alasanNetto = _mmtAlasanNettoController.text.trim();
      if (!finalKetKalkulasi.contains(alasanNetto)) {
        if (finalKetKalkulasi.contains('(Netto)')) {
          finalKetKalkulasi = finalKetKalkulasi.replaceAll(
            '(Netto)',
            '(Netto - Alasan: $alasanNetto)',
          );
        } else {
          finalKetKalkulasi = '$finalKetKalkulasi [Alasan Netto: $alasanNetto]';
        }
      }
    }

    String cleanKet = finalKetKalkulasi
        .replaceAll(
          RegExp(r'^(INC|EXC)\s*PPN[;,]?\s*', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'^\[ALASAN:[^\]]+\]\s*;?\s*', caseSensitive: false),
          '',
        )
        .trim();

    final List<String> ketParts = [];
    ketParts.add(_includePpn ? 'INC PPN' : 'EXC PPN');
    if (_alasanPengajuanController.text.trim().isNotEmpty) {
      ketParts.add('[ALASAN: ${_alasanPengajuanController.text.trim()}]');
    }
    if (cleanKet.isNotEmpty) {
      ketParts.add(cleanKet);
    }
    finalKetKalkulasi = ketParts.join('; ');

    // Nama Kain Submit
    String finalSubmitKain = _selectedDivisi == '1'
        ? _spandukJenisKain
        : (_selectedDivisi == '5'
              ? '$_mmtKategori $_mmtBahanKode'
              : _garmenJenisKain);

    final payload = <String, dynamic>{
      'mh_divisi': _selectedDivisi,
      'mh_cus_kode': _selectedCustomerKode,
      'mh_cus_nama': _customerNamaController.text.trim(),
      'mh_sal_kode': user?.salesKode ?? user?.kode ?? '',
      'mh_nama': _barangController.text.trim(),
      'mh_jmlorder': qty,
      'mh_harga': finalHargaPengajuan,
      'mh_ongkir': _currentOngkirResult.totalOngkir,
      'kald_rpkirim': _currentOngkirResult.ongkirPerPcs,
      'mh_harga_kalkulasi': finalHargaKalkulasi,
      'mh_ket_kalkulasi': isDirectBypass ? '' : finalKetKalkulasi,
      'mh_budget': 0,
      'mh_dateorder': ymdFormat.format(_rencanaOrderDate),
      'mh_kain': finalSubmitKain,
      'mh_panjang': _toNumDecimal(_panjangController.text),
      'mh_lebar': _selectedDivisi == '1'
          ? _spandukLebar
          : _toNumDecimal(_lebarController.text),
      'mh_ukuran': _ukuranController.text.trim(),
      'mh_gramasi': _gramasiController.text.trim(),
      'mh_finishing': _finishingController.text.trim(),
      'mh_sublim': _mhSublim,
      'mh_warna': _selectedDivisi == '4' ? _garmenWarna.toUpperCase() : '',
      'mh_ket': _keteranganController.text.trim(),
      if (_praOrderNomor.isNotEmpty) 'mh_pro_nomor': _praOrderNomor,
      if (_selectedDivisi == '4') ...{
        'kal_kh_kode': _garmenKodeModel,
        'kal_rpallowance':
            _garmenCalcResult?['komponenBiaya']?['allowanceRp'] ?? 0,
        'kal_allowance':
            _garmenCalcResult?['komponenBiaya']?['allowancePersen'] ?? 0,
        'kal_rplaba': _garmenCalcResult?['strataAktif']?['marginRp'] ?? 0,
        'kal_laba': _garmenCalcResult?['strataAktif']?['persen'] ?? 0,
        'kal_ketbeli': _garmenCalcResult?['babaran']?['body'] != null
            ? '$_garmenJenisKain ${_garmenCalcResult!['babaran']['body']}/kg'
            : _garmenJenisKain,
        'garmen_model': _garmenKodeModel,
        'garmen_kain': _garmenJenisKain,
        'garmen_warna': _garmenWarna,
        'garmen_tambahan': _garmenSelectedTambahan,
        'garmen_cetak': _garmenSelectedCetak,
        'mh_workshop': _garmenWorkshop == 'PREMIUM' ? 'P04' : 'P01',
        'garmen_workshop': _garmenWorkshop == 'PREMIUM' ? 'P04' : 'P01',
      },
    };

    bool isSuccess = false;
    String targetNomor = widget.initialDetail?.nomor ?? '';

    if (_isEditMode) {
      isSuccess = await repo.updatePermintaanHarga(targetNomor, payload);
    } else {
      final res = await repo.createPermintaanHarga(payload);
      if (res != null) {
        isSuccess = true;
        targetNomor =
            res['nomor']?.toString() ?? res['mh_nomor']?.toString() ?? '';
      }
    }

    if (isSuccess && _imageBytes != null && targetNomor.isNotEmpty) {
      try {
        await repo.uploadImage(
          targetNomor,
          null,
          slot: 1,
          fileBytes: _imageBytes,
          fileName: _imageName,
        );
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (isSuccess) {
        final isDone =
            !isDirectBypass &&
            finalHargaKalkulasi > 0 &&
            finalHargaPengajuan >= finalHargaKalkulasi;
        final isNego =
            !isDirectBypass &&
            finalHargaKalkulasi > 0 &&
            finalHargaPengajuan < finalHargaKalkulasi;

        final successMessage = _isEditMode
            ? 'Permintaan harga berhasil diperbarui'
            : (isDirectBypass || finalHargaKalkulasi <= 0
                  ? 'Permintaan harga berhasil diajukan (Status: BELUM)'
                  : (isDone
                        ? 'Permintaan harga berhasil diajukan (Status: DONE - Disetujui Otomatis)'
                        : (isNego
                              ? 'Permintaan harga berhasil diajukan (Status: NEGO - Menunggu Persetujuan)'
                              : 'Permintaan harga berhasil disimpan')));

        AppToast.success(context, successMessage);
        context.pop(true);
      } else {
        AppToast.error(
          context,
          'Gagal menyimpan permintaan harga. Silakan periksa koneksi Anda.',
        );
      }
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              _isEditMode ? 'Edit Permintaan Harga' : 'Buat Permintaan Harga',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Text(
              _isEditMode
                  ? 'No. MH: ${widget.initialDetail?.nomor}'
                  : 'Nomor dibuat otomatis oleh sistem',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 18,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Stepper Progress Bar
            _buildStepperBar(),

            // Wizard Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_currentStep == 1)
                        _buildStep1Spesifikasi()
                      else if (_currentStep == 2)
                        _buildStep2Kalkulasi()
                      else
                        _buildStep3Review(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky Footer Action Navigation Bar (Hanya untuk Langkah 1 & 2)
            if (_currentStep != 3) _buildStickyFooter(),
          ],
        ),
      ),
    );
  }

  // --- STEPPER BAR WIDGET ---
  Widget _buildStepperBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildStepItem(
            1,
            'Spesifikasi',
            _currentStep == 1,
            _currentStep > 1,
            () => setState(() => _currentStep = 1),
          ),
          _buildStepLine(_currentStep >= 2),
          _buildStepItem(
            2,
            'Kalkulasi Harga',
            _currentStep == 2,
            _currentStep > 2,
            _goToStep2,
          ),
          _buildStepLine(_currentStep >= 3),
          _buildStepItem(3, 'Review', _currentStep == 3, false, () {
            if (_currentStep >= 2) _goToStep3();
          }),
        ],
      ),
    );
  }

  Widget _buildStepItem(
    int step,
    String label,
    bool isActive,
    bool isPassed,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPassed
                    ? const Color(0xFF10B981)
                    : (isActive
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFF1F5F9)),
                border: Border.all(
                  color: isActive || isPassed
                      ? Colors.transparent
                      : const Color(0xFFCBD5E1),
                ),
              ),
              alignment: Alignment.center,
              child: isPassed
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                color: isActive
                    ? const Color(0xFF4F46E5)
                    : (isPassed
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLine(bool isPassed) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: isPassed ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
      ),
    );
  }

  // --- STICKY FOOTER NAVIGATION BAR (LANGKAH 1 & 2) ---
  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: _currentStep == 1
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(text: 'Kalkulasi Harga ➔', onPressed: _goToStep2),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showConfirmSubmitDialog(isBypass: true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: const Text(
                      'Buat Permintaan Harga (Tanpa Kalkulasi)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () => setState(() => _currentStep = 1),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: Color(0xFF475569),
                    ),
                    label: const Text(
                      'Ubah Spek',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: AppButton(
                    text: 'Lanjut ke Review ➔',
                    onPressed: _goToStep3,
                  ),
                ),
              ],
            ),
    );
  }

  // --- STEP 1: DETAIL & SPESIFIKASI WIDGET ---
  Widget _buildStep1Spesifikasi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Card Pra Order (Opsional)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.playlist_add_check_rounded,
                        size: 20,
                        color: Color(0xFF4F46E5),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Pra Order',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Opsional',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_praOrderNomor.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _praOrderNomor,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                                if (_selectedPraOrderDetail?['divisiNama'] !=
                                        null ||
                                    _selectedPraOrderDetail?['divisi'] !=
                                        null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      (_selectedPraOrderDetail?['divisiNama'] ??
                                              (_selectedPraOrderDetail?['divisi'] ==
                                                      '4'
                                                  ? 'GARMEN'
                                                  : (_selectedPraOrderDetail?['divisi'] ==
                                                            '5'
                                                        ? 'MMT'
                                                        : 'SPANDUK')))
                                          .toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF166534),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if ((_selectedPraOrderDetail?['namaPekerjaan'] ??
                                    _selectedPraOrderDetail?['nama_pekerjaan'] ??
                                    _barangController.text)
                                .toString()
                                .isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                (_selectedPraOrderDetail?['namaPekerjaan'] ??
                                        _selectedPraOrderDetail?['nama_pekerjaan'] ??
                                        _barangController.text)
                                    .toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (_customerNamaController.text.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_rounded,
                                    size: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _customerNamaController.text,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF334155),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              _qtyController.text.isNotEmpty
                                  ? 'Rencana Order: ${_formatNumberDisplay(_toNumCurrency(_qtyController.text))} pcs'
                                  : 'Rencana Order: -',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: _showPraOrderPickerModal,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.sync_rounded,
                                    size: 15,
                                    color: Color(0xFF4F46E5),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Ganti',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _clearPraOrder,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: _showPraOrderPickerModal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: Color(0xFF4F46E5),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Pilih Dari Dokumen Pra-Order...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Card 1: Informasi Pekerjaan
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditMode &&
                  (widget.initialDetail?.nomor.isNotEmpty ?? false)) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Text(
                    'No. MH: ${widget.initialDetail!.nomor}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ],

              const Text(
                '1. Informasi Pekerjaan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),

              // Customer Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: const TextSpan(
                      text: 'Nama Customer ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      children: [
                        TextSpan(
                          text: '*',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final refresh = await context.push<bool>(
                        '/permintaan-harga/tambah-customer',
                      );
                      if (refresh == true && _selectedCustomerKode.isNotEmpty) {
                        _fetchCustomerHistory(_selectedCustomerKode);
                      }
                    },
                    child: Row(
                      children: const [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 14,
                          color: Color(0xFF4F46E5),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '+ Customer Baru',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _customerNamaController.text.isNotEmpty
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _customerNamaController.text.isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _customerNamaController.text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_selectedCustomerKode.isNotEmpty)
                                    Text(
                                      'Kode: $_selectedCustomerKode',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              )
                            : const Text(
                                'Pilih customer...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                      ),
                      if (_customerNamaController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _customerNamaController.clear();
                              _selectedCustomerKode = '';
                              _customerSoHistory = [];
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Color(0xFF4F46E5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Nama Pekerjaan
              RichText(
                text: const TextSpan(
                  text: 'Nama Pekerjaan ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: '*',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _barangController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Banner HUT RI 2x1m',
                  hintStyle: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama pekerjaan wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),

              // Rencana Tanggal Order
              RichText(
                text: const TextSpan(
                  text: 'Rencana Tanggal Order ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: '*',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _rencanaOrderDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() => _rencanaOrderDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd-MM-yyyy').format(_rencanaOrderDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Icon(
                        Icons.event_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Divisi Selector
              RichText(
                text: const TextSpan(
                  text: 'Divisi ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: '*',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildDivisiChip('1', '1 - SPANDUK'),
                  const SizedBox(width: 8),
                  _buildDivisiChip('5', '5 - MMT'),
                  const SizedBox(width: 8),
                  _buildDivisiChip('4', '4 - GARMEN'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Card 2: Spesifikasi Produk & Dimensi
        if (_selectedDivisi == '4')
          _buildCardSpesifikasiGarmen()
        else if (_selectedDivisi == '1')
          _buildCardSpesifikasiSpanduk()
        else
          _buildCardSpesifikasiMmt(),
      ],
    );
  }

  // --- CARD 2: GARMEN ---
  Widget _buildCardSpesifikasiGarmen() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Spesifikasi Garmen',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Model (1 Warna / 2 Warna)
          const Text(
            'Model *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildSelectablePill(
                  '1 Warna (KH-0001)',
                  _garmenKodeModel == 'KH-0001',
                  () => setState(() => _garmenKodeModel = 'KH-0001'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSelectablePill(
                  '2 Warna (KH-0002)',
                  _garmenKodeModel == 'KH-0002',
                  () => setState(() => _garmenKodeModel = 'KH-0002'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Jenis Kain Garmen
          const Text(
            'Jenis Kain *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _showGarmenKainPickerModal,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _garmenJenisKain.isNotEmpty
                        ? _garmenJenisKain
                        : 'Pilih jenis kain garmen...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _garmenJenisKain.isNotEmpty
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _garmenJenisKain.isNotEmpty
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
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
          const SizedBox(height: 12),

          // Kategori Warna
          const Text(
            'Kategori Warna *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildSelectablePill(
                  'Muda',
                  _garmenWarna == 'muda',
                  () => setState(() => _garmenWarna = 'muda'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSelectablePill(
                  'Sedang',
                  _garmenWarna == 'sedang',
                  () => setState(() => _garmenWarna = 'sedang'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSelectablePill(
                  'Tua',
                  _garmenWarna == 'tua',
                  () => setState(() => _garmenWarna = 'tua'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSelectablePill(
                  'Khusus',
                  _garmenWarna == 'khusus',
                  () => setState(() => _garmenWarna = 'khusus'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Workshop Garmen
          const Text(
            'Workshop Garmen *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildSelectablePill(
                  'Medium (P01)',
                  _garmenWorkshop == 'MEDIUM',
                  () => setState(() => _garmenWorkshop = 'MEDIUM'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSelectablePill(
                  'Premium (P04)',
                  _garmenWorkshop == 'PREMIUM',
                  () => setState(() => _garmenWorkshop = 'PREMIUM'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Jumlah Order
          const Text(
            'Jumlah Order (Pcs) *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Icon(Icons.format_list_numbered_rounded, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Rincian Ukuran / Size (Opsional)
          Row(
            children: const [
              Text(
                'Rincian Ukuran / Size',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 4),
              Text(
                '(Opsional)',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _ukuranController,
            decoration: const InputDecoration(
              hintText: 'Misal: XL= 3, L = 2, M = 5',
              prefixIcon: Icon(Icons.straighten_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Gramasi Kain (Otomatis / Opsional)
          Row(
            children: const [
              Text(
                'Gramasi',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 4),
              Text(
                '(Otomatis / Opsional)',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _gramasiController,
            decoration: const InputDecoration(
              hintText: 'Misal: 140-150 GR',
              prefixIcon: Icon(Icons.line_weight_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Finishing Garmen (Opsional)
          Row(
            children: const [
              Text(
                'Finishing',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 4),
              Text(
                '(Opsional)',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _finishingController,
            decoration: const InputDecoration(
              hintText: 'Misal: Lipat rapi, packing plastik',
              prefixIcon: Icon(Icons.checkroom_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Sublim Garmen (Opsional)
          Row(
            children: const [
              Text(
                'Sublim',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 4),
              Text(
                '(Opsional)',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(
              () => _mhSublim = _mhSublim == 'PREMIUM' ? '' : 'PREMIUM',
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _mhSublim == 'PREMIUM'
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 22,
                    color: _mhSublim == 'PREMIUM'
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _mhSublim == 'PREMIUM'
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _mhSublim == 'PREMIUM'
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tambahan Biaya Aksesoris
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambahan Biaya Aksesoris',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: _showGarmenTambahanPickerModal,
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  '+ Tambah Aksesoris',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (_garmenSelectedTambahan.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: _garmenSelectedTambahan.map((t) {
                return Chip(
                  backgroundColor: const Color(0xFFF1F5F9),
                  label: Text(
                    '${t['ket']} (+Rp ${_formatNumberDisplay(t['tarif'])})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    setState(() {
                      _garmenSelectedTambahan.remove(t);
                    });
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),

          // Biaya Cetak Garmen
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Biaya Cetak (Sablon/DTF/Bordir)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: _showGarmenCetakPickerModal,
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  '+ Tambah Cetak',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (_garmenSelectedCetak.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: _garmenSelectedCetak.map((c) {
                return Chip(
                  backgroundColor: const Color(0xFFEFF6FF),
                  label: Text(
                    '${c['jenis']}: ${c['ket']} (Rp ${_formatNumberDisplay(c['biaya'])})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    setState(() {
                      _garmenSelectedCetak.remove(c);
                    });
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),

          // Pengiriman & Keterangan
          _buildPengirimanDanKeteranganSection(),
        ],
      ),
    );
  }

  // --- CARD 2: SPANDUK ---
  Widget _buildCardSpesifikasiSpanduk() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Dimensi & Kuantitas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Metode Cetak
          RichText(
            text: const TextSpan(
              text: 'Metode Cetak ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: _availableSpandukMetode.map((met) {
              final isSel = _spandukMetode.toUpperCase() == met.toUpperCase();
              final label = met.toUpperCase() == 'MANUAL'
                  ? 'Manual'
                  : 'Machine';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildSelectablePill(
                    label,
                    isSel,
                    () => _handleSelectSpandukMetode(met),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Pilihan Jenis Kain Spanduk Dinamis berdasarkan Metode Cetak (Divisi 1)
          RichText(
            text: const TextSpan(
              text: 'Jenis Kain Spanduk ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableSpandukKain.map((kain) {
              final isSel =
                  _spandukJenisKain.toUpperCase() == kain.toUpperCase();
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _handleSelectSpandukKain(kain),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFCBD5E1),
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    kain,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Pilihan Lebar Dinamis yang Difilter Berdasarkan Metode & Jenis Kain (Divisi 1)
          RichText(
            text: TextSpan(
              text:
                  'Pilihan Lebar Spanduk (${_spandukJenisKain.toUpperCase()}) ',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableSpandukLebar.map((leb) {
              final isSel = _spandukLebar == leb;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _spandukLebar = leb;
                    _lebarController.text = leb.toInt().toString();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFCBD5E1),
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    '${leb.toInt()} cm',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Dimensi Panjang (Mtr)
          TextFormField(
            controller: _panjangController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalInputFormatter],
            decoration: const InputDecoration(
              labelText: 'Panjang (Mtr) *',
              hintText: '0',
              prefixIcon: Icon(Icons.straighten_rounded, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Jumlah Order (Pcs) *',
              hintText: '0',
              prefixIcon: Icon(Icons.format_list_numbered_rounded, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Finishing Tambahan Spanduk
          const Text(
            'Finishing Tambahan Spanduk:',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _buildSpandukFinishingChecklist(),
          const SizedBox(height: 12),

          // Pengiriman & Keterangan
          _buildPengirimanDanKeteranganSection(),
        ],
      ),
    );
  }

  // --- CARD 2: MMT ---
  Widget _buildCardSpesifikasiMmt() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Dimensi & Kuantitas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Kategori MMT
          const Text(
            'Kategori MMT *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildSelectablePill(
                  'VYNIL',
                  _mmtKategori == 'VYNIL',
                  () => setState(() => _mmtKategori = 'VYNIL'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSelectablePill(
                  'HI-RES',
                  _mmtKategori == 'HI-RES',
                  () => setState(() => _mmtKategori = 'HI-RES'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSelectablePill(
                  'STICKER',
                  _mmtKategori == 'STICKER',
                  () => setState(() => _mmtKategori = 'STICKER'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bahan MMT
          const Text(
            'Bahan MMT *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('mmt_bahan_${_mmtKategori}_$_mmtBahanKode'),
            initialValue: _mmtBahanKode,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: _currentMmtBahanOptions.map((b) {
              return DropdownMenuItem(
                value: b['kode'],
                child: Text(b['nama'] ?? ''),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _mmtBahanKode = v);
            },
          ),
          const SizedBox(height: 12),

          // Dimensi P x L & Qty
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _panjangController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalInputFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Panjang (Mtr) *',
                    hintText: '0',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _lebarController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalInputFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Lebar (Mtr) *',
                    hintText: '0',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Jumlah Order (Pcs) *',
              hintText: '0',
              prefixIcon: Icon(Icons.format_list_numbered_rounded, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Selongsong MMT
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    'Selongsong Vertikal',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _mmtSelongsongVert,
                  onChanged: (v) {
                    setState(() {
                      _mmtSelongsongVert = v ?? false;
                      _syncSelongsongKet(
                        _mmtSelongsongVert,
                        _mmtSelongsongHoriz,
                      );
                    });
                  },
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    'Selongsong Horisontal',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _mmtSelongsongHoriz,
                  onChanged: (v) {
                    setState(() {
                      _mmtSelongsongHoriz = v ?? false;
                      _syncSelongsongKet(
                        _mmtSelongsongVert,
                        _mmtSelongsongHoriz,
                      );
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Toggle Harga Netto MMT
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Gunakan Harga Netto MMT',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            value: _mmtIsNetto,
            onChanged: (v) => setState(() => _mmtIsNetto = v),
          ),
          if (_mmtIsNetto) ...[
            TextFormField(
              controller: _mmtAlasanNettoController,
              decoration: const InputDecoration(
                labelText: 'Alasan Penggunaan Harga Netto *',
                hintText: 'Wajib diisi jika menggunakan netto...',
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Pengiriman & Keterangan
          _buildPengirimanDanKeteranganSection(),
        ],
      ),
    );
  }

  // --- REUSABLE PENGIRIMAN & KETERANGAN SECTION ---
  Widget _buildPengirimanDanKeteranganSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pengiriman & Ongkir *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            InkWell(
              onTap: _showKetentuanOngkirModal,
              child: Row(
                children: const [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 14,
                    color: Color(0xFF4F46E5),
                  ),
                  SizedBox(width: 3),
                  Text(
                    'Ketentuan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Toggle Mode: Tanpa Ongkir vs Dengan Ongkir
        Row(
          children: [
            Expanded(
              child: _buildSelectablePill(
                'Tanpa Ongkir',
                _alokasiOngkir == 'Tanpa Ongkir',
                () {
                  setState(() => _alokasiOngkir = 'Tanpa Ongkir');
                  _syncOngkirKet('');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSelectablePill(
                'Dengan Ongkir',
                _alokasiOngkir != 'Tanpa Ongkir',
                () {
                  if (_alokasiOngkir == 'Tanpa Ongkir') {
                    setState(() => _alokasiOngkir = 'Jakarta');
                    _syncOngkirKet('Jakarta');
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_alokasiOngkir == 'Tanpa Ongkir')
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tanpa Ongkos Kirim',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Rp 0',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _namaDaerahKirimController,
                    decoration: const InputDecoration(
                      hintText: 'Ketik kota tujuan (misal: Malang, Jambi...)',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (v) => _syncOngkirKet(v),
                  ),
                ),
                if (_namaDaerahKirimController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _namaDaerahKirimController.clear();
                      _syncOngkirKet('');
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Ringkasan Estimasi Ongkir Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _currentOngkirResult.isFreeCharge
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimasi Berat Pesanan',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${_currentOngkirResult.totalBeratKg} kg',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_currentOngkirResult.beratDihitungKg >
                                _currentOngkirResult.totalBeratKg &&
                            _currentOngkirResult.totalBeratKg > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '(Min: ${_currentOngkirResult.beratDihitungKg.toStringAsFixed(0)} kg)',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentOngkirResult.isFreeCharge
                              ? 'Bebas Ongkir'
                              : 'Biaya Ongkir',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _currentOngkirResult.isFreeCharge
                                ? const Color(0xFF15803D)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _currentOngkirResult.isFreeCharge
                              ? 'Memenuhi syarat bebas ongkir'
                              : '+Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)} / pcs',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: _currentOngkirResult.isFreeCharge
                                ? const Color(0xFF166534)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Rp ${_formatNumberDisplay(_currentOngkirResult.totalOngkir)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _currentOngkirResult.isFreeCharge
                            ? const Color(0xFF15803D)
                            : const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            text: 'Keterangan ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _keteranganController,
          minLines: 4,
          maxLines: 7,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Color(0xFF0F172A),
          ),
          decoration: const InputDecoration(
            hintText: 'Tambahkan keterangan permintaan harga...',
            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 2: KALKULASI & REVIEW HARGA WIDGET ---
  Widget _buildStep2Kalkulasi() {
    final bool isStale = _selectedDivisi == '1'
        ? _isSpandukStale
        : (_selectedDivisi == '5' ? _isMmtStale : _isGarmenStale);

    final finalHarga = _toNumCurrency(_hargaMintaController.text);
    final diff = finalHarga - _hargaKalkulasi;
    final isNego = _hargaKalkulasi > 0 && finalHarga < _hargaKalkulasi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Box Ringkasan Spesifikasi Terinput (specSummaryBox)
        _buildSpecSummaryBox(),
        const SizedBox(height: 12),

        // 2. Banner Peringatan Perubahan Data (Stale)
        if (isStale) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Spesifikasi Diubah Pasca-Hitung',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      Text(
                        'Parameter spesifikasi telah berubah. Mohon lakukan hitung ulang kalkulasi.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 3. Tombol Hitung / Refresh Kalkulasi Sistem
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: Color(0xFF4F46E5)),
          ),
          onPressed: () {
            if (_selectedDivisi == '1') _executeHitungSpanduk();
            if (_selectedDivisi == '5') _executeHitungMmt();
            if (_selectedDivisi == '4') _executeHitungGarmen();
          },
          icon: (_spandukLoading || _mmtLoading || _garmenLoadingCalc)
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.calculate_rounded, color: Color(0xFF4F46E5)),
          label: const Text(
            'Hitung / Refresh Kalkulasi Sistem',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF4F46E5),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 4. Hasil Kalkulasi Rincian per Divisi
        if (_selectedDivisi == '1' && _spandukResult != null) ...[
          _buildSpandukKalkulasiResultCard(),
          const SizedBox(height: 10),
          _buildSpandukStrataAccordion(),
          const SizedBox(height: 14),
        ] else if (_selectedDivisi == '5' && _mmtResult != null) ...[
          _buildMmtKalkulasiResultCard(),
          const SizedBox(height: 10),
          _buildMmtStrataAccordion(),
          const SizedBox(height: 14),
        ] else if (_selectedDivisi == '4' && _garmenCalcResult != null) ...[
          _buildGarmenKalkulasiResultCard(),
          const SizedBox(height: 10),
          _buildGarmenStrataAccordion(),
          const SizedBox(height: 14),
        ] else ...[
          // Default Card Rekomendasi Sistem (Gradient) jika belum dihitung secara detail
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'HARGA REKOMENDASI SISTEM',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Rp ${_formatNumberDisplay(_hargaKalkulasi)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Termasuk Ongkir: Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)}/pcs • ${_includePpn ? "INC PPN (11%)" : "EXC PPN"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 5. Toggle PPN 11%
        AppCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _includePpn,
            activeThumbColor: const Color(0xFF4F46E5),
            title: const Text(
              'Sertakan PPN 11% (INC PPN)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              _includePpn
                  ? 'Harga sudah termasuk PPN 11%'
                  : 'Harga belum termasuk PPN (Non-PPN)',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            onChanged: (v) => _handleTogglePpn(),
          ),
        ),
        const SizedBox(height: 14),

        // 6. Keterangan Kalkulasi Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Keterangan Kalkulasi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _keteranganKalkulasiController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Keterangan kalkulasi otomatis...',
                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 7. Penyesuaian Harga Sales Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Penyesuaian Harga Sales /pcs',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _hargaMintaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Pengajuan Sales (Rp) *',
                  prefixIcon: Icon(Icons.price_change_outlined, size: 20),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Text(
                'Total Nilai Pengajuan: Rp ${_formatNumberDisplay((finalHarga > 0 ? finalHarga : _hargaKalkulasi) * _toNumCurrency(_qtyController.text))}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),

              // Status Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isNego
                      ? const Color(0xFFFAF5FF)
                      : (diff > 0
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF0FDF4)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isNego
                        ? const Color(0xFFE9D5FF)
                        : (diff > 0
                              ? const Color(0xFFBFDBFE)
                              : const Color(0xFFBBF7D0)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isNego
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: isNego
                          ? const Color(0xFF6B21A8)
                          : (diff > 0
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF15803D)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isNego
                            ? 'STATUS: NEGO (Memerlukan Persetujuan Manager)'
                            : (diff > 0
                                  ? 'Margin Tambahan: Lebih tinggi Rp ${_formatNumberDisplay(diff)}'
                                  : 'STATUS: DONE (Sesuai / Di Atas Rekomendasi)'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isNego
                              ? const Color(0xFF6B21A8)
                              : (diff > 0
                                    ? const Color(0xFF1D4ED8)
                                    : const Color(0xFF15803D)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (isNego) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _alasanPengajuanController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alasan Pengajuan Harga *',
                    hintText:
                        'Wajib diisi karena harga yang diajukan di bawah kalkulasi standar...',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --- RESULT BOX & ACCORDION STRATA HELPER WIDGETS ---

  // 1. Spanduk Result Box
  Widget _buildSpandukKalkulasiResultCard() {
    final res = _spandukResult!;
    final totalMeter = res['totalMeter'] ?? 0;
    final biayaCetak =
        (res['biayaCetakPerPcs'] ?? res['tarifPerMeter'] ?? 0) as num;
    final items = res['finishing']?['items'] as List<dynamic>? ?? [];
    final qty = _toNumCurrency(_qtyController.text);
    final dppPerPcs =
        ((res['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0) +
        _currentOngkirResult.ongkirPerPcs;
    final finalPerPcs = _includePpn
        ? (dppPerPcs * 1.11).round()
        : dppPerPcs.round();
    final ppnTotal = _includePpn ? ((dppPerPcs * 0.11).round() * qty) : 0;
    final totalOrderKeseluruhan = finalPerPcs * qty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildResultItemRow('Total Panjang Kain:', '$totalMeter Meter'),
          _buildResultItemRow(
            'Tarif Cetak Bahan:',
            'Rp ${_formatNumberDisplay(biayaCetak)} /Pcs',
            valueColor: const Color(0xFF0284C7),
          ),
          for (final fi in items)
            _buildResultItemRow(
              'Finishing (${fi['nama']}):',
              '+Rp ${_formatNumberDisplay(fi['biayaPerPcs'] ?? 0)} /Pcs',
              valueColor: const Color(0xFF0284C7),
            ),
          _buildResultItemRow(
            'Ongkir (${_currentOngkirResult.alokasi}):',
            _currentOngkirResult.isFreeCharge
                ? 'GRATIS'
                : '+Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)} /Pcs',
            valueColor: _currentOngkirResult.isFreeCharge
                ? const Color(0xFF15803D)
                : const Color(0xFF0284C7),
            isBold: true,
          ),
          const Divider(height: 14, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Kalkulasi:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Rp ${_formatNumberDisplay(finalPerPcs)} /Pcs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _includePpn
                      ? const Color(0xFF15803D)
                      : const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          if (_includePpn) ...[
            const SizedBox(height: 4),
            _buildResultItemRow(
              'Biaya PPN 11%:',
              '+Rp ${_formatNumberDisplay(ppnTotal)}',
              valueColor: const Color(0xFF047857),
              isBold: true,
            ),
          ],
          const SizedBox(height: 4),
          _buildResultItemRow(
            'Total Order Keseluruhan (${_formatNumberDisplay(qty)} pcs):',
            'Rp ${_formatNumberDisplay(totalOrderKeseluruhan)}',
            valueColor: const Color(0xFF0F172A),
            isBold: true,
          ),
        ],
      ),
    );
  }

  // Accordion Strata Spanduk
  Widget _buildSpandukStrataAccordion() {
    final list = _spandukResult?['tabelReferensi'] as List<dynamic>? ?? [];
    final activeId = _spandukResult?['strataAktif']?['id'];

    return Column(
      children: [
        InkWell(
          onTap: () => setState(
            () => _showSpandukStrataTabel = !_showSpandukStrataTabel,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.table_chart_rounded,
                      size: 16,
                      color: Color(0xFF4F46E5),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tabel Master Bahan Spanduk',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showSpandukStrataTabel
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_showSpandukStrataTabel && list.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Panjang',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Tarif/Mtr',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final s in list) ...[
                  Builder(
                    builder: (ctx) {
                      final qmin = s['qmin'] ?? 0;
                      final qmax = s['qmax'] ?? 999999;
                      final bool isActive =
                          activeId != null && s['id'] == activeId;
                      final String label = qmax >= 99999
                          ? '≥ $qmin M'
                          : '$qmin - $qmax M';
                      final tarif = s['up'] ?? s['harga'] ?? s['tarif'] ?? 0;

                      return Container(
                        color: isActive
                            ? const Color(0xFFE0F2FE)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Rp ${_formatNumberDisplay(tarif)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 2. MMT Result Box
  Widget _buildMmtKalkulasiResultCard() {
    final res = _mmtResult!;
    final luasPerPcs = res['luasPerPcs'] ?? 0;
    final totalLuas = res['totalLuas'] ?? 0;
    final tarifPerM2 = (res['tarifPerM2'] ?? 0) as num;
    final qty = _toNumCurrency(_qtyController.text);
    final topping = res['topping'];
    final selongsong = res['selongsong'];
    final dppPerPcs =
        ((res['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0) +
        _currentOngkirResult.ongkirPerPcs;
    final finalPerPcs = _includePpn
        ? (dppPerPcs * 1.11).round()
        : dppPerPcs.round();
    final ppnTotal = _includePpn ? ((dppPerPcs * 0.11).round() * qty) : 0;
    final totalOrderKeseluruhan = finalPerPcs * qty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildResultItemRow(
            'Luas (${_panjangController.text} m x ${_lebarController.text} m):',
            '$luasPerPcs m² / Pcs',
            isBold: true,
          ),
          _buildResultItemRow(
            'Total Luas ($qty pcs):',
            '$totalLuas m²',
            valueColor: const Color(0xFF0284C7),
            isBold: true,
          ),
          _buildResultItemRow(
            'Tarif per m²:',
            'Rp ${_formatNumberDisplay(tarifPerM2)} /m²',
            valueColor: const Color(0xFF0284C7),
          ),
          if (topping != null)
            _buildResultItemRow(
              'Biaya Topping:',
              '+Rp ${_formatNumberDisplay(topping['hargaSatuan'] ?? topping['totalHarga'] ?? 0)} /pcs',
              valueColor: const Color(0xFFD97706),
            ),
          if (selongsong != null && (selongsong['isVertical'] == true))
            _buildResultItemRow(
              'Selongsong Vertikal (0,2 x ${_panjangController.text}m):',
              '+Rp ${_formatNumberDisplay(selongsong['biayaVerticalPerPcs'] ?? 0)} /pcs',
              valueColor: const Color(0xFF0284C7),
            ),
          if (selongsong != null && (selongsong['isHorizontal'] == true))
            _buildResultItemRow(
              'Selongsong Horizontal (0,2 x ${_lebarController.text}m):',
              '+Rp ${_formatNumberDisplay(selongsong['biayaHorizontalPerPcs'] ?? 0)} /pcs',
              valueColor: const Color(0xFF0284C7),
            ),
          _buildResultItemRow(
            'Ongkir (${_currentOngkirResult.alokasi}):',
            _currentOngkirResult.isFreeCharge
                ? 'GRATIS'
                : '+Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)} /Pcs',
            valueColor: _currentOngkirResult.isFreeCharge
                ? const Color(0xFF15803D)
                : const Color(0xFF0284C7),
            isBold: true,
          ),
          const Divider(height: 14, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Kalkulasi:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Rp ${_formatNumberDisplay(finalPerPcs)} /Pcs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _includePpn
                      ? const Color(0xFF15803D)
                      : const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          if (_includePpn) ...[
            const SizedBox(height: 4),
            _buildResultItemRow(
              'Biaya PPN 11%:',
              '+Rp ${_formatNumberDisplay(ppnTotal)}',
              valueColor: const Color(0xFF047857),
              isBold: true,
            ),
          ],
          const SizedBox(height: 4),
          _buildResultItemRow(
            'Total Order Keseluruhan (${_formatNumberDisplay(qty)} pcs):',
            'Rp ${_formatNumberDisplay(totalOrderKeseluruhan)}',
            valueColor: const Color(0xFF0F172A),
            isBold: true,
          ),
        ],
      ),
    );
  }

  // Accordion Strata MMT
  Widget _buildMmtStrataAccordion() {
    final list = _mmtResult?['tabelReferensi'] as List<dynamic>? ?? [];
    final activeId = _mmtResult?['strataAktif']?['id'];

    return Column(
      children: [
        InkWell(
          onTap: () =>
              setState(() => _showMmtStrataTabel = !_showMmtStrataTabel),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.table_chart_rounded,
                      size: 16,
                      color: Color(0xFF4F46E5),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tabel Master Bahan MMT',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showMmtStrataTabel
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_showMmtStrataTabel && list.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Rentang Luas',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Tarif/m²',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final s in list) ...[
                  Builder(
                    builder: (ctx) {
                      final bool isNetto = s['is_netto'] == true;
                      final qmin = s['qmin'] ?? 0;
                      final qmax = s['qmax'] ?? 999999;
                      final bool isActive =
                          activeId != null && s['id'] == activeId;
                      final String label = isNetto
                          ? 'Harga Netto'
                          : (qmax >= 99999 ? '≥ $qmin m²' : '$qmin - $qmax m²');
                      final tarif = s['harga'] ?? s['tarif'] ?? s['up'] ?? 0;

                      return Container(
                        color: isActive
                            ? const Color(0xFFE0F2FE)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Rp ${_formatNumberDisplay(tarif)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 3. Garmen Result Box
  Widget _buildGarmenKalkulasiResultCard() {
    final res = _garmenCalcResult!;
    final qty = _toNumCurrency(_qtyController.text);
    final refList =
        (res['tabelReferensi'] ?? res['tanggaMargin'] ?? []) as List<dynamic>;
    final activeTier = refList.firstWhere(
      (t) =>
          (t['tier'] != null && t['tier'] == res['strataAktif']?['tier']) ||
          ((t['qmin'] ?? t['minOrder'] ?? 0) <= qty &&
              (t['qmax'] ?? t['maxOrder'] ?? 999999) >= qty),
      orElse: () => null,
    );
    final hargaBahanSatuan = activeTier != null
        ? (activeTier['up'] ??
              activeTier['jual'] ??
              activeTier['hargaJual'] ??
              0)
        : ((res['hpp'] ?? 0) + (res['strataAktif']?['marginRp'] ?? 0));

    final tambahanPerPcs =
        (res['tambahan']?['totalPerPcs'] ?? res['biayaTambahan'] ?? 0) as num;
    final cetakPerPcs =
        (res['cetak']?['totalPerPcs'] ?? res['biayaCetak'] ?? 0) as num;
    final rawHrg =
        (res['hargaUpPerPcs'] ??
                res['hargaJualRevisi'] ??
                res['hargaJualPerPcs'] ??
                res['hargaJual'] ??
                0)
            as num;
    final dppPerPcs = rawHrg.toDouble() + _currentOngkirResult.ongkirPerPcs;
    final finalPerPcs = _includePpn
        ? (dppPerPcs * 1.11).round()
        : dppPerPcs.round();
    final ppnTotal = _includePpn ? ((dppPerPcs * 0.11).round() * qty) : 0;
    final totalOrderKeseluruhan = finalPerPcs * qty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildResultItemRow(
            'Harga Bahan:',
            'Rp ${_formatNumberDisplay(hargaBahanSatuan)} / Pcs',
            valueColor: const Color(0xFF0284C7),
            isBold: true,
          ),
          if (tambahanPerPcs > 0)
            _buildResultItemRow(
              'Biaya Tambahan:',
              '+Rp ${_formatNumberDisplay(tambahanPerPcs)} / Pcs',
              valueColor: const Color(0xFFD97706),
              isBold: true,
            ),
          if (cetakPerPcs > 0)
            _buildResultItemRow(
              'Biaya Cetak:',
              '+Rp ${_formatNumberDisplay(cetakPerPcs)} / Pcs',
              valueColor: const Color(0xFFD97706),
              isBold: true,
            ),
          _buildResultItemRow(
            'Ongkir (${_currentOngkirResult.alokasi}):',
            _currentOngkirResult.isFreeCharge
                ? 'GRATIS'
                : '+Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)} /Pcs',
            valueColor: _currentOngkirResult.isFreeCharge
                ? const Color(0xFF15803D)
                : const Color(0xFF0284C7),
            isBold: true,
          ),
          const Divider(height: 14, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Kalkulasi:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Rp ${_formatNumberDisplay(finalPerPcs)} /Pcs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _includePpn
                      ? const Color(0xFF15803D)
                      : const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          if (_includePpn) ...[
            const SizedBox(height: 4),
            _buildResultItemRow(
              'Biaya PPN 11%:',
              '+Rp ${_formatNumberDisplay(ppnTotal)}',
              valueColor: const Color(0xFF047857),
              isBold: true,
            ),
          ],
          const SizedBox(height: 4),
          _buildResultItemRow(
            'Total Order Keseluruhan (${_formatNumberDisplay(qty)} pcs):',
            'Rp ${_formatNumberDisplay(totalOrderKeseluruhan)}',
            valueColor: const Color(0xFF0F172A),
            isBold: true,
          ),
        ],
      ),
    );
  }

  // Accordion Strata Garmen
  Widget _buildGarmenStrataAccordion() {
    final list =
        ((_garmenCalcResult?['tabelReferensi'] ??
                _garmenCalcResult?['tanggaMargin'] ??
                [])
            as List<dynamic>);
    final qty = _toNumCurrency(_qtyController.text);
    final activeTier = _garmenCalcResult?['strataAktif']?['tier'];

    return Column(
      children: [
        InkWell(
          onTap: () =>
              setState(() => _showGarmenStrataTabel = !_showGarmenStrataTabel),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.table_chart_rounded,
                      size: 16,
                      color: Color(0xFF4F46E5),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tabel Referensi Strata Garmen',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showGarmenStrataTabel
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_showGarmenStrataTabel && list.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Rentang Qty',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Harga / Pcs',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final tier in list) ...[
                  Builder(
                    builder: (ctx) {
                      final qmin =
                          (tier['qmin'] ?? tier['minOrder'] ?? 0) as num;
                      final qmax =
                          (tier['qmax'] ?? tier['maxOrder'] ?? 999999) as num;
                      final bool isActive =
                          (tier['tier'] != null &&
                              tier['tier'] == activeTier) ||
                          (qty >= qmin && qty <= qmax);
                      final String label =
                          tier['label']?.toString() ??
                          '${_formatNumberDisplay(qmin)} - ${qmax >= 999999 ? "≥ 1000" : _formatNumberDisplay(qmax)} pcs';
                      final hargaTier =
                          (tier['up'] ?? tier['jual'] ?? tier['hargaJual'] ?? 0)
                              as num;

                      return Container(
                        color: isActive
                            ? const Color(0xFFE0F2FE)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Rp ${_formatNumberDisplay(hargaTier)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultItemRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // --- BOX RINGKASAN SPESIFIKASI DI LANGKAH 2 ---
  Widget _buildSpecSummaryBox() {
    final divisiLabel = _selectedDivisi == '1'
        ? 'Spanduk'
        : (_selectedDivisi == '5' ? 'MMT' : 'Garmen');
    String specBahan = '-';
    String specUkuran = '-';

    if (_selectedDivisi == '4') {
      specBahan = '$_garmenJenisKain ($_garmenWarna)';
      specUkuran = _garmenKodeModel == 'KH-0001' ? '1 Warna' : '2 Warna';
    } else if (_selectedDivisi == '1') {
      specBahan = _spandukJenisKain;
      specUkuran = '${_panjangController.text} m x ${_spandukLebar.toInt()} cm';
    } else {
      specBahan = '$_mmtKategori - $_mmtBahanKode';
      specUkuran = '${_panjangController.text} m x ${_lebarController.text} m';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.assignment_rounded,
                    size: 16,
                    color: Color(0xFF4F46E5),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Spesifikasi Terinput',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _currentStep = 1),
                child: Row(
                  children: const [
                    Icon(
                      Icons.edit_rounded,
                      size: 13,
                      color: Color(0xFF4F46E5),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Ubah',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // Grid Baris 1: Customer & Nama Pekerjaan
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      _customerNamaController.text.isNotEmpty
                          ? _customerNamaController.text
                          : '-',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nama Pekerjaan',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      _barangController.text.isNotEmpty
                          ? _barangController.text
                          : '-',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Grid Baris 2: Divisi & Rencana Tgl Order
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Divisi',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      divisiLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rencana Tgl Order',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      DateFormat('dd-MM-yyyy').format(_rencanaOrderDate),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Grid Baris 3: Bahan/Kain & Ukuran
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bahan / Kain',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      specBahan,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ukuran (P x L)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      specUkuran,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Grid Baris 4: Kuantitas Order
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jumlah Order',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      '${_qtyController.text} pcs',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- STEP 3: REVIEW & PENGAJUAN WIDGET ---
  Widget _buildStep3Review() {
    final finalHarga = _toNumCurrency(_hargaMintaController.text);
    final qty = _toNumCurrency(_qtyController.text);
    final divisiLabel = _selectedDivisi == '1'
        ? 'Spanduk'
        : (_selectedDivisi == '5' ? 'MMT' : 'Garmen');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Resume Pengajuan Permintaan Harga
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.fact_check_rounded,
                      size: 16,
                      color: Color(0xFF15803D),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Resume Pengajuan Permintaan Harga',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Lampiran Foto Contoh Produk (1 Slot)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lampiran Foto Contoh Produk',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Maks. 1 MB',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_imageBytes != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _imageBytes!,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => setState(() => _imageBytes = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${((_imageSizeBytes ?? 0) / 1024).toStringAsFixed(0)} KB (Siap Unggah)',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(
                              Icons.photo_camera_rounded,
                              size: 16,
                              color: Color(0xFF4F46E5),
                            ),
                            label: const Text(
                              'Kamera',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(
                              Icons.photo_library_rounded,
                              size: 16,
                              color: Color(0xFF0284C7),
                            ),
                            label: const Text(
                              'Galeri',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '* Unggah sample desain (Opsional)',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              const Divider(height: 20),

              // Section Customer & Pekerjaan
              const Text(
                'Customer & Pekerjaan',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              _buildReviewRow(
                'Customer:',
                _customerNamaController.text,
                isBold: true,
              ),
              _buildReviewRow(
                'Nama Pekerjaan:',
                _barangController.text,
                isBold: true,
              ),
              _buildReviewRow('Divisi:', divisiLabel),
              _buildReviewRow(
                'Rencana Tgl Order:',
                DateFormat('dd-MM-yyyy').format(_rencanaOrderDate),
                isBold: true,
              ),
              const Divider(height: 20),

              // Section Spesifikasi Detail
              const Text(
                'Spesifikasi Detail',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              if (_selectedDivisi == '4') ...[
                _buildReviewRow(
                  'Model:',
                  _garmenKodeModel == 'KH-0001'
                      ? '1 Warna (KH-0001)'
                      : '2 Warna (KH-0002)',
                  isBold: true,
                ),
                _buildReviewRow(
                  'Kain & Warna:',
                  '$_garmenJenisKain ($_garmenWarna)',
                ),
              ] else if (_selectedDivisi == '1') ...[
                _buildReviewRow(
                  'Kain Spanduk:',
                  _spandukJenisKain,
                  isBold: true,
                ),
                _buildReviewRow(
                  'Ukuran (P x L):',
                  '${_panjangController.text} m x ${_spandukLebar.toInt()} cm',
                ),
              ] else ...[
                _buildReviewRow(
                  'Kategori & Bahan:',
                  '$_mmtKategori - $_mmtBahanKode',
                  isBold: true,
                ),
                _buildReviewRow(
                  'Ukuran (P x L):',
                  '${_panjangController.text} m x ${_lebarController.text} m',
                ),
                _buildReviewRow(
                  'Tipe Tarif:',
                  _mmtIsNetto ? 'Harga Netto' : 'Harga Standar (Strata)',
                ),
                if (_mmtIsNetto && _mmtAlasanNettoController.text.isNotEmpty)
                  _buildReviewRow(
                    'Alasan Netto:',
                    _mmtAlasanNettoController.text,
                    valueColor: const Color(0xFF7E22CE),
                    isBold: true,
                  ),
              ],
              if (_ukuranController.text.trim().isNotEmpty)
                _buildReviewRow(
                  'Rincian Ukuran / Size:',
                  _ukuranController.text.trim(),
                ),
              if (_gramasiController.text.trim().isNotEmpty)
                _buildReviewRow('Gramasi:', _gramasiController.text.trim()),
              if (_finishingController.text.trim().isNotEmpty)
                _buildReviewRow('Finishing:', _finishingController.text.trim()),
              if (_mhSublim == 'PREMIUM')
                _buildReviewRow(
                  'Sublim:',
                  'Ya (Sublim Premium)',
                  valueColor: const Color(0xFF15803D),
                  isBold: true,
                ),
              _buildReviewRow(
                'Jumlah Order:',
                '$qty Pcs',
                isBold: true,
                valueColor: const Color(0xFF4F46E5),
                fontSize: 13,
              ),
              if (_keteranganController.text.isNotEmpty)
                _buildReviewRow(
                  'Keterangan:',
                  _keteranganController.text,
                  valueColor: const Color(0xFF475569),
                ),
              const Divider(height: 20),

              // Final Price Summary Box (reviewPriceBox)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReviewRow(
                      'Estimasi Standar Kalkulasi / Pcs:',
                      'Rp ${_formatNumberDisplay(_hargaKalkulasi)} /Pcs',
                      isBold: true,
                      valueColor: _includePpn
                          ? const Color(0xFF15803D)
                          : const Color(0xFF0284C7),
                      fontSize: 14,
                    ),
                    if (_includePpn) ...[
                      const SizedBox(height: 4),
                      _buildReviewRow(
                        'Biaya PPN (11%):',
                        'Rp ${_formatNumberDisplay((_hargaKalkulasi - (_hargaKalkulasi / 1.11).round()) * qty)}',
                        valueColor: const Color(0xFF15803D),
                      ),
                    ],
                    const Divider(height: 12, color: Color(0xFFBBF7D0)),
                    _buildReviewRow(
                      _includePpn
                          ? 'Total Kalkulasi (INC PPN 11%):'
                          : 'Total Kalkulasi (Non PPN):',
                      'Rp ${_formatNumberDisplay(_hargaKalkulasi * qty)}',
                      isBold: true,
                      valueColor: const Color(0xFF15803D),
                      fontSize: 16,
                    ),
                    const SizedBox(height: 4),
                    _buildReviewRow(
                      'Ongkir (${_currentOngkirResult.alokasi}):',
                      _currentOngkirResult.isFreeCharge
                          ? 'GRATIS ONGKIR'
                          : 'Rp ${_formatNumberDisplay(_currentOngkirResult.totalOngkir)} (+Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)} /pcs)',
                      isBold: true,
                      valueColor: _currentOngkirResult.isFreeCharge
                          ? const Color(0xFF15803D)
                          : const Color(0xFF0284C7),
                    ),
                    if (_keteranganKalkulasiController.text.isNotEmpty) ...[
                      const Divider(height: 12, color: Color(0xFFDCFCE7)),
                      Text(
                        'Keterangan Kalkulasi: ${_keteranganKalkulasiController.text}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Riwayat Order Customer (Collapsible Dropdown)
        AppCard(
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(
                  () => _isSoHistoryExpanded = !_isSoHistoryExpanded,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 22,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Riwayat Order Customer',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_customerSoHistory.length} SO',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _customerNamaController.text.isNotEmpty
                                  ? _customerNamaController.text
                                  : 'Belum dipilih',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(
                      _isSoHistoryExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: const Color(0xFF0284C7),
                    ),
                  ],
                ),
              ),

              if (_isSoHistoryExpanded) ...[
                const Divider(height: 16),
                if (_customerSoHistory.isNotEmpty) ...[
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            onChanged: (v) =>
                                setState(() => _soSearchKeyword = v),
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Cari nomor SO, pekerjaan, detail...',
                              hintStyle: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                if (_customerSoHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Customer ini belum memiliki riwayat order sebelumnya.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  )
                else if (_filteredSoHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Tidak ada riwayat SO yang cocok dengan pencarian.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredSoHistory.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final so = _filteredSoHistory[i];
                      final soNomor = so['so_nomor']?.toString() ?? '-';
                      final divisiNama = so['divisi_nama']?.toString() ?? '';
                      final tgl =
                          so['so_tanggal_fmt']?.toString() ??
                          so['so_tanggal']?.toString() ??
                          '';
                      final namaPekerjaan =
                          so['so_nama']?.toString() ??
                          so['so_nama2']?.toString() ??
                          so['nama_barang']?.toString() ??
                          'Pekerjaan Tanpa Nama';
                      final numQty = (so['so_jumlah'] ?? so['qty'] ?? 0) as num;
                      final numHarga =
                          (so['so_harga'] ?? so['harga'] ?? 0) as num;
                      final totalNominal = numQty * numHarga;
                      final kain = so['so_kain']?.toString() ?? '';
                      final ukuran =
                          so['so_ukuran']?.toString() ??
                          (so['so_panjang'] != null || so['so_lebar'] != null
                              ? '${so['so_panjang']}m x ${so['so_lebar']}m'
                              : '');
                      final finishing = so['so_finishing']?.toString() ?? '';
                      final ket = so['so_ket']?.toString() ?? '';

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header SO Item
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFBAE6FD),
                                    ),
                                  ),
                                  child: Text(
                                    soNomor,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                                if (divisiNama.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F3FF),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFDDD6FE),
                                      ),
                                    ),
                                    child: Text(
                                      divisiNama,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  tgl,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Nama Item Pekerjaan
                            Text(
                              namaPekerjaan,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Qty, Harga Satuan, & Total Nominal SO
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      text: 'Qty: ',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _formatNumberDisplay(numQty),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Rp ${_formatNumberDisplay(numHarga)}/pcs',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  Text(
                                    'Total: Rp ${_formatNumberDisplay(totalNominal)}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Spesifikasi Lengkap SO (Box)
                            if (kain.isNotEmpty ||
                                ukuran.isNotEmpty ||
                                finishing.isNotEmpty ||
                                ket.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (kain.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          '• Bahan/Kain: $kain',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    if (ukuran.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          '• Ukuran: $ukuran',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    if (finishing.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          '• Finishing: $finishing',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    if (ket.isNotEmpty)
                                      Text(
                                        '• Keterangan: $ket',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Permintaan Harga Custom & Pengajuan
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.monetization_on_rounded,
                    size: 20,
                    color: Color(0xFF4F46E5),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Permintaan Harga Custom',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Info Pembanding Harga Standar Kalkulasi
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kalkulasi Sistem:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          'Rp ${_formatNumberDisplay(_hargaKalkulasi)} /pcs',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total ($qty Pcs):',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          'Rp ${_formatNumberDisplay(_hargaKalkulasi * qty)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              RichText(
                text: const TextSpan(
                  text: 'Ajukan Permintaan Harga Per Pcs ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: '*',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _hargaMintaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  hintText: 'Masukkan harga pengajuan...',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              Text(
                'Total Nilai Pengajuan: Rp ${_formatNumberDisplay(finalHarga * qty)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(height: 12),

              // Alasan Permintaan Harga
              RichText(
                text: TextSpan(
                  text: 'Alasan Permintaan Harga ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: finalHarga < _hargaKalkulasi && _hargaKalkulasi > 0
                          ? '(Wajib Diisi)*'
                          : '(Opsional)',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            finalHarga < _hargaKalkulasi && _hargaKalkulasi > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _alasanPengajuanController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'Contoh: Diskon repeat order partai besar, menyesuaikan SO terakhir, penyesuaian budget klien...',
                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tombol Aksi Bawah Review
        Row(
          children: [
            Expanded(
              flex: 4,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                onPressed: () => setState(() => _currentStep = 2),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: Color(0xFF475569),
                ),
                label: const Text(
                  'Hitung Ulang',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: AppButton(
                text: _isEditMode ? 'Simpan Perubahan' : 'Kirim Pengajuan',
                icon: Icons.send_rounded,
                isLoading: _isSubmitting,
                onPressed: () => _showConfirmSubmitDialog(isBypass: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildDivisiChip(String kode, String label) {
    final isSelected = _selectedDivisi == kode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDivisi = kode;
            if (kode == '4') _loadGarmenLookups();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectablePill(
    String title,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : const Color(0xFFE2E8F0),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildSpandukFinishingChecklist() {
    final options =
        (_masterOptions?['spandukTambahan'] as List<dynamic>?) ??
        [
          {'id': 1, 'nama': 'Obras'},
          {'id': 2, 'nama': 'Tali Samping'},
          {'id': 3, 'nama': 'Mata Ayam (Ring)'},
        ];

    return Wrap(
      spacing: 6,
      children: options.map((it) {
        final id = it['id'] is int
            ? it['id'] as int
            : int.tryParse(it['id'].toString()) ?? 0;
        final name = it['nama']?.toString() ?? '';
        final isChecked = _spandukFinishingIds.contains(id);

        return FilterChip(
          label: Text(
            name,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          selected: isChecked,
          selectedColor: const Color(0xFFEEF2FF),
          checkmarkColor: const Color(0xFF4F46E5),
          onSelected: (val) {
            setState(() {
              if (val) {
                _spandukFinishingIds.add(id);
              } else {
                _spandukFinishingIds.remove(id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  List<Map<String, String>> get _currentMmtBahanOptions {
    if (_mmtKategori == 'VYNIL') {
      return [
        {'kode': '260', 'nama': 'Frontlite 260'},
        {'kode': '280', 'nama': 'Frontlite 280'},
        {'kode': '340', 'nama': 'Frontlite 340'},
        {'kode': '440', 'nama': 'Frontlite 440'},
        {'kode': 'KORCIN', 'nama': 'Frontlite Korcin'},
      ];
    } else if (_mmtKategori == 'HI-RES') {
      return [
        {'kode': '340', 'nama': 'Hi-Res 340'},
        {'kode': '440', 'nama': 'Hi-Res 440'},
        {'kode': 'KORCIN', 'nama': 'Hi-Res Korcin'},
        {'kode': 'BACKLITE', 'nama': 'Backlite'},
      ];
    }
    return [
      {'kode': 'GRAFTAC', 'nama': 'Sticker Graftac'},
      {'kode': 'RITRAMA', 'nama': 'Sticker Ritrama'},
      {'kode': 'ORAJET', 'nama': 'Sticker Orajet'},
    ];
  }

  List<Map<String, dynamic>> get _filteredSoHistory {
    if (_soSearchKeyword.trim().isEmpty) return _customerSoHistory;
    final q = _soSearchKeyword.toLowerCase().trim();
    return _customerSoHistory.where((so) {
      final no = (so['so_nomor'] ?? '').toString().toLowerCase();
      final item = (so['so_nama'] ?? so['nama_barang'] ?? '')
          .toString()
          .toLowerCase();
      return no.contains(q) || item.contains(q);
    }).toList();
  }

  void _showGarmenKainPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _garmenKainList.where((item) {
              final name =
                  (item['mhk_kain'] ?? item['Jeniskain'] ?? item['nama'] ?? '')
                      .toString();
              return search.isEmpty ||
                  name.toLowerCase().contains(search.toLowerCase());
            }).toList();

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilih Jenis Kain Garmen',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setModalState(() => search = v),
                              style: const TextStyle(fontSize: 12.5),
                              decoration: const InputDecoration(
                                hintText: 'Cari jenis kain...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (search.isNotEmpty)
                            GestureDetector(
                              onTap: () => setModalState(() => search = ''),
                              child: const Icon(
                                Icons.cancel,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _garmenLoadingKain
                          ? const Center(child: CircularProgressIndicator())
                          : filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada jenis kain yang cocok',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (c, idx) {
                                final item = filtered[idx];
                                final name =
                                    (item['mhk_kain'] ??
                                            item['Jeniskain'] ??
                                            item['nama'] ??
                                            '')
                                        .toString();
                                final ktg =
                                    (item['mhk_kategori'] ??
                                            item['kategori'] ??
                                            '')
                                        .toString()
                                        .toLowerCase();

                                return ListTile(
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _garmenJenisKain = name;
                                      _garmenKategoriKain = ktg.isNotEmpty
                                          ? ktg
                                          : 'pe';
                                      final autoGramasi = getGramasiByKain(
                                        name,
                                      );
                                      if (autoGramasi.isNotEmpty &&
                                          _gramasiController.text.isEmpty) {
                                        _gramasiController.text = autoGramasi;
                                      }
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showGarmenTambahanPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Pilih Tambahan Biaya Aksesoris',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: _garmenTambahanMaster.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (c, idx) {
                    final item = _garmenTambahanMaster[idx];
                    final ket =
                        item['mha_ket'] ?? item['ket'] ?? item['nama'] ?? '';
                    final tarif = (item['mha_rp'] ?? item['tarif'] ?? 0) as num;
                    return ListTile(
                      title: Text(
                        ket,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text('Rp ${_formatNumberDisplay(tarif)}'),
                      onTap: () {
                        setState(() {
                          _garmenSelectedTambahan.add({
                            'ket': ket,
                            'tarif': tarif.toInt(),
                          });
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGarmenCetakPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String activeCategory =
            'SABLON'; // 'SABLON' | 'SUBLIM' | 'DTF' | 'BORDIR'
        String sablonSubCategory = 'ALL'; // 'ALL' | 'MEDIUM' | 'RUBBER'
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDtfOrBordir =
                activeCategory == 'DTF' || activeCategory == 'BORDIR';

            // Master item untuk DTF / Bordir
            final masterItem = _garmenCetakMaster.firstWhere(
              (c) =>
                  (c['mhb_jenis'] ?? c['jenis'] ?? '')
                      .toString()
                      .toUpperCase() ==
                  activeCategory,
              orElse: () => <String, dynamic>{},
            );
            final defaultTarif =
                (masterItem['mhb_cm'] as num?)?.toDouble() ??
                (activeCategory == 'DTF' ? 25.0 : 90.0);
            final minTarif =
                (masterItem['mhb_min'] as num?)?.toDouble() ??
                (activeCategory == 'DTF' ? 1000.0 : 2500.0);

            // Perhitungan DTF / Bordir
            final pj = _toNumDecimal(_dtfBordirPanjangController.text);
            final lb = _toNumDecimal(_dtfBordirLebarController.text);
            final luas = pj * lb;

            final currentTarifStr = activeCategory == 'DTF'
                ? _dtfTarifCmController.text
                : _bordirTarifCmController.text;
            final rawTarif = currentTarifStr.isNotEmpty
                ? _toNumDecimal(currentTarifStr)
                : defaultTarif;
            final isTarifUnderDefault =
                currentTarifStr.isNotEmpty && rawTarif < defaultTarif;
            final effectiveTarif = rawTarif < defaultTarif
                ? defaultTarif
                : rawTarif;

            final biayaMurni = luas * effectiveTarif;
            final isMinApplied = luas > 0 && biayaMurni < minTarif;
            final biayaPerPcs = luas > 0
                ? (isMinApplied ? minTarif : biayaMurni.roundToDouble())
                : 0.0;
            final qtyOrder = _toNumCurrency(_qtyController.text);
            final totalBiayaOrder = biayaPerPcs * qtyOrder;

            // List item untuk Sablon / Sublim
            final filteredList = _garmenCetakMaster.where((cItem) {
              final j = (cItem['mhb_jenis'] ?? cItem['jenis'] ?? '')
                  .toString()
                  .toUpperCase();
              if (j != activeCategory) return false;

              final ket =
                  (cItem['mhb_ket'] ?? cItem['ket'] ?? cItem['nama'] ?? '')
                      .toString()
                      .toUpperCase();

              if (activeCategory == 'SABLON') {
                if (sablonSubCategory != 'ALL' &&
                    !ket.contains(sablonSubCategory)) {
                  return false;
                }

                if (searchQuery.trim().isEmpty) {
                  final curKtg = _garmenKategoriKain.toUpperCase();
                  final isPe =
                      curKtg.contains('PE') ||
                      curKtg.contains('HYGIT') ||
                      curKtg.contains('DRYFIT');
                  final isLacost = curKtg.contains('LACOST');

                  if (isPe) {
                    if (!ket.endsWith(' PE')) {
                      return false;
                    }
                  } else if (isLacost) {
                    if (ket.endsWith(' PE') || ket.endsWith(' COTTON')) {
                      return false;
                    }
                  } else {
                    if (ket.endsWith(' PE') || ket.endsWith(' LACOST')) {
                      return false;
                    }
                  }
                }
              }

              if (searchQuery.trim().isNotEmpty) {
                return ket.toLowerCase().contains(
                  searchQuery.toLowerCase().trim(),
                );
              }

              return true;
            }).toList();

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilih Biaya Cetak Garmen',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Category Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          _buildCetakTabItem(
                            'Sablon',
                            'SABLON',
                            activeCategory,
                            (cat) {
                              setModalState(() => activeCategory = cat);
                            },
                          ),
                          _buildCetakTabItem(
                            'Sublim',
                            'SUBLIM',
                            activeCategory,
                            (cat) {
                              setModalState(() => activeCategory = cat);
                            },
                          ),
                          _buildCetakTabItem('DTF', 'DTF', activeCategory, (
                            cat,
                          ) {
                            if (_dtfTarifCmController.text.isEmpty ||
                                _toNumDecimal(_dtfTarifCmController.text) <
                                    defaultTarif) {
                              _dtfTarifCmController.text = defaultTarif
                                  .toInt()
                                  .toString();
                            }
                            setModalState(() => activeCategory = cat);
                          }),
                          _buildCetakTabItem(
                            'Bordir',
                            'BORDIR',
                            activeCategory,
                            (cat) {
                              if (_bordirTarifCmController.text.isEmpty ||
                                  _toNumDecimal(_bordirTarifCmController.text) <
                                      defaultTarif) {
                                _bordirTarifCmController.text = defaultTarif
                                    .toInt()
                                    .toString();
                              }
                              setModalState(() => activeCategory = cat);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // TAMPILAN 1: KALKULATOR UKURAN KHUSUS DTF & BORDIR
                    if (isDtfOrBordir) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Box Tarif per cm2
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isTarifUnderDefault
                                      ? const Color(0xFFFFF1F2)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isTarifUnderDefault
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Tarif / cm²',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'Minimal: Rp ${defaultTarif.toInt()} /cm²',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      height: 38,
                                      child: TextFormField(
                                        controller: activeCategory == 'DTF'
                                            ? _dtfTarifCmController
                                            : _bordirTarifCmController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        decoration: InputDecoration(
                                          prefixText: 'Rp ',
                                          prefixStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF64748B),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 8,
                                              ),
                                          hintText: defaultTarif
                                              .toInt()
                                              .toString(),
                                        ),
                                        onChanged: (_) => setModalState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isTarifUnderDefault) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Tarif tidak boleh di bawah standar minimal (Rp ${defaultTarif.toInt()} /cm²)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFE11D48),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),

                              // Input Dimensi (Panjang x Lebar cm)
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Panjang (cm) *',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller:
                                              _dtfBordirPanjangController,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          inputFormatters: [
                                            _decimalInputFormatter,
                                          ],
                                          decoration: const InputDecoration(
                                            hintText: '0',
                                            suffixText: 'cm',
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                          ),
                                          onChanged: (_) =>
                                              setModalState(() {}),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Lebar (cm) *',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller: _dtfBordirLebarController,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          inputFormatters: [
                                            _decimalInputFormatter,
                                          ],
                                          decoration: const InputDecoration(
                                            hintText: '0',
                                            suffixText: 'cm',
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                          ),
                                          onChanged: (_) =>
                                              setModalState(() {}),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Ringkasan Kalkulasi DTF / Bordir Box
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total Luas:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                        Text(
                                          '${luas.toStringAsFixed(1)} cm²',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Biaya Satuan / Pcs:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              'Rp ${_formatNumberDisplay(biayaPerPcs.toInt())} /pcs',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                            ),
                                            if (isMinApplied) ...[
                                              const SizedBox(width: 4),
                                              Text(
                                                '(Min: Rp ${minTarif.toInt()})',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFFB45309),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(
                                      height: 12,
                                      color: Color(0xFFBFDBFE),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total ($qtyOrder pcs):',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                        Text(
                                          'Rp ${_formatNumberDisplay(totalBiayaOrder.toInt())}',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Tombol Terapkan DTF / Bordir
                              ElevatedButton(
                                onPressed: biayaPerPcs <= 0
                                    ? null
                                    : () {
                                        final label =
                                            '$activeCategory ${pj}x$lb cm';
                                        setState(() {
                                          _garmenSelectedCetak.add({
                                            'jenis': activeCategory,
                                            'ket': label,
                                            'biaya': biayaPerPcs.toInt(),
                                          });
                                        });
                                        Navigator.pop(ctx);
                                        AppToast.success(
                                          context,
                                          '$label berhasil ditambahkan (+Rp ${_formatNumberDisplay(biayaPerPcs.toInt())}/pcs)',
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  backgroundColor: const Color(0xFF4F46E5),
                                ),
                                child: Text(
                                  'Terapkan Ukuran & Biaya $activeCategory Ini',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // TAMPILAN 2: LIST SABLON / SUBLIM
                      if (activeCategory == 'SABLON') ...[
                        Row(
                          children: [
                            _buildSubCategoryChip(
                              'Semua Sablon',
                              'ALL',
                              sablonSubCategory,
                              (s) => setModalState(() => sablonSubCategory = s),
                            ),
                            const SizedBox(width: 6),
                            _buildSubCategoryChip(
                              'Medium',
                              'MEDIUM',
                              sablonSubCategory,
                              (s) => setModalState(() => sablonSubCategory = s),
                            ),
                            const SizedBox(width: 6),
                            _buildSubCategoryChip(
                              'Rubber',
                              'RUBBER',
                              sablonSubCategory,
                              (s) => setModalState(() => sablonSubCategory = s),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Search input
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                onChanged: (v) =>
                                    setModalState(() => searchQuery = v),
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: 'Cari jenis / ukuran...',
                                  hintStyle: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Expanded(
                        child: filteredList.isEmpty
                            ? const Center(
                                child: Text(
                                  'Tidak ada pilihan cetak yang cocok',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredList.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (c, idx) {
                                  final item = filteredList[idx];
                                  final jenis =
                                      (item['mhb_jenis'] ??
                                              item['jenis'] ??
                                              activeCategory)
                                          .toString()
                                          .toUpperCase();
                                  final ket =
                                      (item['mhb_ket'] ??
                                              item['ket'] ??
                                              item['nama'] ??
                                              jenis)
                                          .toString();
                                  final biaya =
                                      ((item['mhb_rp'] ??
                                                  item['mhb_biaya'] ??
                                                  item['biaya'] ??
                                                  0)
                                              as num)
                                          .toInt();
                                  final desc = getSablonUkuranDesc(ket);

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    title: Text(
                                      ket,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: desc.isNotEmpty
                                        ? Text(
                                            desc,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          )
                                        : null,
                                    trailing: Text(
                                      'Rp ${_formatNumberDisplay(biaya)} /pcs',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _garmenSelectedCetak.add({
                                          'jenis': jenis,
                                          'ket': ket,
                                          'biaya': biaya,
                                        });
                                      });
                                      Navigator.pop(ctx);
                                      AppToast.success(
                                        context,
                                        '$ket ditambahkan (+Rp ${_formatNumberDisplay(biaya)}/pcs)',
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildCetakTabItem(
    String label,
    String key,
    String active,
    ValueChanged<String> onTap,
  ) {
    final isSelected = active == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildSubCategoryChip(
    String label,
    String key,
    String active,
    ValueChanged<String> onTap,
  ) {
    final isSelected = active == key;
    return GestureDetector(
      onTap: () => onTap(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFC4B5FD)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF6D28D9)
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  void _showKetentuanOngkirModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: Color(0xFF0284C7),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Ketentuan Ongkos Kirim',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Seksi 1: Rasio Berat
                      _buildInfoSectionCard(
                        title: '1. Rasio Konversi Berat Pesanan',
                        icon: Icons.scale_rounded,
                        items: const [
                          'Spanduk: 10 meter = 1 kg',
                          'MMT: 2 m² = 1 kg (0.5 kg / m²)',
                          'Garmen Medium: 5 pcs = 1 kg',
                          'Garmen Premium: 3 pcs = 1 kg',
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Seksi 2: Aturan Minimal
                      _buildInfoSectionCard(
                        title: '2. Aturan Minimum Berat Kirim',
                        icon: Icons.rule_rounded,
                        items: const [
                          'Pulau Jawa: Minimum berat kirim dihitung 20 kg',
                          'Luar Pulau Jawa: Minimum berat kirim dihitung 40 kg',
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Seksi 3: Syarat Gratis Ongkir
                      _buildInfoSectionCard(
                        title: '3. Syarat Gratis Ongkir (Free Charge)',
                        icon: Icons.verified_rounded,
                        accentColor: const Color(0xFF10B981),
                        items: const [
                          'Berlaku untuk alokasi: Jakarta (Jabodetabek), Bandung, Yogya, Sidoarjo, Surabaya, Surakarta (Solo Raya)',
                          'Spanduk: Order ≥ 1.000 meter',
                          'MMT: Order ≥ 500 m²',
                          'Garmen: Order ≥ 300 pcs',
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Seksi 4: Tarif Daerah Berbayar
                      _buildInfoSectionCard(
                        title: '4. Tarif Kirim Daerah Ekspedisi',
                        icon: Icons.map_rounded,
                        items: const [
                          'Jawa Lainnya: Rp 5.000 /kg (min 20 kg)',
                          'Bali: Rp 8.000 /kg (min 40 kg)',
                          'Sumatra: Rp 10.000 /kg (min 40 kg)',
                          'Sulawesi: Rp 10.000 /kg (min 40 kg)',
                          'Nusa Tenggara: Rp 10.000 /kg (min 40 kg)',
                          'Kalimantan: Rp 15.000 /kg (min 40 kg)',
                        ],
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

  static Widget _buildInfoSectionCard({
    required String title,
    required IconData icon,
    required List<String> items,
    Color? accentColor,
  }) {
    final color = accentColor ?? const Color(0xFF4F46E5);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      it,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    double fontSize = 12.5,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _PraOrderPickerSheet extends ConsumerStatefulWidget {
  final Future<void> Function(Map<String, dynamic> item) onSelect;

  const _PraOrderPickerSheet({required this.onSelect});

  @override
  ConsumerState<_PraOrderPickerSheet> createState() =>
      _PraOrderPickerSheetState();
}

class _PraOrderPickerSheetState extends ConsumerState<_PraOrderPickerSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;
  bool _fetchingDetail = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchList('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchList(String keyword) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final res = await repo.getPraOrderList(keyword);
      if (mounted) {
        setState(() {
          _list = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _list = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchList(val.trim());
    });
  }

  String _formatDateOrderDisplay(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) {
        return DateFormat('dd-MM-yyyy').format(parsed);
      }
      final clean = dateStr.split('T')[0];
      final parts = clean.split('-');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }

  String _formatThousands(num value) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Modal Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.playlist_add_check_rounded,
                              size: 18,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Pilih Pra Order',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  'Ketik nomor, customer, atau pekerjaan...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: const Icon(
                              Icons.cancel_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // List Pra Order / Loading / Empty
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF4F46E5),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Memuat data pra order...',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _list.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: Color(0xFFCBD5E1),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Pra Order Tidak Ditemukan',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            bottomInset + 16,
                          ),
                          itemCount: _list.length,
                          itemBuilder: (context, index) {
                            final item = _list[index];
                            return _buildPraOrderItemCard(item);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        // Overlay Loading saat menerapkan detail
        if (_fetchingDetail)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Menerapkan Data Pra Order...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPraOrderItemCard(Map<String, dynamic> item) {
    final no =
        item['nomor']?.toString() ?? item['pro_nomor']?.toString() ?? '-';
    final divisi = item['divisi']?.toString() ?? '1';
    final divisiNama =
        item['divisiNama']?.toString() ??
        (divisi == '4' ? 'GARMEN' : (divisi == '5' ? 'MMT' : 'SPANDUK'));
    final tanggal = _formatDateOrderDisplay(
      item['tanggal']?.toString() ?? item['pro_tanggal']?.toString(),
    );
    final namaPekerjaan =
        item['namaPekerjaan']?.toString() ??
        item['nama_pekerjaan']?.toString() ??
        '-';
    final cusNama =
        item['cusNama']?.toString() ?? item['cus_nama']?.toString() ?? '-';
    final qty =
        (item['qtyRencana'] as num?)?.toDouble() ??
        (item['rencanaOrder'] as num?)?.toDouble() ??
        (item['pro_qty_rencana'] as num?)?.toDouble() ??
        0;
    final sudahDipakaiOleh =
        item['sudahDipakaiOleh']?.toString() ??
        item['pro_mh_nomor']?.toString();

    Color divBgColor;
    Color divTextColor;
    if (divisi == '4') {
      divBgColor = const Color(0xFFFEF3C7);
      divTextColor = const Color(0xFFB45309);
    } else if (divisi == '5') {
      divBgColor = const Color(0xFFEDE9FE);
      divTextColor = const Color(0xFF6D28D9);
    } else {
      divBgColor = const Color(0xFFDCFCE7);
      divTextColor = const Color(0xFF15803D);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            setState(() => _fetchingDetail = true);
            try {
              await widget.onSelect(item);
              if (mounted) Navigator.pop(context);
            } finally {
              if (mounted) setState(() => _fetchingDetail = false);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        no,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: divBgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        divisiNama,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: divTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        tanggal,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Nama Pekerjaan
                Text(
                  namaPekerjaan,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),

                // Customer Row
                Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: Color(0xFF0F172A),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        cusNama,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Qty Text
                Text(
                  qty > 0
                      ? 'Rencana Order: ${_formatThousands(qty)} pcs'
                      : 'Rencana Order: -',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),

                // Badge Sudah Terpakai (jika ada)
                if (sudahDipakaiOleh != null &&
                    sudahDipakaiOleh.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 13,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sudah terpakai pada $sudahDipakaiOleh',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
