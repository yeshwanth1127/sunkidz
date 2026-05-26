import 'dart:convert';

import 'package:dio/dio.dart';
import 'authenticated_dio.dart';
import '../config/api_config.dart';

class StoriesApi {
  StoriesApi(String token, {OnUnauthorized? onUnauthorized})
      : _token = token,
        _dio = createAuthenticatedDio(
          token: token,
          onUnauthorized: onUnauthorized,
        );

  final String _token;
  final Dio _dio;

  String fileUrl(String storyId) {
    final encoded = Uri.encodeQueryComponent(_token);
    return '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/stories/$storyId/file?token=$encoded';
  }

  Future<List<Map<String, dynamic>>> listStories({
    String? storyType,
    String? studentId,
    bool includeInactive = false,
  }) async {
    final r = await _dio.get(
      '/stories',
      queryParameters: {
        if (storyType != null) 'story_type': storyType,
        if (studentId != null) 'student_id': studentId,
        if (includeInactive) 'include_inactive': true,
      },
    );
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> uploadStory({
    required String title,
    required String storyType,
    String? description,
    required List<String> branchIds,
    required List<String> classIds,
    required MultipartFile file,
  }) async {
    final form = FormData.fromMap({
      'title': title,
      'story_type': storyType,
      if (description != null && description.isNotEmpty) 'description': description,
      'branch_ids': jsonEncode(branchIds),
      'class_ids': jsonEncode(classIds),
      'file': file,
    });
    final r = await _dio.post('/stories/upload', data: form);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> deleteStory(String id) async {
    await _dio.delete('/stories/$id');
  }

  Future<Map<String, dynamic>> updateStory(
    String id, {
    bool? isActive,
  }) async {
    final r = await _dio.patch(
      '/stories/$id',
      data: {if (isActive != null) 'is_active': isActive},
    );
    return Map<String, dynamic>.from(r.data as Map);
  }
}
