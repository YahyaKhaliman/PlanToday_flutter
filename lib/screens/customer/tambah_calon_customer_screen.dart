import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/customer_repository.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class TambahCalonCustomerScreen extends ConsumerStatefulWidget {
  const TambahCalonCustomerScreen({super.key});

  @override
  ConsumerState<TambahCalonCustomerScreen> createState() =>
      _TambahCalonCustomerScreenState();
}

class _TambahCalonCustomerScreenState
    extends ConsumerState<TambahCalonCustomerScreen> {
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(customerRepositoryProvider);

    final customer = CustomerModel(
      kode: '',
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

    final success = await repo.createCalonCustomer(
      customer,
      user?.nama ?? 'User',
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer berhasil ditambahkan'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
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
        title: const Text('Tambah Calon Customer'),
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
                        decoration: const InputDecoration(labelText: 'Nama Customer *'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _alamatController,
                        decoration: const InputDecoration(labelText: 'Alamat *'),
                        maxLines: 2,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Alamat wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _kotaController,
                        decoration: const InputDecoration(labelText: 'Kota *'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Kota wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _telpController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'No. Telp / WA *'),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'No telp wajib diisi' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cpController,
                              decoration: const InputDecoration(labelText: 'Contact Person *'),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'CP wajib diisi' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email *'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Email wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // Switch Korporasi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Entitas Korporasi / Perusahaan?',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _jenisUsahaController,
                          decoration: const InputDecoration(labelText: 'Jenis Usaha'),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _npwpController,
                          decoration: const InputDecoration(labelText: 'Nomor NPWP'),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _namaNpwpController,
                          decoration: const InputDecoration(labelText: 'Nama NPWP'),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _alamatNpwpController,
                          decoration: const InputDecoration(labelText: 'Alamat NPWP'),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _kotaNpwpController,
                          decoration: const InputDecoration(labelText: 'Kota NPWP'),
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
