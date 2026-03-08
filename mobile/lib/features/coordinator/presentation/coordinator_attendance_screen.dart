import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../shared/widgets/coordinator_drawer.dart';

class CoordinatorAttendanceScreen extends ConsumerStatefulWidget {
  const CoordinatorAttendanceScreen({super.key});

  @override
  ConsumerState<CoordinatorAttendanceScreen> createState() =>
      _CoordinatorAttendanceScreenState();
}

class _CoordinatorAttendanceScreenState
    extends ConsumerState<CoordinatorAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  Map<String, dynamic>? _attendanceData;
  Map<String, dynamic>? _historyData;
  String _historyPeriod = 'week';
  String? _filterClassId;
  bool _historyViewByStudent = false;
  // For mark attendance tab
  Map<String, String> _statusMap = {};
  bool _saving = false;
  List<Map<String, dynamic>> _students = [];
  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) {
        _loadMarkAttendance();
      } else if (!_tabController.indexIsChanging && _tabController.index == 2) {
        _loadHistory();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAttendance());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    final api = ref.read(coordinatorApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final res = await api.getAttendance(
        date: _dateStr(_selectedDate),
        classId: _filterClassId,
      );
      setState(() {
        _attendanceData = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _attendanceData = null;
        _loading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    final api = ref.read(coordinatorApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final res = await api.getAttendanceHistory(
        period: _historyPeriod,
        classId: _filterClassId,
      );
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

  Future<void> _loadMarkAttendance() async {
    final api = ref.read(coordinatorApiProvider);
    if (api == null) return;
    setState(() {
      _loading = true;
      _statusMap = {};
      _students = [];
    });
    try {
      final res = await api.getAttendance(
        date: _dateStr(_selectedDate),
        classId: _filterClassId,
      );
      final byClass = res['by_class'] as Map<String, dynamic>? ?? {};
      final students = <Map<String, dynamic>>[];
      final map = <String, String>{};

      for (final classEntry in byClass.entries) {
        final classList = List<Map<String, dynamic>>.from(
          classEntry.value as List? ?? [],
        );
        students.addAll(classList);
        for (final s in classList) {
          map[s['id'] as String] = s['status'] as String? ?? 'present';
        }
      }

      setState(() {
        _students = students;
        _statusMap = map;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _students = [];
      });
    }
  }

  Future<void> _submitAttendance() async {
    final api = ref.read(coordinatorApiProvider);
    if (api == null) return;
    setState(() => _saving = true);
    try {
      final records = _statusMap.entries
          .map((e) => {'student_id': e.key, 'status': e.value})
          .toList();
      await api.upsertAttendance(
        date: _dateStr(_selectedDate),
        records: records,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Attendance saved')));
      }
      await _loadMarkAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CoordinatorDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Branch Attendance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'By Date'),
            Tab(text: 'Mark'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildByDateTab(),
          _buildMarkAttendanceTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildByDateTab() {
    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d != null) setState(() => _selectedDate = d);
                      await _loadAttendance();
                    },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_formatDate(_selectedDate)),
            ),
            const SizedBox(height: 16),
            if (_loading && _attendanceData == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_attendanceData == null)
              const Center(child: Text('Failed to load'))
            else
              _buildByClassContent(
                _attendanceData!['by_class'] as Map<String, dynamic>? ?? {},
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildByClassContent(Map<String, dynamic> byClass) {
    if (byClass.isEmpty) {
      return const Center(child: Text('No students in this branch'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: (byClass as Map).entries.map((e) {
        final className = e.key;
        final students = List<Map<String, dynamic>>.from(e.value as List);
        int present = 0, absent = 0, leave = 0;
        for (final s in students) {
          final st = s['status'] as String? ?? 'present';
          if (st == 'present')
            present++;
          else if (st == 'absent')
            absent++;
          else
            leave++;
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.class_, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    Text(
                      className,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _Chip(
                      label: 'Total: ${students.length}',
                      color: AppColors.primary,
                    ),
                    _Chip(label: 'P: $present', color: Colors.green),
                    _Chip(label: 'A: $absent', color: Colors.red),
                    _Chip(label: 'L: $leave', color: Colors.amber),
                  ],
                ),
                const SizedBox(height: 12),
                ...students.map(
                  (s) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(
                        (s['name'] as String? ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(s['name'] as String? ?? '—'),
                    trailing: _statusChip(s['status'] as String? ?? 'present'),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statusChip(String status) {
    Color c = Colors.green;
    if (status == 'absent') c = Colors.red;
    if (status == 'leave') c = Colors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c),
      ),
    );
  }

  Widget _buildMarkAttendanceTab() {
    return RefreshIndicator(
      onRefresh: _loadMarkAttendance,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d != null) {
                        setState(() => _selectedDate = d);
                        await _loadMarkAttendance();
                      }
                    },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_formatDate(_selectedDate)),
            ),
            const SizedBox(height: 16),
            if (_loading && _students.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_students.isEmpty)
              const Center(child: Text('No students found'))
            else ...[
              ..._students.map((student) {
                final studentId = student['id'] as String;
                final name = student['name'] as String? ?? '?';
                final admissionNumber =
                    student['admission_number'] as String? ?? '?';
                final status = _statusMap[studentId] ?? 'present';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Roll: $admissionNumber',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<String>(
                          value: status,
                          underline: const SizedBox(),
                          items: ['present', 'absent', 'leave']
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _statusMap[studentId] = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving || _students.isEmpty
                    ? null
                    : _submitAttendance,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_saving ? 'Saving...' : 'Save Attendance'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
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
                  onSelected: (_) =>
                      setState(() => _historyViewByStudent = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('By Student'),
                  selected: _historyViewByStudent,
                  onSelected: (_) =>
                      setState(() => _historyViewByStudent = true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading && _historyData == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_historyData == null)
              const Center(child: Text('No history'))
            else
              _historyViewByStudent
                  ? _buildHistoryByStudent(_historyData!)
                  : _buildHistoryContent(_historyData!),
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
        Text(
          '${data['start']} to ${data['end']}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        ...dates.reversed.map((dk) {
          final recs = byDate[dk] as List? ?? [];
          final present = recs
              .where((r) => (r as Map)['status'] == 'present')
              .length;
          final absent = recs
              .where((r) => (r as Map)['status'] == 'absent')
              .length;
          final leave = recs
              .where((r) => (r as Map)['status'] == 'leave')
              .length;
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
    final byClass = data['by_class'] as Map<String, dynamic>? ?? {};
    final dates = List<String>.from(data['dates'] as List? ?? []);
    if (byClass.isEmpty) return const Center(child: Text('No students'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data['start']} to ${data['end']}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        ...(byClass as Map).entries.map((clsEntry) {
          final className = clsEntry.key as String;
          final clsData = clsEntry.value as Map<String, dynamic>;
          final students = clsData['students'] as Map<String, dynamic>? ?? {};
          if (students.isEmpty) return const SizedBox.shrink();
          final studentEntries = (students as Map).entries.toList()
            ..sort(
              (a, b) => ((a.value as Map)['name'] as String? ?? '').compareTo(
                (b.value as Map)['name'] as String? ?? '',
              ),
            );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  className,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              ...studentEntries.map((e) {
                final info = e.value as Map<String, dynamic>;
                final name = info['name'] as String? ?? '—';
                final admissionNumber =
                    info['admission_number'] as String? ?? '—';
                final datesMap = info['dates'] as Map<String, dynamic>? ?? {};
                final present = datesMap.values
                    .where((v) => v == 'present')
                    .length;
                final absent = datesMap.values
                    .where((v) => v == 'absent')
                    .length;
                final leave = datesMap.values.where((v) => v == 'leave').length;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Roll #$admissionNumber • P: $present  A: $absent  L: $leave',
                    ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: c.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '${_formatDate(dk)}: ${(status as String).toUpperCase()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
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

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
