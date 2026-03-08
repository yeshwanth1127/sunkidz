import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../shared/widgets/teacher_drawer.dart';
import '../../../shared/widgets/marks_card_form.dart';

class TeacherMarksEntryScreen extends ConsumerStatefulWidget {
  final String studentId;

  const TeacherMarksEntryScreen({super.key, required this.studentId});

  @override
  ConsumerState<TeacherMarksEntryScreen> createState() => _TeacherMarksEntryScreenState();
}

class _TeacherMarksEntryScreenState extends ConsumerState<TeacherMarksEntryScreen> {
  Map<String, dynamic>? _student;
  Map<String, dynamic> _data = {};
  String _academicYear = '2024-25';
  bool _loading = true;
  bool _sendingToParent = false;
  String? _sentToParentAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(teacherApiProvider);
    if (api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final student = await api.getStudent(widget.studentId);
      final marks = await api.getMarks(widget.studentId, academicYear: _academicYear);
      if (mounted) setState(() {
        _student = student;
        _data = Map<String, dynamic>.from(marks['data'] as Map? ?? {});
        _sentToParentAt = marks['sent_to_parent_at'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _save(Map<String, dynamic> data) async {
    await ref.read(teacherApiProvider)!.upsertMarks(
          widget.studentId,
          academicYear: _academicYear,
          data: data,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      drawer: const TeacherDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(_student?['name'] ?? 'Marks'),
        actions: [
          if (_sentToParentAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                label: Text('Sent', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
              ),
            ),
          TextButton.icon(
            onPressed: _sendingToParent ? null : () async {
              setState(() => _sendingToParent = true);
              try {
                await ref.read(teacherApiProvider)!.sendMarksToParent(widget.studentId, academicYear: _academicYear);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marks card sent to parent')));
                  setState(() => _sendingToParent = false);
                  _load();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  setState(() => _sendingToParent = false);
                }
              }
            },
            icon: _sendingToParent ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, size: 18),
            label: Text(_sendingToParent ? 'Sending...' : 'Send to Parent'),
          ),
          DropdownButton<String>(
            value: _academicYear,
            items: const [
              DropdownMenuItem(value: '2024-25', child: Text('2024-25')),
              DropdownMenuItem(value: '2025-26', child: Text('2025-26')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _academicYear = v);
                _load();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _student == null
                  ? const Center(child: Text('Student not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: MarksCardForm(
                        student: _student!,
                        academicYear: _academicYear,
                        initialData: _data,
                        onSave: _save,
                        error: _error,
                      ),
                    ),
    );
  }
}
