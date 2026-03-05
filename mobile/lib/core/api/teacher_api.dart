import 'package:dio/dio.dart';
import '../config/api_config.dart';

class TeacherApi {
  TeacherApi(this._token);

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
    final r = await _dio.get('/teacher/dashboard');
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyStudents() async {
    final r = await _dio.get('/teacher/students');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> getStudent(String id) async {
    final r = await _dio.get('/teacher/students/$id');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMarks(String studentId, {String academicYear = '2024-25'}) async {
    final r = await _dio.get('/teacher/marks/$studentId', queryParameters: {'academic_year': academicYear});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> upsertMarks(String studentId, {required String academicYear, required Map<String, dynamic> data}) async {
    final r = await _dio.put('/teacher/marks/$studentId', data: {'academic_year': academicYear, 'data': data});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMarksToParent(String studentId, {String academicYear = '2024-25'}) async {
    final r = await _dio.post('/teacher/marks/$studentId/send-to-parent', queryParameters: {'academic_year': academicYear});
    return r.data as Map<String, dynamic>;
  }

  // Attendance
  Future<Map<String, dynamic>> getAttendance({required String date}) async {
    final r = await _dio.get('/teacher/attendance', queryParameters: {'att_date': date});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> upsertAttendance({required String date, required List<Map<String, dynamic>> records}) async {
    final r = await _dio.put('/teacher/attendance', data: {'date': date, 'records': records});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAttendanceHistory({String period = 'week'}) async {
    final r = await _dio.get('/teacher/attendance/history', queryParameters: {'period': period});
    return r.data as Map<String, dynamic>;
  }
}
