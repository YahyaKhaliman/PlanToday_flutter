import 'dart:io';
import 'package:dio/dio.dart';
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

  Future<Map<String, dynamic>?> createPermintaanHargaCustomer(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _api.dio.post(
        '/permintaan-harga/customer',
        data: payload,
      );
      if (response.data != null && response.data['success'] == true) {
        return (response.data['data'] as Map<String, dynamic>?) ?? payload;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, int>> getStatusCounts({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      final response = await _api.dio.get(
        '/permintaan-harga/status-counts',
        queryParameters: queryParams,
      );
      final data = response.data;
      if (data != null && data['data'] is Map) {
        final map = <String, int>{};
        (data['data'] as Map).forEach((k, v) {
          map[k.toString().toUpperCase()] = (v as num?)?.toInt() ?? 0;
        });
        return map;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>?> createPermintaanHarga(
      Map<String, dynamic> payload) async {
    try {
      final response = await _api.dio.post(
        '/permintaan-harga',
        data: payload,
      );
      if (response.data != null && response.data['success'] == true) {
        return (response.data['data'] as Map<String, dynamic>?) ?? payload;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updatePermintaanHarga(
      String nomor, Map<String, dynamic> payload) async {
    try {
      final response = await _api.dio.put(
        '/permintaan-harga/$nomor',
        data: payload,
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePermintaanHarga(String nomor) async {
    try {
      final response = await _api.dio.delete('/permintaan-harga/$nomor');
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> copyPermintaanHarga(
      String nomor, Map<String, dynamic> payload) async {
    try {
      final response = await _api.dio.post(
        '/permintaan-harga/$nomor/copy',
        data: payload,
      );
      if (response.data != null && response.data['success'] == true) {
        return (response.data['data'] as Map<String, dynamic>?);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadImage(String nomor, File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(Platform.pathSeparator).last,
        ),
      });
      final response = await _api.dio.post(
        '/permintaan-harga/$nomor/image',
        data: formData,
      );
      return response.data?['data']?['url']?.toString() ??
          response.data?['data']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerSoHistory(String cusKode) async {
    try {
      final response = await _api.dio.get(
        '/penjualan/minta-harga-form/katalog/customer/$cusKode',
      );
      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => item as Map<String, dynamic>)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getKalkulasiOptions() async {
    try {
      final response = await _api.dio.get('/permintaan-harga/kalkulasi/options');
      if (response.data != null && response.data['data'] is Map) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
