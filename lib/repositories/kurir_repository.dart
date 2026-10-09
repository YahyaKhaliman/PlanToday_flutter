import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/kurir_model.dart';
import '../providers/auth_provider.dart';

final kurirRepositoryProvider = Provider<KurirRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return KurirRepository(api);
});

class KurirRepository {
  final ApiClient _api;

  KurirRepository(this._api);

  Future<List<KurirRencanaItem>> getRencanaKirim({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _api.dio.get(
        ApiConfig.kurirRencanaKirim,
        queryParameters: {
          'tanggal_awal': startDate,
          'tanggal_akhir': endDate,
        },
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => KurirRencanaItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<KurirRencanaItem>> getJadwalKirim({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _api.dio.get(
        ApiConfig.kurirKirim,
        queryParameters: {
          'tanggal_awal': startDate,
          'tanggal_akhir': endDate,
        },
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => KurirRencanaItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> createPengiriman(Map<String, dynamic> payload) async {
    try {
      final response = await _api.dio.post(
        '/kurir/pengiriman',
        data: payload,
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> prosesPengiriman({
    required int id,
    required String catatan,
    double? latitude,
    double? longitude,
    File? photo,
  }) async {
    try {
      final payload = <String, dynamic>{
        'status': 'delivered',
        'catatan': catatan,
      };
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      final resStatus = await _api.dio.patch(
        '/kurir/pengiriman/$id/status',
        data: payload,
      );

      final isSuccess = resStatus.data != null && resStatus.data['success'] == true;

      if (isSuccess && photo != null) {
        try {
          final formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(
              photo.path,
              filename: photo.path.split(Platform.pathSeparator).last,
            ),
          });
          await _api.dio.post('/kurir/pengiriman/$id/photo', data: formData);
        } catch (_) {}
      }

      return isSuccess;
    } catch (_) {
      return false;
    }
  }
}
