import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/current_user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/teacher_drawer.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/stat_card.dart';
import '../data/teacher_dashboard_provider.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const teacherPrimary = Color(0xFF42F07C);
    final userAsync = ref.watch(currentUserProvider);
    final dashboardAsync = ref.watch(teacherDashboardDataProvider);

    final userName =
        userAsync.valueOrNull?['full_name']?.toString() ?? 'Teacher';
    final branchName = dashboardAsync.valueOrNull?.branchName ?? '—';
    final className = dashboardAsync.valueOrNull?.className ?? '—';
    final studentsCount = dashboardAsync.valueOrNull?.studentsCount ?? 0;
    final boysCount = dashboardAsync.valueOrNull?.boysCount ?? 0;
    final girlsCount = dashboardAsync.valueOrNull?.girlsCount ?? 0;
    final attendanceToday = dashboardAsync.valueOrNull?.attendanceToday ?? 0;
    final genderStr = boysCount > 0 || girlsCount > 0
        ? '$boysCount Boys, $girlsCount Girls'
        : '—';

    final dateStr = _formatDate(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      drawer: const TeacherDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9), // Light green for teacher
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                'assets/images/sunkidz_logo_hd.png',
                height: 28,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.school, color: Colors.green, size: 24);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    className,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D2323),
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Branch: $branchName',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          NotificationBell(
            notificationsRoute: '/teacher/notifications',
            iconColor: Colors.black87,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.go('/teacher/settings'),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.shade100),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: teacherPrimary.withValues(alpha: 0.1),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'T',
                  style: TextStyle(
                    color: teacherPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Colors.green.shade50.withValues(alpha: 0.5),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentUserProvider);
          ref.invalidate(teacherDashboardDataProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Class at a Glance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: teacherPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: teacherPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  StatCard(
                    icon: Icons.groups,
                    label: 'Total Students',
                    value: '$studentsCount',
                    trend: genderStr,
                    backgroundColor: AppColors.pastelGreen,
                    iconColor: Colors.green.shade600,
                  ),
                  StatCard(
                    icon: Icons.how_to_reg,
                    label: 'Attendance Today',
                    value: '$attendanceToday',
                    trend: studentsCount > 0
                        ? '${(attendanceToday / studentsCount * 100).toStringAsFixed(0)}% present'
                        : '—',
                    trendUp:
                        studentsCount > 0 &&
                        attendanceToday >= studentsCount * 0.8,
                    backgroundColor: AppColors.pastelYellow,
                    iconColor: Colors.orange.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TeacherActionCard(
                      icon: Icons.task_alt,
                      label: 'Mark Attendance',
                      color: teacherPrimary,
                      onTap: () => context.go('/teacher/attendance'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TeacherActionCard(
                      icon: Icons.menu_book,
                      label: 'View Syllabus',
                      color: Colors.purple,
                      isOutlined: true,
                      onTap: () => context.go('/teacher/syllabus'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TeacherActionCard(
                      icon: Icons.cloud_upload,
                      label: 'Upload Homework',
                      color: Colors.blue,
                      isOutlined: true,
                      onTap: () => context.go('/teacher/homework'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TeacherActionCard(
                      icon: Icons.photo_library_outlined,
                      label: 'Upload Gallery',
                      color: Colors.teal,
                      isOutlined: true,
                      onTap: () => context.go('/teacher/gallery-upload'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TeacherActionCard(
                      icon: Icons.edit_note,
                      label: 'Enter Marks',
                      color: Colors.orange,
                      isOutlined: true,
                      onTap: () => context.go('/teacher/marks'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TeacherActionCard(
                      icon: Icons.groups_2_outlined,
                      label: 'View Students',
                      color: Colors.indigo,
                      isOutlined: true,
                      onTap: () => context.go('/teacher/students'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Center(
                  child: Text(
                    'No recent activity',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      teacherPrimary.withValues(alpha: 0.3),
                      Colors.blue.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Branch Analytics',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '$branchName performance summary',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/teacher/marks'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.8),
                      ),
                      child: Text(
                        'View Marks',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _TeacherActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isOutlined;
  final VoidCallback onTap;

  const _TeacherActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.isOutlined = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOutlined ? color.withValues(alpha: 0.1) : color,
          borderRadius: BorderRadius.circular(12),
          border: isOutlined
              ? Border.all(color: color.withValues(alpha: 0.5))
              : null,
          boxShadow: isOutlined
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: isOutlined ? color : Colors.black87),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOutlined ? color : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
