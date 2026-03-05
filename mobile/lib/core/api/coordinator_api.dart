import 'package:dio/dio.dart';
import '../config/api_config.dart';

class CoordinatorApi {
  CoordinatorApi(this._token);

  final String _token;
  late final Dio _dio = Dio(BaseOptions(
    baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
    connectTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $_token',
    },
  ));

  Future<Map<String, dynamic>> getDashboard() async {
    final r = await _dio.get('/coordinator/dashboard');
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getTeachers() async {
    final r = await _dio.get('/coordinator/teachers');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<List<Map<String, dynamic>>> getStudents({String? classId}) async {
    final params = classId != null ? {'class_id': classId} : null;
    final r = await _dio.get('/coordinator/students', queryParameters: params);
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> getStudent(String id) async {
    final r = await _dio.get('/coordinator/students/$id');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStudent(String id, Map<String, dynamic> data) async {
    final r = await _dio.put('/coordinator/students/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAttendance({required String date, String? classId}) async {
    final params = <String, String>{'att_date': date};
    if (classId != null) params['class_id'] = classId;
    final r = await _dio.get('/coordinator/attendance', queryParameters: params);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAttendanceHistory({String period = 'week', String? classId}) async {
    final params = <String, String>{'period': period};
    if (classId != null) params['class_id'] = classId;
    final r = await _dio.get('/coordinator/attendance/history', queryParameters: params);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStaffAttendance({required String date}) async {
    final r = await _dio.get('/coordinator/staff-attendance', queryParameters: {'att_date': date});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> upsertStaffAttendance({
    required String date,
    required List<Map<String, String>> records,
  }) async {
    final r = await _dio.put('/coordinator/staff-attendance', data: {'date': date, 'records': records});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStaffAttendanceHistory({String period = 'week'}) async {
    final r = await _dio.get('/coordinator/staff-attendance/history', queryParameters: {'period': period});
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getEnquiries({String? status}) async {
    final params = status != null ? {'status': status} : null;
    final r = await _dio.get('/coordinator/enquiries', queryParameters: params);
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> createEnquiry(Map<String, dynamic> data) async {
    final r = await _dio.post('/coordinator/enquiries', data: data);
    return r.data as Map<String, dynamic>;
  }
}
