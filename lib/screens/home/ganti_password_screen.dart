import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class GantiPasswordScreen extends ConsumerStatefulWidget {
  const GantiPasswordScreen({super.key});

  @override
  ConsumerState<GantiPasswordScreen> createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends ConsumerState<GantiPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final oldPass = _oldPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfirmasi password tidak cocok'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.post(
        '/ganti-password',
        data: {
          'oldPassword': oldPass,
          'newPassword': newPass,
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.data != null && response.data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password berhasil diperbarui'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        } else {
          final msg = response.data?['message'] ?? 'Gagal mengganti password';
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
            content: Text('Terjadi kesalahan: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 480,
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
                            'Ganti Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Perbarui kata sandi akun Anda',
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
                                'Amankan Akun Anda',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Pastikan password baru Anda kuat dan tidak mudah ditebak.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 18),

                              // Password Lama
                              TextFormField(
                                controller: _oldPasswordController,
                                obscureText: _obscureOld,
                                decoration: InputDecoration(
                                  labelText: 'Password Saat Ini *',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: const Color(0xFF64748B),
                                    ),
                                    onPressed: () => setState(() => _obscureOld = !_obscureOld),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Password lama wajib diisi' : null,
                              ),
                              const SizedBox(height: 14),

                              // Password Baru
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: _obscureNew,
                                decoration: InputDecoration(
                                  labelText: 'Password Baru *',
                                  prefixIcon: const Icon(Icons.key_outlined, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: const Color(0xFF64748B),
                                    ),
                                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.length < 5) ? 'Minimal 5 karakter' : null,
                              ),
                              const SizedBox(height: 14),

                              // Konfirmasi Password Baru
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                decoration: InputDecoration(
                                  labelText: 'Ulangi Password Baru *',
                                  prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: const Color(0xFF64748B),
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscureConfirm = !_obscureConfirm),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Konfirmasi password wajib diisi' : null,
                              ),
                              const SizedBox(height: 22),

                              // Tombol Simpan
                              AppButton(
                                text: 'Perbarui Password',
                                isLoading: _isLoading,
                                onPressed: _handleSubmit,
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
