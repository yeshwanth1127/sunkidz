import 'package:dio/dio.dart';
import 'authenticated_dio.dart';
import '../config/api_config.dart';

/// Client for the admission-document digitization module (`/documents/*` on
/// the backend). Shared by admin, teacher and coordinator — the backend
/// scopes what each role can see/do by their assigned branches, same as
/// [GalleryApi]. Parents have no access to any of these endpoints.
class DocumentsApi {
  DocumentsApi(String token, {OnUnauthorized? onUnauthorized})
      : _token = token,
        _dio = createAuthenticatedDio(
          token: token,
          onUnauthorized: onUnauthorized,
        ) {
    _dio.options.sendTimeout = const Duration(minutes: 5);
    _dio.options.receiveTimeout = const Duration(minutes: 2);
  }

  final String _token;
  final Dio _dio;

  /// Authenticated URL for a document's original file, usable directly in
  /// `Image.network` or opened externally for a PDF.
  String fileUrl(String documentId) {
    final encoded = Uri.encodeQueryComponent(_token);
    return '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/documents/$documentId/file?token=$encoded';
  }

  Future<List<Map<String, dynamic>>> listBranchOptions() async {
    final r = await _dio.get('/documents/branch-options');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<List<Map<String, dynamic>>> listClassOptions(String branchId) async {
    final r = await _dio.get(
      '/documents/class-options',
      queryParameters: {'branch_id': branchId},
    );
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<List<Map<String, dynamic>>> listDocuments({
    String? status,
    String? branchId,
  }) async {
    final r = await _dio.get(
      '/documents',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
      },
    );
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> getDocument(String id) async {
    final r = await _dio.get('/documents/$id');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> uploadDocument({
    required String branchId,
    required String classId,
    required MultipartFile file,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'branch_id': branchId,
      'class_id': classId,
      'doc_type': 'admission_form',
      'file': file,
    });
    final r = await _dio.post(
      '/documents',
      data: form,
      onSendProgress: onProgress,
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> retryOcr(String id) async {
    final r = await _dio.post('/documents/$id/retry-ocr');
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// Throws [DioException] with `response.statusCode == 409` and
  /// `response.data['detail']` containing `{message, candidates}` when a
  /// likely-duplicate student/parent is found — the caller should surface
  /// that list and let the reviewer either pick one or resubmit with
  /// `force_new_student` / `force_new_parent` set.
  Future<Map<String, dynamic>> applyDocument(
    String id,
    Map<String, dynamic> data,
  ) async {
    final r = await _dio.post('/documents/$id/apply', data: data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> rejectDocument(String id, {String? reason}) async {
    final r = await _dio.post(
      '/documents/$id/reject',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    return Map<String, dynamic>.from(r.data as Map);
  }
}
