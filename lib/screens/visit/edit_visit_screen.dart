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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Kamera', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Galeri', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
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
      appBar: AppBar(
        title: const Text('Edit Kunjungan (Visit)'),
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
                      // Header Info Customer & Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              v.cusNama,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          AppBadge(
                            label: v.realisasi == 'Y' ? 'SELESAI' : 'PROSES',
                            variant: v.realisasi == 'Y' ? BadgeVariant.success : BadgeVariant.warning,
                          ),
                        ],
                      ),
                      if (v.cusAlamat.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(v.cusAlamat, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      ],
                      const Divider(height: 24, color: AppColors.border),

                      // Tanggal Kunjungan
                      const Text(
                        'Tanggal Kunjungan *',
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

                      // GPS Koordinat
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.my_location, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _isGettingGps
                                  ? const Text('Mencari titik lokasi GPS...', style: TextStyle(fontSize: 12))
                                  : _latitude != null && _longitude != null
                                      ? Text(
                                          'GPS: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                        )
                                      : const Text('GPS belum tercatat', style: TextStyle(fontSize: 12)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                              onPressed: _fetchGpsLocation,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Note / Tujuan
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(labelText: 'Tujuan / Keperluan Visit *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Tujuan wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // Catatan Tambahan
                      TextFormField(
                        controller: _catatanController,
                        decoration: const InputDecoration(labelText: 'Catatan / Hasil Kunjungan'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Foto Dokumentasi
                      const Text(
                        'Foto Dokumentasi',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _showImageSourceDialog,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: AppColors.soft,
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _newPhotoFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.medium),
                                  child: Image.file(_newPhotoFile!, fit: BoxFit.cover, width: double.infinity),
                                )
                              : (v.fotoUrl != null && v.fotoUrl!.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadius.medium),
                                      child: Image.network(
                                        v.fotoUrl!.startsWith('http')
                                            ? v.fotoUrl!
                                            : '${ApiConfig.imageReadUrl}${v.fotoUrl}',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (ctx, err, stack) => const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_a_photo, size: 36, color: AppColors.muted),
                                            SizedBox(height: 8),
                                            Text('Ketuk untuk mengganti foto', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    )
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo, size: 36, color: AppColors.muted),
                                        SizedBox(height: 8),
                                        Text('Ambil Foto atau Pilih dari Galeri', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                      ],
                                    ),
                        ),
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
