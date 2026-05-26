import 'package:dio/dio.dart';
import 'authenticated_dio.dart';

class DiaryApi {
  DiaryApi(String token, {OnUnauthorized? onUnauthorized})
      : _dio = createAuthenticatedDio(
          token: token,
          onUnauthorized: onUnauthorized,
        );

  final Dio _dio;

  Future<Map<String, dynamic>> upsertEntry({
    required String classId,
    required String entryDate,
    String? studentId,
    String? remarks,
    String? activities,
    String? homeworkNotes,
  }) async {
    final r = await _dio.post(
      '/diary/entries',
      data: {
        'class_id': classId,
        'entry_date': entryDate,
        if (studentId != null) 'student_id': studentId,
        'remarks': remarks,
        'activities': activities,
        'homework_notes': homeworkNotes,
      },
    );
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteEntry(String entryId) async {
    await _dio.delete('/diary/entries/$entryId');
  }

  Future<List<Map<String, dynamic>>> listClassStudents(String classId) async {
    final r = await _dio.get('/diary/classes/$classId/students');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<List<Map<String, dynamic>>> listEntries({
    required String classId,
    String? studentId,
    String? fromDate,
    String? toDate,
  }) async {
    final r = await _dio.get(
      '/diary/entries',
      queryParameters: {
        'class_id': classId,
        if (studentId != null) 'student_id': studentId,
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
      },
    );
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<List<Map<String, dynamic>>> listParentEntries({
    String? fromDate,
    String? toDate,
  }) async {
    final r = await _dio.get(
      '/diary/parent/entries',
      queryParameters: {
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
      },
    );
    return List<Map<String, dynamic>>.from(r.data as List);
  }
}
