import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sunkidz_lms/core/theme/app_theme.dart';
import 'package:sunkidz_lms/core/api/admin_provider.dart';
import 'package:sunkidz_lms/shared/widgets/shimmer_loading.dart';
import 'package:sunkidz_lms/shared/widgets/admin_drawer.dart';
import 'package:sunkidz_lms/features/dashboard/data/dashboard_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AdminDrawer(),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardDataProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              stretch: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                title: const Text(
                  'SUNKIDZ ADMIN',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8),
                            const Color(0xFFF59E0B),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -30,
                      top: -20,
                      child: Icon(
                        Icons.wb_sunny_rounded,
                        size: 200,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                  onPressed: () => context.push('/admin/notifications'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: dashboardAsync.when(
                loading: () => const _DashboardLoadingPlaceholder(),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: $err'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.refresh(dashboardDataProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (data) {
                  if (data == null) return const Center(child: Text('No data available'));
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                          children: [
                            StatCard(
                              icon: Icons.apartment_rounded,
                              label: 'Branches',
                              value: '${data.branchesCount}',
                              backgroundColor: AppColors.pastelBlue,
                              iconColor: Colors.blue.shade600,
                              onTap: () => context.push('/branches'),
                            ),
                            StatCard(
                              icon: Icons.face_retouching_natural_rounded,
                              label: 'Students',
                              value: '${data.studentsCount}',
                              backgroundColor: AppColors.pastelGreen,
                              iconColor: Colors.green.shade600,
                              onTap: () => context.push('/students'),
                            ),
                            StatCard(
                              icon: Icons.groups_rounded,
                              label: 'Staff',
                              value: '${data.staffCount}',
                              backgroundColor: AppColors.pastelYellow,
                              iconColor: Colors.orange.shade600,
                              onTap: () => context.push('/staff'),
                            ),
                            StatCard(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'Pending Fees',
                              value: currencyFmt.format(data.feesPending),
                              backgroundColor: AppColors.pastelOrange,
                              iconColor: Colors.deepOrange.shade600,
                              onTap: () => context.push('/admin/fees'),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Metrics Section
                        AnimatedListItem(
                          index: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatusBox(
                                  label: 'New Enquiries',
                                  value: '${data.newEnquiries}',
                                  icon: Icons.mail_rounded,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _StatusBox(
                                  label: 'Conversion Rate',
                                  value: '${data.conversionRate.toStringAsFixed(1)}%',
                                  icon: Icons.auto_graph_rounded,
                                  color: AppColors.accentGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),

                        // Messaging & Communication Section
                        Text('Messaging & Communication', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _AdminActionCard(
                                icon: Icons.chat_rounded,
                                label: 'Chats',
                                color: Colors.indigo,
                                onTap: () => context.push('/chat'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AdminActionCard(
                                icon: Icons.campaign_rounded,
                                label: 'Broadcast',
                                color: AppColors.primary,
                                onTap: () => context.push('/admin/send-message'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AdminActionCard(
                                icon: Icons.event_note_rounded,
                                label: 'Leaves',
                                color: Colors.teal,
                                onTap: () => context.push('/admin/leave'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Recent Enquiries
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Recent Enquiries', style: Theme.of(context).textTheme.titleLarge),
                            TextButton(
                              onPressed: () => context.push('/enquiries'),
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (data.recentEnquiries.isEmpty)
                          const _EmptyEnquiries()
                        else
                          ...data.recentEnquiries.asMap().entries.map((e) => AnimatedListItem(
                            index: e.key + 5,
                            child: _EnquiryTile(
                              name: e.value['parent_name'] ?? 'Unknown',
                              date: _fmtDate(e.value['created_at']),
                              status: e.value['status'] ?? 'pending',
                            ),
                          )),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(String? dt) {
    if (dt == null) return '';
    try {
      final date = DateTime.parse(dt);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (_) {
      return dt;
    }
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatusBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }
}

class AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;

  const AnimatedListItem({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return child; // Simple for now
  }
}

class _EnquiryTile extends StatelessWidget {
  final String name;
  final String date;
  final String status;

  const _EnquiryTile({required this.name, required this.date, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.pastelBlue,
            child: Text(name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _getStatusColor(status)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'converted': return Colors.green;
      case 'rejected': return Colors.red;
      default: return AppColors.primary;
    }
  }
}

class _DashboardLoadingPlaceholder extends StatelessWidget {
  const _DashboardLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoading.rectangular(height: 20, width: 100),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: List.generate(4, (index) => const ShimmerLoading.rectangular(height: 100)),
          ),
          const SizedBox(height: 32),
          const ShimmerLoading.rectangular(height: 80),
          const SizedBox(height: 32),
          const ShimmerLoading.rectangular(height: 80),
          const SizedBox(height: 8),
          const ShimmerLoading.rectangular(height: 80),
        ],
      ),
    );
  }
}

class _EmptyEnquiries extends StatelessWidget {
  const _EmptyEnquiries();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No recent enquiries yet', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}
