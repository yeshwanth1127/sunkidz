import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/utils/branch_system.dart';
import '../../../shared/widgets/copy_admission_number_button.dart';

class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({
    super.key,
    required this.branchId,
    required this.classId,
    this.className,
    this.systemType,
  });

  final String branchId;
  final String classId;
  final String? className;
  final String? systemType;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(adminApiProvider);
    if (api == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await api.getAdmissions(
        branchId: widget.branchId,
        classId: widget.classId,
      );
      // The /admin/users endpoint doesn't accept a class_id filter, but every
      // teacher record it returns already carries the class_id of their
      // assignment, so all teachers for this exact class can be found by
      // filtering the real, already-fetched data client-side.
      final teacherUsers = await api.getUsers(
        role: 'teacher',
        branchId: widget.branchId,
      );
      final teachers =
          teacherUsers
              .where((u) => u['class_id']?.toString() == widget.classId)
              .toList();
      if (!mounted) return;
      setState(() {
        _students = students;
        _teachers = teachers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = canonicalGradeLabel(widget.className, widget.systemType);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title.isNotEmpty ? title : 'Class',
          style: const TextStyle(
            color: Color(0xFF2D2323),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Teachers',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${_teachers.length}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_teachers.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No teacher assigned to this class.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      ..._teachers.map(
                        (t) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.pastelBlue,
                              child: Icon(
                                Icons.person,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              t['full_name']?.toString() ?? 'Teacher',
                            ),
                            subtitle: Text(
                              t['email']?.toString() ??
                                  t['phone']?.toString() ??
                                  '',
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Students',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${_students.length}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_students.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No students in this class.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      ..._students.map(
                        (s) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.pastelGreen,
                              child: Icon(
                                Icons.face_retouching_natural_rounded,
                                color: Colors.green.shade700,
                              ),
                            ),
                            title: Text(s['name']?.toString() ?? 'Student'),
                            subtitle: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('ID: ${s['admission_number'] ?? '—'}'),
                                CopyAdmissionNumberButton(
                                  admissionNumber:
                                      s['admission_number']?.toString(),
                                  size: 13,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}
