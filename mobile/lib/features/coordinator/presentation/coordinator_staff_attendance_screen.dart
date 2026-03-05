import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../shared/widgets/coordinator_drawer.dart';

class CoordinatorStaffAttendanceScreen extends ConsumerStatefulWidget {
  const CoordinatorStaffAttendanceScreen({super.key});

  @override
  ConsumerState<CoordinatorStaffAttendanceScreen> createState() => _CoordinatorStaffAttendanceScreenState();
}

class _CoordinatorStaffAttendanceScreenState extends ConsumerState<CoordinatorStaffAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _staffData;
  Map<String, dynamic>? _historyData;
  String _historyPeriod = 'week';
  bool _historyViewByStaff = false;

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) _loadHistory();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStaffAttendance());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffAttendance() async {
    final api = ref.read(coordinatorApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final res = await api.getStaffAttendance(date: _dateStr(_selectedDate));
      if (mounted) {
        setState(() {
          _staffData = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _staffData = null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    final api = ref.read(coordinatorApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final res = await api.getStaffAttendanceHistory(period: _historyPeriod);
      if (mounted) {
        setState(() {
          _historyData = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyData = null;
          _loading = false;
        });
      }
    }
  }

  void _setStatus(int index, String status) {
    if (_staffData == null) return;
    final staff = List<Map<String, dynamic>>.from(_staffData!['staff'] as List);
    if (index >= staff.length) return;
    staff[index] = {...staff[index], 'status': status};
    setState(() => _staffData = {..._staffData!, 'staff': staff});
  }

  Future<void> _saveAttendance() async {
    final api = ref.read(coordinatorApiProvider);
    if (api == null || _staffData == null) return;
    final staff = List<Map<String, dynamic>>.from(_staffData!['staff'] as List);
    if (staff.isEmpty) return;
    setState(() => _saving = true);
    try {
      final records = staff
          .map((s) => {
                'user_id': s['user_id'] as String,
                'status': s['status'] as String? ?? 'present',
              })
          .toList();
      await api.upsertStaffAttendance(date: _dateStr(_selectedDate), records: records);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved')));
        _loadStaffAttendance();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CoordinatorDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        title: const Text('Staff Attendance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mark Attendance'),
            Tab(text: 'View History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMarkTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildMarkTab() {
    return RefreshIndicator(
      onRefresh: _loadStaffAttendance,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _loading ? null : () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (d != null) {
                  setState(() => _selectedDate = d);
                  await _loadStaffAttendance();
                }
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_formatDate(_selectedDate)),
            ),
            const SizedBox(height: 16),
            if (_loading && _staffData == null)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_staffData == null)
              const Center(child: Text('Failed to load'))
            else
              _buildStaffList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList() {
    final staff = List<Map<String, dynamic>>.from(_staffData!['staff'] as List);
    if (staff.isEmpty) {
      return const Center(child: Text('No teachers in this branch'));
    }
    int present = 0, absent = 0, leave = 0;
    for (final s in staff) {
      final st = s['status'] as String? ?? 'present';
      if (st == 'present') present++;
      else if (st == 'absent') absent++;
      else leave++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            _Chip(label: 'Total: ${staff.length}', color: AppColors.primary),
            _Chip(label: 'P: $present', color: Colors.green),
            _Chip(label: 'A: $absent', color: Colors.red),
            _Chip(label: 'L: $leave', color: Colors.amber),
          ],
        ),
        const SizedBox(height: 16),
        ...staff.asMap().entries.map((e) => _StaffRow(
              staff: e.value,
              onStatusChanged: (status) => _setStatus(e.key, status),
            )),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _saveAttendance,
          child: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Attendance'),
        ),
      ],
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
                  selected: !_historyViewByStaff,
                  onSelected: (_) => setState(() => _historyViewByStaff = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('By Staff'),
                  selected: _historyViewByStaff,
                  onSelected: (_) => setState(() => _historyViewByStaff = true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading && _historyData == null)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_historyData == null)
              const Center(child: Text('No history'))
            else
              _historyViewByStaff ? _buildHistoryByStaff(_historyData!) : _buildHistoryByDate(_historyData!),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryByDate(Map<String, dynamic> data) {
    final dates = List<String>.from(data['dates'] as List? ?? []);
    final byDate = data['by_date'] as Map<String, dynamic>? ?? {};
    if (dates.isEmpty) {
      return const Center(child: Text('No staff attendance records for this period'));
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

  Widget _buildHistoryByStaff(Map<String, dynamic> data) {
    final byStaff = data['by_staff'] as Map<String, dynamic>? ?? {};
    final dates = List<String>.from(data['dates'] as List? ?? []);
    if (byStaff.isEmpty) return const Center(child: Text('No staff'));
    final entries = (byStaff as Map).entries.toList()
      ..sort((a, b) => (a.value as Map)['name']?.toString().compareTo((b.value as Map)['name']?.toString() ?? '') ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${data['start']} to ${data['end']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        ...entries.map((e) {
          final info = e.value as Map<String, dynamic>;
          final name = info['name'] as String? ?? '—';
          final className = info['class_name'] as String? ?? '';
          final datesMap = info['dates'] as Map<String, dynamic>? ?? {};
          final present = datesMap.values.where((v) => v == 'present').length;
          final absent = datesMap.values.where((v) => v == 'absent').length;
          final leave = datesMap.values.where((v) => v == 'leave').length;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${className.isNotEmpty ? "$className • " : ""}P: $present  A: $absent  L: $leave'),
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
                        child: Text(
                          '${_formatDate(dk)}: ${status.toString().toUpperCase()}',
                          style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500),
                        ),
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

class _StaffRow extends StatelessWidget {
  final Map<String, dynamic> staff;
  final void Function(String) onStatusChanged;

  const _StaffRow({required this.staff, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    final status = staff['status'] as String? ?? 'present';
    final name = staff['full_name'] as String? ?? '—';
    final className = staff['class_name'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                if (className.isNotEmpty) Text(className, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'present', label: Text('P'), icon: Icon(Icons.check, size: 16)),
              ButtonSegment(value: 'absent', label: Text('A'), icon: Icon(Icons.close, size: 16)),
              ButtonSegment(value: 'leave', label: Text('L'), icon: Icon(Icons.event_busy, size: 16)),
            ],
            selected: {status},
            onSelectionChanged: (s) => onStatusChanged(s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            ),
          ),
        ],
      ),
    );
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
