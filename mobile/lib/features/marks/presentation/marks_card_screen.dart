import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';

/// Marks card screen matching Sun Kidz PERFORMANCE PROFILE design.
/// Student selection, scholastic & co-scholastic marks input.
class MarksCardScreen extends ConsumerStatefulWidget {
  const MarksCardScreen({super.key});

  @override
  ConsumerState<MarksCardScreen> createState() => _MarksCardScreenState();
}

class _MarksCardScreenState extends ConsumerState<MarksCardScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _classes = [];
  String? _selectedBranchId;
  String? _selectedClassId;
  Map<String, dynamic>? _selectedStudent;
  Map<String, dynamic> _data = {};
  String _academicYear = '2024-25';
  bool _loading = false;
  bool _saving = false;
  bool _sendingToParent = false;
  String? _sentToParentAt;
  String? _error;

  static const _cols = ['pt1', 'ca1', 'hy', 'pt2', 'an'];
  static const _colLabels = ['PT1', 'CA1', 'HY Term 1', 'PT2', 'AN Term 2'];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final branches = await api.getBranches();
      if (mounted) setState(() {
        _branches = branches;
        _classes = [];
        _selectedClassId = null;
      });
      await _loadStudents();
      if (_selectedBranchId != null) await _loadClasses(_selectedBranchId!);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadClasses(String branchId) async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      final classes = await api.getClasses(branchId: branchId);
      if (mounted) setState(() {
        _classes = classes;
        _selectedClassId = null;
      });
    } catch (_) {}
  }

  Future<void> _loadStudents() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      final students = await api.getAdmissions(
        branchId: _selectedBranchId,
        classId: _selectedClassId,
      );
      if (mounted) setState(() => _students = students);
    } catch (_) {}
  }

  void _onStudentSelected(Map<String, dynamic>? student) async {
    setState(() {
      _selectedStudent = student;
      _data = {};
      _error = null;
    });
    if (student == null) return;
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final res = await api.getMarks(student['id'], academicYear: _academicYear);
      if (mounted) setState(() {
        _data = Map<String, dynamic>.from(res['data'] as Map? ?? {});
        _sentToParentAt = res['sent_to_parent_at'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _data = {};
        _loading = false;
      });
    }
  }

  int _getInt(String key, [int def = 0]) =>
      (_data[key] is int) ? _data[key] as int : (int.tryParse(_data[key]?.toString() ?? '') ?? def);

  String _getStr(String key, [String def = '']) => _data[key]?.toString() ?? def;

  void _set(String key, dynamic value) => setState(() => _data[key] = value);

  void _setNested(String subject, String item, String col, int value) {
    setState(() {
      _data[subject] ??= {};
      (_data[subject] as Map)[item] ??= {};
      (_data[subject] as Map)[item][col] = value;
    });
  }

  int _getNested(String subject, String item, String col) {
    try {
      final s = _data[subject] as Map?;
      final i = s?[item] as Map?;
      final v = i?[col];
      return v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _save() async {
    if (_selectedStudent == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminApiProvider)!.upsertMarks(
            _selectedStudent!['id'],
            academicYear: _academicYear,
            data: _data,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marks saved')));
        setState(() => _saving = false);
        _onStudentSelected(_selectedStudent);
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Marks Card'),
        actions: [
          if (_selectedStudent != null) ...[
            if (_sentToParentAt != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  avatar: Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                  label: Text('Sent to parent', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                ),
              ),
            TextButton.icon(
              onPressed: _sendingToParent ? null : () async {
                if (_selectedStudent == null) return;
                setState(() => _sendingToParent = true);
                try {
                  await ref.read(adminApiProvider)!.sendMarksToParent(_selectedStudent!['id'], academicYear: _academicYear);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marks card sent to parent')));
                    setState(() => _sendingToParent = false);
                    _onStudentSelected(_selectedStudent);
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
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            ),
          ],
        ],
      ),
      body: _loading && _selectedStudent == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStudentSelector(),
                  if (_selectedStudent != null) ...[
                    const SizedBox(height: 24),
                    _buildMarksCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStudentSelector() {
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
          Text('Select Student', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBranchId,
                  decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All branches')),
                    ..._branches.map((b) => DropdownMenuItem(value: b['id'] as String?, child: Text(b['name']?.toString() ?? '—'))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selectedBranchId = v;
                      _classes = [];
                      _selectedClassId = null;
                      _selectedStudent = null;
                    });
                    if (v != null) _loadClasses(v).then((_) => _loadStudents());
                    else _loadStudents();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedClassId,
                  decoration: const InputDecoration(labelText: 'Grade', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All grades')),
                    ..._classes.map((c) => DropdownMenuItem(value: c['id'] as String?, child: Text(c['name']?.toString() ?? '—'))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selectedClassId = v;
                      _selectedStudent = null;
                    });
                    _loadStudents();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _selectedStudent,
            decoration: const InputDecoration(labelText: 'Student', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            items: [
              const DropdownMenuItem(value: null, child: Text('Select a student')),
              ..._students.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text('${s['name']} (${s['admission_number'] ?? ''})'),
                  )),
            ],
            onChanged: _onStudentSelected,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _academicYear,
            decoration: const InputDecoration(labelText: 'Academic Year', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            items: const [
              DropdownMenuItem(value: '2024-25', child: Text('2024-25')),
              DropdownMenuItem(value: '2025-26', child: Text('2025-26')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _academicYear = v);
                if (_selectedStudent != null) _onStudentSelected(_selectedStudent);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMarksCard() {
    final s = _selectedStudent!;
    // Force form rebuild when student or year changes
    final dob = s['date_of_birth']?.toString();
    final dobStr = dob != null && dob.isNotEmpty ? dob.split('T').first : '—';

    return KeyedSubtree(
      key: ValueKey('${s['id']}_$_academicYear'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildStudentInfo(s['name'], s['father_name'], s['mother_name'], dobStr, s['class_name'], s['branch_name']),
          const SizedBox(height: 16),
          _buildAttendance(),
          const SizedBox(height: 16),
          _buildScholasticSection(),
          const SizedBox(height: 16),
          _buildCoScholasticSection(),
          const SizedBox(height: 16),
          _buildRemarks(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
    ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text('Sun Kidz', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('No 66, 3rd Cross, Ashwathnagar, Marathahalli, Bangalore 560037', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Text('PERFORMANCE PROFILE', style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 1)),
      ],
    );
  }

  Widget _buildStudentInfo(String name, String? father, String? mother, String dob, String? className, String? branchName) {
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(0.3), 2: FlexColumnWidth(2)},
      children: [
        _infoRow('Student Name', name),
        _infoRow('Father Name', father ?? '—'),
        _infoRow('Mother Name', mother ?? '—'),
        _infoRow('Date of birth', dob),
        _infoRow('Class', '${className ?? '—'} ${branchName != null ? '• $branchName' : ''}'),
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text('PT', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                  Text('Ab', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                  Text('Absent', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                  Text('CA', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(),
            const SizedBox(),
          ],
        ),
      ],
    );
  }

  TableRow _infoRow(String label, String value) => TableRow(
        children: [
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
          const Padding(padding: EdgeInsets.only(top: 4), child: Text(':')),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      );

  Widget _buildAttendance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attendance', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colLabels.asMap().entries.map((e) {
            final key = 'att_${_cols[e.key]}';
            return SizedBox(
              width: 70,
              child: TextFormField(
                initialValue: _getInt(key).toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: e.value, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                onChanged: (v) => _set(key, int.tryParse(v) ?? 0),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 70,
          child: TextFormField(
            initialValue: _getStr('att_total'),
            decoration: const InputDecoration(labelText: 'Total', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            onChanged: (v) => _set('att_total', v),
          ),
        ),
      ],
    );
  }

  Widget _buildScholasticSection() {
    const subjects = {
      'English': ['Dictation', 'Reading', 'Rhymes', 'Conversation', 'Story Telling', 'Writing'],
      'Kannada': ['Dictation', 'Reading', 'Writing'],
      'Mathematics': ['Dictation', 'Reading', 'Writing'],
      'Hindi': ['Dictation', 'Counting'],
      'General Knowledge': ['Oral', 'Writing'],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SCHOLASTIC AREA', style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text('Periodic Test (PT) • Half Yearly (HY) • Class Assessment (CA) • Annual (AN)', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        ...subjects.entries.map((sub) => _buildSubjectTable(sub.key, sub.value)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey.shade100,
          child: Text('Grade: A+ (90-100) | A (75-89) | B+ (60-74) | B (50-59) | C+ (35-49) | Below 35', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
        ),
      ],
    );
  }

  Widget _buildSubjectTable(String subject, List<String> items) {
    final key = subject.toLowerCase().replaceAll(' ', '_');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(0.5),
              2: FlexColumnWidth(0.5),
              3: FlexColumnWidth(0.5),
              4: FlexColumnWidth(0.5),
              5: FlexColumnWidth(0.5),
              6: FlexColumnWidth(0.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade200),
                children: [
                  _cell('Subject', bold: true),
                  _cell('PT1'),
                  _cell('CA1'),
                  _cell('HY'),
                  _cell('PT2'),
                  _cell('AN'),
                  _cell('Total'),
                ],
              ),
              ...items.map((item) => TableRow(
                    children: [
                      _cell(item),
                      _marksCell(key, item, 'pt1'),
                      _marksCell(key, item, 'ca1'),
                      _marksCell(key, item, 'hy'),
                      _marksCell(key, item, 'pt2'),
                      _marksCell(key, item, 'an'),
                      _cell((_getNested(key, item, 'pt1') + _getNested(key, item, 'ca1') + _getNested(key, item, 'hy') + _getNested(key, item, 'pt2') + _getNested(key, item, 'an')).toString()),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );

  Widget _marksCell(String subject, String item, String col) {
    final v = _getNested(subject, item, col);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        width: 40,
        child: TextFormField(
          initialValue: v == 0 ? '' : v.toString(),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4), border: OutlineInputBorder()),
          onChanged: (val) {
            final n = int.tryParse(val) ?? 0;
            _setNested(subject, item, col, n);
          },
        ),
      ),
    );
  }

  Widget _buildCoScholasticSection() {
    const items = ['Discipline', 'Confidence', 'Hygiene & Cleanliness', 'Emotional Stability', 'Adaptability', 'Drawing and Coloring'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CO-SCHOLASTIC AREA', style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: [_cell('', bold: true), _cell('Term 1'), _cell('Term 2')],
            ),
            ...items.map((item) {
              final key = 'co_${item.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
              return TableRow(
                children: [
                  _cell(item),
                  _gradeCell('${key}_t1'),
                  _gradeCell('${key}_t2'),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _gradeCell(String key) {
    const grades = ['A+', 'A', 'B+', 'B', 'C+', '—'];
    final v = _getStr(key);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: DropdownButtonFormField<String>(
        value: grades.contains(v) ? v : '—',
        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4), border: OutlineInputBorder()),
        items: grades.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 11)))).toList(),
        onChanged: (val) => _set(key, val ?? '—'),
      ),
    );
  }

  Widget _buildRemarks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: _getStr('remarks'),
          decoration: const InputDecoration(labelText: 'Class Teacher Remarks', border: OutlineInputBorder(), alignLabelWithHint: true),
          maxLines: 2,
          onChanged: (v) => _set('remarks', v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _getStr('passed_to'),
          decoration: const InputDecoration(labelText: 'Passed to (e.g. Grade 1)', border: OutlineInputBorder()),
          onChanged: (v) => _set('passed_to', v),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(children: [Text('Parent', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)), const SizedBox(height: 24)]),
            Column(children: [Text('Class Teacher', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)), const SizedBox(height: 24)]),
            Column(children: [Text('Principal', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)), const SizedBox(height: 24)]),
          ],
        ),
      ],
    );
  }
}
