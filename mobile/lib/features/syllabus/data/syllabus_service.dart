import 'package:dio/dio.dart';
import '../domain/models/syllabus_model.dart';
import '../../../core/api/api_client.dart';

class SyllabusService {
  final ApiClient _apiClient;

  SyllabusService(this._apiClient);

  // ========== Syllabus API Calls ==========

  Future<List<Syllabus>> fetchSyllabus({
    String? classId,
    String? uploadDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (classId != null) queryParams['class_id'] = classId;
      if (uploadDate != null) queryParams['upload_date'] = uploadDate;

      final response = await _apiClient.dio.get(
        '/syllabus',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Syllabus.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch syllabus');
    } catch (e) {
      throw Exception('Error fetching syllabus: $e');
    }
  }

  Future<Syllabus> getSyllabusById(String syllabusId) async {
    try {
      final response = await _apiClient.dio.get('/syllabus/$syllabusId');
      if (response.statusCode == 200) {
        return Syllabus.fromJson(response.data);
      }
      throw Exception('Failed to fetch syllabus');
    } catch (e) {
      throw Exception('Error fetching syllabus: $e');
    }
  }

  Future<Syllabus> uploadSyllabus({
    required String classId,
    required String title,
    required DateTime uploadDate,
    String? description,
    required MultipartFile file,
  }) async {
    try {
      final formData = FormData.fromMap({
        'class_id': classId,
        'title': title,
        'upload_date': uploadDate.toIso8601String(),
        if (description != null) 'description': description,
        'file': file,
      });

      final response = await _apiClient.dio.post(
        '/syllabus/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        return Syllabus.fromJson(response.data);
      }
      throw Exception('Failed to upload syllabus');
    } catch (e) {
      throw Exception('Error uploading syllabus: $e');
    }
  }

  Future<Syllabus> updateSyllabus({
    required String syllabusId,
    String? title,
    String? description,
    DateTime? uploadDate,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (uploadDate != null) data['upload_date'] = uploadDate.toIso8601String();

      final response = await _apiClient.dio.put(
        '/syllabus/$syllabusId',
        data: data,
      );

      if (response.statusCode == 200) {
        return Syllabus.fromJson(response.data);
      }
      throw Exception('Failed to update syllabus');
    } catch (e) {
      throw Exception('Error updating syllabus: $e');
    }
  }

  Future<void> deleteSyllabus(String syllabusId) async {
    try {
      final response = await _apiClient.dio.delete('/syllabus/$syllabusId');
      if (response.statusCode != 200) {
        throw Exception('Failed to delete syllabus');
      }
    } catch (e) {
      throw Exception('Error deleting syllabus: $e');
    }
  }

  // ========== Homework API Calls ==========

  Future<List<Homework>> fetchHomework({
    String? classId,
    String? uploadDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (classId != null) queryParams['class_id'] = classId;
      if (uploadDate != null) queryParams['upload_date'] = uploadDate;

      final response = await _apiClient.dio.get(
        '/homework',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Homework.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch homework');
    } catch (e) {
      throw Exception('Error fetching homework: $e');
    }
  }

  Future<Homework> getHomeworkById(String homeworkId) async {
    try {
      final response = await _apiClient.dio.get('/homework/$homeworkId');
      if (response.statusCode == 200) {
        return Homework.fromJson(response.data);
      }
      throw Exception('Failed to fetch homework');
    } catch (e) {
      throw Exception('Error fetching homework: $e');
    }
  }

  Future<Homework> uploadHomework({
    required String classId,
    required String title,
    required DateTime uploadDate,
    DateTime? dueDate,
    String? description,
    required MultipartFile file,
  }) async {
    try {
      final formData = FormData.fromMap({
        'class_id': classId,
        'title': title,
        'upload_date': uploadDate.toIso8601String(),
        if (dueDate != null) 'due_date': dueDate.toIso8601String(),
        if (description != null) 'description': description,
        'file': file,
      });

      final response = await _apiClient.dio.post(
        '/homework/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        return Homework.fromJson(response.data);
      }
      throw Exception('Failed to upload homework');
    } catch (e) {
      throw Exception('Error uploading homework: $e');
    }
  }

  Future<Homework> updateHomework({
    required String homeworkId,
    String? title,
    String? description,
    DateTime? uploadDate,
    DateTime? dueDate,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (uploadDate != null) data['upload_date'] = uploadDate.toIso8601String();
      if (dueDate != null) data['due_date'] = dueDate.toIso8601String();

      final response = await _apiClient.dio.put(
        '/homework/$homeworkId',
        data: data,
      );

      if (response.statusCode == 200) {
        return Homework.fromJson(response.data);
      }
      throw Exception('Failed to update homework');
    } catch (e) {
      throw Exception('Error updating homework: $e');
    }
  }

  Future<void> deleteHomework(String homeworkId) async {
    try {
      final response = await _apiClient.dio.delete('/homework/$homeworkId');
      if (response.statusCode != 200) {
        throw Exception('Failed to delete homework');
      }
    } catch (e) {
      throw Exception('Error deleting homework: $e');
    }
  }
}
