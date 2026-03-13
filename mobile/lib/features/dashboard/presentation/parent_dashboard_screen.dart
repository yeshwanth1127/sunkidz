import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/current_user_provider.dart';
import '../../../core/api/parent_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/marks_card_display.dart';
import '../../../shared/widgets/parent_bus_tracking_widget.dart';
import '../../../features/syllabus/providers/syllabus_provider.dart';
import '../../../features/syllabus/domain/models/syllabus_model.dart';
import '../../../core/config/api_config.dart';

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  List<Map<String, dynamic>> _marksCards = [];
  List<Map<String, dynamic>> _children = [];
  List<Homework> _homework = [];
  List<GalleryItem> _dailyGalleryItems = [];
  Map<String, dynamic>? _feeData;
  bool _loadingMarks = true;
  bool _loadingChildren = true;
  bool _loadingHomework = true;
  bool _loadingFees = true;
  bool _loadingGallery = true;
  Map<String, dynamic>? _selectedChild;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMarksCards();
      _loadChildren();
    });
  }

  Future<void> _loadHomework() async {
    if (_selectedChild == null) {
      setState(() {
        _homework = [];
        _loadingHomework = false;
      });
      return;
    }

    final classId = _selectedChild!['class_id'] as String?;
    if (classId == null) {
      setState(() {
        _homework = [];
        _loadingHomework = false;
      });
      return;
    }

    setState(() => _loadingHomework = true);

    try {
      final service = ref.read(syllabusServiceProvider);
      final homeworkList = await service.fetchHomework(classId: classId);
      if (mounted) {
        setState(() {
          _homework = homeworkList;
          _loadingHomework = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _homework = [];
          _loadingHomework = false;
        });
      }
    }
  }

  Future<void> _loadGallery() async {
    if (_selectedChild == null) {
      setState(() {
        _dailyGalleryItems = [];
        _loadingGallery = false;
      });
      return;
    }

    final classId = _selectedChild!['class_id'] as String?;
    if (classId == null) {
      setState(() {
        _dailyGalleryItems = [];
        _loadingGallery = false;
      });
      return;
    }

    setState(() => _loadingGallery = true);

    try {
      final service = ref.read(syllabusServiceProvider);
      final gallery = await service.fetchGallery(classId: classId);
      if (mounted) {
        setState(() {
          _dailyGalleryItems = gallery;
          _loadingGallery = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dailyGalleryItems = [];
          _loadingGallery = false;
        });
      }
    }
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
        final children = List<Map<String, dynamic>>.from(
          res['children'] as List? ?? [],
        );
        // Restore the previously selected child if still in the list, so
        // navigating away and back doesn't flip to a different kid.
        final savedId = ref.read(selectedChildProvider)?['id'] as String?;
        Map<String, dynamic>? newSelection;
        if (savedId != null) {
          newSelection = children.where((c) => c['id'] == savedId).firstOrNull;
        }
        newSelection ??= children.isNotEmpty ? children[0] : null;
        if (newSelection != null) {
          ref.read(selectedChildProvider.notifier).state = newSelection;
        }
        setState(() {
          _children = children;
          _selectedChild = newSelection;
          _loadingChildren = false;
        });
        _loadHomework();
        _loadFees();
        _loadGallery();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChildren = false);
    }
  }

  Future<void> _loadFees() async {
    if (_selectedChild == null) {
      setState(() {
        _feeData = null;
        _loadingFees = false;
      });
      return;
    }

    final api = ref.read(parentApiProvider);
    if (api == null) {
      setState(() => _loadingFees = false);
      return;
    }

    setState(() => _loadingFees = true);

    try {
      final fees = await api.getStudentFees(_selectedChild!['id']);
      if (mounted) {
        setState(() {
          _feeData = fees;
          _loadingFees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feeData = null;
          _loadingFees = false;
        });
      }
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
      if (mounted)
        setState(() {
          _marksCards = List<Map<String, dynamic>>.from(
            res['marks_cards'] as List? ?? [],
          );
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
                  Text(
                    '${mc['student_name']} • ${mc['academic_year']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
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
    final userName =
        userAsync.valueOrNull?['full_name']?.toString() ?? 'Parent';
    final userId = ref.read(authProvider).userId;
    final authToken = ref.read(authProvider).token;
    final hasProfilePhoto = userAsync.valueOrNull?['profile_photo'] != null;
    final profilePhotoUrl = hasProfilePhoto && userId != null
        ? '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/profile-photo/$userId'
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
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
              IconButton(
                icon: Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              Positioned(
                top: 8,
                right: 8,
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
          InkWell(
            onTap: () => context.push('/parent/settings'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: profilePhotoUrl != null
                    ? NetworkImage(
                        '$profilePhotoUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                      )
                    : null,
                child: profilePhotoUrl == null
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'P',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            ),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'images/new_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.school,
                                size: 28,
                                color: AppColors.primary,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Parent Portal',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_loadingChildren && _children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No children linked',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              const Divider(),
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
                  context.push(
                    '/parent/attendance',
                    extra: {'student': _selectedChild},
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a student first'),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.menu_book, color: Colors.orange),
              title: const Text('Homework'),
              onTap: () {
                Navigator.pop(context);
                context.push('/parent/homework');
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
                if (_selectedChild != null) {
                  context.push(
                    '/parent/fees',
                    extra: {'student': _selectedChild, 'feeData': _feeData},
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a student first'),
                    ),
                  );
                }
              },
            ),
              if (_hasBusAccess)
              ListTile(
                leading: Icon(Icons.directions_bus, color: Colors.blue),
                title: const Text('Bus Tracking'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
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
              title: Text(
                'Logout',
                style: TextStyle(color: Colors.red.shade700),
              ),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                (_selectedChild!['name'] as String? ?? 'S')[0]
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedChild!['name'] as String? ??
                                      'Unknown',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _selectedChild!['branch_name']
                                                as String? ??
                                            'No Branch',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Class: ${_selectedChild!['class_name'] ?? 'Not Assigned'}',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                if (_selectedChild!['admission_number'] != null)
                                  Text(
                                    'Admission: ${_selectedChild!['admission_number']}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_hasBusAccess)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Bus Facility Active',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                    Text(
                      'Live Bus Tracking',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    const ParentBusTrackingWidget(),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
                        context.push(
                          '/parent/attendance',
                          extra: {'student': _selectedChild},
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a student first'),
                          ),
                        );
                      }
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.menu_book,
                    label: 'Homework',
                    color: Colors.orange,
                    onTap: () {
                      context.push('/parent/homework');
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.assignment,
                    label: 'Marks Cards',
                    color: Colors.green,
                    onTap: () {
                      context.push('/parent/marks-cards');
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.payments,
                    label: 'Fees',
                    color: Colors.purple,
                    onTap: () {
                      if (_selectedChild != null) {
                        context.push(
                          '/parent/fees',
                          extra: {
                            'student': _selectedChild,
                            'feeData': _feeData,
                          },
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a student first'),
                          ),
                        );
                      }
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
                  Text(
                    'Marks Cards',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_marksCards.isNotEmpty)
                    Text(
                      '${_marksCards.length} sent',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingMarks)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
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
                      Icon(
                        Icons.assignment_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'No marks cards sent yet. Your child\'s teacher will share them when ready.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._marksCards.map(
                (mc) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: _MarksCardTile(
                    marksCard: mc,
                    onTap: () => _showMarksCard(context, mc),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            // Fees Section
            if (_selectedChild != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Fee Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingFees)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_feeData == null ||
                  (_feeData!['total_due'] ?? 0.0) == 0.0)
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
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'No fee structure set up yet for this student.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
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
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.purple,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fee Summary',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${_feeData!['student_name']}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _FeeStatCard(
                                label: 'Total Due',
                                amount: _feeData!['total_due'] ?? 0.0,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FeeStatCard(
                                label: 'Paid',
                                amount: _feeData!['total_paid'] ?? 0.0,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FeeStatCard(
                                label: 'Balance',
                                amount: _feeData!['total_balance'] ?? 0.0,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        _FeeComponentRow(
                          'Advance Fees',
                          _feeData!['advance_fees_balance'] ?? 0.0,
                        ),
                        const SizedBox(height: 8),
                        _FeeComponentRow(
                          'Term Fee 1',
                          _feeData!['term_fee_1_balance'] ?? 0.0,
                        ),
                        const SizedBox(height: 8),
                        _FeeComponentRow(
                          'Term Fee 2',
                          _feeData!['term_fee_2_balance'] ?? 0.0,
                        ),
                        const SizedBox(height: 8),
                        _FeeComponentRow(
                          'Term Fee 3',
                          _feeData!['term_fee_3_balance'] ?? 0.0,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Homework',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_homework.isNotEmpty)
                    Text(
                      '${_homework.length} assigned',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingHomework)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_homework.isEmpty)
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
                      Icon(Icons.school, size: 40, color: Colors.grey.shade400),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'No homework assigned yet for ${_selectedChild?['class_name'] ?? 'this class'}.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 180,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _homework.length,
                  itemBuilder: (ctx, i) {
                    final hw = _homework[i];
                    return Container(
                      width: 300,
                      margin: EdgeInsets.only(
                        right: i < _homework.length - 1 ? 12 : 0,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
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
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.assignment,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hw.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    if (hw.dueDate != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: hw.dueDate!.isBefore(DateTime.now())
                                              ? Colors.red.withValues(alpha: 0.1)
                                              : Colors.blue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 12,
                                              color: hw.dueDate!.isBefore(DateTime.now())
                                                  ? Colors.red
                                                  : Colors.blue,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Due: ${DateFormat('MMM dd').format(hw.dueDate!)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: hw.dueDate!.isBefore(DateTime.now())
                                                    ? Colors.red
                                                    : Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => context.push('/parent/homework'),
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('View Details'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange,
                              minimumSize: const Size(double.infinity, 36),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily Gallery',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 128,
              child: _loadingGallery
                  ? const Center(child: CircularProgressIndicator())
                  : _dailyGalleryItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'No gallery photos available yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _dailyGalleryItems.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _dailyGalleryItems[index];
                        final url =
                            '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/gallery/${item.id}/file${authToken != null ? '?token=$authToken' : ''}';
                        return _GalleryImage(url: url);
                      },
                    ),
            ),
            const SizedBox(height: 100),
          ],
        ),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.assignment,
                color: Colors.green.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    marksCard['student_name'] as String? ?? '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${marksCard['academic_year']} • ${marksCard['class_name'] ?? '—'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Sent: $sentStr',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
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

class _FeeStatCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _FeeStatCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeComponentRow extends StatelessWidget {
  final String label;
  final double balance;

  const _FeeComponentRow(this.label, this.balance);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: balance > 0
                ? Colors.orange.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '₹${balance.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: balance > 0
                  ? Colors.orange.shade700
                  : Colors.green.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
