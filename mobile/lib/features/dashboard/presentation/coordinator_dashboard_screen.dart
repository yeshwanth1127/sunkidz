import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/current_user_provider.dart';
import '../../../core/api/coordinator_api.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../../../shared/widgets/coordinator_drawer.dart';
import '../../../shared/widgets/dob_picker.dart';
import '../data/coordinator_dashboard_provider.dart';

class CoordinatorDashboardScreen extends ConsumerWidget {
  const CoordinatorDashboardScreen({super.key});

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static void _showEnquiryForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => _EnquiryFormSheet(
        onSaved: () {
          Navigator.of(ctx).pop();
          ref.invalidate(coordinatorDashboardDataProvider);
        },
        api: ref.read(coordinatorApiProvider)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final dashboardAsync = ref.watch(coordinatorDashboardDataProvider);

    final userName = userAsync.valueOrNull?['full_name']?.toString() ?? 'Coordinator';
    final branchName = dashboardAsync.valueOrNull?.branchName ?? '—';
    final studentsCount = dashboardAsync.valueOrNull?.studentsCount ?? 0;
    final teachersCount = dashboardAsync.valueOrNull?.teachersCount ?? 0;
    final attendanceToday = dashboardAsync.valueOrNull?.attendanceToday ?? 0;
    final weeklyAttendance = dashboardAsync.valueOrNull?.weeklyAttendance ?? [];
    final classes = dashboardAsync.valueOrNull?.classes ?? [];

    return Scaffold(
      drawer: const CoordinatorDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
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
                  return Icon(Icons.school, color: AppColors.primaryLight, size: 24);
                },
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(branchName, style: Theme.of(context).textTheme.titleMedium),
                Text('Branch Coordinator Dashboard', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(e.toString(), style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(coordinatorDashboardDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (_) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(coordinatorDashboardDataProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryLight, AppColors.primaryLight.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppColors.primaryLight.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_greeting()}, $userName!', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        branchName != '—' ? 'Overview for $branchName' : 'No branch assigned',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(_formatDate(DateTime.now()), style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _CoordStatCard(icon: Icons.person, label: 'Teachers', value: '$teachersCount', trend: 'in branch'),
                    _CoordStatCard(icon: Icons.groups, label: 'Total Students', value: '$studentsCount', trend: 'enrolled'),
                    _CoordStatCard(
                      icon: Icons.how_to_reg,
                      label: 'Attendance Today',
                      value: '$attendanceToday',
                      trend: studentsCount > 0 ? 'of $studentsCount present' : '—',
                      trendUp: studentsCount > 0 && attendanceToday >= studentsCount * 0.8,
                    ),
                    _CoordStatCard(icon: Icons.class_, label: 'Classes', value: '${classes.length}', trend: 'grades'),
                  ],
                ),
                const SizedBox(height: 24),
                // Enquiry Analytics Section
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
                                  'Converted',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                ),
                                Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              (dashboardAsync.valueOrNull?.convertedEnquiries ?? 0).toString(),
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enquiry conversions are handled by the admin. You can view enquiry status here.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                    children: [
                      _ActionTile(icon: Icons.badge, label: 'Teachers', onTap: () => context.go('/coordinator/teachers')),
                      _ActionTile(icon: Icons.face, label: 'Students', onTap: () => context.go('/coordinator/students')),
                      _ActionTile(icon: Icons.event_available, label: 'Attendance', onTap: () => context.go('/coordinator/attendance')),
                      _ActionTile(icon: Icons.people_alt, label: 'Staff Attendance', onTap: () => context.go('/coordinator/staff-attendance')),
                      _ActionTile(icon: Icons.menu_book, label: 'Syllabus', onTap: () => context.go('/coordinator/syllabus')),
                      _ActionTile(icon: Icons.school, label: 'Homework', onTap: () => context.go('/coordinator/homework')),
                      _ActionTile(icon: Icons.account_balance_wallet, label: 'Fees', onTap: () {}),
                      _ActionTile(icon: Icons.mail_outline, label: 'Add Enquiry', onTap: () => _showEnquiryForm(context, ref)),
                    ],
                  ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Weekly Attendance', style: TextStyle(color: Colors.grey, fontSize: 14)),
                              Text(
                                weeklyAttendance.isNotEmpty
                                    ? '${(weeklyAttendance.map((e) => (e['pct'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / weeklyAttendance.length).toStringAsFixed(0)}% Average'
                                    : '—',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text('MON - FRI', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 100,
                        child: weeklyAttendance.isEmpty
                            ? Center(child: Text('No data yet', style: TextStyle(color: Colors.grey.shade600)))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: weeklyAttendance.asMap().entries.map((e) {
                                  final pct = (e.value['pct'] as num?)?.toDouble() ?? 0.0;
                                  final h = (pct / 100).clamp(0.1, 1.0);
                                  final dayLabel = (e.value['day'] as String?) ?? '${e.key + 1}';
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: LayoutBuilder(
                                        builder: (_, constraints) {
                                          final barMax = (constraints.maxHeight - 24).clamp(20.0, 72.0);
                                          return Column(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                height: (barMax * h).clamp(4.0, barMax),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withValues(alpha: 0.2),
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                                ),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary,
                                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                                  ),
                                                ),
                                              ),
                                          const SizedBox(height: 6),
                                          Text(
                                            dayLabel.substring(0, 1),
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                                          ),
                                        ],
                                      );
                                        },
                                      ),
                                    ),
                                  );
                                }).toList(),
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
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (_) {},
        items: const [
          NavItem(icon: Icons.home, label: 'Home'),
          NavItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
          NavItem(icon: Icons.calendar_today, label: 'Schedule'),
          NavItem(icon: Icons.person, label: 'Profile'),
        ],
      ),
    );
  }
}

class _CoordStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? trend;
  final bool trendUp;

  const _CoordStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.trend,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              if (trend != null) Text(trend!, style: TextStyle(fontSize: 11, color: trendUp ? Colors.green.shade700 : Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EnquiryFormSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final CoordinatorApi api;

  const _EnquiryFormSheet({required this.onSaved, required this.api});

  @override
  State<_EnquiryFormSheet> createState() => _EnquiryFormSheetState();
}

class _EnquiryFormSheetState extends State<_EnquiryFormSheet> {
  final _childName = TextEditingController();
  DateTime? _selectedDob;
  final _fatherName = TextEditingController();
  final _fatherOccupation = TextEditingController();
  final _fatherPlace = TextEditingController();
  final _fatherEmail = TextEditingController();
  final _fatherPhone = TextEditingController();
  final _motherName = TextEditingController();
  final _motherOccupation = TextEditingController();
  final _motherPlace = TextEditingController();
  final _motherEmail = TextEditingController();
  final _motherPhone = TextEditingController();
  final _siblingsInfo = TextEditingController();
  final _siblingsAge = TextEditingController();
  final _address = TextEditingController();
  final _residentialPhone = TextEditingController();
  final _challenges = TextEditingController();
  final _expectations = TextEditingController();
  String? _gender;
  bool _loading = false;

  @override
  void dispose() {
    _childName.dispose();
    _fatherName.dispose();
    _fatherOccupation.dispose();
    _fatherPlace.dispose();
    _fatherEmail.dispose();
    _fatherPhone.dispose();
    _motherName.dispose();
    _motherOccupation.dispose();
    _motherPlace.dispose();
    _motherEmail.dispose();
    _motherPhone.dispose();
    _siblingsInfo.dispose();
    _siblingsAge.dispose();
    _address.dispose();
    _residentialPhone.dispose();
    _challenges.dispose();
    _expectations.dispose();
    super.dispose();
  }

  Map<String, dynamic> _toData() {
    final (ageYears, ageMonths) = _selectedDob != null ? DobPicker.calculateAge(_selectedDob!) : (0, 0);
    return {
      'child_name': _childName.text.trim(),
      'date_of_birth': _selectedDob?.toIso8601String().split('T').first,
      'age_years': _selectedDob != null ? ageYears : null,
      'age_months': _selectedDob != null ? ageMonths : null,
      'gender': _gender,
      'father_name': _fatherName.text.trim().isEmpty ? null : _fatherName.text.trim(),
      'father_occupation': _fatherOccupation.text.trim().isEmpty ? null : _fatherOccupation.text.trim(),
      'father_place_of_work': _fatherPlace.text.trim().isEmpty ? null : _fatherPlace.text.trim(),
      'father_email': _fatherEmail.text.trim().isEmpty ? null : _fatherEmail.text.trim(),
      'father_contact_no': _fatherPhone.text.trim().isEmpty ? null : _fatherPhone.text.trim(),
      'mother_name': _motherName.text.trim().isEmpty ? null : _motherName.text.trim(),
      'mother_occupation': _motherOccupation.text.trim().isEmpty ? null : _motherOccupation.text.trim(),
      'mother_place_of_work': _motherPlace.text.trim().isEmpty ? null : _motherPlace.text.trim(),
      'mother_email': _motherEmail.text.trim().isEmpty ? null : _motherEmail.text.trim(),
      'mother_contact_no': _motherPhone.text.trim().isEmpty ? null : _motherPhone.text.trim(),
      'siblings_info': _siblingsInfo.text.trim().isEmpty ? null : _siblingsInfo.text.trim(),
      'siblings_age': _siblingsAge.text.trim().isEmpty ? null : _siblingsAge.text.trim(),
      'residential_address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'residential_contact_no': _residentialPhone.text.trim().isEmpty ? null : _residentialPhone.text.trim(),
      'challenges_specialities': _challenges.text.trim().isEmpty ? null : _challenges.text.trim(),
      'expectations_from_school': _expectations.text.trim().isEmpty ? null : _expectations.text.trim(),
      'status': 'pending',
    };
  }

  Future<void> _submit() async {
    if (_childName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Child name required')));
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.api.createEnquiry(_toData());
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New Enquiry', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _section('Child', context),
              TextField(controller: _childName, decoration: const InputDecoration(labelText: 'Child Name *')),
              DobPicker(value: _selectedDob, onChanged: (d) => setState(() => _selectedDob = d)),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [DropdownMenuItem(value: 'male', child: Text('Male')), DropdownMenuItem(value: 'female', child: Text('Female')), DropdownMenuItem(value: 'other', child: Text('Other'))],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 16),
              _section('Father', context),
              TextField(controller: _fatherName, decoration: const InputDecoration(labelText: 'Father Name')),
              TextField(controller: _fatherOccupation, decoration: const InputDecoration(labelText: 'Occupation')),
              TextField(controller: _fatherPlace, decoration: const InputDecoration(labelText: 'Place of Work')),
              TextField(controller: _fatherEmail, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              TextField(controller: _fatherPhone, decoration: const InputDecoration(labelText: 'Contact')),
              const SizedBox(height: 16),
              _section('Mother', context),
              TextField(controller: _motherName, decoration: const InputDecoration(labelText: 'Mother Name')),
              TextField(controller: _motherOccupation, decoration: const InputDecoration(labelText: 'Occupation')),
              TextField(controller: _motherPlace, decoration: const InputDecoration(labelText: 'Place of Work')),
              TextField(controller: _motherEmail, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              TextField(controller: _motherPhone, decoration: const InputDecoration(labelText: 'Contact')),
              const SizedBox(height: 16),
              _section('Siblings', context),
              TextField(controller: _siblingsInfo, decoration: const InputDecoration(labelText: 'Siblings Info'), maxLines: 2),
              TextField(controller: _siblingsAge, decoration: const InputDecoration(labelText: 'Siblings Age')),
              const SizedBox(height: 16),
              _section('Address', context),
              TextField(controller: _address, decoration: const InputDecoration(labelText: 'Residential Address'), maxLines: 2),
              TextField(controller: _residentialPhone, decoration: const InputDecoration(labelText: 'Residential Contact')),
              const SizedBox(height: 16),
              _section('Other', context),
              TextField(controller: _challenges, decoration: const InputDecoration(labelText: 'Challenges / Specialities'), maxLines: 2),
              TextField(controller: _expectations, decoration: const InputDecoration(labelText: 'Expectations from School'), maxLines: 2),
              const SizedBox(height: 24),
              FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Enquiry')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, BuildContext context) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)));
}

