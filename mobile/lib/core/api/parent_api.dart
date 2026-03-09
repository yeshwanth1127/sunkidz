import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ParentApi {
  ParentApi(this._token);

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

  Future<Map<String, dynamic>> getMarksCards() async {
    final r = await _dio.get('/parent/marks-cards');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getChildren() async {
    final r = await _dio.get('/parent/children');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStudentAttendance(String studentId, {int days = 30}) async {
    final r = await _dio.get('/parent/student/$studentId/attendance', queryParameters: {'days': days});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStudentFees(String studentId) async {
    final r = await _dio.get('/parent/students/$studentId/fees');
    return r.data as Map<String, dynamic>;
  }
}
