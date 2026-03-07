// IMPORTANT: After adding new routes, do a FULL RESTART (stop app + flutter run)
// or press R (capital R) for hot restart. Hot reload (r) does NOT pick up route changes.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../../features/landing/presentation/landing_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/admin_dashboard_screen.dart';
import '../../features/dashboard/presentation/coordinator_dashboard_screen.dart';
import '../../features/dashboard/presentation/teacher_dashboard_screen.dart';
import '../../features/teacher/presentation/teacher_students_screen.dart';
import '../../features/teacher/presentation/teacher_student_profile_screen.dart';
import '../../features/teacher/presentation/teacher_attendance_screen.dart';
import '../../features/teacher/presentation/teacher_marks_screen.dart';
import '../../features/teacher/presentation/teacher_marks_entry_screen.dart';
import '../../features/dashboard/presentation/parent_dashboard_screen.dart';
import '../../features/parent/presentation/parent_bus_tracking_screen.dart';
import '../../features/parent/presentation/parent_attendance_screen.dart';
import '../../features/parent/presentation/parent_marks_cards_screen.dart';
import '../../features/dashboard/presentation/bus_staff_dashboard_screen.dart';
import '../../features/branches/presentation/branch_list_screen.dart';
import '../../features/admin/presentation/staff_management_screen.dart';
import '../../features/admin/presentation/branch_detail_screen.dart';
import '../../features/enquiries/presentation/enquiry_list_screen.dart';
import '../../features/admissions/presentation/admission_list_screen.dart';
import '../../features/students/presentation/student_list_screen.dart';
import '../../features/students/presentation/student_profile_screen.dart';
import '../../features/marks/presentation/marks_card_screen.dart';
import '../../features/attendance/presentation/student_attendance_screen.dart';
import '../../features/coordinator/presentation/coordinator_attendance_screen.dart';
import '../../features/coordinator/presentation/coordinator_teachers_screen.dart';
import '../../features/coordinator/presentation/coordinator_students_screen.dart';
import '../../features/coordinator/presentation/coordinator_staff_attendance_screen.dart';
import '../../features/admin/presentation/admin_attendance_screen.dart';
import '../../features/admin/presentation/admin_fee_management_screen.dart';
import '../../features/admin/presentation/admin_reports_screen.dart';
import '../../features/parent/presentation/parent_fees_screen.dart';
import '../../features/syllabus/presentation/syllabus_list_screen.dart';
import '../../features/syllabus/presentation/homework_list_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isLoggedIn = auth.isAuthenticated;
      final isLandingPage = state.matchedLocation == '/';
      final isLoggingIn = state.matchedLocation == '/login';
      
      // Allow landing page for everyone
      if (isLandingPage) return null;
      
      // Redirect unauthenticated users to login
      if (!isLoggedIn && !isLoggingIn) return '/login';
      
      // Redirect authenticated users from login to their dashboard
      if (isLoggedIn && isLoggingIn) return _homeForRole(auth.role);
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const LandingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminDashboardScreen(),
        routes: [
          GoRoute(path: 'attendance', builder: (_, __) => const AdminAttendanceScreen()),
          GoRoute(
            path: 'fees',
            builder: (_, state) {
              final branchId = state.uri.queryParameters['branch_id'] ?? '';
              final studentId = state.uri.queryParameters['student_id'];
              return AdminFeeManagementScreen(branchId: branchId, studentId: studentId);
            },
          ),
          GoRoute(path: 'reports', builder: (_, __) => const AdminReportsScreen()),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/coordinator',
        builder: (_, __) => const CoordinatorDashboardScreen(),
        routes: [
          GoRoute(path: 'attendance', builder: (_, __) => const CoordinatorAttendanceScreen()),
          GoRoute(path: 'teachers', builder: (_, __) => const CoordinatorTeachersScreen()),
          GoRoute(path: 'students', builder: (_, __) => const CoordinatorStudentsScreen()),
          GoRoute(path: 'staff-attendance', builder: (_, __) => const CoordinatorStaffAttendanceScreen()),
          GoRoute(path: 'syllabus', builder: (_, __) => const SyllabusListScreen()),
          GoRoute(path: 'homework', builder: (_, __) => const HomeworkListScreen()),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/teacher',
        builder: (_, __) => const TeacherDashboardScreen(),
        routes: [
          GoRoute(path: 'students', builder: (_, __) => const TeacherStudentsScreen()),
          GoRoute(path: 'students/:id', builder: (_, s) => TeacherStudentProfileScreen(studentId: s.pathParameters['id']!)),
          GoRoute(path: 'attendance', builder: (_, __) => const TeacherAttendanceScreen()),
          GoRoute(path: 'syllabus', builder: (_, __) => const SyllabusListScreen()),
          GoRoute(path: 'homework', builder: (_, __) => const HomeworkListScreen()),
          GoRoute(path: 'marks', builder: (_, __) => const TeacherMarksScreen()),
          GoRoute(path: 'marks/:studentId', builder: (_, s) => TeacherMarksEntryScreen(studentId: s.pathParameters['studentId']!)),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/parent',
        builder: (_, __) => const ParentDashboardScreen(),
        routes: [
          GoRoute(
            path: 'bus-tracking',
            builder: (_, __) => const ParentBusTrackingScreen(),
          ),
          GoRoute(
            path: 'attendance',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ParentAttendanceScreen(student: extra?['student'] ?? {});
            },
          ),
          GoRoute(
            path: 'fees',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ParentFeesScreen(student: extra?['student'] ?? {});
            },
          ),
          GoRoute(
            path: 'marks-cards',
            builder: (_, __) => const ParentMarksCardsScreen(),
          ),
          GoRoute(
            path: 'homework',
            builder: (_, __) => const HomeworkListScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/bus-staff',
        builder: (_, __) => const BusStaffDashboardScreen(),
      ),
      GoRoute(
        path: '/branches',
        builder: (_, __) => const BranchListScreen(),
      ),
      GoRoute(
        path: '/branches/:id',
        builder: (_, state) => BranchDetailScreen(branchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/staff',
        builder: (_, __) => const StaffManagementScreen(),
      ),
      GoRoute(
        path: '/enquiries',
        builder: (_, __) => const EnquiryListScreen(),
      ),
      GoRoute(
        path: '/admissions',
        builder: (_, __) => const AdmissionListScreen(),
      ),
      GoRoute(
        path: '/students',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id != null && id.isNotEmpty) {
            return StudentProfileScreen(studentId: id);
          }
          return const StudentListScreen();
        },
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => StudentProfileScreen(studentId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/marks',
        builder: (_, __) => const MarksCardScreen(),
      ),
      GoRoute(
        path: '/attendance',
        builder: (_, __) => const StudentAttendanceScreen(),
      ),
      GoRoute(
        path: '/syllabus',
        builder: (_, __) => const SyllabusListScreen(),
      ),
      GoRoute(
        path: '/homework',
        builder: (_, __) => const HomeworkListScreen(),
      ),
    ],
  );
  ref.listen(authProvider, (_, __) => router.refresh());
  return router;
});

String _homeForRole(UserRole? role) {
  switch (role) {
    case UserRole.admin:
      return '/admin';
    case UserRole.coordinator:
      return '/coordinator';
    case UserRole.teacher:
      return '/teacher';
    case UserRole.parent:
      return '/parent';
    case UserRole.busStaff:
      return '/bus-staff';
    default:
      return '/login';
  }
}
