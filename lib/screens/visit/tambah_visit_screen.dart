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
import '../../repositories/customer_repository.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class TambahVisitScreen extends ConsumerStatefulWidget {
  const TambahVisitScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _fetchGpsLocation();
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
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
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

  Future<void> _selectCustomer() async {
    final customerRepo = ref.read(customerRepositoryProvider);
    final customers = await customerRepo.getRekapCalonCustomer();

    if (!mounted) return;

    final selected = await showModalBottomSheet<CustomerModel>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Pilih Customer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: customers.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = customers[i];
                  return ListTile(
                    title: Text(c.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.alamat, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(ctx, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _selectedCustomer = selected);
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

    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(visitRepositoryProvider);

    final ymd = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final success = await repo.createVisit(
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

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan visit berhasil dikirim'),
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
      appBar: AppBar(
        title: const Text('Tambah Kunjungan (Visit)'),
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
                      // Tanggal Kunjungan
                      const Text('Tanggal Visit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
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

                      // Pilih Customer
                      const Text('Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _selectCustomer,
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
                              Expanded(
                                child: Text(
                                  _selectedCustomer?.nama ?? 'Ketuk untuk pilih customer...',
                                  style: TextStyle(
                                    color: _selectedCustomer != null ? AppColors.ink : AppColors.muted,
                                    fontWeight: _selectedCustomer != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: AppColors.muted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Geolocation GPS Badge
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
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        )
                                      : const Text('GPS belum diperoleh', style: TextStyle(fontSize: 12)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                              onPressed: _fetchGpsLocation,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Note / Keperluan
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
                      const Text('Dokumentasi Foto', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _showImageSourceDialog,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _imageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.medium),
                                  child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
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

                // Tombol Simpan
                AppButton(
                  text: 'Kirim Laporan Visit',
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
