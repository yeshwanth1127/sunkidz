import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../shared/widgets/teacher_drawer.dart';

class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  ConsumerState<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends ConsumerState<TeacherAttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  Map<String, String> _statusMap = {};
  bool _loading = true;
  bool _saving = false;
  bool _locked = false;  // Track if attendance is locked/submitted
  String? _error;
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _historyData;
  String _historyPeriod = 'week';
  bool _historyViewByStudent = false;

  static String _dateStr(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) _loadHistory();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAttendance());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    final api = ref.read(teacherApiProvider);
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _statusMap = {};
      _locked = false;
    });
    try {
      final res = await api.getAttendance(date: _dateStr(_selectedDate));
      final recs = List<Map<String, dynamic>>.from(res['records'] as List? ?? []);
      final map = <String, String>{};
      for (final r in recs) {
        map[r['id'] as String] = r['status'] as String? ?? 'present';
      }
      setState(() {
        _records = recs;
        _statusMap = map;
        _locked = (res['locked'] as bool?) ?? false;  // Get locked status
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _records = [];
      });
    }
  }

  Future<void> _loadHistory() async {
    final api = ref.read(teacherApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final res = await api.getAttendanceHistory(period: _historyPeriod);
      setState(() {
        _historyData = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _historyData = null;
        _loading = false;
      });
    }
  }


  Future<void> _submitAttendance() async {
    final api = ref.read(teacherApiProvider);
    if (api == null) return;
    setState(() => _saving = true);
    try {
      final records = _statusMap.entries
          .map((e) => {'student_id': e.key, 'status': e.value})
          .toList();
      await api.upsertAttendance(date: _dateStr(_selectedDate), records: records);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved')));
      }
      await _loadAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const TeacherDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        title: const Text('Attendance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mark Today'),
            Tab(text: 'View History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMarkTodayTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildMarkTodayTab() {
    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),  // Only today and before, not future
                      );
                      if (d != null) setState(() => _selectedDate = d);
                      await _loadAttendance();
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_formatDate(_selectedDate)),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _saving || _loading || _records.isEmpty || _locked ? null : _submitAttendance,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : _locked
                          ? const Icon(Icons.lock)
                          : const Icon(Icons.check_circle),
                  label: Text(_locked ? 'Locked' : (_saving ? 'Saving...' : 'Save Attendance')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_locked)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Attendance for this date is locked and cannot be edited',
                          style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_loading && _records.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_records.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No students in your class', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              )
            else ...[
              _buildSummaryChips(),
              const SizedBox(height: 16),
              ..._records.map((r) => _StudentAttendanceCard(
                    student: r,
                    status: _statusMap[r['id'] as String] ?? 'present',
                    onStatusChanged: (s) => _locked ? null : setState(() => _statusMap[r['id'] as String] = s),
                    locked: _locked,
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChips() {
    int present = 0, absent = 0, leave = 0;
    for (final s in _statusMap.values) {
      if (s == 'present') present++;
      else if (s == 'absent') absent++;
      else leave++;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SummaryChip(label: 'Total: ${_records.length}', color: AppColors.primary),
            const SizedBox(width: 8),
            _SummaryChip(label: 'Present: $present', color: Colors.green),
            const SizedBox(width: 8),
            _SummaryChip(label: 'Absent: $absent', color: Colors.red),
            const SizedBox(width: 8),
            _SummaryChip(label: 'Leave: $leave', color: Colors.amber),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_tabController.index != 1) return const SizedBox();
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Weekly'),
                  selected: _historyPeriod == 'week',
                  onSelected: (_) async {
                    setState(() => _historyPeriod = 'week');
                    await _loadHistory();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Monthly'),
                  selected: _historyPeriod == 'month',
                  onSelected: (_) async {
                    setState(() => _historyPeriod = 'month');
                    await _loadHistory();
                  },
                ),
                const Spacer(),
                ChoiceChip(
                  label: const Text('By Date'),
                  selected: !_historyViewByStudent,
                  onSelected: (_) => setState(() => _historyViewByStudent = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('By Student'),
                  selected: _historyViewByStudent,
                  onSelected: (_) => setState(() => _historyViewByStudent = true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading && _historyData == null)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_historyData == null)
              const Center(child: Text('No history'))
            else
              _historyViewByStudent ? _buildHistoryByStudent(_historyData!) : _buildHistoryContent(_historyData!),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent(Map<String, dynamic> data) {
    final dates = List<String>.from(data['dates'] as List? ?? []);
    final byDate = data['by_date'] as Map<String, dynamic>? ?? {};
    if (dates.isEmpty) {
      return const Center(child: Text('No attendance records for this period'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${data['start']} to ${data['end']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        ...dates.reversed.map((dk) {
          final recs = byDate[dk] as List? ?? [];
          final present = recs.where((r) => (r as Map)['status'] == 'present').length;
          final absent = recs.where((r) => (r as Map)['status'] == 'absent').length;
          final leave = recs.where((r) => (r as Map)['status'] == 'leave').length;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(_formatDate(dk)),
              subtitle: Text('P: $present  A: $absent  L: $leave'),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHistoryByStudent(Map<String, dynamic> data) {
    final byStudent = data['by_student'] as Map<String, dynamic>? ?? {};
    final dates = List<String>.from(data['dates'] as List? ?? []);
    if (byStudent.isEmpty) {
      return const Center(child: Text('No students in your class'));
    }
    final entries = (byStudent as Map).entries.toList()
      ..sort((a, b) => ((a.value as Map)['name'] as String? ?? '').compareTo((b.value as Map)['name'] as String? ?? ''));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${data['start']} to ${data['end']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        ...entries.map((e) {
          final info = e.value as Map<String, dynamic>;
          final name = info['name'] as String? ?? '—';
          final admissionNumber = info['admission_number'] as String? ?? '—';
          final datesMap = info['dates'] as Map<String, dynamic>? ?? {};
          final present = datesMap.values.where((v) => v == 'present').length;
          final absent = datesMap.values.where((v) => v == 'absent').length;
          final leave = datesMap.values.where((v) => v == 'leave').length;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Roll #$admissionNumber • P: $present  A: $absent  L: $leave'),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: dates.reversed.map((dk) {
                      final status = datesMap[dk] as String? ?? '—';
                      Color c = Colors.grey;
                      if (status == 'present') c = Colors.green;
                      if (status == 'absent') c = Colors.red;
                      if (status == 'leave') c = Colors.amber;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.withValues(alpha: 0.3)),
                        ),
                        child: Text('${_formatDate(dk)}: ${status.toUpperCase()}', style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static String _formatDate(dynamic d) {
    if (d is DateTime) return '${d.day}/${d.month}/${d.year}';
    final s = d.toString();
    if (s.length >= 10) {
      final parts = s.substring(0, 10).split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return s;
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final bool locked;

  const _StudentAttendanceCard({
    required this.student,
    required this.status,
    required this.onStatusChanged,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: locked ? Colors.grey.shade50 : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: locked ? Colors.orange.withValues(alpha: 0.3) : Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Text((student['name'] as String? ?? '?').substring(0, 1).toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['name'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Roll #${student['admission_number'] ?? '—'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _StatusBtn(label: 'P', status: 'present', current: status, onTap: () => locked ? null : onStatusChanged('present'), locked: locked),
                _StatusBtn(label: 'A', status: 'absent', current: status, onTap: () => locked ? null : onStatusChanged('absent'), locked: locked),
                _StatusBtn(label: 'L', status: 'leave', current: status, onTap: () => locked ? null : onStatusChanged('leave'), locked: locked),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final String status;
  final String current;
  final VoidCallback? onTap;
  final bool locked;

  const _StatusBtn({
    required this.label,
    required this.status,
    required this.current,
    required this.onTap,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == status;
    Color bg = Colors.transparent;
    Color fg = Colors.grey;
    if (status == 'present') {
      if (isSelected) { bg = Colors.green; fg = Colors.white; }
    } else if (status == 'absent') {
      if (isSelected) { bg = Colors.red; fg = Colors.white; }
    } else if (status == 'leave') {
      if (isSelected) { bg = Colors.amber; fg = Colors.white; }
    }
    
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: Opacity(
        opacity: locked ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
        ),
      ),
    );
  }
}
