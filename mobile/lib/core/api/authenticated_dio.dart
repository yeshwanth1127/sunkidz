import 'package:dio/dio.dart';
import '../config/api_config.dart';

typedef OnUnauthorized = void Function();

bool _handlingUnauthorized = false;

/// Creates a Dio instance that calls [onUnauthorized] once on HTTP 401.
Dio createAuthenticatedDio({
  required String token,
  OnUnauthorized? onUnauthorized,
  String? baseUrl,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ),
  );

  if (onUnauthorized != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401) {
            if (!_handlingUnauthorized) {
              _handlingUnauthorized = true;
              try {
                onUnauthorized();
              } finally {
                _handlingUnauthorized = false;
              }
            }
          }
          handler.next(e);
        },
      ),
    );
  }

  return dio;
}
