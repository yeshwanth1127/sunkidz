import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Read-only display of a marks card for parent view.
class MarksCardDisplay extends StatelessWidget {
  const MarksCardDisplay({
    super.key,
    required this.studentName,
    required this.academicYear,
    required this.data,
    this.fatherName,
    this.motherName,
    this.dob,
    this.className,
    this.branchName,
  });

  final String studentName;
  final String academicYear;
  final Map<String, dynamic> data;
  final String? fatherName;
  final String? motherName;
  final String? dob;
  final String? className;
  final String? branchName;

  int _getInt(String key, [int def = 0]) =>
      (data[key] is int) ? data[key] as int : (int.tryParse(data[key]?.toString() ?? '') ?? def);
  String _getStr(String key, [String def = '']) => data[key]?.toString() ?? def;
  int _getNested(String subject, String item, String col) {
    try {
      final s = data[subject] as Map?;
      final i = s?[item] as Map?;
      final v = i?[col];
      return v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sun Kidz', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text('PERFORMANCE PROFILE • $academicYear', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 16),
          _infoRow('Student Name', studentName),
          _infoRow('Father Name', fatherName ?? '—'),
          _infoRow('Mother Name', motherName ?? '—'),
          _infoRow('Date of birth', dob ?? '—'),
          _infoRow('Class', '${className ?? '—'} ${(branchName ?? '').isNotEmpty ? '• $branchName' : ''}'),
          const SizedBox(height: 16),
          _buildAttendance(context),
          const SizedBox(height: 16),
          _buildScholasticSummary(context),
          const SizedBox(height: 16),
          if (_getStr('remarks').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Class Teacher Remarks', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(_getStr('remarks'), style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
            Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          ],
        ),
      );

  Widget _buildAttendance(BuildContext context) {
    const cols = ['pt1', 'ca1', 'hy', 'pt2', 'an'];
    const labels = ['PT1', 'CA1', 'HY', 'PT2', 'AN'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attendance', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: List.generate(5, (i) {
            final v = _getInt('att_${cols[i]}');
            return Chip(label: Text('${labels[i]}: $v'));
          }),
        ),
      ],
    );
  }

  Widget _buildScholasticSummary(BuildContext context) {
    const subjects = {
      'English': ['Dictation', 'Reading', 'Rhymes', 'Conversation', 'Story Telling', 'Writing'],
      'Kannada': ['Dictation', 'Reading', 'Writing'],
      'Mathematics': ['Dictation', 'Reading', 'Writing'],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SCHOLASTIC AREA', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...subjects.entries.map((e) {
          final key = e.key.toLowerCase().replaceAll(' ', '_');
          final items = e.value;
          final totals = items.map((item) => _getNested(key, item, 'pt1') + _getNested(key, item, 'ca1') + _getNested(key, item, 'hy') + _getNested(key, item, 'pt2') + _getNested(key, item, 'an')).toList();
          final avg = totals.isEmpty ? 0 : totals.reduce((a, b) => a + b) / totals.length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Avg: ${avg.toStringAsFixed(1)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          );
        }),
      ],
    );
  }
}
