import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive_helper.dart';
import '../providers/version_provider.dart';

class WebUpdateBanner extends ConsumerWidget {
  final Widget child;

  const WebUpdateBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionState = ref.watch(versionProvider);
    final isMobile = ResponsiveHelper.isMobile(context);

    return Stack(
      children: [
        child,
        SafeArea(
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            offset: versionState.hasUpdate ? Offset.zero : const Offset(0, -1.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              opacity: versionState.hasUpdate ? 1.0 : 0.0,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12.0 : 20.0,
                    vertical: isMobile ? 8.0 : 16.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 620,
                    ),
                    child: Material(
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(
                        isMobile ? AppRadius.large : AppRadius.large,
                      ),
                      color: AppColors.ink,
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 14.0 : 16.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            isMobile ? AppRadius.large : AppRadius.large,
                          ),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0F172A),
                              Color(0xFF1E293B),
                            ],
                          ),
                        ),
                        child: isMobile
                            ? _buildMobileContent(context, ref, versionState)
                            : _buildDesktopContent(context, ref, versionState),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Layout untuk perangkat Mobile (layar < 600px)
  Widget _buildMobileContent(
    BuildContext context,
    WidgetRef ref,
    VersionState versionState,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Pembaruan Sistem',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (versionState.latestVersion != null &&
                      versionState.latestVersion!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'v${versionState.latestVersion}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: () {
                ref.read(versionProvider.notifier).dismissUpdateNotification();
              },
              tooltip: 'Tutup',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Versi baru telah tersedia dengan pembaruan sistem terbaru. Silakan muat ulang halaman untuk menerapkannya.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            ref.read(versionProvider.notifier).applyUpdateAndReload();
          },
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Muat Ulang Sekarang'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(38),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Layout untuk Tablet dan Desktop (layar >= 600px)
  Widget _buildDesktopContent(
    BuildContext context,
    WidgetRef ref,
    VersionState versionState,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.system_update_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Pembaruan Sistem Tersedia',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (versionState.latestVersion != null &&
                      versionState.latestVersion!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'v${versionState.latestVersion}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Versi baru telah dirilis dengan peningkatan sistem. Silakan muat ulang halaman.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        ElevatedButton.icon(
          onPressed: () {
            ref.read(versionProvider.notifier).applyUpdateAndReload();
          },
          icon: const Icon(Icons.refresh_rounded, size: 15),
          label: const Text('Muat Ulang'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.white70,
            size: 18,
          ),
          onPressed: () {
            ref.read(versionProvider.notifier).dismissUpdateNotification();
          },
          tooltip: 'Tutup',
          splashRadius: 18,
        ),
      ],
    );
  }
}
