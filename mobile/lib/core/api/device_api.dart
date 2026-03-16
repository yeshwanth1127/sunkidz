import 'package:dio/dio.dart';
import '../config/api_config.dart';

/// API for device/push registration.
class DeviceApi {
  DeviceApi(this._token);

  final String _token;
  late final Dio _dio = Dio(BaseOptions(
    baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
    connectTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $_token',
    },
  ));

  /// Register OneSignal subscription ID with the backend.
  Future<Map<String, dynamic>> registerDevice(String subscriptionId) async {
    final r = await _dio.post(
      '/device/register',
      data: {'onesignal_player_id': subscriptionId},
    );
    return r.data as Map<String, dynamic>;
  }
}
