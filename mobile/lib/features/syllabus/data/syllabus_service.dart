import 'package:dio/dio.dart';
import '../domain/models/syllabus_model.dart';
import '../../../core/api/api_client.dart';

class SyllabusService {
  final ApiClient _apiClient;

  SyllabusService(this._apiClient);

  // ========== Syllabus API Calls ==========

  Future<SyllabusCalendar> fetchSyllabusCalendar({
    required String classId,
    int? academicYear,
  }) async {
    try {
      final queryParams = <String, dynamic>{'class_id': classId};
      if (academicYear != null) queryParams['academic_year'] = academicYear;
      final response = await _apiClient.dio.get(
        '/syllabus/calendar',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        return SyllabusCalendar.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Failed to fetch syllabus calendar');
    } catch (e) {
      throw Exception('Error fetching syllabus calendar: $e');
    }
  }

  Future<List<Syllabus>> fetchSyllabus({
    String? classId,
    int? schoolDay,
    String? academicYearStart,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (classId != null) queryParams['class_id'] = classId;
      if (schoolDay != null) queryParams['school_day'] = schoolDay;
      if (academicYearStart != null) queryParams['academic_year_start'] = academicYearStart;
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

  Future<List<String>> fetchGradeNames() async {
    try {
      final response = await _apiClient.dio.get('/syllabus/grades');
      if (response.statusCode == 200) {
        return (response.data as List).map((e) => e.toString()).toList();
      }
      throw Exception('Failed to fetch grades');
    } catch (e) {
      throw Exception('Error fetching grades: $e');
    }
  }

  Future<Syllabus> uploadSyllabus({
    String? classId,
    String? className,
    required String title,
    required int schoolDay,
    String? academicYearStart,
    String? description,
    required MultipartFile file,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (classId != null) 'class_id': classId,
        if (className != null) 'class_name': className,
        'title': title,
        'school_day': schoolDay,
        if (academicYearStart != null) 'academic_year_start_str': academicYearStart,
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
    int? schoolDay,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (schoolDay != null) data['school_day'] = schoolDay;
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

  Future<void> addSyllabusHoliday({
    required DateTime holidayDate,
    String? reason,
  }) async {
    try {
      await _apiClient.dio.post('/syllabus/holidays', data: {
        'holiday_date': holidayDate.toIso8601String().split('T')[0],
        if (reason != null) 'reason': reason,
      });
    } catch (e) {
      throw Exception('Error adding holiday: $e');
    }
  }

  Future<void> addSyllabusHolidayRange({
    required DateTime startDate,
    int numDays = 1,
    String? reason,
  }) async {
    try {
      await _apiClient.dio.post('/syllabus/holidays/range', data: {
        'start_date': startDate.toIso8601String().split('T')[0],
        'num_days': numDays,
        if (reason != null) 'reason': reason,
      });
    } catch (e) {
      throw Exception('Error adding holidays: $e');
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

  // ========== Gallery API Calls ==========

  Future<List<GalleryItem>> fetchGallery({
    String? classId,
    String? uploadDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (classId != null) queryParams['class_id'] = classId;
      if (uploadDate != null) queryParams['upload_date'] = uploadDate;

      final response = await _apiClient.dio.get(
        '/gallery',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => GalleryItem.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch gallery');
    } catch (e) {
      throw Exception('Error fetching gallery: $e');
    }
  }

  Future<GalleryItem> uploadGalleryImage({
    required String classId,
    required DateTime uploadDate,
    String? title,
    String? description,
    required MultipartFile file,
  }) async {
    try {
      final formData = FormData.fromMap({
        'class_id': classId,
        'upload_date': uploadDate.toIso8601String(),
        if (title != null && title.isNotEmpty) 'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        'file': file,
      });

      final response = await _apiClient.dio.post('/gallery/upload', data: formData);

      if (response.statusCode == 200) {
        return GalleryItem.fromJson(response.data);
      }
      throw Exception('Failed to upload gallery image');
    } catch (e) {
      throw Exception('Error uploading gallery image: $e');
    }
  }
}
