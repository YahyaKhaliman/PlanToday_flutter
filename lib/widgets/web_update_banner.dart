import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive_helper.dart';
import '../providers/version_provider.dart';

class WebUpdateBanner extends ConsumerStatefulWidget {
  final Widget child;

  const WebUpdateBanner({super.key, required this.child});

  @override
  ConsumerState<WebUpdateBanner> createState() => _WebUpdateBannerState();
}

class _WebUpdateBannerState extends ConsumerState<WebUpdateBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final versionState = ref.watch(versionProvider);
    final isMobile = ResponsiveHelper.isMobile(context);

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: versionState.hasUpdate
                ? _buildTopBanner(context, versionState, isMobile)
                : const SizedBox(width: double.infinity, height: 0),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildTopBanner(
    BuildContext context,
    VersionState versionState,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.18),
            width: 1.0,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.card,
            AppColors.bgTop,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12.0 : 20.0,
                vertical: isMobile ? 8.0 : 9.0,
              ),
              child: isMobile
                  ? _buildMobileContent(versionState)
                  : _buildDesktopContent(versionState),
            ),
            // Smooth Moving Underline (Animated Shimmer Bar)
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, _) {
                final t = _shimmerController.value;
                return Container(
                  height: 3.0,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-2.0 + (t * 4.0), 0),
                      end: Alignment(-0.5 + (t * 4.0), 0),
                      colors: const [
                        AppColors.primary,
                        AppColors.accent,
                        Color(0xFF38BDF8),
                        AppColors.accent,
                        AppColors.primary,
                      ],
                      tileMode: TileMode.mirror,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionBadge(VersionState versionState) {
    final label = versionState.fullLatestVersion.isNotEmpty
        ? 'v${versionState.fullLatestVersion}'
        : (versionState.latestVersion?.isNotEmpty == true
            ? 'v${versionState.latestVersion}'
            : '');
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildGradientReloadButton({
    required String label,
    required VoidCallback onPressed,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      height: fullWidth ? 38 : 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: AppShadows.button,
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh_rounded, size: 15, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileContent(VersionState versionState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Pembaruan Sistem Tersedia',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildVersionBadge(versionState),
                ],
              ),
            ),
            if (!versionState.isMandatory)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.muted,
                  size: 18,
                ),
                onPressed: () {
                  ref.read(versionProvider.notifier).dismissUpdateNotification();
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (kIsWeb)
          RichText(
            text: const TextSpan(
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '⚠️ Simpan pekerjaan Anda terlebih dahulu',
                  style: TextStyle(
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' sebelum memuat ulang halaman.',
                ),
              ],
            ),
          )
        else
          Text(
            versionState.releaseNotes?.isNotEmpty == true
                ? versionState.releaseNotes!
                : (versionState.isMandatory
                    ? '⚠️ Pembaruan penting wajib diunduh untuk melanjutkan pemakaian aplikasi.'
                    : 'File APK versi baru telah tersedia. Unduh dan pasang pembaruan sekarang.'),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        const SizedBox(height: 8),
        _buildGradientReloadButton(
          label: kIsWeb ? 'Muat Ulang Sekarang' : 'Unduh & Pasang Update (APK)',
          fullWidth: true,
          onPressed: () {
            ref.read(versionProvider.notifier).applyUpdateAndReload();
          },
        ),
      ],
    );
  }

  Widget _buildDesktopContent(VersionState versionState) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.system_update_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              const Text(
                'Pembaruan Sistem Tersedia',
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  letterSpacing: -0.2,
                ),
              ),
              _buildVersionBadge(versionState),
              const SizedBox(width: 12),
              Expanded(
                child: kIsWeb
                    ? RichText(
                        overflow: TextOverflow.ellipsis,
                        text: const TextSpan(
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11.5,
                          ),
                          children: [
                            TextSpan(
                              text: '⚠️ Simpan pekerjaan Anda terlebih dahulu',
                              style: TextStyle(
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' sebelum memuat ulang untuk menerapkan pembaruan.',
                            ),
                          ],
                        ),
                      )
                    : Text(
                        versionState.releaseNotes?.isNotEmpty == true
                            ? versionState.releaseNotes!
                            : 'Pembaruan aplikasi versi baru telah tersedia di server.',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _buildGradientReloadButton(
          label: kIsWeb ? 'Muat Ulang' : 'Unduh APK',
          onPressed: () {
            ref.read(versionProvider.notifier).applyUpdateAndReload();
          },
        ),
        if (!versionState.isMandatory) ...[
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.muted,
              size: 18,
            ),
            onPressed: () {
              ref.read(versionProvider.notifier).dismissUpdateNotification();
            },
            splashRadius: 18,
          ),
        ],
      ],
    );
  }
}
