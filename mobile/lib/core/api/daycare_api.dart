import 'package:dio/dio.dart';
import '../config/api_config.dart';

class DaycareApi {
  DaycareApi(this._token);

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

  /// Daycare staff: get students in their group(s)
  Future<Map<String, dynamic>> getMyStudents() async {
    final r = await _dio.get('/daycare/my-students');
    return r.data as Map<String, dynamic>;
  }

  /// Daycare staff: post a daily update (multipart for optional photo)
  Future<Map<String, dynamic>> createDailyUpdate({
    required String studentId,
    required String date,
    required String content,
    String? photoPath,
  }) async {
    final map = <String, dynamic>{
      'student_id': studentId,
      'date_str': date,
      'content': content,
    };
    if (photoPath != null && photoPath.isNotEmpty) {
      map['photo'] = await MultipartFile.fromFile(photoPath);
    }
    final formData = FormData.fromMap(map);
    final r = await _dio.post('/daycare/updates', data: formData);
    return r.data as Map<String, dynamic>;
  }

  /// Daycare staff: list updates they posted
  Future<List<Map<String, dynamic>>> listMyUpdates({
    String? studentId,
    String? fromDate,
    String? toDate,
  }) async {
    final params = <String, String>{};
    if (studentId != null) params['student_id'] = studentId;
    if (fromDate != null) params['from_date'] = fromDate;
    if (toDate != null) params['to_date'] = toDate;
    final r = await _dio.get('/daycare/updates', queryParameters: params);
    return List<Map<String, dynamic>>.from(r.data as List);
  }
}
