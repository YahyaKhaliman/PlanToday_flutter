import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/customer_picker_modal.dart';
import '../../widgets/form_confirm_dialog.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class TambahVisitScreen extends ConsumerStatefulWidget {
  final CustomerModel? initialCustomer;
  final String? initialDate;

  const TambahVisitScreen({
    super.key,
    this.initialCustomer,
    this.initialDate,
  });

  @override
  ConsumerState<TambahVisitScreen> createState() => _TambahVisitScreenState();
}

class _TambahVisitScreenState extends ConsumerState<TambahVisitScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  CustomerModel? _selectedCustomer;
  final _noteController = TextEditingController();
  final _catatanController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isGettingGps = false;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  int? _existingVisitId;
  bool _isCheckingDraft = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomer != null) {
      _selectedCustomer = widget.initialCustomer;
    }
    if (widget.initialDate != null && widget.initialDate!.isNotEmpty) {
      try {
        _selectedDate = DateFormat('yyyy-MM-dd').parse(widget.initialDate!);
      } catch (_) {}
    }
    _fetchGpsLocation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedCustomer != null) {
        _checkAndLoadExistingVisit();
      }
    });
  }

  Future<void> _checkAndLoadExistingVisit() async {
    if (_selectedCustomer == null) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final ymd = DateFormat('yyyy-MM-dd').format(_selectedDate);
    setState(() => _isCheckingDraft = true);

    try {
      final repo = ref.read(visitRepositoryProvider);
      final found = await repo.findExistingVisitOrDraft(
        user: user.nama,
        cusKode: _selectedCustomer!.kode,
        tanggal: ymd,
      );

      if (found != null && mounted) {
        setState(() {
          _existingVisitId = (found['id'] is int)
              ? found['id']
              : int.tryParse(found['id'].toString());
          if (_noteController.text.trim().isEmpty &&
              (found['note'] ?? '').toString().isNotEmpty) {
            _noteController.text = found['note'].toString();
          }
          if (_catatanController.text.trim().isEmpty &&
              (found['catatan'] ?? '').toString().isNotEmpty) {
            _catatanController.text = found['catatan'].toString();
          }
        });

        final tipe =
            found['status'] == 'DONE' ? 'Laporan Kunjungan' : 'Visit Plan';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$tipe ditemukan, formulir terisi otomatis.'),
            backgroundColor: const Color(0xFF4F46E5),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingDraft = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    setState(() => _isGettingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (mounted) {
          setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
            _isGettingGps = false;
          });
        }
      } else {
        if (mounted) setState(() => _isGettingGps = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isGettingGps = false);
    }
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
                'Ambil Foto Kunjungan',
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectCustomer() async {
    final selected = await showCustomerPickerModal(context);
    if (selected != null && mounted) {
      setState(() {
        _selectedCustomer = selected;
        _existingVisitId = null;
      });
      _checkAndLoadExistingVisit();
    }
  }

  Future<void> _submit() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap pilih customer terlebih dahulu'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final ymdFormat = DateFormat('yyyy-MM-dd');
    final todayYmd = ymdFormat.format(DateTime.now());
    final ymd = ymdFormat.format(_selectedDate);

    if (ymd.compareTo(todayYmd) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal visit tidak boleh kurang dari hari ini'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final isRealisasi = _existingVisitId != null;
    final confirmed = await showFormConfirmDialog(
      context,
      title: isRealisasi ? 'Konfirmasi Realisasi Visit' : 'Konfirmasi Laporan Visit',
      subtitle: isRealisasi
          ? 'Rencana kunjungan akan direalisasikan menjadi laporan kunjungan'
          : 'Pastikan data dan titik lokasi kunjungan sudah sesuai',
      icon: Icons.place_rounded,
      iconColor: AppColors.primary,
      summaryItems: [
        MapEntry('Customer', _selectedCustomer!.nama),
        MapEntry('Tanggal', DateFormat('dd MMM yyyy').format(_selectedDate)),
        MapEntry('Status Form', isRealisasi ? 'Realisasi Plan' : 'Visit Baru'),
        MapEntry('Lokasi GPS', _latitude != null ? 'Terdeteksi' : 'Belum Terdeteksi'),
        MapEntry('Foto Bukti', _imageFile != null ? 'Terlampir' : 'Tidak Ada'),
        if (_noteController.text.trim().isNotEmpty)
          MapEntry('Tujuan', _noteController.text.trim()),
      ],
      confirmText: isRealisasi ? 'Ya, Realisasikan Visit' : 'Ya, Kirim Laporan',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(visitRepositoryProvider);

    final bool success;
    if (_existingVisitId != null) {
      success = await repo.updateVisit(
        id: _existingVisitId!,
        note: _noteController.text.trim(),
        catatan: _catatanController.text.trim(),
        tanggal: ymd,
        latitude: _latitude,
        longitude: _longitude,
        photo: _imageFile,
      );
    } else {
      success = await repo.createVisit(
        tanggal: ymd,
        customerKode: _selectedCustomer!.kode,
        customerNama: _selectedCustomer!.nama,
        note: _noteController.text.trim(),
        catatan: _catatanController.text.trim(),
        cabang: user?.cabang ?? '',
        sales: user?.nama ?? '',
        latitude: _latitude,
        longitude: _longitude,
        photo: _imageFile,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRealisasi
                  ? 'Visit berhasil direalisasikan dan tersimpan'
                  : 'Laporan visit berhasil dikirim',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan visit'),
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
                            'Tambah Kunjungan (Visit)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Formulir check-in realisasi kunjungan sales',
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
                                'Data Kunjungan',
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

                              // Tanggal Kunjungan
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Tanggal Kunjungan *',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (_isCheckingDraft)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    )
                                  else if (_existingVisitId != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Mode Realisasi Plan',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final todayDate =
                                      DateTime(now.year, now.month, now.day);
                                  final firstAllowed =
                                      _selectedDate.isBefore(todayDate)
                                          ? _selectedDate
                                          : todayDate;

                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: firstAllowed,
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedDate = picked);
                                    _checkAndLoadExistingVisit();
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

                              // Lokasi GPS Check-in Card
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color.fromRGBO(15, 23, 42, 0.06),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.pin_drop_rounded,
                                        color: Color(0xFF4F46E5),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Koordinat GPS',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _isGettingGps
                                                ? 'Mendeteksi lokasi...'
                                                : (_latitude != null &&
                                                        _longitude != null
                                                    ? 'Lat: ${_latitude!.toStringAsFixed(5)}, Long: ${_longitude!.toStringAsFixed(5)}'
                                                    : 'GPS belum terdeteksi'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _latitude != null
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.my_location_rounded,
                                          size: 20, color: Color(0xFF4F46E5)),
                                      onPressed: _fetchGpsLocation,
                                      tooltip: 'Ambil Lokasi',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Foto Dokumentasi
                              const Text(
                                'Foto Dokumentasi Kunjungan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _showImageSourceDialog,
                                child: Container(
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: _imageFile != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.file(
                                            _imageFile!,
                                            width: double.infinity,
                                            height: 140,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.add_a_photo_outlined,
                                              size: 32,
                                              color: Color(0xFF64748B),
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              'Ambil / Unggah Foto Bukti Kunjungan',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Hasil Kunjungan / Catatan
                              const Text(
                                'Hasil Kunjungan / Catatan *',
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
                                      'Contoh: Bertemu dengan PIC, membahas SPK...',
                                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Hasil kunjungan wajib diisi'
                                        : null,
                              ),
                              const SizedBox(height: 20),

                              // Tombol Simpan
                              AppButton(
                                text: 'Kirim Laporan Visit',
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
