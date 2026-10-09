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
      };
      if (isManager) {
        queryParams['is_manager'] = 'true';
      }
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
      final payload = <String, dynamic>{
        'user': sales,
        'cus_kode': customerKode,
        'tanggal': tanggal,
        'note': note,
        'catatan': catatan,
      };
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      final response = await _api.dio.post(ApiConfig.visit, data: payload);
      final isSuccess = response.data != null && response.data['success'] == true;

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

  Future<bool> updateVisit({
    required int id,
    required String note,
    required String catatan,
    required String tanggal,
    double? latitude,
    double? longitude,
    File? photo,
  }) async {
    try {
      final payload = <String, dynamic>{
        'note': note,
        'catatan': catatan,
        'tanggal': tanggal,
      };
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      final response = await _api.dio.put('${ApiConfig.visit}/$id', data: payload);
      final isSuccess = response.data != null && response.data['success'] == true;

      if (isSuccess && photo != null) {
        try {
          final formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(
              photo.path,
              filename: photo.path.split(Platform.pathSeparator).last,
            ),
          });
          await _api.dio.post('${ApiConfig.visit}/$id/photo', data: formData);
        } catch (_) {}
      }

      return isSuccess;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createVisitPlan({
    required String cusKode,
    required String user,
    required String tanggalPlan,
    required String note,
  }) async {
    try {
      final payload = <String, dynamic>{
        'cus_kode': cusKode,
        'user': user,
        'tanggal_plan': tanggalPlan,
        'note': note,
      };

      final response = await _api.dio.post(ApiConfig.visitPlan, data: payload);
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateVisitPlan({
    required int id,
    required String tanggalPlan,
    required String note,
    String? catatan,
  }) async {
    try {
      final payload = <String, dynamic>{
        'tanggal_plan': tanggalPlan,
        'note': note,
      };
      if (catatan != null) payload['catatan'] = catatan;

      final response = await _api.dio.put('${ApiConfig.visitPlan}/$id', data: payload);
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getRekapVisitPlanWA({
    required String user,
    required String cabang,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _api.dio.get(
        '/rekap-visit-plan/wa',
        queryParameters: {
          'user': user,
          'cabang': cabang,
          'tanggal_awal': startDate,
          'tanggal_akhir': endDate,
        },
      );
      return response.data?['wa_text']?.toString() ??
          response.data?['data']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> getSalesByCabang(String cabang) async {
    try {
      final response = await _api.dio.get(
        '/karyawan',
        queryParameters: {'cabang': cabang},
      );
      final raw = response.data?['data'] ?? response.data;
      if (raw is List) {
        final names = raw
            .where((x) =>
                x['kar_jabatan']?.toString().toUpperCase() == 'SALES')
            .map((x) => x['kar_nama']?.toString().trim() ?? '')
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        return names;
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
