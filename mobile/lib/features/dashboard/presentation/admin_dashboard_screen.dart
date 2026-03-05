import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/current_user_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/admin_drawer.dart';
import '../../../shared/widgets/admissions_chart.dart';
import '../data/dashboard_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _getConversionRate({required int newEnquiries, required int convertedEnquiries}) {
    final total = newEnquiries + convertedEnquiries;
    if (total == 0) return '0%';
    final rate = (convertedEnquiries / total * 100).toStringAsFixed(1);
    return '$rate%';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);

    final userName = userAsync.valueOrNull?['full_name']?.toString() ?? 'Admin';
    final branchesCount = dashboardAsync.valueOrNull?.branchesCount ?? 0;
    final studentsCount = dashboardAsync.valueOrNull?.studentsCount ?? 0;
    final staffCount = dashboardAsync.valueOrNull?.staffCount ?? 0;
    final recentEnquiries = dashboardAsync.valueOrNull?.recentEnquiries ?? [];

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        title: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset(
            'images/new_logo.png',
            height: 32,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.grid_view, color: AppColors.primary, size: 24);
            },
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {},
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentUserProvider);
          ref.invalidate(dashboardDataProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}, $userName',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                branchesCount == 1
                    ? "Here's what's happening across 1 branch."
                    : "Here's what's happening across $branchesCount branches.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  StatCard(
                    icon: Icons.business,
                    label: 'Branches',
                    value: '$branchesCount',
                    backgroundColor: AppColors.pastelBlue,
                    iconColor: AppColors.primary,
                  ),
                  StatCard(
                    icon: Icons.face,
                    label: 'Students',
                    value: '$studentsCount',
                    backgroundColor: AppColors.pastelYellow,
                    iconColor: const Color(0xFFCA8A04),
                  ),
                  StatCard(
                    icon: Icons.groups,
                    label: 'Staff',
                    value: '$staffCount',
                    backgroundColor: AppColors.pastelGreen,
                    iconColor: const Color(0xFF16A34A),
                  ),
                  StatCard(
                    icon: Icons.payments,
                    label: 'Fees Due',
                    value: '—',
                    backgroundColor: const Color(0xFFF1F5F9),
                    iconColor: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Quick Metrics', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'New Enquiries',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                              ),
                              Icon(Icons.mail_outline, color: Colors.blue, size: 20),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (dashboardAsync.valueOrNull?.newEnquiries ?? 0).toString(),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Conversion Rate',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                              ),
                              Icon(Icons.trending_up, color: Colors.green, size: 20),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _getConversionRate(
                              newEnquiries: dashboardAsync.valueOrNull?.newEnquiries ?? 0,
                              convertedEnquiries: dashboardAsync.valueOrNull?.convertedEnquiries ?? 0,
                            ),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Admissions Analytics', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => context.push('/admissions'),
                    child: Text('View Report', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AdmissionsChart(
                newEnquiries: dashboardAsync.valueOrNull?.newEnquiries ?? 0,
                convertedEnquiries: dashboardAsync.valueOrNull?.convertedEnquiries ?? 0,
                rejectedEnquiries: dashboardAsync.valueOrNull?.rejectedEnquiries ?? 0,
                admissionsThisMonth: dashboardAsync.valueOrNull?.admissionsThisMonth.length ?? 0,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Enquiries', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => context.push('/enquiries'),
                    child: Text('See All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (recentEnquiries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Center(
                    child: Text('No enquiries yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  ),
                )
              else
                ...recentEnquiries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _EnquiryTile(
                        name: e['child_name']?.toString() ?? '—',
                        branch: e['branch_name']?.toString() ?? '—',
                        age: e['age_years'] ?? 0,
                        status: e['status']?.toString() ?? 'pending',
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnquiryTile extends StatelessWidget {
  final String name;
  final String branch;
  final int age;
  final String status;

  const _EnquiryTile({required this.name, required this.branch, required this.age, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.pastelYellow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.mail, color: const Color(0xFFCA8A04), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('$branch • Age $age', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status.toLowerCase() == 'new' ? Colors.blue.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status.toLowerCase() == 'new' ? Colors.blue.shade700 : Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
