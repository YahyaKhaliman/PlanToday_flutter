import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/web_reload.dart';

const String _kAppliedVersionKey = 'plantoday_applied_version';

class VersionState {
  final String currentVersion;
  final String currentBuildNumber;
  final String? latestVersion;
  final String? latestBuildNumber;
  final bool hasUpdate;
  final bool isChecking;
  final bool isMandatory;
  final String? apkUrl;
  final String? releaseNotes;

  // Unduhan APK In-App
  final bool isDownloading;
  final double downloadProgress; // 0.0 - 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String? downloadedApkPath;
  final String? downloadError;

  const VersionState({
    this.currentVersion = '1.0.0',
    this.currentBuildNumber = '1',
    this.latestVersion,
    this.latestBuildNumber,
    this.hasUpdate = false,
    this.isChecking = false,
    this.isMandatory = false,
    this.apkUrl,
    this.releaseNotes,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.downloadedApkPath,
    this.downloadError,
  });

  String get fullCurrentVersion => '$currentVersion+$currentBuildNumber';
  String get fullLatestVersion =>
      (latestVersion != null && latestBuildNumber != null)
          ? '$latestVersion+$latestBuildNumber'
          : (latestVersion ?? '');

  bool get isApkReady {
    if (kIsWeb) return false;
    if (downloadedApkPath == null || downloadedApkPath!.isEmpty) return false;
    try {
      return File(downloadedApkPath!).existsSync();
    } catch (_) {
      return false;
    }
  }

  String formatProgressText() {
    if (totalBytes <= 0) {
      if (downloadedBytes > 0) {
        return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(downloadProgress * 100).toInt()}%';
    }
    final currentMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final percent = (downloadProgress * 100).toInt();
    return '$percent% ($currentMb MB / $totalMb MB)';
  }

  VersionState copyWith({
    String? currentVersion,
    String? currentBuildNumber,
    String? latestVersion,
    String? latestBuildNumber,
    bool? hasUpdate,
    bool? isChecking,
    bool? isMandatory,
    String? apkUrl,
    String? releaseNotes,
    bool? isDownloading,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    String? downloadedApkPath,
    String? downloadError,
  }) {
    return VersionState(
      currentVersion: currentVersion ?? this.currentVersion,
      currentBuildNumber: currentBuildNumber ?? this.currentBuildNumber,
      latestVersion: latestVersion ?? this.latestVersion,
      latestBuildNumber: latestBuildNumber ?? this.latestBuildNumber,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      isChecking: isChecking ?? this.isChecking,
      isMandatory: isMandatory ?? this.isMandatory,
      apkUrl: apkUrl ?? this.apkUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedApkPath: downloadedApkPath ?? this.downloadedApkPath,
      downloadError: downloadError ?? this.downloadError,
    );
  }
}

class VersionNotifier extends Notifier<VersionState> {
  Timer? _pollingTimer;
  AppLifecycleListener? _lifecycleListener;
  DateTime? _lastCheckTime;
  CancelToken? _downloadCancelToken;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  @override
  VersionState build() {
    _initVersionInfo();
    ref.onDispose(() {
      _pollingTimer?.cancel();
      _lifecycleListener?.dispose();
      _downloadCancelToken?.cancel();
    });
    return const VersionState();
  }

  Future<void> _initVersionInfo() async {
    if (kIsWeb) {
      await _initWebVersionBaseline();
    } else {
      try {
        final info = await PackageInfo.fromPlatform();
        state = state.copyWith(
          currentVersion: info.version,
          currentBuildNumber: info.buildNumber,
        );
      } catch (_) {}
    }

    await checkForUpdate(force: true);

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      checkForUpdate();
    });

    _lifecycleListener?.dispose();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => checkForUpdate(),
    );

    if (kIsWeb) {
      registerWebFocusListener(() {
        checkForUpdate();
      });
    }
  }

  /// Di Flutter Web, `PackageInfo.fromPlatform()` mengambil `/version.json` dari server.
  /// Agar refresh biasa (F5) yang masih memuat JS lama dari cache tidak tertipu mengira
  /// sudah versi terbaru, kita simpan baseline versi yang benar-benar sudah di-hard-reload
  /// di SharedPreferences (`localStorage`).
  Future<void> _initWebVersionBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kAppliedVersionKey);
      final hasHardReloadParam = Uri.base.queryParameters.containsKey('_v');

      if (saved != null && saved.contains('+') && !hasHardReloadParam) {
        final parts = saved.split('+');
        state = state.copyWith(
          currentVersion: parts[0],
          currentBuildNumber: parts[1],
        );
        return;
      }

      // Kunjungan pertama kali atau baru saja selesai forceHardReload (ada ?_v=...)
      final remote = await _fetchRemoteVersionJson();
      if (remote != null) {
        final v = remote['version'] ?? '1.0.0';
        final b = remote['build_number'] ?? '1';
        await prefs.setString(_kAppliedVersionKey, '$v+$b');
        state = state.copyWith(
          currentVersion: v,
          currentBuildNumber: b,
        );
      }
    } catch (_) {}
  }

  Future<Map<String, String>?> _fetchRemoteVersionJson() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.base.resolve('version.json?t=$timestamp').toString();

    final response = await _dio.get(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      Map<String, dynamic>? decoded;
      if (response.data is Map) {
        decoded = Map<String, dynamic>.from(response.data as Map);
      } else if (response.data is String) {
        final raw = (response.data as String).trim();
        if (raw.startsWith('{')) {
          decoded = jsonDecode(raw) as Map<String, dynamic>;
        }
      }

      if (decoded != null) {
        return {
          'version': decoded['version']?.toString().trim() ?? '',
          'build_number': decoded['build_number']?.toString().trim() ?? '',
        };
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchRemoteLatestJson() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseCheckUrl = ApiConfig.updateCheckUrl;
    final separator = baseCheckUrl.contains('?') ? '&' : '?';
    final url = '$baseCheckUrl${separator}t=$timestamp';

    final response = await _dio.get(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      } else if (response.data is String) {
        final raw = (response.data as String).trim();
        if (raw.startsWith('{')) {
          return jsonDecode(raw) as Map<String, dynamic>;
        }
      }
    }
    return null;
  }

  Future<void> checkForUpdate({bool force = false}) async {
    if (state.isChecking || state.isDownloading) return;

    final now = DateTime.now();
    if (!force &&
        _lastCheckTime != null &&
        now.difference(_lastCheckTime!) < const Duration(seconds: 10)) {
      return;
    }
    _lastCheckTime = now;

    state = state.copyWith(isChecking: true);
    try {
      if (kIsWeb) {
        final remote = await _fetchRemoteVersionJson();
        if (remote != null) {
          final remoteVersion = remote['version'] ?? '';
          final remoteBuild = remote['build_number'] ?? '';

          final currentBuild = int.tryParse(state.currentBuildNumber) ?? 0;
          final targetBuild = int.tryParse(remoteBuild) ?? 0;

          final isNewer = (targetBuild > currentBuild) ||
              (remoteBuild.isNotEmpty &&
                  remoteBuild != state.currentBuildNumber) ||
              (remoteVersion.isNotEmpty &&
                  remoteVersion != state.currentVersion);

          if (isNewer) {
            state = state.copyWith(
              latestVersion: remoteVersion,
              latestBuildNumber: remoteBuild,
              hasUpdate: true,
              isChecking: false,
            );
            return;
          }
        }
      } else {
        final remote = await _fetchRemoteLatestJson();
        if (remote != null) {
          final remoteCode = remote['versionCode']?.toString() ?? '';
          final remoteName = remote['versionName']?.toString() ?? '';
          final mandatory = remote['mandatory'] == true;
          final apkUrl = remote['apkUrl']?.toString();
          final notes = remote['notes']?.toString();

          final currentBuild = int.tryParse(state.currentBuildNumber) ?? 0;
          final targetBuild = int.tryParse(remoteCode) ?? 0;

          final isNewer = targetBuild > currentBuild;

          if (isNewer) {
            state = state.copyWith(
              latestVersion:
                  remoteName.isNotEmpty ? remoteName : state.currentVersion,
              latestBuildNumber: remoteCode,
              hasUpdate: true,
              isMandatory: mandatory,
              apkUrl: apkUrl,
              releaseNotes: notes,
              isChecking: false,
            );
            return;
          }
        }
      }
      state = state.copyWith(isChecking: false);
    } catch (_) {
      state = state.copyWith(isChecking: false);
    }
  }

  void dismissUpdateNotification() {
    if (state.isMandatory || state.isDownloading) return;
    state = state.copyWith(hasUpdate: false);
  }

  /// Memulai unduhan APK langsung di latar belakang aplikasi
  Future<void> startDownloadApk() async {
    if (kIsWeb || state.isDownloading) return;

    final downloadUrl = state.apkUrl?.isNotEmpty == true
        ? state.apkUrl!
        : 'http://103.94.238.252:8182/releases/PlanToday-latest.apk';

    try {
      state = state.copyWith(
        isDownloading: true,
        downloadProgress: 0.0,
        downloadedBytes: 0,
        totalBytes: 0,
        downloadError: null,
      );

      final tempDir = await getTemporaryDirectory();
      final targetBuild = state.latestBuildNumber ?? 'latest';
      final apkFilePath = '${tempDir.path}/plantoday_update_$targetBuild.apk';
      final apkFile = File(apkFilePath);

      // Bersihkan file sisa jika sebelumnya ada unduhan gagal
      if (await apkFile.exists()) {
        try {
          await apkFile.delete();
        } catch (_) {}
      }

      _downloadCancelToken = CancelToken();

      await _dio.download(
        downloadUrl,
        apkFilePath,
        cancelToken: _downloadCancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            state = state.copyWith(
              downloadProgress: progress,
              downloadedBytes: received,
              totalBytes: total,
            );
          } else {
            state = state.copyWith(
              downloadedBytes: received,
            );
          }
        },
      );

      state = state.copyWith(
        isDownloading: false,
        downloadProgress: 1.0,
        downloadedApkPath: apkFilePath,
        downloadError: null,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        state = state.copyWith(isDownloading: false);
        return;
      }
      state = state.copyWith(
        isDownloading: false,
        downloadError: 'Gagal mengunduh APK: $e',
      );
    }
  }

  void cancelDownload() {
    _downloadCancelToken?.cancel();
    state = state.copyWith(isDownloading: false);
  }

  /// Memicu installer paket bawaan Android untuk menginstal berkas APK
  Future<OpenResult?> installApk() async {
    if (kIsWeb) return null;
    final path = state.downloadedApkPath;
    if (path == null || !File(path).existsSync()) {
      await startDownloadApk();
      if (state.downloadedApkPath == null) return null;
    }

    try {
      final result = await OpenFilex.open(
        state.downloadedApkPath!,
        type: 'application/vnd.android.package-archive',
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        downloadError: 'Gagal membuka installer APK: $e',
      );
      return null;
    }
  }

  /// Cadangan jika perangkat membatasi instalasi lokal langsung
  Future<void> openInBrowserFallback() async {
    final downloadUrl = state.apkUrl?.isNotEmpty == true
        ? state.apkUrl!
        : 'http://103.94.238.252:8182/releases/PlanToday-latest.apk';
    final uri = Uri.parse(downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> applyUpdateAndReload() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final targetVer = state.latestVersion ?? state.currentVersion;
        final targetBuild = state.latestBuildNumber ?? state.currentBuildNumber;
        await prefs.setString(_kAppliedVersionKey, '$targetVer+$targetBuild');
      } catch (_) {}
      reloadWebPage();
    } else {
      if (state.isApkReady) {
        await installApk();
      } else {
        await startDownloadApk();
      }
    }
  }
}

final versionProvider =
    NotifierProvider<VersionNotifier, VersionState>(() => VersionNotifier());
