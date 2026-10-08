import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/visit_model.dart';
import '../providers/auth_provider.dart';

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return VisitRepository(api);
});

class VisitRepository {
  final ApiClient _api;

  VisitRepository(this._api);

  Future<List<VisitModel>> getVisitList({
    required String cabang,
    required String sales,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'user': sales,
        'tanggal_awal': startDate,
        'tanggal_akhir': endDate,
      };
      if (cabang.isNotEmpty) {
        queryParams['cabang'] = cabang;
      }

      final response = await _api.dio.get(
        ApiConfig.rekapVisit,
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => VisitModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<VisitModel>> getVisitPlanList({
    required String cabang,
    required String sales,
    required String startDate,
    required String endDate,
    bool isManager = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'user': sales,
        'tanggal_awal': startDate,
        'tanggal_akhir': endDate,
        if (isManager) 'is_manager': 'true',
      };
      if (cabang.isNotEmpty) {
        queryParams['cabang'] = cabang;
      }

      final response = await _api.dio.get(
        ApiConfig.rekapVisitPlan,
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => VisitModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> createVisit({
    required String tanggal,
    required String customerKode,
    required String customerNama,
    required String note,
    required String catatan,
    required String cabang,
    required String sales,
    double? latitude,
    double? longitude,
    File? photo,
  }) async {
    try {
      // 1. Backend homeController.js expects JSON body to POST /visits
      final payload = <String, dynamic>{
        'user': sales,
        'cus_kode': customerKode,
        'tanggal': tanggal,
        'note': note,
        'latitude': ?latitude,
        'longitude': ?longitude,
      };

      final response = await _api.dio.post(ApiConfig.visit, data: payload);
      final isSuccess = response.data != null && response.data['success'] == true;

      // 2. Jika ada foto dan id kunjungan berhasil didapat, upload ke /visits/:id/photo
      final createdId = response.data?['data']?['id'] ?? response.data?['id'];
      if (isSuccess && photo != null && createdId != null) {
        try {
          final formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(
              photo.path,
              filename: photo.path.split(Platform.pathSeparator).last,
            ),
          });
          await _api.dio.post('${ApiConfig.visit}/$createdId/photo', data: formData);
        } catch (_) {}
      }

      return isSuccess;
    } catch (_) {
      return false;
    }
  }
}
