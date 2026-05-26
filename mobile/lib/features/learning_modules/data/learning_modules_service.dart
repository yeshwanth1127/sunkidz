import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api/authenticated_dio.dart';

class LearningModulesService {
  LearningModulesService(String token, {OnUnauthorized? onUnauthorized})
      : _dio = createAuthenticatedDio(token: token, onUnauthorized: onUnauthorized);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> getModules() async {
    try {
      final response = await _dio.get('/learning-modules/');
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load modules: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getModuleVideos(String moduleId) async {
    try {
      final response = await _dio.get('/learning-modules/$moduleId/videos');
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load videos: $e');
    }
  }

  Future<Map<String, dynamic>> createModule(String name, String? description) async {
    try {
      final formData = FormData.fromMap({
        'name': name,
        if (description != null) 'description': description,
      });
      final response = await _dio.post('/learning-modules/', data: formData);
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw Exception('Failed to create module: $e');
    }
  }

  Future<Map<String, dynamic>> uploadVideo(
    String moduleId,
    PlatformFile file,
    String title,
    String? description,
  ) async {
    try {
      final multipartFile = MultipartFile.fromBytes(
        file.bytes!,
        filename: file.name,
      );
      final formData = FormData.fromMap({
        'title': title,
        if (description != null) 'description': description,
        'file': multipartFile,
      });
      final response = await _dio.post(
        '/learning-modules/$moduleId/videos/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  Future<void> deleteModule(String moduleId) async {
    try {
      await _dio.delete('/learning-modules/$moduleId');
    } catch (e) {
      throw Exception('Failed to delete module: $e');
    }
  }

  Future<void> deleteVideo(String videoId) async {
    try {
      await _dio.delete('/learning-modules/videos/$videoId');
    } catch (e) {
      throw Exception('Failed to delete video: $e');
    }
  }
}
