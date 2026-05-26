import 'package:dio/dio.dart';
import 'authenticated_dio.dart';

class BirthdaysApi {
  BirthdaysApi(String token, {OnUnauthorized? onUnauthorized})
      : _dio = createAuthenticatedDio(token: token, onUnauthorized: onUnauthorized);

  final Dio _dio;

  Future<Map<String, dynamic>> today() async {
    final r = await _dio.get('/birthdays/today');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> upcoming({int days = 7}) async {
    final r = await _dio.get('/birthdays/upcoming', queryParameters: {'days': days});
    return Map<String, dynamic>.from(r.data as Map);
  }
}
