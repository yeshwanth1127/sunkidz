import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/coordinator_provider.dart';

class CoordinatorDashboardData {
  final String? branchId;
  final String? branchName;
  final int studentsCount;
  final int teachersCount;
  final int attendanceToday;
  final List<Map<String, dynamic>> weeklyAttendance;
  final List<Map<String, dynamic>> classes;
  final int newEnquiries;
  final int convertedEnquiries;
  final int rejectedEnquiries;

  CoordinatorDashboardData({
    this.branchId,
    this.branchName,
    this.studentsCount = 0,
    this.teachersCount = 0,
    this.attendanceToday = 0,
    this.weeklyAttendance = const [],
    this.classes = const [],
    this.newEnquiries = 0,
    this.convertedEnquiries = 0,
    this.rejectedEnquiries = 0,
  });

  factory CoordinatorDashboardData.fromMap(Map<String, dynamic> data) {
    final weekly = data['weekly_attendance'] as List? ?? [];
    final cls = data['classes'] as List? ?? [];
    return CoordinatorDashboardData(
      branchId: data['branch_id']?.toString(),
      branchName: data['branch_name']?.toString(),
      studentsCount: data['students_count'] as int? ?? 0,
      teachersCount: data['teachers_count'] as int? ?? 0,
      attendanceToday: data['attendance_today'] as int? ?? 0,
      weeklyAttendance: weekly.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      classes: cls.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
}

final coordinatorDashboardDataProvider = FutureProvider<CoordinatorDashboardData>((ref) async {
  final api = ref.watch(coordinatorApiProvider);
  if (api == null) return CoordinatorDashboardData();
  
  try {
    final dashboardData = await api.getDashboard();
    
    // Fetch enquiries from coordinator endpoint
    final enquiries = await api.getEnquiries();
    
    // Count enquiry statuses
    int newEnquiries = 0;
    int convertedEnquiries = 0;
    int rejectedEnquiries = 0;
    
    for (var enquiry in enquiries) {
      final status = enquiry['status']?.toString().toLowerCase() ?? 'new';
      if (status == 'new') newEnquiries++;
      else if (status == 'converted') convertedEnquiries++;
      else if (status == 'rejected') rejectedEnquiries++;
    }
    
    final data = CoordinatorDashboardData.fromMap(dashboardData);
    return CoordinatorDashboardData(
      branchId: data.branchId,
      branchName: data.branchName,
      studentsCount: data.studentsCount,
      teachersCount: data.teachersCount,
      attendanceToday: data.attendanceToday,
      weeklyAttendance: data.weeklyAttendance,
      classes: data.classes,
      newEnquiries: newEnquiries,
      convertedEnquiries: convertedEnquiries,
      rejectedEnquiries: rejectedEnquiries,
    );
  } catch (_) {
    return CoordinatorDashboardData();
  }
});
