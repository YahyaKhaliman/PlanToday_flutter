import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/penawaran_model.dart';
import '../providers/auth_provider.dart';

final penawaranRepositoryProvider = Provider<PenawaranRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return PenawaranRepository(api);
});

class PenawaranRepository {
  final ApiClient _api;

  PenawaranRepository(this._api);

  Future<List<PenawaranListItem>> getPenawaranList({
    String? startDate,
    String? endDate,
    String? status,
    String? search,
    String? salesKode,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (status != null && status != 'ALL') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (salesKode != null && salesKode.isNotEmpty) queryParams['sales_kode'] = salesKode;

      final response = await _api.dio.get(
        '/penawaran',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => PenawaranListItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<PenawaranDetailItem>> getPenawaranDetail(String nomor) async {
    try {
      // Backend route is GET /penawaran/:nomor
      final response = await _api.dio.get('/penawaran/$nomor');
      final data = response.data;
      if (data != null && data['data'] != null) {
        // Backend returns: data: { header: {...}, details: [...] }
        final detailsRaw = data['data']['details'] ?? data['data'];
        if (detailsRaw is List) {
          return detailsRaw
              .map((item) => PenawaranDetailItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> approvePenawaran(String nomor, String note) async {
    try {
      final response = await _api.dio.post(
        '/penawaran/$nomor/approve',
        data: {'note': note},
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
