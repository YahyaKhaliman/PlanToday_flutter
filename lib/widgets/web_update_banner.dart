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

    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !versionState.hasUpdate,
          child: SafeArea(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              offset: versionState.hasUpdate
                  ? Offset.zero
                  : const Offset(0, -1.2),
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
                        maxWidth: isMobile ? double.infinity : 660,
                      ),
                      child: Material(
                        elevation: 10,
                        shadowColor: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        color: AppColors.ink,
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppRadius.large),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  isMobile ? 14.0 : 16.0,
                                  isMobile ? 12.0 : 14.0,
                                  isMobile ? 14.0 : 16.0,
                                  isMobile ? 12.0 : 14.0,
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
                                    height: 3.5,
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
        color: AppColors.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
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
                      'Pembaruan Sistem Tersedia',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildVersionBadge(versionState),
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
              tooltip: 'Nanti',
            ),
          ],
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11.5,
              height: 1.4,
            ),
            children: const [
              TextSpan(
                text: '⚠️ Simpan perubahan/pekerjaan Anda terlebih dahulu',
                style: TextStyle(
                  color: Color(0xFFFBBF24),
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text:
                    ' sebelum memuat ulang halaman agar pembaruan sistem diterapkan dengan aman.',
              ),
            ],
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

  Widget _buildDesktopContent(VersionState versionState) {
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
                  _buildVersionBadge(versionState),
                ],
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                  children: const [
                    TextSpan(
                      text:
                          '⚠️ Simpan perubahan/pekerjaan Anda terlebih dahulu',
                      style: TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' sebelum memuat ulang halaman untuk menerapkan pembaruan.',
                    ),
                  ],
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
          tooltip: 'Nanti',
          splashRadius: 18,
        ),
      ],
    );
  }
}
