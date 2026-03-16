import 'package:dio/dio.dart';
import '../config/api_config.dart';

/// API for notifications/messages - works for any authenticated user.
class MessagesApi {
  MessagesApi(this._token);

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

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final r = await _dio.get('/me/notifications');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<int> getUnreadCount() async {
    final r = await _dio.get('/me/notifications/unread_count');
    return r.data as int;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _dio.post('/me/notifications/mark_read/$notificationId');
  }
}
