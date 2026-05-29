import 'package:dio/dio.dart';
import '../../../core/api/authenticated_dio.dart';

class DailyRepertoryService {
  DailyRepertoryService(String token, {OnUnauthorized? onUnauthorized})
      : _dio = createAuthenticatedDio(token: token, onUnauthorized: onUnauthorized);

  final Dio _dio;

  Exception _mapError(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final detail = data['detail'] ?? data['message'] ?? data['error'];
        if (detail != null) return Exception(detail.toString());
      }
      final status = error.response?.statusCode;
      if (status != null) return Exception('$fallback (HTTP $status)');
      return Exception(fallback);
    }
    return Exception(error.toString());
  }

  Future<Map<String, dynamic>?> getReport(String classId, String date) async {
    try {
      final response = await _dio.get(
        '/daily-repertory/',
        queryParameters: {'class_id': classId, 'date': date},
      );
      if (response.data == null) return null;
      if (response.data is! Map) return null;
      final data = Map<String, dynamic>.from(response.data as Map);
      return data.isEmpty ? null : data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _mapError(e, 'Failed to load report');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<Map<String, dynamic>> createReport(
    String classId,
    String date,
    List<Map<String, dynamic>> slots,
  ) async {
    try {
      final response = await _dio.post(
        '/daily-repertory/',
        data: {'class_id': classId, 'report_date': date, 'slots': slots},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw _mapError(e, 'Failed to create report');
    }
  }

  Future<Map<String, dynamic>> updateReport(
    String reportId,
    List<Map<String, dynamic>> slots,
  ) async {
    try {
      final response = await _dio.put(
        '/daily-repertory/$reportId',
        data: {'slots': slots},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw _mapError(e, 'Failed to update report');
    }
  }

  Future<void> deleteReport(String reportId) async {
    try {
      await _dio.delete('/daily-repertory/$reportId');
    } catch (e) {
      throw _mapError(e, 'Failed to delete report');
    }
  }

  Future<Map<String, dynamic>> sendToParents(String reportId) async {
    try {
      final response = await _dio.post('/daily-repertory/$reportId/send-to-parents');
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw _mapError(e, 'Failed to send to parents');
    }
  }
}
