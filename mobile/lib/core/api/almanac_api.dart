import 'package:dio/dio.dart';
import 'authenticated_dio.dart';

class AlmanacApi {
  AlmanacApi(String token, {OnUnauthorized? onUnauthorized})
      : _dio = createAuthenticatedDio(
          token: token,
          onUnauthorized: onUnauthorized,
        );

  final Dio _dio;

  Future<Map<String, dynamic>> getCalendar({
    required String branchId,
    String? classId,
    int? academicYear,
  }) async {
    final r = await _dio.get(
      '/almanac/calendar',
      queryParameters: {
        'branch_id': branchId,
        if (classId != null) 'class_id': classId,
        if (academicYear != null) 'academic_year': academicYear,
      },
    );
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listHolidays({
    String? branchId,
    int? academicYear,
  }) async {
    final r = await _dio.get(
      '/almanac/holidays',
      queryParameters: {
        if (branchId != null) 'branch_id': branchId,
        if (academicYear != null) 'academic_year': academicYear,
      },
    );
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> addHoliday({
    required String holidayDate,
    String? reason,
    String? branchId,
    String? academicYearStart,
  }) async {
    final r = await _dio.post(
      '/almanac/holidays',
      data: {
        'holiday_date': holidayDate,
        'reason': reason,
        if (branchId != null) 'branch_id': branchId,
        if (academicYearStart != null) 'academic_year_start': academicYearStart,
      },
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createEvent({
    String? branchId,
    required String eventDate,
    required String title,
    String? description,
    String? eventType,
    String? classId,
    bool isGlobal = false,
    String? academicYearStart,
  }) async {
    final r = await _dio.post(
      '/almanac/events',
      data: {
        if (branchId != null) 'branch_id': branchId,
        'event_date': eventDate,
        'title': title,
        'description': description,
        'event_type': eventType ?? 'event',
        'is_global': isGlobal,
        if (classId != null) 'class_id': classId,
        if (academicYearStart != null) 'academic_year_start': academicYearStart,
      },
    );
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listEvents({
    String? branchId,
    int? academicYear,
  }) async {
    final r = await _dio.get(
      '/almanac/events',
      queryParameters: {
        if (branchId != null) 'branch_id': branchId,
        if (academicYear != null) 'academic_year': academicYear,
      },
    );
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<void> deleteEvent(String eventId) async {
    await _dio.delete('/almanac/events/$eventId');
  }

  Future<void> deleteHoliday(String holidayId) async {
    await _dio.delete('/almanac/holidays/$holidayId');
  }
}
