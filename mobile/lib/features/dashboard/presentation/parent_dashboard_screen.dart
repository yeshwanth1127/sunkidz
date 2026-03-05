import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/current_user_provider.dart';
import '../../../core/api/parent_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../../../shared/widgets/marks_card_display.dart';
import '../../../shared/widgets/parent_bus_tracking_widget.dart';

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  List<Map<String, dynamic>> _marksCards = [];
  List<Map<String, dynamic>> _children = [];
  bool _loadingMarks = true;
  bool _loadingChildren = true;
  Map<String, dynamic>? _selectedChild;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMarksCards();
      _loadChildren();
    });
  }



  Future<void> _loadChildren() async {
    final api = ref.read(parentApiProvider);
    if (api == null) {
      setState(() => _loadingChildren = false);
      return;
    }
    try {
      final res = await api.getChildren();
      if (mounted) {
        final children = List<Map<String, dynamic>>.from(res['children'] as List? ?? []);
        setState(() {
          _children = children;
          _selectedChild = children.isNotEmpty ? children[0] : null;
          _loadingChildren = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChildren = false);
    }
  }

  Future<void> _loadMarksCards() async {
    final api = ref.read(parentApiProvider);
    if (api == null) {
      setState(() => _loadingMarks = false);
      return;
    }
    try {
      final res = await api.getMarksCards();
      if (mounted) setState(() {
        _marksCards = List<Map<String, dynamic>>.from(res['marks_cards'] as List? ?? []);
        _loadingMarks = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMarks = false);
    }
  }

  void _showMarksCard(BuildContext context, Map<String, dynamic> mc) {
    final data = mc['data'] as Map<String, dynamic>? ?? {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 1,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${mc['student_name']} • ${mc['academic_year']}', style: Theme.of(context).textTheme.titleMedium),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                child: MarksCardDisplay(
                  studentName: mc['student_name'] as String? ?? '—',
                  academicYear: mc['academic_year'] as String? ?? '—',
                  data: data,
                  fatherName: mc['father_name']?.toString(),
                  motherName: mc['mother_name']?.toString(),
                  dob: (mc['date_of_birth']?.toString() ?? '').split('T').first,
                  className: mc['class_name']?.toString(),
                  branchName: mc['branch_name']?.toString(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasBusAccess {
    if (_selectedChild == null) return false;
    return _selectedChild!['bus_opted'] as bool? ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final userName = userAsync.valueOrNull?['full_name']?.toString() ?? 'Parent';
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'images/new_logo.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.school, size: 28, color: AppColors.primary);
              },
            ),
            const SizedBox(width: 12),
            const Text('Parent Portal'),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(icon: Icon(Icons.notifications_outlined), onPressed: () {}),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'images/new_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.school, size: 32, color: AppColors.primary);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Parent Portal',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                  ),
                ],
              ),
            ),
            if (_loadingChildren)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No children linked', style: TextStyle(color: Colors.grey.shade600)),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(
                    labelText: 'Select Child',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _selectedChild,
                  items: _children.map((child) {
                    return DropdownMenuItem(
                      value: child,
                      child: Text(child['name'] as String? ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedChild = val);
                  },
                ),
              ),
              const Divider(),
            ],
            ListTile(
              leading: Icon(Icons.home, color: AppColors.primary),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.event_available, color: AppColors.primary),
              title: const Text('Attendance'),
              onTap: () {
                Navigator.pop(context);
                if (_selectedChild != null) {
                  context.push('/parent/attendance', extra: {'student': _selectedChild});
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a student first')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.menu_book, color: Colors.orange),
              title: const Text('Homework'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Homework feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.assignment, color: Colors.green),
              title: const Text('Marks Cards'),
              onTap: () {
                Navigator.pop(context);
                // Already on home showing marks cards
              },
            ),
            ListTile(
              leading: Icon(Icons.payments, color: Colors.purple),
              title: const Text('Fees'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fees feature coming soon')),
                );
              },
            ),
            if (_hasBusAccess)
              ListTile(
                leading: Icon(Icons.directions_bus, color: Colors.blue),
                title: const Text('Bus Tracking'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/parent/bus-tracking');
                },
              ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red.shade700),
              title: Text('Logout', style: TextStyle(color: Colors.red.shade700)),
              onTap: () {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedChild != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                (_selectedChild!['name'] as String? ?? 'S')[0].toUpperCase(),
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedChild!['name'] as String? ?? 'Unknown',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _selectedChild!['branch_name'] as String? ?? 'No Branch',
                                        style: TextStyle(color: AppColors.primary, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Class: ${_selectedChild!['class_name'] ?? 'Not Assigned'}',
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                                if (_selectedChild!['admission_number'] != null)
                                  Text(
                                    'Admission: ${_selectedChild!['admission_number']}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile editing coming soon')),
                                );
                              },
                              icon: Icon(Icons.edit, size: 18),
                              label: const Text('Edit Profile'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 48,
                            height: 40,
                            decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.child_care, color: Colors.black87),
                          ),
                        ],
                      ),
                      if (_hasBusAccess)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Bus Facility Active',
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // Live Bus Tracking Widget
            if (_hasBusAccess && _selectedChild != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Bus Tracking', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    const ParentBusTrackingWidget(),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _QuickActionCard(
                    icon: Icons.event_available,
                    label: 'Attendance',
                    color: AppColors.primary,
                    onTap: () {
                      if (_selectedChild != null) {
                        context.push('/parent/attendance', extra: {'student': _selectedChild});
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a student first')),
                        );
                      }
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.menu_book,
                    label: 'Homework',
                    color: Colors.orange,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Homework feature coming soon')),
                      );
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.assignment,
                    label: 'Marks Cards',
                    color: Colors.green,
                    onTap: () {
                      // Scroll to marks cards section or show filtered
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.payments,
                    label: 'Fees',
                    color: Colors.purple,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fees feature coming soon')),
                      );
                    },
                  ),
                  if (_hasBusAccess)
                    _QuickActionCard(
                      icon: Icons.directions_bus,
                      label: 'Bus Tracking',
                      color: Colors.blue,
                      onTap: () {
                        context.push('/parent/bus-tracking');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Marks Cards', style: Theme.of(context).textTheme.titleLarge),
                  if (_marksCards.isNotEmpty)
                    Text('${_marksCards.length} sent', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingMarks)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_marksCards.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.assignment_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'No marks cards sent yet. Your child\'s teacher will share them when ready.',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._marksCards.map((mc) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _MarksCardTile(
                      marksCard: mc,
                      onTap: () => _showMarksCard(context, mc),
                    ),
                  )),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Daily Gallery', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(onPressed: () {}, child: Text('See All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 128,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _GalleryImage(url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAHwdpFhE-lMEBdDwyGfq5TfffGSaVD9gIWknw3BgnRLY-PFUCAA6HH9wrDIXx2A98y_G9I5Pu-2Dya1hsW6drtJv7a0LQ09AEo0by3VpflTGTAQjsE3Dc16ed1v12n4cOHHBPe6cirUkLKeG8slgsi-eP4I0i50MjpfXDIriKLVzq97qg0K6U-ooeo-TA4W_G6fF8XeJsxIyBtMQLIr5FfqWjeuU8g1i93dsKKm3TDIfLFI_RpWxlTOsIsdvUypq4s0sXy2t_jM7g'),
                  const SizedBox(width: 12),
                  _GalleryImage(url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCPuKoqqBFyiDqsZSEwIwYH-zdFDvDaVdRkH6cnvYDsfJayv0_WDir2XGXH91OMmkOjeqy_fuHPjK42rV-Q9i92hKHL2GMPJjJU7IJTc6jLSVH-Yk57SiSBprcxsuCG4cID5DWAj811686aVjs4k-TfhespDqC_VCWGsioX0fJTQ2F71Cq31VY1xgz0LP2r1ogsmmjIPhAeexaYEFjXcfevBtdfNBxwNzONWSRZW1z77XC4wY3mzu4EGMs-0fzECXseW-ehnhKVRI0'),
                  const SizedBox(width: 12),
                  _GalleryImage(url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuC6edSOTxJ7wqV7K8Vg1JqNmwgT2JsSJpj71Eh_cJRQBWu2e1Kb8ax6Z-PPflUCIsWPcJaBRHkFi6a59LwnqxG8-GDEj7q9ydJx1x5colTmDF4at5_eEoR0UrjCN_e8ragtvgBpVbcjfISYFtO8uOF6_XeH3tqgOCFTLSVjPQk3sBHrMM3VIehn3_wDso5pSb7LGyIZotHUEpVAu5HHIeUfaghCpgnbWTZhObS-LO071aJ5eFt_GpC1XyzysHJwALWEiiNy2u9Pfc4'),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (_) {},
        items: const [
          NavItem(icon: Icons.home, label: 'Home'),
          NavItem(icon: Icons.menu_book, label: 'Academic'),
          NavItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
          NavItem(icon: Icons.credit_card, label: 'Fees'),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarksCardTile extends StatelessWidget {
  final Map<String, dynamic> marksCard;
  final VoidCallback onTap;

  const _MarksCardTile({required this.marksCard, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sentAt = marksCard['sent_at'] as String?;
    String sentStr = '—';
    if (sentAt != null && sentAt.length >= 10) {
      final parts = sentAt.substring(0, 10).split('-');
      if (parts.length == 3) sentStr = '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.assignment, color: Colors.green.shade700, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(marksCard['student_name'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text('${marksCard['academic_year']} • ${marksCard['class_name'] ?? '—'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text('Sent: $sentStr', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _GalleryImage extends StatelessWidget {
  final String url;

  const _GalleryImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(url, width: 128, height: 128, fit: BoxFit.cover),
    );
  }
}
