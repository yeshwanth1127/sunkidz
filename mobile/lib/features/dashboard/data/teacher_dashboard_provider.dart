import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/teacher_provider.dart';

class TeacherDashboardData {
  final String? branchName;
  final String? classId;
  final String? className;
  final int studentsCount;
  final int boysCount;
  final int girlsCount;
  final int attendanceToday;

  const TeacherDashboardData({
    this.branchName,
    this.classId,
    this.className,
    this.studentsCount = 0,
    this.boysCount = 0,
    this.girlsCount = 0,
    this.attendanceToday = 0,
  });
}

final teacherDashboardDataProvider = FutureProvider<TeacherDashboardData?>((ref) async {
  final api = ref.watch(teacherApiProvider);
  if (api == null) return null;
  try {
    final data = await api.getDashboard();
    return TeacherDashboardData(
      branchName: data['branch_name']?.toString(),
      classId: data['class_id']?.toString(),
      className: data['class_name']?.toString(),
      studentsCount: data['students_count'] as int? ?? 0,
      boysCount: data['boys_count'] as int? ?? 0,
      girlsCount: data['girls_count'] as int? ?? 0,
      attendanceToday: data['attendance_today'] as int? ?? 0,
    );
  } catch (_) {
    return null;
  }
});
