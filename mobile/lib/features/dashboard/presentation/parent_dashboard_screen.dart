import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../core/theme/app_theme.dart';
import '../../../core/api/current_user_provider.dart';
import '../../../core/api/parent_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/marks_card_display.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/parent_bus_tracking_widget.dart';
import '../../../shared/widgets/parent_drawer.dart';
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
      if (mounted) {
        setState(() {
          _marksCards = List<Map<String, dynamic>>.from(
            res['marks_cards'] as List? ?? [],
          );
          _loadingMarks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMarks = false);
    }
  }

  void _onChildSwitched(Map<String, dynamic> child) {
    if (_selectedChild?['id'] == child['id']) return;

    ref.read(selectedChildProvider.notifier).state = child;
    setState(() {
      _selectedChild = child;
    });

    // Refresh child-specific data
    _loadHomework();
    _loadFees();
    _loadGallery();
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
    final userName = userAsync.valueOrNull?['full_name']?.toString() ?? 'Parent';
    final userId = ref.read(authProvider).userId;
    final authToken = ref.read(authProvider).token;
    final hasProfilePhoto = userAsync.valueOrNull?['profile_photo'] != null;
    final profilePhotoUrl = hasProfilePhoto && userId != null
        ? '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/profile-photo/$userId'
        : null;

    final childName = _selectedChild?['name'] as String? ?? 'Unknown';
    final childClass = _selectedChild?['class_name'] as String? ?? 'Not Assigned';
    final childBranch = _selectedChild?['branch_name'] as String? ?? 'No Branch';
    final childAvatarLetter = childName.isNotEmpty ? childName[0].toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/sunkidz_logo_hd.png',
                        height: 28,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.school, size: 28, color: AppColors.primary);
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Parent Portal',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF0E5),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: CircleAvatar(
                          backgroundColor: Colors.black87,
                          radius: 16,
                          child: InkWell(
                            onTap: () => context.push('/parent/notifications'),
                            child: const Icon(Icons.notifications, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => context.push('/parent/settings'),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF0E5),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.transparent,
                            backgroundImage: profilePhotoUrl != null
                                ? NetworkImage('$profilePhotoUrl?t=${DateTime.now().millisecondsSinceEpoch}')
                                : null,
                            child: profilePhotoUrl == null
                                ? Icon(Icons.person, color: Colors.orange.shade300, size: 20)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loadingChildren)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator(color: Colors.orange)),
                      )
                    else if (_selectedChild != null) ...[
                      if (_children.length > 1)
                        _buildChildSwitcher(),
                      _buildProfileCard(childName, childClass, childBranch, childAvatarLetter, profilePhotoUrl),
                    ],
                    
                    const SizedBox(height: 10),

                    // Quick Actions
                    _buildQuickActions(context),

                    // Recent Homework
                    if (_homework.isNotEmpty)
                      _buildRecentHomework(),

                    const SizedBox(height: 30),

                    // Classroom Moments
                    _buildClassroomMoments(authToken),

                    // Fee Summary
                    if (_selectedChild != null && !_loadingFees && _feeData != null)
                      _buildFeeSummary(),

                    // Bus Tracking
                    if (_hasBusAccess && _selectedChild != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bus Tracking',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            const ParentBusTrackingWidget(),
                          ],
                        ),
                      ),

                    const SizedBox(height: 120), // Bottom navigation padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedChild?['id'],
            isExpanded: true,
            icon: const Icon(Icons.swap_horiz, color: Colors.orange),
            hint: const Text('Select Child'),
            items: _children.map((child) {
              return DropdownMenuItem<String>(
                value: child['id'],
                child: Text(
                  child['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
            onChanged: (childId) {
              final child = _children.firstWhere((c) => c['id'] == childId);
              _onChildSwitched(child);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(String name, String className, String branch, String letter, String? profilePhotoUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade100.withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Floating background icons
          Positioned(
            top: -10,
            child: Icon(Icons.wb_sunny_outlined, color: Colors.yellow.shade600, size: 28),
          ),
          Positioned(
            bottom: -20,
            right: 40,
            child: Icon(Icons.rocket_launch, color: Colors.blue.shade200, size: 28),
          ),
          Positioned(
            top: -20,
            right: 80,
            child: Icon(Icons.star, color: Colors.orange.shade100, size: 24),
          ),
          
          Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange.shade200, width: 2, style: BorderStyle.solid),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.teal.shade700,
                      backgroundImage: profilePhotoUrl != null
                          ? NetworkImage('$profilePhotoUrl?t=${DateTime.now().millisecondsSinceEpoch}')
                          : null,
                      child: profilePhotoUrl == null
                          ? Text(
                              letter,
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF29B27),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D2323),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'GRADE: ${className.toUpperCase()} • ${branch.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7C6E6E),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHomework() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Recent Assignments',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D2323),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: math.min(_homework.length, 5), // Only show top 5
            itemBuilder: (context, index) {
              final hw = _homework[index];
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: InkWell(
                  onTap: () => context.push('/parent/homework'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hw.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          hw.description ?? 'No description provided.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Due: ${hw.dueDate != null ? DateFormat('MMM dd').format(hw.dueDate!) : 'N/A'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.25,
        children: [
          _SaffronGridBtn(
            label: 'Attendance',
            icon: Icons.calendar_today,
            bgColor: const Color(0xFFE5F5FF),
            iconColor: const Color(0xFF3B9DE8),
            textColor: const Color(0xFF0F6FA3),
            onTap: () {
              if (_selectedChild != null) {
                context.push('/parent/attendance', extra: {'student': _selectedChild});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student first')));
              }
            },
          ),
          _SaffronGridBtn(
            label: 'Homework',
            icon: Icons.edit_document,
            bgColor: const Color(0xFFFFFAD6),
            iconColor: const Color(0xFFE4AD12),
            textColor: const Color(0xFFA67A00),
            onTap: () => context.push('/parent/homework'),
          ),
          _SaffronGridBtn(
            label: 'Messages',
            icon: Icons.chat_bubble_outline,
            bgColor: const Color(0xFFFFF0F5),
            iconColor: const Color(0xFFE65B90),
            textColor: const Color(0xFFAD1752),
            onTap: () => context.push('/parent/send-message'),
          ),
          _SaffronGridBtn(
            label: 'MarksCard',
            icon: Icons.star_border,
            bgColor: const Color(0xFFF5F0FF),
            iconColor: const Color(0xFFA575FF),
            textColor: const Color(0xFF5A1EBD),
            onTap: () => context.push('/parent/marks-cards'),
          ),
          _SaffronGridBtn(
            label: 'Fees',
            icon: Icons.payments_outlined,
            bgColor: const Color(0xFFE5FFED),
            iconColor: const Color(0xFF4ADE80),
            textColor: const Color(0xFF148540),
            onTap: () {
              if (_selectedChild != null) {
                context.push('/parent/fees', extra: {'student': _selectedChild, 'feeData': _feeData});
              }
            },
          ),
          _SaffronGridBtn(
            label: 'Receipts',
            icon: Icons.receipt_long,
            bgColor: const Color(0xFFE5FCFF),
            iconColor: const Color(0xFF22D3EE),
            textColor: const Color(0xFF008D9B),
            onTap: () => context.push('/parent/receipts'),
          ),
          _SaffronGridBtn(
            label: 'Settings',
            icon: Icons.settings,
            bgColor: const Color(0xFFFFF0E5),
            iconColor: const Color(0xFFFB923C),
            textColor: const Color(0xFFB55500),
            onTap: () => context.push('/parent/settings'),
          ),
          _SaffronGridBtn(
            label: 'Logout',
            icon: Icons.logout,
            bgColor: const Color(0xFFFFF0F0),
            iconColor: const Color(0xFFFB7185),
            textColor: const Color(0xFFB5162D),
            onTap: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
          _SaffronGridBtn(
            label: 'Notifications',
            icon: Icons.notifications_none,
            bgColor: const Color(0xFFF0F5FF),
            iconColor: const Color(0xFF60A5FA),
            textColor: const Color(0xFF1D4ED8),
            onTap: () => context.push('/parent/notifications'),
          ),
          if (_hasBusAccess)
            _SaffronGridBtn(
              label: 'Bus Map',
              icon: Icons.directions_bus_outlined,
              bgColor: const Color(0xFFF5F5DC),
              iconColor: const Color(0xFFD4B04C),
              textColor: const Color(0xFF8A6C21),
              onTap: () => context.push('/parent/bus-tracking'),
            ),
        ],
      ),
    );
  }

  Widget _buildClassroomMoments(String? authToken) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Classroom\nMoments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: Color(0xFF2D2323),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.orange.shade200)),
                    child: const Icon(Icons.chevron_left, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.orange.shade200)),
                    child: const Icon(Icons.chevron_right, color: Colors.orange, size: 20),
                  ),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 260,
          child: _loadingGallery
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : _dailyGalleryItems.isEmpty
                  ? Center(child: Text('No gallery photos yet.', style: TextStyle(color: Colors.grey.shade600)))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _dailyGalleryItems.length,
                      itemBuilder: (context, index) {
                        final item = _dailyGalleryItems[index];
                        final url = '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/gallery/${item.id}/file${authToken != null ? '?token=$authToken' : ''}';
                        // Alternate rotations: left, straight, right
                        final double rotation = index % 3 == 0 ? -0.05 : (index % 3 == 1 ? 0.0 : 0.05);
                        return Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: _PolaroidCard(url: url, caption: 'Moment ${index + 1} 📸', angle: rotation),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFeeSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.04),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.savings, color: Color(0xFFF28F1D), size: 36),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fee Summary',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2323)),
                  ),
                  Text(
                    'Total Yearly Overview',
                    style: TextStyle(fontSize: 14, color: Colors.orange.shade800),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.orange.shade100, thickness: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'TOTAL\nOUTSTANDING',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Color(0xFF7C6E6E),
                  height: 1.4,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4, right: 4),
                    child: Text('₹', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2323))),
                  ),
                  Text(
                    NumberFormat('#,##,###').format(_feeData!['total_balance'] ?? 0),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF2D2323)),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.orange.shade100, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 60), // Space for PLAY button
              _BottomNavBtn(icon: Icons.school, label: 'LEARN', active: false),
              _BottomNavBtn(icon: Icons.auto_awesome, label: 'MOMENTS', active: false),
              _BottomNavBtn(icon: Icons.chat_bubble, label: 'CHAT', active: false),
              const SizedBox(width: 60), // Space for FAB
            ],
          ),
          Positioned(
            top: -15,
            left: 20,
            child: Container(
              height: 65,
              width: 55,
              decoration: BoxDecoration(
                color: const Color(0xFFF25C15),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFF25C15).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.toys, color: Colors.white, size: 24),
                  SizedBox(height: 4),
                  Text('PLAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _SaffronGridBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  const _SaffronGridBtn({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PolaroidCard extends StatelessWidget {
  final String url;
  final String caption;
  final double angle;

  const _PolaroidCard({required this.url, required this.caption, required this.angle});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 160,
        padding: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(5, 10),
            )
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.grey.shade100,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              caption,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF2D2323),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _BottomNavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _BottomNavBtn({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? const Color(0xFFF25C15) : Colors.grey.shade400, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: active ? const Color(0xFFF25C15) : Colors.grey.shade400,
          ),
        )
      ],
    );
  }
}
