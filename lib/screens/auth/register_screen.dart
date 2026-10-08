import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _namaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cabangController = TextEditingController();
  String _selectedJabatan = 'SALES';
  bool _isLoading = false;

  final List<String> _jabatanOptions = ['SALES', 'MANAGER', 'KURIR'];

  @override
  void dispose() {
    _namaController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _cabangController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final nama = _namaController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final cabang = _cabangController.text.trim();

    if (nama.isEmpty || username.isEmpty || password.isEmpty || cabang.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua kolom wajib diisi'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.post(
        '/register',
        data: {
          'nama': nama,
          'username': username,
          'password': password,
          'jabatan': _selectedJabatan,
          'cabang': cabang,
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.data != null && response.data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registrasi berhasil! Silakan login.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        } else {
          final msg = response.data?['message'] ?? 'Registrasi gagal';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg.toString()),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal registrasi: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrasi Akun'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ResponsiveContainer(
              maxWidth: 480,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'DAFTAR AKUN BARU',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nama Lengkap
                    const Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _namaController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'Nama lengkap'),
                    ),
                    const SizedBox(height: 16),

                    // Username
                    const Text('Username', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'Username'),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    const Text('Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'Password'),
                    ),
                    const SizedBox(height: 16),

                    // Jabatan Dropdown
                    const Text('Jabatan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedJabatan,
                      items: _jabatanOptions.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedJabatan = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Cabang
                    const Text('Cabang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _cabangController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(hintText: 'Contoh: JKT, BDG, SUB'),
                    ),
                    const SizedBox(height: 24),

                    // Tombol Daftar
                    AppButton(
                      text: 'Daftar Sekarang',
                      isLoading: _isLoading,
                      onPressed: _handleRegister,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
