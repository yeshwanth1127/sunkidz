import 'package:dio/dio.dart';
import '../config/api_config.dart';

class AuthApi {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  ));

  Future<Map<String, dynamic>> login({
    String? email,
    String? password,
    String? admissionNumber,
    String? dateOfBirth,
  }) async {
    final body = <String, dynamic>{};
    if (admissionNumber != null && dateOfBirth != null) {
      body['admission_number'] = admissionNumber;
      body['date_of_birth'] = dateOfBirth;
    } else if (email != null && password != null) {
      body['email'] = email;
      body['password'] = password;
    } else {
      throw Exception('Provide either (email, password) or (admission_number, date_of_birth)');
    }
    final response = await _dio.post(
      '${ApiConfig.apiPrefix}/auth/login',
      data: body,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe(String token) async {
    final response = await _dio.get(
      '${ApiConfig.apiPrefix}/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data as Map<String, dynamic>;
  }
}
