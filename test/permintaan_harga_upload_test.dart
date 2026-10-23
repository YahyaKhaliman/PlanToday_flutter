import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantoday_flutter/core/network/api_client.dart';
import 'package:plantoday_flutter/repositories/permintaan_harga_repository.dart';

void main() {
  setUp(() {
    dotenv.testLoad(mergeWith: {'API_BASE_URL': 'http://localhost'});
  });

  test('uploadImage formats base64 payload and calls base64 endpoint', () async {
    late RequestOptions capturedOptions;
    final apiClient = ApiClient();
    apiClient.dio.interceptors.clear();
    apiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedOptions = options;
          return handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'success': true,
                'data': {'url': 'http://example.com/img.jpg'},
              },
            ),
          );
        },
      ),
    );

    final repo = PermintaanHargaRepository(apiClient);

    final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final url = await repo.uploadImage(
      'MH.2026.0001',
      null,
      slot: 1,
      fileBytes: dummyBytes,
      fileName: 'sample.png',
    );

    expect(url, equals('http://example.com/img.jpg'));
    expect(
      capturedOptions.path,
      equals('/permintaan-harga/MH.2026.0001/gambar-base64/1'),
    );
    final data = capturedOptions.data as Map<String, dynamic>;
    expect(data['file_type'], equals('image/png'));
    expect(data['file_name'], equals('sample.png'));
    expect(
      data['file_base64'],
      equals('data:image/png;base64,${base64Encode(dummyBytes)}'),
    );
  });
}
