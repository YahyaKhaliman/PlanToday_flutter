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
}
