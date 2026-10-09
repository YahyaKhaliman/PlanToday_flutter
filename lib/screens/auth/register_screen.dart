import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _namaController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPass = false;
  bool _loading = false;
  String _deviceId = 'unknown';

  String _selectedJabatan = 'SALES';
  String _selectedCabang = 'PUSAT';

  final List<String> _jabatanOptions = ['SALES', 'KURIR'];
  final List<String> _cabangOptions = ['PUSAT', 'JATIM', 'JATENG', 'JAKARTA'];

  bool get _canSubmit =>
      _namaController.text.trim().isNotEmpty &&
      _passwordController.text.length >= 3 &&
      !_loading;

  @override
  void initState() {
    super.initState();
    _initDeviceId();
  }

  Future<void> _initDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        _deviceId = 'web-client';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'ios-device';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _deviceId = windowsInfo.deviceId;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _namaController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showGlassSelectModal({
    required String title,
    required String currentValue,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle Indicator
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

              // Header Modal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 22, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(
                  height: 16, color: Color.fromRGBO(15, 23, 42, 0.08)),
              const SizedBox(height: 8),

              // Option List
              ...options.map((opt) {
                final isActive = opt == currentValue;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF4F46E5)
                          : const Color.fromRGBO(15, 23, 42, 0.06),
                      width: isActive ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    trailing: isActive
                        ? const Icon(Icons.check_circle_rounded,
                            size: 20, color: Color(0xFF4F46E5))
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelected(opt);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final nama = _namaController.text.trim();
    final password = _passwordController.text;

    if (nama.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama dan password wajib diisi'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (password.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password minimal 3 karakter'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final api = ref.read(apiClientProvider);
      final payload = {
        'nama': nama,
        'password': password,
        'jabatan': _selectedJabatan,
        'cabang': _selectedCabang,
        'deviceId': _deviceId,
      };

      final res = await api.dio.post('/register', data: payload);

      if (mounted) {
        setState(() => _loading = false);

        if (res.data != null && res.data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  res.data['message']?.toString() ?? 'Registrasi Berhasil'),
              backgroundColor: AppColors.success,
            ),
          );

          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) context.go('/login');
          });
        } else {
          final msg = res.data?['message']?.toString() ?? 'Registrasi Gagal';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } on DioException catch (err) {
      if (mounted) {
        setState(() => _loading = false);
        final errorMsg =
            err.response?.data?['message'] ?? 'Gagal koneksi ke server';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan koneksi ke server'),
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ResponsiveContainer(
              maxWidth: 420,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // HERO HEADER BANNER persis Screenshot Image 2
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromRGBO(79, 70, 229, 0.12),
                          Color.fromRGBO(6, 182, 212, 0.06),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => context.pop(),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        const Color.fromRGBO(15, 23, 42, 0.08),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  size: 16,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'REGISTER',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(bounds),
                          child: const Text(
                            'PLANTODAY',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // FORM CARD persis Screenshot Image 2
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color.fromRGBO(15, 23, 42, 0.08),
                        width: 1,
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Daftar Akun Baru',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Label NAMA
                        const Text(
                          'NAMA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Input Container NAMA
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _namaController,
                            enabled: !_loading,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Nama',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Dropdown JABATAN
                        const Text(
                          'JABATAN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _loading
                              ? null
                              : () => _showGlassSelectModal(
                                    title: 'Pilih Jabatan',
                                    currentValue: _selectedJabatan,
                                    options: _jabatanOptions,
                                    onSelected: (val) =>
                                        setState(() => _selectedJabatan = val),
                                  ),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color.fromRGBO(15, 23, 42, 0.06),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedJabatan,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Dropdown CABANG
                        const Text(
                          'CABANG',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _loading
                              ? null
                              : () => _showGlassSelectModal(
                                    title: 'Pilih Cabang',
                                    currentValue: _selectedCabang,
                                    options: _cabangOptions,
                                    onSelected: (val) =>
                                        setState(() => _selectedCabang = val),
                                  ),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color.fromRGBO(15, 23, 42, 0.06),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedCabang,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Label PASSWORD
                        const Text(
                          'PASSWORD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Input Container PASSWORD
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _passwordController,
                                  obscureText: !_showPass,
                                  enabled: !_loading,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _handleRegister(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Password',
                                    hintStyle: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    setState(() => _showPass = !_showPass),
                                child: Icon(
                                  _showPass
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Tombol Register Gradient
                        Opacity(
                          opacity: _canSubmit ? 1.0 : 0.65,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _canSubmit ? _handleRegister : null,
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Register',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Link Footer Login
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _loading ? null : () => context.pop(),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text.rich(
                              TextSpan(
                                text: 'Sudah punya akun? ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Login',
                                    style: TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w800,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
