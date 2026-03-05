import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'teacher_api.dart';

final teacherApiProvider = Provider<TeacherApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  if (auth.role != UserRole.teacher) return null;
  return TeacherApi(auth.token!);
});
