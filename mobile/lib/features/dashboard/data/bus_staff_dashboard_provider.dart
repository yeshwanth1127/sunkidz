import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/bus_tracking_provider.dart' show busTrackingApiProvider;

/// Bus staff dashboard data. Backend API to be added when bus/route feature exists.
class BusStaffDashboardData {
  final String? routeId;
  final String? routeName;
  final String? branchName;
  final int studentsAssigned;
  final int pickedUp;
  final String? estimatedArrival;
  final List<Map<String, dynamic>> students;

  const BusStaffDashboardData({
    this.routeId,
    this.routeName,
    this.branchName,
    this.studentsAssigned = 0,
    this.pickedUp = 0,
    this.estimatedArrival,
    this.students = const [],
  });
}

final busStaffDashboardDataProvider = FutureProvider<BusStaffDashboardData>((ref) async {
  try {
    final api = ref.watch(busTrackingApiProvider);
    if (api == null) {
      print('Bus tracking API is null');
      return const BusStaffDashboardData();
    }
    
    final route = await api.getMyRoute();
    print('Route data received: $route');
    
    final routeId = route['id'] as String?;
    final routeName = route['name'] as String?;
    final branchId = route['branch_id'] as String?;
    final busStaffName = route['bus_staff_name'] as String?;
    final students = (route['students'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    print('Parsed route - ID: $routeId, Name: $routeName, Branch: $branchId');
    
    return BusStaffDashboardData(
      routeId: routeId,
      routeName: routeName,
      branchName: branchId,
      studentsAssigned: students.length,
      students: students,
    );
  } catch (e, st) {
    print('Error fetching bus staff dashboard data: $e');
    print('Stack trace: $st');
    return const BusStaffDashboardData();
  }
});
