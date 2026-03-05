import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable marks card form. Used by admin and teacher marks screens.
class MarksCardForm extends StatefulWidget {
  final Map<String, dynamic> student;
  final String academicYear;
  final Map<String, dynamic> initialData;
  final Future<void> Function(Map<String, dynamic> data) onSave;
  final String? error;

  const MarksCardForm({
    super.key,
    required this.student,
    required this.academicYear,
    required this.initialData,
    required this.onSave,
    this.error,
  });

  @override
  State<MarksCardForm> createState() => _MarksCardFormState();
}

class _MarksCardFormState extends State<MarksCardForm> {
  late Map<String, dynamic> _data;
  bool _saving = false;

  static const _cols = ['pt1', 'ca1', 'hy', 'pt2', 'an'];
  static const _colLabels = ['PT1', 'CA1', 'HY Term 1', 'PT2', 'AN Term 2'];

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.initialData);
  }

  @override
  void didUpdateWidget(MarksCardForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student['id'] != widget.student['id'] || oldWidget.academicYear != widget.academicYear) {
      _data = Map<String, dynamic>.from(widget.initialData);
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
    setState(() => _saving = true);
    try {
      await widget.onSave(_data);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marks saved')));
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final dob = s['date_of_birth']?.toString();
    final dobStr = dob != null && dob.isNotEmpty ? dob.split('T').first : '—';

    return KeyedSubtree(
      key: ValueKey('${s['id']}_${widget.academicYear}'),
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
            _buildStudentInfo(
              s['name']?.toString() ?? '—',
              s['father_name']?.toString(),
              s['mother_name']?.toString(),
              dobStr,
              s['class_name']?.toString(),
              s['branch_name']?.toString(),
            ),
            const SizedBox(height: 16),
            _buildAttendance(),
            const SizedBox(height: 16),
            _buildScholasticSection(),
            const SizedBox(height: 16),
            _buildCoScholasticSection(),
            const SizedBox(height: 16),
            _buildRemarks(),
            if (widget.error != null) ...[
              const SizedBox(height: 12),
              Text(widget.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Marks'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(
        children: [
          Text('Sun Kidz', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text('No 66, 3rd Cross, Ashwathnagar, Marathahalli, Bangalore 560037', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('PERFORMANCE PROFILE', style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 1)),
        ],
      );

  Widget _buildStudentInfo(String name, String? father, String? mother, String dob, String? className, String? branchName) => Table(
        columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(0.3), 2: FlexColumnWidth(2)},
        children: [
          _infoRow('Student Name', name),
          _infoRow('Father Name', father ?? '—'),
          _infoRow('Mother Name', mother ?? '—'),
          _infoRow('Date of birth', dob),
          _infoRow('Class', '${className ?? '—'}${(branchName ?? '').isNotEmpty ? ' • $branchName' : ''}'),
        ],
      );

  TableRow _infoRow(String label, String value) => TableRow(
        children: [
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
          const Padding(padding: EdgeInsets.only(top: 4), child: Text(':')),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      );

  Widget _buildAttendance() => Column(
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
                  key: ValueKey(key),
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
              key: const ValueKey('att_total'),
              initialValue: _getStr('att_total'),
              decoration: const InputDecoration(labelText: 'Total', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              onChanged: (v) => _set('att_total', v),
            ),
          ),
        ],
      );

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
            columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(0.5), 2: FlexColumnWidth(0.5), 3: FlexColumnWidth(0.5), 4: FlexColumnWidth(0.5), 5: FlexColumnWidth(0.5), 6: FlexColumnWidth(0.5)},
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade200),
                children: [_cell('Subject', bold: true), _cell('PT1'), _cell('CA1'), _cell('HY'), _cell('PT2'), _cell('AN'), _cell('Total')],
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
            TableRow(decoration: BoxDecoration(color: Colors.grey.shade200), children: [_cell('', bold: true), _cell('Term 1'), _cell('Term 2')]),
            ...items.map((item) {
              final key = 'co_${item.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
              return TableRow(children: [_cell(item), _gradeCell('${key}_t1'), _gradeCell('${key}_t2')]);
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

  Widget _buildRemarks() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: const ValueKey('remarks'),
            initialValue: _getStr('remarks'),
            decoration: const InputDecoration(labelText: 'Class Teacher Remarks', border: OutlineInputBorder(), alignLabelWithHint: true),
            maxLines: 2,
            onChanged: (v) => _set('remarks', v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('passed_to'),
            initialValue: _getStr('passed_to'),
            decoration: const InputDecoration(labelText: 'Passed to (e.g. Grade 1)', border: OutlineInputBorder()),
            onChanged: (v) => _set('passed_to', v),
          ),
        ],
      );
}
