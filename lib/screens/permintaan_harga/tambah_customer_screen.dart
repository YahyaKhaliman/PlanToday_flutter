import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class TambahCustomerPermintaanHargaScreen extends ConsumerStatefulWidget {
  final CustomerModel? initialCustomer;

  const TambahCustomerPermintaanHargaScreen({
    super.key,
    this.initialCustomer,
  });

  @override
  ConsumerState<TambahCustomerPermintaanHargaScreen> createState() =>
      _TambahCustomerPermintaanHargaScreenState();
}

class _TambahCustomerPermintaanHargaScreenState
    extends ConsumerState<TambahCustomerPermintaanHargaScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _kodeController;
  late final TextEditingController _namaController;
  late final TextEditingController _alamatController;
  late final TextEditingController _kotaController;
  late final TextEditingController _telpController;
  late final TextEditingController _cpController;
  late final TextEditingController _emailController;
  late final TextEditingController _jenisUsahaController;
  late final TextEditingController _npwpController;
  late final TextEditingController _namaNpwpController;
  late final TextEditingController _alamatNpwpController;
  late final TextEditingController _kotaNpwpController;

  String _korporasi = 'N';
  bool _isLoading = false;

  bool get _isEdit => widget.initialCustomer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCustomer;
    _kodeController = TextEditingController(text: c?.kode ?? '');
    _namaController = TextEditingController(text: c?.nama ?? '');
    _alamatController = TextEditingController(text: c?.alamat ?? '');
    _kotaController = TextEditingController(text: c?.kota ?? '');
    _telpController = TextEditingController(text: c?.telp ?? '');
    _cpController = TextEditingController(text: c?.cp ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _jenisUsahaController = TextEditingController(text: c?.jenisUsaha ?? '');
    _npwpController = TextEditingController(text: c?.npwp ?? '');
    _namaNpwpController = TextEditingController(text: c?.namaNpwp ?? '');
    _alamatNpwpController = TextEditingController(text: c?.alamatNpwp ?? '');
    _kotaNpwpController = TextEditingController(text: c?.kotaNpwp ?? '');
    _korporasi = (c?.korporasi == 'Y') ? 'Y' : 'N';
  }

  @override
  void dispose() {
    _kodeController.dispose();
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
      AppToast.error(context, 'Format email tidak valid');
      return;
    }

    if (_korporasi == 'Y' &&
        (_jenisUsahaController.text.trim().isEmpty ||
            _npwpController.text.trim().isEmpty)) {
      AppToast.error(
        context,
        'Jenis Usaha dan NPWP wajib diisi untuk Korporasi',
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_isEdit) {
      final c = widget.initialCustomer!;
      final customerRepo = ref.read(customerRepositoryProvider);
      final updatedCustomer = CustomerModel(
        id: c.id,
        kode: c.kode,
        nama: _namaController.text.trim(),
        alamat: _alamatController.text.trim(),
        kota: _kotaController.text.trim(),
        telp: _telpController.text.trim(),
        cp: _cpController.text.trim(),
        email: _emailController.text.trim(),
        korporasi: _korporasi,
        jenisUsaha: _jenisUsahaController.text.trim(),
        npwp: _npwpController.text.trim(),
        namaNpwp: _namaNpwpController.text.trim(),
        alamatNpwp: _alamatNpwpController.text.trim(),
        kotaNpwp: _kotaNpwpController.text.trim(),
      );

      final success = await customerRepo.updateCalonCustomer(
        c.kode,
        updatedCustomer,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          AppToast.success(context, 'Data customer berhasil diperbarui');
          context.pop(true);
        } else {
          AppToast.error(context, 'Gagal memperbarui data customer');
        }
      }
      return;
    }

    // Mode Tambah Customer Baru (POST /permintaan-harga/customer)
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
        AppToast.success(
          context,
          'Customer ${created['nama'] ?? payload['nama']} berhasil ditambahkan',
        );
        context.pop(created);
      } else {
        AppToast.error(context, 'Gagal menambahkan customer');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorporasi = _korporasi == 'Y';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/permintaan-harga');
            }
          },
        ),
        title: Text(_isEdit ? 'Edit Customer' : 'Tambah Customer'),
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

                      if (_isEdit) ...[
                        TextFormField(
                          controller: _kodeController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Kode Customer',
                            prefixIcon: Icon(
                              Icons.qr_code,
                              size: 20,
                              color: AppColors.muted,
                            ),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      TextFormField(
                        controller: _namaController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Customer *',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            size: 20,
                            color: AppColors.muted,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _alamatController,
                        decoration: const InputDecoration(
                          labelText: 'Alamat Lengkap *',
                          prefixIcon: Icon(
                            Icons.place_outlined,
                            size: 20,
                            color: AppColors.muted,
                          ),
                        ),
                        maxLines: 2,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Alamat wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _kotaController,
                        decoration: const InputDecoration(
                          labelText: 'Kota *',
                          prefixIcon: Icon(
                            Icons.location_city_outlined,
                            size: 20,
                            color: AppColors.muted,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Kota wajib diisi'
                            : null,
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
                                prefixIcon: Icon(
                                  Icons.phone_outlined,
                                  size: 20,
                                  color: AppColors.muted,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'No telp wajib diisi'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cpController,
                              decoration: const InputDecoration(
                                labelText: 'Contact Person *',
                                prefixIcon: Icon(
                                  Icons.badge_outlined,
                                  size: 20,
                                  color: AppColors.muted,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'CP wajib diisi'
                                  : null,
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
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            size: 20,
                            color: AppColors.muted,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Email wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 18),

                      // Switch Korporasi
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.soft,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Entitas Korporasi / Perusahaan?',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.ink,
                              ),
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
                            prefixIcon: Icon(
                              Icons.storefront_outlined,
                              size: 20,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _npwpController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor NPWP *',
                            prefixIcon: Icon(
                              Icons.credit_card_outlined,
                              size: 20,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _namaNpwpController,
                          decoration: const InputDecoration(
                            labelText: 'Nama Tertera di NPWP',
                            prefixIcon: Icon(
                              Icons.account_box_outlined,
                              size: 20,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _alamatNpwpController,
                          decoration: const InputDecoration(
                            labelText: 'Alamat NPWP',
                            prefixIcon: Icon(
                              Icons.home_work_outlined,
                              size: 20,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _kotaNpwpController,
                          decoration: const InputDecoration(
                            labelText: 'Kota NPWP',
                            prefixIcon: Icon(
                              Icons.map_outlined,
                              size: 20,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                AppButton(
                  text: _isEdit ? 'Simpan Perubahan' : 'Simpan Customer',
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
