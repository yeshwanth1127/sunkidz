import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/utils/branch_system.dart';
import '../../../shared/widgets/branch_grade_filter.dart';

import '../../../core/api/admin_provider.dart';
import '../providers/syllabus_provider.dart';
import '../domain/models/syllabus_model.dart';
import 'homework_upload_screen.dart';

class HomeworkListScreen extends ConsumerStatefulWidget {
  const HomeworkListScreen({super.key});

  @override
  ConsumerState<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends ConsumerState<HomeworkListScreen> {
  String? _selectedBranchId;
  String? _selectedGrade;
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _classes = [];

  /// Class ids matching the Branch / Grade filters, or null when neither is
  /// set (no class filtering).
  Set<String>? get _matchingClassIds {
    if (_selectedBranchId == null && _selectedGrade == null) return null;
    return _classes
        .where(
          (c) =>
              (_selectedBranchId == null ||
                  c['branch_id'] == _selectedBranchId) &&
              (_selectedGrade == null || c['grade'] == _selectedGrade),
        )
        .map((c) => c['id'].toString())
        .toSet();
  }

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final auth = ref.read(authProvider);
    // Only load classes for admin
    if (auth.role != UserRole.admin) {
      return;
    }
    final api = ref.read(adminApiProvider);
    if (api == null) {
      return;
    }
    try {
      final branches = await api.getBranches();
      final classes = <Map<String, dynamic>>[];
      for (final branch in branches) {
        if (branch['classes'] != null) {
          for (final cls in branch['classes']) {
            final grade = canonicalGradeLabel(cls['name']?.toString());
            classes.add({
              'id': cls['id'],
              'name': '$grade - ${branch['name']}',
              'grade': grade,
              'branch_id': branch['id']?.toString(),
            });
          }
        }
      }
      setState(() {
        _branches = branches;
        _classes = sortByCanonicalGrade(classes, (c) => c['grade'] as String?);
      });
    } catch (e) {
      // Handle error silently
    }
  }

  void _navigateToUpload() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomeworkUploadScreen()),
    ).then((_) => setState(() {}));
  }

  Future<void> _viewHomeworkFile(String homeworkId) async {
    final auth = ref.read(authProvider);
    final token = auth.token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login again to view files')),
        );
      }
      return;
    }

    final encodedToken = Uri.encodeQueryComponent(token);
    final url =
        '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/homework/$homeworkId/file?token=$encodedToken';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteHomework(String homeworkId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Homework'),
            content: const Text(
              'Are you sure you want to delete this homework?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(syllabusServiceProvider);
        await service.deleteHomework(homeworkId);
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Homework deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting homework: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isAdmin = auth.role == UserRole.admin;
    final canUpload =
        auth.role == UserRole.admin ||
        auth.role == UserRole.teacher ||
        auth.role == UserRole.coordinator;
    final isParent = auth.role == UserRole.parent;
    final matchingClassIds = _matchingClassIds;
    final filter = HomeworkFilter(
      // A single matching class is filtered server-side as before; broader
      // Branch / Grade selections are filtered client-side below.
      classId:
          matchingClassIds != null && matchingClassIds.length == 1
              ? matchingClassIds.first
              : null,
      uploadDate: _selectedDate?.toIso8601String().split('T')[0],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Homework',
          style: TextStyle(
            color: Color(0xFF2D2323),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (canUpload)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black87),
              onPressed: _navigateToUpload,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Branch / Grade filters (only for admin)
                if (isAdmin) ...[
                  BranchFilterDropdown(
                    branches: _branches,
                    value: _selectedBranchId,
                    onChanged:
                        (value) => setState(() {
                          _selectedBranchId = value;
                          _selectedGrade = null;
                        }),
                  ),
                  const SizedBox(height: 12),
                  GradeFilterDropdown(
                    value: _selectedGrade,
                    onChanged: (value) => setState(() => _selectedGrade = value),
                  ),
                  const SizedBox(height: 12),
                ],
                // Date filter
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Filter by Date',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _selectedDate != null
                          ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                          : 'All Dates',
                    ),
                  ),
                ),
                if (_selectedDate != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _selectedDate = null),
                      child: const Text('Clear Date'),
                    ),
                  ),
              ],
            ),
          ),
          // List
          Expanded(
            child: ref
                .watch(homeworkListProvider(filter))
                .when(
                  data: (allHomework) {
                    final homeworkList =
                        matchingClassIds == null
                            ? allHomework
                            : allHomework
                                .where(
                                  (h) => matchingClassIds.contains(h.classId),
                                )
                                .toList();
                    if (homeworkList.isEmpty) {
                      return const Center(child: Text('No homework found'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: homeworkList.length,
                      itemBuilder: (context, index) {
                        final homework = homeworkList[index];
                        return _HomeworkCard(
                          homework: homework,
                          isAdmin: isAdmin,
                          onView: () => _viewHomeworkFile(homework.id),
                          onDelete:
                              isAdmin
                                  ? () => _deleteHomework(homework.id)
                                  : null,
                        );
                      },
                    );
                  },
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Error: $error')),
                ),
          ),
        ],
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  final Homework homework;
  final bool isAdmin;
  final VoidCallback onView;
  final VoidCallback? onDelete;

  const _HomeworkCard({
    required this.homework,
    required this.isAdmin,
    required this.onView,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.assignment, color: AppColors.primary),
        ),
        title: Text(
          homework.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class: ${canonicalGradeLabel(homework.className)}'),
            Text(
              'Upload Date: ${DateFormat('MMM dd, yyyy').format(homework.uploadDate)}',
            ),
            if (homework.dueDate != null)
              Text(
                'Due Date: ${DateFormat('MMM dd, yyyy').format(homework.dueDate!)}',
              ),
            if (homework.uploaderName != null)
              Text('Assigned by: ${homework.uploaderName}'),
            if (homework.fileSize != null) Text('Size: ${homework.fileSize}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility),
                      SizedBox(width: 8),
                      Text('View'),
                    ],
                  ),
                ),
                if (isAdmin)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
          onSelected: (value) {
            if (value == 'delete' && onDelete != null) {
              onDelete!();
            } else if (value == 'view') {
              onView();
            }
          },
        ),
        isThreeLine: true,
      ),
    );
  }
}
