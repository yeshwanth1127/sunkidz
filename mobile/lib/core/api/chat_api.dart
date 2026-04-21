import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ChatApi {
  ChatApi(this._token);

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

  Future<List<Map<String, dynamic>>> listThreads() async {
    final r = await _dio.get('/chat/threads');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> unreadCount() async {
    final r = await _dio.get('/chat/unread_count');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> startThread({
    required String otherUserId,
    String? studentId,
  }) async {
    final data = <String, dynamic>{'other_user_id': otherUserId};
    if (studentId != null) data['student_id'] = studentId;
    final r = await _dio.post('/chat/threads', data: data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<Map<String, dynamic>>> listMessages(
    String threadId, {
    String? afterId,
    int limit = 100,
  }) async {
    final r = await _dio.get(
      '/chat/threads/$threadId/messages',
      queryParameters: {
        if (afterId != null) 'after_id': afterId,
        'limit': limit,
      },
    );
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> sendMessage(String threadId, String body) async {
    final r = await _dio.post(
      '/chat/threads/$threadId/messages',
      data: {'body': body},
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> markRead(String threadId) async {
    await _dio.post('/chat/threads/$threadId/read');
  }

  Future<List<Map<String, dynamic>>> eligibleParentsForStaff({String? query}) async {
    final r = await _dio.get(
      '/chat/staff/eligible_parents',
      queryParameters: {if (query != null && query.isNotEmpty) 'q': query},
    );
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<List<Map<String, dynamic>>> eligibleStaffForParent() async {
    final r = await _dio.get('/chat/parent/eligible_staff');
    return List<Map<String, dynamic>>.from(r.data as List);
  }
}
