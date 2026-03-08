import 'package:dio/dio.dart';
import '../config/api_config.dart';

class AdminApi {
  AdminApi(this._token);

  final String _token;
  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
      connectTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    ),
  );

  // Branches
  Future<List<Map<String, dynamic>>> getBranches() async {
    final r = await _dio.get('/admin/branches');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> getBranch(String id) async {
    final r = await _dio.get('/admin/branches/$id');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createBranch({
    required String name,
    String? code,
    String? address,
    String? contactNo,
    String status = 'active',
  }) async {
    final r = await _dio.post(
      '/admin/branches',
      data: {
        'name': name,
        if (code != null) 'code': code,
        'address': address,
        'contact_no': contactNo,
        'status': status,
      },
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBranch(
    String id, {
    String? name,
    String? address,
    String? contactNo,
    String? status,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    if (contactNo != null) data['contact_no'] = contactNo;
    if (status != null) data['status'] = status;
    final r = await _dio.put('/admin/branches/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteBranch(String id) async {
    await _dio.delete('/admin/branches/$id');
  }

  // Classes (Grades)
  Future<List<Map<String, dynamic>>> getClasses({String? branchId}) async {
    final q = branchId != null ? '?branch_id=$branchId' : '';
    final r = await _dio.get('/admin/classes$q');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> createClass({
    required String branchId,
    required String name,
    String academicYear = '2024-25',
  }) async {
    final r = await _dio.post(
      '/admin/classes',
      data: {
        'branch_id': branchId,
        'name': name,
        'academic_year': academicYear,
      },
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateClass(
    String id, {
    String? name,
    String? academicYear,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (academicYear != null) data['academic_year'] = academicYear;
    final r = await _dio.put('/admin/classes/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteClass(String id) async {
    await _dio.delete('/admin/classes/$id');
  }

  // Users (Teachers, Coordinators)
  Future<List<Map<String, dynamic>>> getUsers({
    String? role,
    String? branchId,
  }) async {
    final params = <String, String>{};
    if (role != null) params['role'] = role;
    if (branchId != null) params['branch_id'] = branchId;
    final q = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final r = await _dio.get('/admin/users$q');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> createUser({
    String? email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
  }) async {
    final r = await _dio.post(
      '/admin/users',
      data: {
        if (email != null) 'email': email,
        'password': password,
        'full_name': fullName,
        'role': role,
        if (phone != null) 'phone': phone,
      },
    );
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteUser(String id) async {
    await _dio.delete('/admin/users/$id');
  }

  Future<void> deleteStudent(String id) async {
    await _dio.delete('/admin/students/$id');
  }

  Future<Map<String, dynamic>> toggleBusOpt(String studentId) async {
    final r = await _dio.post('/admin/students/$studentId/toggle-bus-opt');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transferStudentBranch(
    String studentId, {
    required String branchId,
    String? classId,
  }) async {
    final r = await _dio.put(
      '/admin/students/$studentId/branch',
      data: {'branch_id': branchId, if (classId != null) 'class_id': classId},
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateUser(
    String id, {
    String? email,
    String? fullName,
    String? phone,
    String? isActive,
  }) async {
    final data = <String, dynamic>{};
    if (email != null) data['email'] = email;
    if (fullName != null) data['full_name'] = fullName;
    if (phone != null) data['phone'] = phone;
    if (isActive != null) data['is_active'] = isActive;
    final r = await _dio.put('/admin/users/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  // Assignments (Reassign)
  Future<List<Map<String, dynamic>>> getAssignments({String? branchId}) async {
    final q = branchId != null ? '?branch_id=$branchId' : '';
    final r = await _dio.get('/admin/assignments$q');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> createAssignment({
    required String userId,
    required String branchId,
    String? classId,
  }) async {
    final r = await _dio.post(
      '/admin/assignments',
      data: {
        'user_id': userId,
        'branch_id': branchId,
        if (classId != null) 'class_id': classId,
      },
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAssignment(
    String id, {
    String? branchId,
    String? classId,
  }) async {
    final data = <String, dynamic>{};
    if (branchId != null) data['branch_id'] = branchId;
    if (classId != null) data['class_id'] = classId;
    final r = await _dio.put('/admin/assignments/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteAssignment(String id) async {
    await _dio.delete('/admin/assignments/$id');
  }

  // Enquiries
  Future<List<Map<String, dynamic>>> getEnquiries({
    String? status,
    String? branchId,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (branchId != null) params['branch_id'] = branchId;
    final q = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final r = await _dio.get('/admin/enquiries$q');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> getEnquiry(String id) async {
    final r = await _dio.get('/admin/enquiries/$id');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createEnquiry(Map<String, dynamic> data) async {
    final r = await _dio.post('/admin/enquiries', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectEnquiry(String enquiryId) async {
    final r = await _dio.post('/admin/enquiries/$enquiryId/reject');
    return r.data as Map<String, dynamic>;
  }

  // Students
  Future<Map<String, dynamic>> getStudent(String id) async {
    final r = await _dio.get('/admin/students/$id');
    return r.data as Map<String, dynamic>;
  }

  // Admissions / Students (convert enquiry to admission)
  Future<List<Map<String, dynamic>>> getAdmissions({
    String? branchId,
    String? classId,
  }) async {
    final params = <String, String>{};
    if (branchId != null) params['branch_id'] = branchId;
    if (classId != null) params['class_id'] = classId;
    final q = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final r = await _dio.get('/admin/admissions$q');
    return List<Map<String, dynamic>>.from(r.data as List);
  }

  Future<Map<String, dynamic>> createAdmissionFromEnquiry(
    Map<String, dynamic> data,
  ) async {
    final r = await _dio.post('/admin/admissions/from-enquiry', data: data);
    return r.data as Map<String, dynamic>;
  }

  // Marks Cards
  Future<Map<String, dynamic>> getMarks(
    String studentId, {
    String academicYear = '2024-25',
  }) async {
    final r = await _dio.get(
      '/admin/marks/$studentId',
      queryParameters: {'academic_year': academicYear},
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> upsertMarks(
    String studentId, {
    required String academicYear,
    required Map<String, dynamic> data,
  }) async {
    final r = await _dio.put(
      '/admin/marks/$studentId',
      data: {'academic_year': academicYear, 'data': data},
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMarksToParent(
    String studentId, {
    String academicYear = '2024-25',
  }) async {
    final r = await _dio.post(
      '/admin/marks/$studentId/send-to-parent',
      queryParameters: {'academic_year': academicYear},
    );
    return r.data as Map<String, dynamic>;
  }

  // Attendance
  Future<Map<String, dynamic>> getAttendance({
    required String date,
    String? branchId,
    String? classId,
  }) async {
    final params = <String, String>{'att_date': date};
    if (branchId != null) params['branch_id'] = branchId;
    if (classId != null) params['class_id'] = classId;
    final r = await _dio.get('/admin/attendance', queryParameters: params);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAttendanceHistory({
    String period = 'week',
    String? branchId,
    String? classId,
  }) async {
    final params = <String, String>{'period': period};
    if (branchId != null) params['branch_id'] = branchId;
    if (classId != null) params['class_id'] = classId;
    final r = await _dio.get(
      '/admin/attendance/history',
      queryParameters: params,
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStudentAttendance(
    String studentId, {
    int days = 30,
  }) async {
    final r = await _dio.get(
      '/admin/students/$studentId/attendance',
      queryParameters: {'days': days},
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStudentAttendance(
    String studentId,
    String date,
    String status,
  ) async {
    final r = await _dio.put(
      '/admin/students/$studentId/attendance',
      queryParameters: {'att_date': date, 'status': status},
    );
    return r.data as Map<String, dynamic>;
  }

  // Fees
  Future<Map<String, dynamic>> getStudentFees(String studentId) async {
    final r = await _dio.get('/admin/students/$studentId/fees');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStudentFees(
    String studentId,
    Map<String, dynamic> data,
  ) async {
    final r = await _dio.put('/admin/students/$studentId/fees', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recordFeePayment(
    String studentId,
    Map<String, dynamic> data,
  ) async {
    final r = await _dio.post(
      '/admin/students/$studentId/fees/payments',
      data: data,
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStudentFeePayments(String studentId) async {
    final r = await _dio.get('/admin/students/$studentId/fees/payments');
    return r.data as Map<String, dynamic>;
  }

  // Analytics
  Future<Map<String, dynamic>> getAnalytics() async {
    final r = await _dio.get('/admin/analytics');
    return r.data as Map<String, dynamic>;
  }

  // Staff Attendance
  Future<Map<String, dynamic>> getStaffAttendance({
    required String date,
    String? branchId,
  }) async {
    final params = <String, String>{'att_date': date};
    if (branchId != null) params['branch_id'] = branchId;
    final r = await _dio.get(
      '/admin/staff-attendance',
      queryParameters: params,
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStaffAttendanceHistory({
    String period = 'week',
    String? branchId,
  }) async {
    final params = <String, String>{'period': period};
    if (branchId != null) params['branch_id'] = branchId;
    final r = await _dio.get(
      '/admin/staff-attendance/history',
      queryParameters: params,
    );
    return r.data as Map<String, dynamic>;
  }
}
