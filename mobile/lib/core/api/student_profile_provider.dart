import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_provider.dart';
import 'coordinator_provider.dart';
import 'parent_provider.dart';

/// API for student profile: get and optionally update.
class StudentProfileApi {
  StudentProfileApi({
    required this.getStudent,
    this.updateStudent,
    required this.getStudentAttendance,
    this.updateStudentAttendance,
    this.getStudentFees,
    this.updateStudentFees,
    this.recordFeePayment,
    this.getStudentFeePayments,
  });

  final Future<Map<String, dynamic>> Function(String) getStudent;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  updateStudent;
  final Future<Map<String, dynamic>> Function(String, {int days})
  getStudentAttendance;
  final Future<Map<String, dynamic>> Function(String, String, String)?
  updateStudentAttendance;
  final Future<Map<String, dynamic>> Function(String)? getStudentFees;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  updateStudentFees;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  recordFeePayment;
  final Future<Map<String, dynamic>> Function(String)? getStudentFeePayments;
}

/// Returns the API that can fetch a student profile for the current user.
/// Admin uses admin API; coordinator uses coordinator API (with edit).
final studentProfileApiProvider = Provider<StudentProfileApi?>((ref) {
  final adminApi = ref.watch(adminApiProvider);
  final coordinatorApi = ref.watch(coordinatorApiProvider);
  final parentApi = ref.watch(parentApiProvider);

  if (adminApi != null) {
    return StudentProfileApi(
      getStudent: adminApi.getStudent,
      updateStudent: null,
      getStudentAttendance: adminApi.getStudentAttendance,
      updateStudentAttendance: adminApi.updateStudentAttendance,
      getStudentFees: adminApi.getStudentFees,
      updateStudentFees: adminApi.updateStudentFees,
      recordFeePayment: adminApi.recordFeePayment,
      getStudentFeePayments: adminApi.getStudentFeePayments,
    );
  }
  if (coordinatorApi != null) {
    return StudentProfileApi(
      getStudent: coordinatorApi.getStudent,
      updateStudent: coordinatorApi.updateStudent,
      getStudentAttendance: coordinatorApi.getStudentAttendance,
      updateStudentAttendance: coordinatorApi.updateStudentAttendance,
      getStudentFees: coordinatorApi.getStudentFees,
      updateStudentFees: coordinatorApi.updateStudentFees,
      recordFeePayment: coordinatorApi.recordFeePayment,
      getStudentFeePayments: coordinatorApi.getStudentFeePayments,
    );
  }
  if (parentApi != null) {
    return StudentProfileApi(
      getStudent: (studentId) async {
        final res = await parentApi.getChildren();
        final children = (res['children'] as List?) ?? const [];
        for (final c in children) {
          if (c is Map<String, dynamic> && c['id']?.toString() == studentId) {
            return c;
          }
        }
        throw Exception('Student not found');
      },
      getStudentAttendance: parentApi.getStudentAttendance,
      getStudentFees: parentApi.getStudentFees,
    );
  }
  return null;
});
