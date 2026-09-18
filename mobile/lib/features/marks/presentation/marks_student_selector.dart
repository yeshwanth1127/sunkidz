import 'package:flutter/material.dart';
import '../../../core/utils/branch_system.dart';

/// Branch → Grade → Student → Academic Year selector for the Marks Card flow.
///
/// Stateless: the parent screen owns the data lists and the current selection
/// and rebuilds this widget when they change. Extracted from
/// [MarksCardScreen] so the dependent-dropdown behaviour can be widget-tested
/// without a live backend.
///
/// The Grade dropdown is explicitly dependent on Branch: it stays disabled
/// (with an explanatory hint) until a specific branch is chosen and its
/// classes have loaded. Every dropdown uses `isExpanded: true` and the fields
/// are stacked vertically so nothing overflows on a phone viewport.
class MarksStudentSelector extends StatelessWidget {
  const MarksStudentSelector({
    super.key,
    required this.branches,
    required this.classes,
    required this.students,
    required this.selectedBranchId,
    required this.selectedClassId,
    required this.selectedStudent,
    required this.academicYear,
    required this.academicYearOptions,
    required this.onBranchChanged,
    required this.onClassChanged,
    required this.onStudentChanged,
    required this.onAcademicYearChanged,
    this.loadingClasses = false,
    this.loadingStudents = false,
  });

  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> students;
  final String? selectedBranchId;
  final String? selectedClassId;
  final Map<String, dynamic>? selectedStudent;
  final String academicYear;
  final List<String> academicYearOptions;
  final bool loadingClasses;
  final bool loadingStudents;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<Map<String, dynamic>?> onStudentChanged;
  final ValueChanged<String> onAcademicYearChanged;

  bool get _branchChosen => selectedBranchId != null;
  bool get _gradeChosen => selectedClassId != null;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Select Student', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _branchField(),
          const SizedBox(height: 12),
          _gradeField(),
          const SizedBox(height: 12),
          _studentField(),
          const SizedBox(height: 12),
          _academicYearField(),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, {String? helper}) => InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  Widget _branchField() {
    return DropdownButtonFormField<String>(
      key: const Key('marks_branch_dropdown'),
      value: selectedBranchId,
      isExpanded: true,
      decoration: _decoration('Branch'),
      hint: const Text('Select a branch'),
      items: [
        const DropdownMenuItem(value: null, child: Text('All branches')),
        ...branches.map(
          (b) => DropdownMenuItem(
            value: b['id']?.toString(),
            child: Text(
              b['name']?.toString() ?? '—',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onBranchChanged,
    );
  }

  Widget _gradeField() {
    final gradeItems = classes
        .map(
          (c) => DropdownMenuItem<String>(
            value: c['id']?.toString(),
            child: Text(
              canonicalGradeLabel(c['name']?.toString()),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();

    final enabled = _branchChosen && gradeItems.isNotEmpty;

    String disabledHint;
    if (!_branchChosen) {
      disabledHint = 'Select a branch first';
    } else if (loadingClasses) {
      disabledHint = 'Loading grades…';
    } else {
      disabledHint = 'No grades in this branch';
    }

    return DropdownButtonFormField<String>(
      key: const Key('marks_grade_dropdown'),
      value: enabled ? selectedClassId : null,
      isExpanded: true,
      decoration: _decoration('Grade'),
      hint: const Text('Select a grade'),
      disabledHint: Text(disabledHint),
      items: enabled ? gradeItems : const [],
      onChanged: enabled ? onClassChanged : null,
    );
  }

  Widget _studentField() {
    final enabled = students.isNotEmpty;
    return DropdownButtonFormField<Map<String, dynamic>>(
      key: const Key('marks_student_dropdown'),
      value: (enabled && students.contains(selectedStudent))
          ? selectedStudent
          : null,
      isExpanded: true,
      decoration: _decoration('Student'),
      hint: const Text('Select a student'),
      disabledHint: Text(
        loadingStudents
            ? 'Loading students…'
            : (!_branchChosen
                ? 'Select a branch first'
                : (!_gradeChosen
                    ? 'Select a grade first'
                    : 'No students in this grade')),
      ),
      items: enabled
          ? students
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    '${s['name'] ?? '—'}'
                    '${(s['admission_number'] ?? '').toString().isNotEmpty ? ' (${s['admission_number']})' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList()
          : const [],
      onChanged: enabled ? onStudentChanged : null,
    );
  }

  Widget _academicYearField() {
    final options = academicYearOptions.isEmpty
        ? [academicYear]
        : academicYearOptions;
    return DropdownButtonFormField<String>(
      key: const Key('marks_year_dropdown'),
      value: options.contains(academicYear) ? academicYear : options.first,
      isExpanded: true,
      decoration: _decoration('Academic Year'),
      items: options
          .map((y) => DropdownMenuItem(value: y, child: Text(y)))
          .toList(),
      onChanged: (v) {
        if (v != null) onAcademicYearChanged(v);
      },
    );
  }
}
