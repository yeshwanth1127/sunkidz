import 'package:dio/dio.dart';
import 'authenticated_dio.dart';
import '../config/api_config.dart';

/// Client for the branch Gallery module (`/gallery/*` on the backend).
///
/// Uploads can take a while for videos, so this client uses a longer
/// send/receive timeout than [createAuthenticatedDio]'s default.
class GalleryApi {
  GalleryApi(String token, {OnUnauthorized? onUnauthorized})
      : _token = token,
        _dio = createAuthenticatedDio(
          token: token,
          onUnauthorized: onUnauthorized,
        ) {
    _dio.options.sendTimeout = const Duration(minutes: 10);
    _dio.options.receiveTimeout = const Duration(minutes: 5);
  }

  final String _token;
  final Dio _dio;

  /// Authenticated URL for an item's file, usable directly in an
  /// `Image.network` / `VideoPlayerController.networkUrl`.
  String fileUrl(String itemId) {
    final encoded = Uri.encodeQueryComponent(_token);
    return '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/gallery/items/$itemId/file?token=$encoded';
  }

  Future<List<Map<String, dynamic>>> listItems({
    String? branchId,
    String? mediaType,
  }) async {
    final r = await _dio.get(
      '/gallery/items',
      queryParameters: {
        if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
        if (mediaType != null && mediaType.isNotEmpty) 'media_type': mediaType,
      },
    );
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<List<Map<String, dynamic>>> listBranchOptions() async {
    final r = await _dio.get('/gallery/branch-options');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> uploadItem({
    required String branchId,
    String? title,
    String? description,
    required MultipartFile file,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'branch_id': branchId,
      if (title != null && title.isNotEmpty) 'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'file': file,
    });
    final r = await _dio.post(
      '/gallery/items',
      data: form,
      onSendProgress: onProgress,
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> updateItem(
    String id, {
    String? title,
    String? description,
  }) async {
    final r = await _dio.patch(
      '/gallery/items/$id',
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      },
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> deleteItem(String id) async {
    await _dio.delete('/gallery/items/$id');
  }
}
