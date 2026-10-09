import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class TambahCustomerPermintaanHargaScreen extends ConsumerStatefulWidget {
  const TambahCustomerPermintaanHargaScreen({super.key});

  @override
  ConsumerState<TambahCustomerPermintaanHargaScreen> createState() =>
      _TambahCustomerPermintaanHargaScreenState();
}

class _TambahCustomerPermintaanHargaScreenState
    extends ConsumerState<TambahCustomerPermintaanHargaScreen> {
  final _formKey = GlobalKey<FormState>();

  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _kotaController = TextEditingController();
  final _telpController = TextEditingController();
  final _cpController = TextEditingController();
  final _emailController = TextEditingController();
  final _jenisUsahaController = TextEditingController();
  final _npwpController = TextEditingController();
  final _namaNpwpController = TextEditingController();
  final _alamatNpwpController = TextEditingController();
  final _kotaNpwpController = TextEditingController();

  String _korporasi = 'N';
  bool _isLoading = false;

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _kotaController.dispose();
    _telpController.dispose();
    _cpController.dispose();
    _emailController.dispose();
    _jenisUsahaController.dispose();
    _npwpController.dispose();
    _namaNpwpController.dispose();
    _alamatNpwpController.dispose();
    _kotaNpwpController.dispose();
    super.dispose();
  }

  bool _isBasicEmail(String val) {
    final v = val.trim();
    if (v.isEmpty || v == '-') return true;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isBasicEmail(_emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format email tidak valid'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_korporasi == 'Y' &&
        (_jenisUsahaController.text.trim().isEmpty ||
            _npwpController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jenis Usaha dan NPWP wajib diisi untuk Korporasi'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(permintaanHargaRepositoryProvider);

    final payload = {
      'nama': _namaController.text.trim(),
      'alamat': _alamatController.text.trim(),
      'kota': _kotaController.text.trim(),
      'cus_telp': _telpController.text.trim(),
      'cus_cp': _cpController.text.trim(),
      'cus_email': _emailController.text.trim(),
      'user_create': user?.nama ?? '',
      'cus_korporasi': _korporasi,
      'cus_jenisusaha': _jenisUsahaController.text.trim(),
      'cus_npwp': _npwpController.text.trim(),
      'cus_nama_npwp': _namaNpwpController.text.trim(),
      'cus_alamat_npwp': _alamatNpwpController.text.trim(),
      'cus_kota_npwp': _kotaNpwpController.text.trim(),
    };

    final created = await repo.createPermintaanHargaCustomer(payload);

    if (mounted) {
      setState(() => _isLoading = false);

      if (created != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer ${created['nama'] ?? payload['nama']} berhasil ditambahkan'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(created);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menambahkan customer'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorporasi = _korporasi == 'Y';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Customer (PH)'),
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
                      const Text(
                        'Informasi Utama',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _namaController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Customer *',
                          prefixIcon: Icon(Icons.person_outline, size: 20, color: AppColors.muted),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _alamatController,
                        decoration: const InputDecoration(
                          labelText: 'Alamat Lengkap *',
                          prefixIcon: Icon(Icons.place_outlined, size: 20, color: AppColors.muted),
                        ),
                        maxLines: 2,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Alamat wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _kotaController,
                        decoration: const InputDecoration(
                          labelText: 'Kota *',
                          prefixIcon: Icon(Icons.location_city_outlined, size: 20, color: AppColors.muted),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Kota wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _telpController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'No. Telp / WA *',
                                prefixIcon: Icon(Icons.phone_outlined, size: 20, color: AppColors.muted),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'No telp wajib diisi' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cpController,
                              decoration: const InputDecoration(
                                labelText: 'Contact Person *',
                                prefixIcon: Icon(Icons.badge_outlined, size: 20, color: AppColors.muted),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'CP wajib diisi' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppColors.muted),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Email wajib diisi' : null,
                      ),
                      const SizedBox(height: 18),

                      // Switch Korporasi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.soft,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Entitas Korporasi / Perusahaan?',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
                            ),
                            Switch(
                              value: isKorporasi,
                              activeThumbColor: AppColors.primary,
                              onChanged: (val) {
                                setState(() => _korporasi = val ? 'Y' : 'N');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (isKorporasi) ...[
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Data Perpajakan / NPWP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _jenisUsahaController,
                          decoration: const InputDecoration(
                            labelText: 'Jenis Usaha *',
                            prefixIcon: Icon(Icons.storefront_outlined, size: 20, color: AppColors.muted),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _npwpController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor NPWP *',
                            prefixIcon: Icon(Icons.credit_card_outlined, size: 20, color: AppColors.muted),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _namaNpwpController,
                          decoration: const InputDecoration(
                            labelText: 'Nama Tertera di NPWP',
                            prefixIcon: Icon(Icons.account_box_outlined, size: 20, color: AppColors.muted),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _alamatNpwpController,
                          decoration: const InputDecoration(
                            labelText: 'Alamat NPWP',
                            prefixIcon: Icon(Icons.home_work_outlined, size: 20, color: AppColors.muted),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _kotaNpwpController,
                          decoration: const InputDecoration(
                            labelText: 'Kota NPWP',
                            prefixIcon: Icon(Icons.map_outlined, size: 20, color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                AppButton(
                  text: 'Simpan Customer',
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
