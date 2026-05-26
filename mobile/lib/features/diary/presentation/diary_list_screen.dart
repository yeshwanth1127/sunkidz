import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../core/api/parent_provider.dart';
import '../../../core/api/diary_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Class diary — class-wide remarks/activities/homework plus optional
/// per-student notes so each child gets their own daily entry.
class DiaryListScreen extends ConsumerStatefulWidget {
  const DiaryListScreen({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  ConsumerState<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends ConsumerState<DiaryListScreen> {
  String? _selectedClassId;
  String? _selectedStudentId; // null = "All / class-wide"
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  String? get _selectedClassLabel {
    if (_selectedClassId == null) return null;
    final m = _classes.firstWhere(
      (c) => c['id'] == _selectedClassId,
      orElse: () => const <String, dynamic>{},
    );
    return m['name'] as String?;
  }

  Future<void> _loadClasses() async {
    final auth = ref.read(authProvider);
    final classes = <Map<String, dynamic>>[];

    try {
      if (widget.readOnly && auth.role == UserRole.parent) {
        final api = ref.read(parentApiProvider);
        if (api != null) {
          final response = await api.getChildren();
          for (final child in (response['children'] as List? ?? [])) {
            final m = child as Map<String, dynamic>;
            final classId = m['class_id']?.toString();
            if (classId != null) {
              classes.add({
                'id': classId,
                'name':
                    '${m['class_name'] ?? ''} · ${m['branch_name'] ?? ''} (${m['name'] ?? ''})',
              });
            }
          }
        }
      } else if (auth.role == UserRole.admin) {
        final api = ref.read(adminApiProvider);
        if (api != null) {
          for (final branch in await api.getBranches()) {
            for (final cls in (branch['classes'] as List? ?? [])) {
              classes.add({
                'id': cls['id'],
                'name': '${cls['name']} — ${branch['name']}',
              });
            }
          }
        }
      } else if (auth.role == UserRole.coordinator) {
        final api = ref.read(coordinatorApiProvider);
        if (api != null) {
          final dash = await api.getDashboard();
          final branchName = dash['branch_name'] ?? '';
          for (final cls in (dash['classes'] as List? ?? [])) {
            classes.add({
              'id': cls['id'],
              'name': '${cls['name']} — $branchName',
            });
          }
        }
      } else if (auth.role == UserRole.teacher) {
        final api = ref.read(teacherApiProvider);
        if (api != null) {
          final assigned = await api.getMyClasses();
          if (assigned.isNotEmpty) {
            for (final c in assigned) {
              classes.add({
                'id': c['class_id'],
                'name': '${c['class_name']} — ${c['branch_name'] ?? ''}',
              });
            }
          } else {
            final dash = await api.getDashboard();
            final classId = dash['class_id']?.toString();
            if (classId != null) {
              classes.add({
                'id': classId,
                'name': '${dash['class_name']} — ${dash['branch_name']}',
              });
            }
            for (final c in (dash['classes'] as List? ?? [])) {
              final id = c['class_id']?.toString();
              if (id != null && !classes.any((x) => x['id'] == id)) {
                classes.add({
                  'id': id,
                  'name': '${c['class_name']} — ${c['branch_name'] ?? ''}',
                });
              }
            }
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _classes = classes;
      if (_selectedClassId == null && classes.isNotEmpty) {
        _selectedClassId = classes.first['id'] as String;
      }
    });
    if (_selectedClassId != null) {
      await _loadStudents();
      await _loadEntries();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStudents() async {
    final api = ref.read(diaryApiProvider);
    if (api == null || _selectedClassId == null) return;
    try {
      final list = await api.listClassStudents(_selectedClassId!);
      if (!mounted) return;
      setState(() => _students = list);
    } catch (_) {
      if (mounted) setState(() => _students = []);
    }
  }

  Future<void> _loadEntries() async {
    final diaryApi = ref.read(diaryApiProvider);
    if (diaryApi == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      List<Map<String, dynamic>> entries;
      if (widget.readOnly && ref.read(authProvider).role == UserRole.parent) {
        entries = await diaryApi.listParentEntries();
        if (_selectedClassId != null) {
          entries = entries
              .where((e) => e['class_id']?.toString() == _selectedClassId)
              .toList();
        }
      } else if (_selectedClassId != null) {
        entries = await diaryApi.listEntries(
          classId: _selectedClassId!,
          studentId: _selectedStudentId,
        );
      } else {
        entries = [];
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? existing]) async {
    if (widget.readOnly || _selectedClassId == null) return;

    final remarksCtrl = TextEditingController(text: existing?['remarks']?.toString() ?? '');
    final activitiesCtrl = TextEditingController(text: existing?['activities']?.toString() ?? '');
    final homeworkCtrl = TextEditingController(text: existing?['homework_notes']?.toString() ?? '');
    DateTime entryDate = existing != null
        ? DateTime.tryParse(existing['entry_date']?.toString() ?? '') ?? DateTime.now()
        : DateTime.now();

    // For new entries we use the current sidebar selection.
    // For edits we keep the entry's own student_id.
    String? studentId = existing != null
        ? existing['student_id']?.toString()
        : _selectedStudentId;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Diary entry', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  if (_selectedClassLabel != null)
                    Text(_selectedClassLabel!, style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text(DateFormat.yMMMd().format(entryDate)),
                      const Spacer(),
                      TextButton(
                        onPressed: existing != null
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: entryDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 1)),
                                );
                                if (picked != null) {
                                  setSheet(() => entryDate = picked);
                                }
                              },
                        child: const Text('Change date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: studentId,
                    decoration: const InputDecoration(
                      labelText: 'For',
                      helperText: 'Class-wide note OR pick a student',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Class-wide (all students)'),
                      ),
                      ..._students.map(
                        (s) => DropdownMenuItem<String?>(
                          value: s['id'] as String,
                          child: Text(s['name'] as String? ?? ''),
                        ),
                      ),
                    ],
                    onChanged: existing != null
                        ? null // can't move an entry between scopes
                        : (v) => setSheet(() => studentId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksCtrl,
                    decoration: const InputDecoration(labelText: 'Remarks'),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: activitiesCtrl,
                    decoration: const InputDecoration(labelText: 'Day activities'),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: homeworkCtrl,
                    decoration: const InputDecoration(labelText: 'Homework notes'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (saved != true) return;
    final api = ref.read(diaryApiProvider);
    if (api == null) return;

    try {
      await api.upsertEntry(
        classId: _selectedClassId!,
        entryDate: DateFormat('yyyy-MM-dd').format(entryDate),
        studentId: studentId,
        remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
        activities: activitiesCtrl.text.trim().isEmpty ? null : activitiesCtrl.text.trim(),
        homeworkNotes: homeworkCtrl.text.trim().isEmpty ? null : homeworkCtrl.text.trim(),
      );
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diary saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _deleteEntry(String id) async {
    final api = ref.read(diaryApiProvider);
    if (api == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete diary entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deleteEntry(id);
      await _loadEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _entryCard(Map<String, dynamic> e, {required bool canWrite}) {
    final date = DateTime.parse(e['entry_date'].toString());
    final studentName = e['student_name']?.toString();
    final isClassWide = e['student_id'] == null;
    final author = e['author_name']?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isClassWide
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isClassWide ? 'Class-wide' : (studentName ?? 'Student'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isClassWide ? AppColors.primary : Colors.deepOrange,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat.yMMMd().format(date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (e['class_name'] != null || e['branch_name'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${e['class_name'] ?? ''} · ${e['branch_name'] ?? ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            if (e['remarks'] != null && e['remarks'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Remarks: ${e['remarks']}'),
              ),
            if (e['activities'] != null && e['activities'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Activities: ${e['activities']}'),
              ),
            if (e['homework_notes'] != null && e['homework_notes'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Homework: ${e['homework_notes']}'),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (author != null)
                  Expanded(
                    child: Text(
                      'by $author',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                if (canWrite) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _openEditor(e),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () => _deleteEntry(e['id'].toString()),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    final canWrite = !widget.readOnly && role != UserRole.parent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Diary'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: _selectedClassLabel == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _selectedClassLabel!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
      ),
      floatingActionButton: canWrite && _selectedClassId != null
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.edit_note),
              label: Text(
                _selectedStudentId == null ? 'Add class note' : 'Add student note',
              ),
            )
          : null,
      body: Column(
        children: [
          if (_classes.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedClassId,
                decoration: const InputDecoration(labelText: 'Class · Branch'),
                items: _classes
                    .map((c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(c['name'] as String? ?? ''),
                        ))
                    .toList(),
                onChanged: (v) async {
                  setState(() {
                    _selectedClassId = v;
                    _selectedStudentId = null;
                    _students = [];
                  });
                  await _loadStudents();
                  await _loadEntries();
                },
              ),
            ),
          if (!widget.readOnly && _students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedStudentId,
                decoration: const InputDecoration(
                  labelText: 'Filter by student',
                  helperText: 'Class-wide notes always visible',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All students'),
                  ),
                  ..._students.map(
                    (s) => DropdownMenuItem<String?>(
                      value: s['id'] as String,
                      child: Text(s['name'] as String? ?? ''),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedStudentId = v);
                  _loadEntries();
                },
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _entries.isEmpty
                        ? const Center(child: Text('No diary entries yet'))
                        : RefreshIndicator(
                            onRefresh: _loadEntries,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _entries.length,
                              itemBuilder: (_, i) =>
                                  _entryCard(_entries[i], canWrite: canWrite),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
