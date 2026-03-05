import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  Map<String, dynamic>? _attendanceData;
  Map<String, dynamic>? _historyData;
  String _historyPeriod = 'week';
  String? _filterBranchId;
  String? _filterClassId;
  bool _historyViewByStudent = false;
  List<Map<String, dynamic>> _branches = [];

  static String _dateStr(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) _loadHistory();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBranches();
      _loadAttendance();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      final list = await api.getBranches();
      setState(() => _branches = list);
    } catch (_) {}
  }

  Future<void> _loadAttendance() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final res = await api.getAttendance(
        date: _dateStr(_selectedDate),
        branchId: _filterBranchId,
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
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final res = await api.getAttendanceHistory(
        period: _historyPeriod,
        branchId: _filterBranchId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        title: const Text('Attendance (All Branches)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'By Date'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildByDateTab(),
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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterBranchId,
                    decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Branches')),
                      ..._branches.map((b) => DropdownMenuItem(value: b['id'] as String?, child: Text(b['name'] as String? ?? '—'))),
                    ],
                    onChanged: (v) async {
                      setState(() => _filterBranchId = v);
                      await _loadAttendance();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () async {
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
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading && _attendanceData == null)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_attendanceData == null)
              const Center(child: Text('Failed to load'))
            else
              _buildByBranchClassContent(_attendanceData!['by_branch_class'] as List? ?? []),
          ],
        ),
      ),
    );
  }

  Widget _buildByBranchClassContent(List<dynamic> list) {
    if (list.isEmpty) {
      return const Center(child: Text('No attendance data'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list.map((item) {
        final m = item as Map<String, dynamic>;
        final branch = m['branch'] as String? ?? '—';
        final cls = m['class'] as String? ?? '—';
        final students = List<Map<String, dynamic>>.from(m['students'] as List? ?? []);
        int present = 0, absent = 0, leave = 0;
        for (final s in students) {
          final st = s['status'] as String? ?? 'present';
          if (st == 'present') present++;
          else if (st == 'absent') absent++;
          else leave++;
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
                    Icon(Icons.business, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('$branch • $cls', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _Chip(label: 'Total: ${students.length}', color: AppColors.primary),
                    _Chip(label: 'P: $present', color: Colors.green),
                    _Chip(label: 'A: $absent', color: Colors.red),
                    _Chip(label: 'L: $leave', color: Colors.amber),
                  ],
                ),
                const SizedBox(height: 12),
                ...students.take(10).map((s) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text((s['name'] as String? ?? '?').substring(0, 1).toUpperCase()),
                      ),
                      title: Text(s['name'] as String? ?? '—'),
                      trailing: _statusChip(s['status'] as String? ?? 'present'),
                    )),
                if (students.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('+ ${students.length - 10} more', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
      decoration: BoxDecoration(color: c.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c)),
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
    if (byStudent.isEmpty) return const Center(child: Text('No students'));
    final entries = (byStudent as Map).entries.toList()
      ..sort((a, b) {
        final aVal = a.value as Map;
        final bVal = b.value as Map;
        final cmp = ((aVal['branch_name'] ?? '') as String).compareTo((bVal['branch_name'] ?? '') as String);
        if (cmp != 0) return cmp;
        return ((aVal['name'] ?? '') as String).compareTo((bVal['name'] ?? '') as String);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${data['start']} to ${data['end']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        ...entries.map((e) {
          final info = e.value as Map<String, dynamic>;
          final name = info['name'] as String? ?? '—';
          final branchName = info['branch_name'] as String? ?? '—';
          final className = info['class_name'] as String? ?? '—';
          final datesMap = info['dates'] as Map<String, dynamic>? ?? {};
          final present = datesMap.values.where((v) => v == 'present').length;
          final absent = datesMap.values.where((v) => v == 'absent').length;
          final leave = datesMap.values.where((v) => v == 'leave').length;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('$branchName • $className • P: $present  A: $absent  L: $leave'),
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
                        child: Text('${_formatDate(dk)}: ${status.toString().toUpperCase()}', style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500)),
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

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
