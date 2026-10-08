import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/permintaan_harga_model.dart';
import '../providers/auth_provider.dart';

final permintaanHargaRepositoryProvider =
    Provider<PermintaanHargaRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return PermintaanHargaRepository(api);
});

class PermintaanHargaRepository {
  final ApiClient _api;

  PermintaanHargaRepository(this._api);

  Future<List<PermintaanHargaItem>> getList({
    String? startDate,
    String? endDate,
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (status != null && status != 'ALL') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _api.dio.get(
        '/permintaan-harga',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) =>
                PermintaanHargaItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<PermintaanHargaDetail?> getDetail(String nomor) async {
    try {
      final response = await _api.dio.get('/permintaan-harga/$nomor');
      final data = response.data;
      if (data != null && data['data'] is Map<String, dynamic>) {
        return PermintaanHargaDetail.fromJson(
            data['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
