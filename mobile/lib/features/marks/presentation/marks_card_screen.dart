import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/config/api_config.dart';
import '../../../core/utils/branch_system.dart';
import '../../../shared/widgets/marks_card_form.dart';
import 'marks_student_selector.dart';

/// Admin → Marks Card.
///
/// Flow: Branch → Grade → Student → Academic Year → the selected student's
/// editable Sun Kidz PERFORMANCE PROFILE card ([MarksCardForm]).
class MarksCardScreen extends ConsumerStatefulWidget {
  const MarksCardScreen({super.key});

  @override
  ConsumerState<MarksCardScreen> createState() => _MarksCardScreenState();
}

class _MarksCardScreenState extends ConsumerState<MarksCardScreen> {
  static const _academicYears = ['2026-27'];

  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _students = [];

  String? _selectedBranchId;
  String? _selectedClassId;
  Map<String, dynamic>? _selectedStudent;

  Map<String, dynamic> _marksData = {};
  String _academicYear = '2026-27';

  bool _loadingBranches = false;
  bool _loadingClasses = false;
  bool _loadingStudents = false;
  bool _loadingMarks = false;
  bool _sendingToParent = false;
  String? _sentToParentAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() => _loadingBranches = true);
    try {
      final branches = await api.getBranches();
      if (mounted) setState(() => _branches = branches);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
    if (mounted) setState(() => _loadingBranches = false);
  }

  Future<void> _loadClasses(String branchId) async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() {
      _loadingClasses = true;
      _error = null;
    });
    try {
      final classes = sortByCanonicalGrade(
        await api.getClasses(branchId: branchId),
        (c) => c['name'] as String?,
      );
      if (mounted) setState(() => _classes = classes);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
    if (mounted) setState(() => _loadingClasses = false);
  }

  Future<void> _loadStudents() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() => _loadingStudents = true);
    try {
      final students = await api.getAdmissions(
        branchId: _selectedBranchId,
        classId: _selectedClassId,
      );
      if (mounted) setState(() => _students = students);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
    if (mounted) setState(() => _loadingStudents = false);
  }

  void _onBranchChanged(String? branchId) {
    setState(() {
      _selectedBranchId = branchId;
      _classes = [];
      _selectedClassId = null;
      _students = [];
      _selectedStudent = null;
      _marksData = {};
      _sentToParentAt = null;
      _error = null;
    });
    if (branchId != null) {
      _loadClasses(branchId).then((_) => _loadStudents());
    } else {
      _loadStudents();
    }
  }

  void _onClassChanged(String? classId) {
    setState(() {
      _selectedClassId = classId;
      _students = [];
      _selectedStudent = null;
      _marksData = {};
      _sentToParentAt = null;
    });
    _loadStudents();
  }

  Future<void> _onStudentChanged(Map<String, dynamic>? student) async {
    setState(() {
      _selectedStudent = student;
      _marksData = {};
      _sentToParentAt = null;
      _error = null;
      _loadingMarks = student != null;
    });
    if (student == null) return;
    await _loadMarks();
  }

  Future<void> _loadMarks() async {
    final api = ref.read(adminApiProvider);
    final student = _selectedStudent;
    if (api == null || student == null) return;
    setState(() => _loadingMarks = true);
    try {
      final res = await api.getMarks(
        student['id'],
        academicYear: _academicYear,
      );
      if (mounted) {
        setState(() {
          _marksData = Map<String, dynamic>.from(res['data'] as Map? ?? {});
          _sentToParentAt = res['sent_to_parent_at'] as String?;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
    if (mounted) setState(() => _loadingMarks = false);
  }

  Future<void> _saveMarks(Map<String, dynamic> data) async {
    final api = ref.read(adminApiProvider);
    final student = _selectedStudent;
    if (api == null || student == null) return;
    setState(() => _error = null);
    try {
      final res = await api.upsertMarks(
        student['id'],
        academicYear: _academicYear,
        data: data,
      );
      if (mounted) {
        setState(() {
          _marksData = Map<String, dynamic>.from(res['data'] as Map? ?? data);
          _sentToParentAt = res['sent_to_parent_at'] as String?;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
      rethrow;
    }
  }

  Future<void> _sendToParent() async {
    final api = ref.read(adminApiProvider);
    final student = _selectedStudent;
    if (api == null || student == null) return;
    // Send operates on the last-saved server copy; require a save first.
    if (_marksData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save the marks card before sending it to the parent'),
        ),
      );
      return;
    }
    setState(() => _sendingToParent = true);
    try {
      await api.sendMarksToParent(student['id'], academicYear: _academicYear);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marks card sent to parent')),
      );
      await _loadMarks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${_msg(e)}')));
      }
    }
    if (mounted) setState(() => _sendingToParent = false);
  }

  String _msg(Object e) => e.toString().replaceAll('Exception: ', '');

  /// Uploads a Parent / Class Teacher / Principal signature image for the
  /// selected student's current marks card. Returns the stored path (which the
  /// form uses to show the preview) or null on failure.
  Future<String?> _uploadSignature(
    String role,
    Uint8List bytes,
    String filename,
  ) async {
    final api = ref.read(adminApiProvider);
    final student = _selectedStudent;
    if (api == null || student == null) return null;
    if (_marksData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save the marks card before adding a signature'),
        ),
      );
      return null;
    }
    try {
      final res = await api.uploadMarksSignature(
        student['id'],
        academicYear: _academicYear,
        role: role,
        bytes: bytes,
        filename: filename,
      );
      final data = res['data'];
      if (data is Map) {
        _marksData = Map<String, dynamic>.from(data);
      }
      return res['path'] as String?;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${_msg(e)}')));
      }
      return null;
    }
  }

  /// Prominent action shown directly below the Marks Card (which ends with its
  /// own "Save Marks" button). Drives the existing `/admin/marks/{id}/send-to-parent`
  /// flow via [_sendToParent] — which requires a saved server copy first.
  Widget _sendToParentButton() {
    final sent = _sentToParentAt != null;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('marks_send_to_parent_button'),
        onPressed: _sendingToParent ? null : _sendToParent,
        style: FilledButton.styleFrom(
          backgroundColor: sent ? Colors.green.shade700 : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon:
            _sendingToParent
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Icon(sent ? Icons.check_circle : Icons.send, size: 18),
        label: Text(
          _sendingToParent
              ? 'Sending…'
              : (sent ? 'Sent to Parent' : 'Send to Parent'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = _selectedStudent;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Marks Card',
          style: TextStyle(
            color: Color(0xFF2D2323),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (student != null) ...[
            if (_sentToParentAt != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Colors.green.shade700,
                  semanticLabel: 'Sent to parent',
                ),
              ),
            IconButton(
              tooltip: _sendingToParent ? 'Sending…' : 'Send to Parent',
              onPressed: _sendingToParent ? null : _sendToParent,
              icon:
                  _sendingToParent
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send, size: 20),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MarksStudentSelector(
              branches: _branches,
              classes: _classes,
              students: _students,
              selectedBranchId: _selectedBranchId,
              selectedClassId: _selectedClassId,
              selectedStudent: _selectedStudent,
              academicYear: _academicYear,
              academicYearOptions: _academicYears,
              loadingClasses: _loadingClasses,
              loadingStudents: _loadingStudents,
              onBranchChanged: _onBranchChanged,
              onClassChanged: _onClassChanged,
              onStudentChanged: _onStudentChanged,
              onAcademicYearChanged: (y) {
                setState(() {
                  _academicYear = y;
                  if (_selectedStudent != null) _loadingMarks = true;
                });
                if (_selectedStudent != null) _loadMarks();
              },
            ),
            if (_loadingBranches && _branches.isEmpty) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            if (student != null) ...[
              const SizedBox(height: 20),
              if (_loadingMarks)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                MarksCardForm(
                  student: student,
                  academicYear: _academicYear,
                  initialData: _marksData,
                  onSave: _saveMarks,
                  onUploadSignature: _uploadSignature,
                  signatureUploadRoles: const {
                    'parent',
                    'class_teacher',
                    'principal',
                  },
                  signatureBaseUrl: ApiConfig.baseUrl,
                ),
                const SizedBox(height: 12),
                _sendToParentButton(),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
