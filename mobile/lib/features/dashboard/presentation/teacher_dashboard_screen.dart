import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/current_user_provider.dart';
import '../../../shared/widgets/teacher_drawer.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../data/teacher_dashboard_provider.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const teacherPrimary = Color(0xFF42F07C);
    final userAsync = ref.watch(currentUserProvider);
    final dashboardAsync = ref.watch(teacherDashboardDataProvider);

    final userName = userAsync.valueOrNull?['full_name']?.toString() ?? 'Teacher';
    final branchName = dashboardAsync.valueOrNull?.branchName ?? '—';
    final className = dashboardAsync.valueOrNull?.className ?? '—';
    final studentsCount = dashboardAsync.valueOrNull?.studentsCount ?? 0;
    final boysCount = dashboardAsync.valueOrNull?.boysCount ?? 0;
    final girlsCount = dashboardAsync.valueOrNull?.girlsCount ?? 0;
    final attendanceToday = dashboardAsync.valueOrNull?.attendanceToday ?? 0;
    final genderStr = boysCount > 0 || girlsCount > 0 ? '$boysCount Boys, $girlsCount Girls' : '—';

    final dateStr = _formatDate(DateTime.now());

    return Scaffold(
      drawer: const TeacherDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'images/new_logo.png',
                height: 32,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.school, color: teacherPrimary, size: 24);
                },
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(className, style: Theme.of(context).textTheme.titleMedium),
                Text('Branch: $branchName', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          CircleAvatar(
            radius: 20,
            backgroundColor: teacherPrimary.withValues(alpha: 0.2),
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'T',
              style: TextStyle(color: teacherPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 8),
        ],
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
                  Text('Class at a Glance', style: Theme.of(context).textTheme.titleLarge),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: teacherPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                    child: Text(dateStr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: teacherPrimary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: teacherPrimary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.groups, color: teacherPrimary, size: 20), const SizedBox(width: 8), Text('Total Students', style: TextStyle(fontSize: 14, color: teacherPrimary))]),
                          const SizedBox(height: 8),
                          Text('$studentsCount', style: Theme.of(context).textTheme.headlineMedium),
                          Text(genderStr, style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: teacherPrimary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.how_to_reg, color: teacherPrimary, size: 20), const SizedBox(width: 8), Text('Attendance Today', style: TextStyle(fontSize: 14, color: teacherPrimary))]),
                          const SizedBox(height: 8),
                          Text('$attendanceToday', style: Theme.of(context).textTheme.headlineMedium),
                          Text(attendanceToday > 0 ? 'of $studentsCount present' : '—', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
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
                      icon: Icons.edit_note,
                      label: 'Enter Marks',
                      color: Colors.orange,
                      isOutlined: true,
                      onTap: () => context.go('/teacher/marks'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Center(
                  child: Text('No recent activity', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [teacherPrimary.withValues(alpha: 0.3), Colors.blue.withValues(alpha: 0.2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Branch Analytics', style: Theme.of(context).textTheme.titleMedium),
                    Text('$branchName performance summary', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.8)),
                      child: Text('View Report', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (_) {},
        items: const [
          NavItem(icon: Icons.dashboard, label: 'Home'),
          NavItem(icon: Icons.groups, label: 'Students'),
          NavItem(icon: Icons.event_available, label: 'Attendance'),
          NavItem(icon: Icons.assignment, label: 'Homework'),
          NavItem(icon: Icons.more_horiz, label: 'More'),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _TeacherActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isOutlined;
  final VoidCallback onTap;

  const _TeacherActionCard({required this.icon, required this.label, required this.color, this.isOutlined = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOutlined ? color.withValues(alpha: 0.1) : color,
          borderRadius: BorderRadius.circular(12),
          border: isOutlined ? Border.all(color: color.withValues(alpha: 0.5)) : null,
          boxShadow: isOutlined ? null : [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: isOutlined ? color : Colors.black87),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isOutlined ? color : Colors.black87), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
