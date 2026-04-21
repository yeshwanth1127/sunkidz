import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/api/current_user_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../data/dashboard_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 3) {
      _scaffoldKey.currentState?.openDrawer();
      return;
    }
    if (mounted) {
      setState(() => _selectedIndex = index);
    }
    switch (index) {
      case 0: context.go('/admin'); break;
      case 1: context.push('/enquiries'); break;
      case 2: context.push('/students'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final displayName =
        userAsync.valueOrNull?['full_name']?.toString() ?? 'Admin';
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: const AdminDrawer(),
      extendBody: true,
      bottomNavigationBar: _buildPremiumNavBar(),
      body: Stack(
        children: [
          // Animated Background Gradient
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(const Color(0xFFF8FAFC), const Color(0xFFEFF6FF), _bgController.value)!,
                      Color.lerp(const Color(0xFFF1F5F9), const Color(0xFFFDFCFB), _bgController.value)!,
                    ],
                  ),
                ),
              );
            },
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: dashboardAsync.when(
                    loading: () => const _DashboardLoadingPlaceholder(),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                    data: (data) {
                      if (data == null) {
                        return const Center(child: Text('No dashboard data'));
                      }
                      return RefreshIndicator(
                      onRefresh: () => ref.refresh(dashboardDataProvider.future),
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Personalized Greeting
                            AnimatedListItem(
                              index: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getGreeting(),
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    displayName,
                                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Stats Grid
                            AnimatedListItem(
                              index: 2,
                              child: GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
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

                            // Quick Actions
                            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            AnimatedListItem(
                              index: 4,
                              child: InkWell(
                                onTap: () => context.push('/admin/send-message'),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                                      ),
                                      const SizedBox(width: 16),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Send Message to Staff/Parents',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Text(
                                              'Broadcast updates, news or notifications',
                                              style: TextStyle(color: Colors.white70, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Recent Activity
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
                            const SizedBox(height: 12),
                            if (data.recentEnquiries.isEmpty)
                              const _EmptyEnquiries()
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: data.recentEnquiries.length,
                                itemBuilder: (context, index) {
                                  final enq = data.recentEnquiries[index];
                                  return AnimatedListItem(
                                    index: index + 4,
                                    child: _EnquiryTile(
                                      name: enq['child_name'] ?? 'Unknown',
                                      status: enq['status'] ?? 'new',
                                      date: enq['created_at'] != null ? DateFormat('dd MMM').format(DateTime.parse(enq['created_at'])) : 'Today',
                                    ),
                                  );
                                },
                              ),
                            
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [AppShadows.soft],
              ),
              child: const Icon(Icons.menu_rounded, size: 22, color: Color(0xFF1E293B)),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Image.asset(
              'assets/images/sunkidz_logo_hd.png',
              height: 40,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const Spacer(),
          const NotificationBell(notificationsRoute: '/admin/notifications'),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.go('/admin/settings'),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
              child: const Icon(Icons.person_rounded, size: 22, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildPremiumNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [AppShadows.elevated],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBtn(icon: Icons.grid_view_rounded, label: 'Home', isSelected: _selectedIndex == 0, onTap: () => _onItemTapped(0)),
              _NavBtn(icon: Icons.person_search_rounded, label: 'Enquiries', isSelected: _selectedIndex == 1, onTap: () => _onItemTapped(1)),
              _NavBtn(icon: Icons.people_alt_rounded, label: 'Students', isSelected: _selectedIndex == 2, onTap: () => _onItemTapped(2)),
              _NavBtn(icon: Icons.menu_open_rounded, label: 'Menu', isSelected: false, onTap: () => _onItemTapped(3)),
            ],
          ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EnquiryTile extends StatelessWidget {
  final String name;
  final String status;
  final String date;

  const _EnquiryTile({required this.name, required this.status, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBtn({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.white : const Color(0xFF94A3B8), size: 24),
          const SizedBox(height: 4),
          if (isSelected)
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}

class _DashboardLoadingPlaceholder extends StatelessWidget {
  const _DashboardLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoading.rectangular(height: 20, width: 100),
          const SizedBox(height: 8),
          const ShimmerLoading.rectangular(height: 32, width: 200),
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
          const ShimmerList(itemCount: 3),
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
