import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/visit_model.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class EditVisitScreen extends ConsumerStatefulWidget {
  final VisitModel visit;

  const EditVisitScreen({super.key, required this.visit});

  @override
  ConsumerState<EditVisitScreen> createState() => _EditVisitScreenState();
}

class _EditVisitScreenState extends ConsumerState<EditVisitScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late final TextEditingController _noteController;
  late final TextEditingController _catatanController;

  double? _latitude;
  double? _longitude;
  bool _isGettingGps = false;

  File? _newPhotoFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.visit;
    _noteController = TextEditingController(text: v.note);
    _catatanController = TextEditingController(text: v.catatan);
    _latitude = v.latitude;
    _longitude = v.longitude;

    try {
      _selectedDate = DateFormat('yyyy-MM-dd').parse(v.tanggal);
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
        setState(() => _newPhotoFile = File(picked.path));
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
                'Ambil Foto Bukti Kunjungan',
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.visit.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID kunjungan tidak valid'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final ymd = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final repo = ref.read(visitRepositoryProvider);

    final success = await repo.updateVisit(
      id: widget.visit.id!,
      note: _noteController.text.trim(),
      catatan: _catatanController.text.trim(),
      tanggal: ymd,
      latitude: _latitude,
      longitude: _longitude,
      photo: _newPhotoFile,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perubahan laporan visit berhasil disimpan'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui laporan visit'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dmyFormat = DateFormat('dd MMMM yyyy');
    final v = widget.visit;

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
                            'Edit Kunjungan (Visit)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Perbarui laporan hasil kunjungan sales',
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
                              // Header Info Customer & Status
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      v.cusNama,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  AppBadge(
                                    label: v.realisasi == 'Y'
                                        ? 'SELESAI'
                                        : 'PROSES',
                                    variant: v.realisasi == 'Y'
                                        ? BadgeVariant.success
                                        : BadgeVariant.warning,
                                  ),
                                ],
                              ),
                              if (v.cusAlamat.isNotEmpty) ...[
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
                                        v.cusAlamat,
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

                              // Tanggal Kunjungan
                              const Text(
                                'Tanggal Kunjungan *',
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

                              // GPS Koordinat
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
                                                ? 'Mencari lokasi GPS...'
                                                : (_latitude != null &&
                                                        _longitude != null
                                                    ? 'GPS: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                                                    : 'GPS belum tercatat'),
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
                                      icon: const Icon(
                                        Icons.my_location_rounded,
                                        size: 20,
                                        color: Color(0xFF4F46E5),
                                      ),
                                      onPressed: _fetchGpsLocation,
                                      tooltip: 'Ambil Lokasi',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Tujuan / Keperluan Visit
                              const Text(
                                'Tujuan / Keperluan Visit *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _noteController,
                                decoration: const InputDecoration(
                                  hintText: 'Tujuan kunjungan...',
                                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Tujuan wajib diisi'
                                        : null,
                              ),
                              const SizedBox(height: 14),

                              // Catatan / Hasil Kunjungan
                              const Text(
                                'Catatan / Hasil Kunjungan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _catatanController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Catatan hasil kunjungan...',
                                  prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
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
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: _newPhotoFile != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Image.file(
                                            _newPhotoFile!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 150,
                                          ),
                                        )
                                      : (v.fotoUrl != null &&
                                              v.fotoUrl!.isNotEmpty)
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Image.network(
                                                v.fotoUrl!.startsWith('http')
                                                    ? v.fotoUrl!
                                                    : '${ApiConfig.imageReadUrl}${v.fotoUrl}',
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: 150,
                                                errorBuilder: (ctx, err,
                                                        stack) =>
                                                    Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: const [
                                                    Icon(
                                                      Icons.broken_image_outlined,
                                                      size: 32,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      'Foto tidak dapat dimuat',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
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
                                                  'Ketuk untuk mengganti foto bukti',
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
                              const SizedBox(height: 20),

                              // Tombol Simpan
                              AppButton(
                                text: 'Simpan Perubahan Visit',
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
