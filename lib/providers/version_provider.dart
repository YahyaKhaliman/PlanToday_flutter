import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/utils/web_reload.dart';

class VersionState {
  final String currentVersion;
  final String currentBuildNumber;
  final String? latestVersion;
  final String? latestBuildNumber;
  final bool hasUpdate;
  final bool isChecking;

  const VersionState({
    this.currentVersion = '1.0.0',
    this.currentBuildNumber = '1',
    this.latestVersion,
    this.latestBuildNumber,
    this.hasUpdate = false,
    this.isChecking = false,
  });

  String get fullCurrentVersion => '$currentVersion+$currentBuildNumber';
  String get fullLatestVersion =>
      (latestVersion != null && latestBuildNumber != null)
          ? '$latestVersion+$latestBuildNumber'
          : '';

  VersionState copyWith({
    String? currentVersion,
    String? currentBuildNumber,
    String? latestVersion,
    String? latestBuildNumber,
    bool? hasUpdate,
    bool? isChecking,
  }) {
    return VersionState(
      currentVersion: currentVersion ?? this.currentVersion,
      currentBuildNumber: currentBuildNumber ?? this.currentBuildNumber,
      latestVersion: latestVersion ?? this.latestVersion,
      latestBuildNumber: latestBuildNumber ?? this.latestBuildNumber,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      isChecking: isChecking ?? this.isChecking,
    );
  }
}

class VersionNotifier extends Notifier<VersionState> {
  Timer? _pollingTimer;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  @override
  VersionState build() {
    _initVersionInfo();
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    return const VersionState();
  }

  Future<void> _initVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      state = state.copyWith(
        currentVersion: info.version,
        currentBuildNumber: info.buildNumber,
      );
    } catch (_) {
      // Fallback ke default 1.0.0+1
    }

    // Cek update segera setelah startup
    await checkForUpdate();

    // Di web, pasang polling berkala setiap 10 menit
    if (kIsWeb) {
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(minutes: 10), (_) {
        checkForUpdate();
      });
    }
  }

  Future<void> checkForUpdate() async {
    if (!kIsWeb) return; // Khusus web membaca version.json

    state = state.copyWith(isChecking: true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Membaca version.json bawaan build Flutter Web dengan cache-buster
      final response = await _dio.get(
        '/version.json?t=$timestamp',
        options: Options(
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final remoteVersion = data['version']?.toString() ?? '';
        final remoteBuild = data['build_number']?.toString() ?? '';

        final currentBuild = int.tryParse(state.currentBuildNumber) ?? 0;
        final targetBuild = int.tryParse(remoteBuild) ?? 0;

        final isNewer = (targetBuild > currentBuild) ||
            (remoteBuild != state.currentBuildNumber && remoteBuild.isNotEmpty) ||
            (remoteVersion != state.currentVersion && remoteVersion.isNotEmpty);

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
      state = state.copyWith(isChecking: false);
    } catch (_) {
      state = state.copyWith(isChecking: false);
    }
  }

  void dismissUpdateNotification() {
    state = state.copyWith(hasUpdate: false);
  }

  void applyUpdateAndReload() {
    reloadWebPage();
  }
}

final versionProvider =
    NotifierProvider<VersionNotifier, VersionState>(() => VersionNotifier());
