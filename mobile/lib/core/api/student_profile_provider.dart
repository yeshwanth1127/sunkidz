import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_provider.dart';
import 'coordinator_provider.dart';

/// API for student profile: get and optionally update.
class StudentProfileApi {
  StudentProfileApi({required this.getStudent, this.updateStudent});

  final Future<Map<String, dynamic>> Function(String) getStudent;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? updateStudent;
}

/// Returns the API that can fetch a student profile for the current user.
/// Admin uses admin API; coordinator uses coordinator API (with edit).
final studentProfileApiProvider = Provider<StudentProfileApi?>((ref) {
  final adminApi = ref.watch(adminApiProvider);
  final coordinatorApi = ref.watch(coordinatorApiProvider);
  if (adminApi != null) {
    return StudentProfileApi(getStudent: adminApi.getStudent, updateStudent: null);
  }
  if (coordinatorApi != null) {
    return StudentProfileApi(
      getStudent: coordinatorApi.getStudent,
      updateStudent: coordinatorApi.updateStudent,
    );
  }
  return null;
});
