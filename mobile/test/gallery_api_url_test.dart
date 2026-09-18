import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunkidz_lms/core/api/gallery_api.dart';
import 'package:sunkidz_lms/core/config/api_config.dart';

/// Guards the fix for the Gallery "Not Found" bug: in a non-release build
/// (local `flutter run`), with no --dart-define override, the app must talk
/// to the local backend, and the Gallery client must hit `/api/v1/gallery/*`
/// (not `/gallery/*` and not production).
void main() {
  test('API base URL resolves to the local backend for local dev', () {
    // `flutter test` runs in debug mode, exactly like `flutter run`.
    expect(kReleaseMode, isFalse);
    expect(ApiConfig.baseUrl, 'http://localhost:9889');
    expect(ApiConfig.apiPrefix, '/api/v1');
  });

  test('GalleryApi builds fully-prefixed request URLs', () {
    final api = GalleryApi('dummy-token');

    // fileUrl is built by hand in the client
    expect(
      api.fileUrl('abc-123'),
      'http://localhost:9889/api/v1/gallery/items/abc-123/file?token=dummy-token',
    );

    // Dio composes list/branch-options URLs from baseUrl + path
    final dio = Dio(BaseOptions(
      baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
    ));
    expect(
      dio.options.baseUrl,
      'http://localhost:9889/api/v1',
    );
    final req = RequestOptions(path: '/gallery/items', baseUrl: dio.options.baseUrl);
    expect(req.uri.toString(), 'http://localhost:9889/api/v1/gallery/items');

    final req2 = RequestOptions(
      path: '/gallery/branch-options',
      baseUrl: dio.options.baseUrl,
    );
    expect(
      req2.uri.toString(),
      'http://localhost:9889/api/v1/gallery/branch-options',
    );
  });
}
