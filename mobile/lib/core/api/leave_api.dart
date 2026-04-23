import 'package:dio/dio.dart';
import '../config/api_config.dart';

class LeaveApi {
  LeaveApi(this._token);

  final String _token;
  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    ),
  );

  Future<Map<String, dynamic>> createLeave({
    required String studentId,
    required String reason,
    required String startDate,
    required String endDate,
  }) async {
    final r = await _dio.post('/leave', data: {
      'student_id': studentId,
      'reason': reason,
      'start_date': startDate,
      'end_date': endDate,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<Map<String, dynamic>>> listLeaves({String? status}) async {
    final r = await _dio.get(
      '/leave',
      queryParameters: {if (status != null && status.isNotEmpty) 'status': status},
    );
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> reviewLeave({
    required String leaveId,
    required String status,
    String? note,
  }) async {
    final r = await _dio.post('/leave/$leaveId/review', data: {
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }
}
