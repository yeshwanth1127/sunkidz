import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api/authenticated_dio.dart';

class LearningModulesService {
  LearningModulesService(String token, {OnUnauthorized? onUnauthorized})
      : _dio = createAuthenticatedDio(token: token, onUnauthorized: onUnauthorized);

  final Dio _dio;

  Exception _mapError(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final detail = data['detail'] ?? data['message'] ?? data['error'];
        if (detail != null) {
          return Exception(detail.toString());
        }
      }
      final status = error.response?.statusCode;
      if (status != null) {
        return Exception('$fallback (HTTP $status)');
      }
      return Exception(fallback);
    }
    return Exception(error.toString());
  }

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


  Future<List<Map<String, dynamic>>> getModulesForStudent(String studentId) async {
    try {
      final response = await _dio.get('/learning-modules/for-student/$studentId');
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load modules for student: $e');
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
    int? schoolDay,
    String? academicYearStart, // YYYY-06-01
  ) async {
    try {
      final multipartFile = file.bytes != null
          ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
          : await MultipartFile.fromFile(file.path!, filename: file.name);
      final formData = FormData.fromMap({
        'title': title,
        if (description != null) 'description': description,
        'file': multipartFile,
        if (schoolDay != null) 'school_day': schoolDay,
        if (academicYearStart != null) 'academic_year_start_str': academicYearStart,
      });
      final response = await _dio.post(
        '/learning-modules/$moduleId/videos/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 30),
          receiveTimeout: const Duration(minutes: 30),
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

  Future<Map<String, dynamic>> assignModuleToClass(String moduleId, String classId) async {
    try {
      final response = await _dio.post('/learning-modules/$moduleId/assign-to-class/$classId');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw _mapError(e, 'Failed to assign module to class');
    }
  }

  Future<Map<String, dynamic>> assignModuleToBranch(String moduleId, String branchId) async {
    try {
      final response = await _dio.post('/learning-modules/$moduleId/assign-to-branch/$branchId');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw _mapError(e, 'Failed to assign module to branch');
    }
  }

  Future<void> unassignModuleFromClass(String moduleId, String classId) async {
    try {
      await _dio.delete('/learning-modules/$moduleId/unassign-from-class/$classId');
    } catch (e) {
      throw Exception('Failed to unassign module from class: $e');
    }
  }

  Future<void> unassignModuleFromBranch(String moduleId, String branchId) async {
    try {
      await _dio.delete('/learning-modules/$moduleId/unassign-from-branch/$branchId');
    } catch (e) {
      throw Exception('Failed to unassign module from branch: $e');
    }
  }

  Future<Map<String, dynamic>> fetchClassCalendar(
    String classId, {
    int? academicYear,
    bool refresh = false,
  }) async {
    try {
      final params = <String, dynamic>{'class_id': classId};
      if (academicYear != null) params['academic_year'] = academicYear;
      if (refresh) params['refresh'] = true;
      final response = await _dio.get('/learning-modules/class-calendar', queryParameters: params);
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw _mapError(e, 'Failed to fetch class calendar');
    }
  }

  /// Force the backend to re-pull the school calendar from the Google Sheet.
  Future<Map<String, dynamic>> refreshSchoolCalendar() async {
    try {
      final response = await _dio.post('/learning-modules/calendar/refresh');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw _mapError(e, 'Failed to refresh calendar from Google Sheet');
    }
  }

  Future<Map<String, dynamic>> uploadVideoForClass(
    String classId,
    PlatformFile file,
    String title,
    String? description,
    int schoolDay,
    String? academicYearStart, {
    String? subjectName,
  }) async {
    try {
      final multipartFile = file.bytes != null
          ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
          : await MultipartFile.fromFile(file.path!, filename: file.name);
      final formData = FormData.fromMap({
        'class_id': classId,
        'school_day': schoolDay,
        'title': title,
        if (subjectName != null && subjectName.isNotEmpty) 'subject_name': subjectName,
        if (description != null) 'description': description,
        'file': multipartFile,
        if (academicYearStart != null) 'academic_year_start_str': academicYearStart,
      });
      final response = await _dio.post(
        '/learning-modules/class-upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 30),
          receiveTimeout: const Duration(minutes: 30),
        ),
      );
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw _mapError(e, 'Failed to upload video');
    }
  }

  Future<Map<String, dynamic>> uploadVideoForAllClasses(
    String branchId,
    PlatformFile file,
    String title,
    String? subjectName,
    String? description,
    int schoolDay,
    String? academicYearStart,
  ) async {
    try {
      final multipartFile = file.bytes != null
          ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
          : await MultipartFile.fromFile(file.path!, filename: file.name);
      final formData = FormData.fromMap({
        'branch_id': branchId,
        'school_day': schoolDay,
        'title': title,
        if (subjectName != null && subjectName.isNotEmpty) 'subject_name': subjectName,
        if (description != null) 'description': description,
        'file': multipartFile,
        if (academicYearStart != null) 'academic_year_start_str': academicYearStart,
      });
      final response = await _dio.post(
        '/learning-modules/branch-upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 30),
          receiveTimeout: const Duration(minutes: 30),
        ),
      );
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw _mapError(e, 'Failed to upload video to all classes');
    }
  }

  Future<Map<String, dynamic>> fetchModuleCalendar(String moduleId, String classId, {int? academicYear}) async {
    try {
      final params = <String, dynamic>{'class_id': classId};
      if (academicYear != null) params['academic_year'] = academicYear;
      final response = await _dio.get('/learning-modules/$moduleId/calendar', queryParameters: params);
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw _mapError(e, 'Failed to fetch module calendar');
    }
  }

  Future<List<Map<String, dynamic>>> getDayFolders(
    String classId,
    int schoolDay,
    String academicYearStart,
  ) async {
    try {
      final year = int.parse(academicYearStart.substring(0, 4));
      final response = await _dio.get(
        '/learning-modules/day-folders',
        queryParameters: {'class_id': classId, 'school_day': schoolDay, 'academic_year': year},
      );
      if (response.data is List) return List<Map<String, dynamic>>.from(response.data);
      return [];
    } catch (e) {
      throw _mapError(e, 'Failed to load folders');
    }
  }

  Future<Map<String, dynamic>> createDayFolder(
    String classId,
    int schoolDay,
    String name,
    String academicYearStart,
  ) async {
    try {
      final formData = FormData.fromMap({
        'class_id': classId,
        'school_day': schoolDay,
        'name': name,
        'academic_year_start_str': academicYearStart,
      });
      final response = await _dio.post('/learning-modules/day-folders', data: formData);
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw _mapError(e, 'Failed to create folder');
    }
  }

  Future<void> renameDayFolder(String folderId, String newName) async {
    try {
      await _dio.patch(
        '/learning-modules/day-folders/$folderId',
        data: {'name': newName},
      );
    } catch (e) {
      throw _mapError(e, 'Failed to rename folder');
    }
  }

  Future<void> deleteDayFolder(String folderId) async {
    try {
      await _dio.delete('/learning-modules/day-folders/$folderId');
    } catch (e) {
      throw _mapError(e, 'Failed to delete folder');
    }
  }

  Future<List<Map<String, dynamic>>> getFolderContents(String folderId) async {
    try {
      final response = await _dio.get('/learning-modules/day-folders/$folderId/contents');
      if (response.data is List) return List<Map<String, dynamic>>.from(response.data);
      return [];
    } catch (e) {
      throw _mapError(e, 'Failed to load folder contents');
    }
  }

  Future<Map<String, dynamic>> uploadFolderContent(
    String folderId,
    PlatformFile file,
    String title,
    String? description,
  ) async {
    try {
      final multipartFile = file.bytes != null
          ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
          : await MultipartFile.fromFile(file.path!, filename: file.name);
      final formData = FormData.fromMap({
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        'file': multipartFile,
      });
      final response = await _dio.post(
        '/learning-modules/day-folders/$folderId/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 30),
          receiveTimeout: const Duration(minutes: 30),
        ),
      );
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw _mapError(e, 'Failed to upload content');
    }
  }

  Future<void> deleteFolderContent(String contentId) async {
    try {
      await _dio.delete('/learning-modules/day-folder-contents/$contentId');
    } catch (e) {
      throw _mapError(e, 'Failed to delete content');
    }
  }

}
