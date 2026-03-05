import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../features/dashboard/data/coordinator_dashboard_provider.dart';
import '../../../shared/widgets/coordinator_drawer.dart';

class CoordinatorStudentsScreen extends ConsumerStatefulWidget {
  const CoordinatorStudentsScreen({super.key});

  @override
  ConsumerState<CoordinatorStudentsScreen> createState() => _CoordinatorStudentsScreenState();
}

class _CoordinatorStudentsScreenState extends ConsumerState<CoordinatorStudentsScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    final api = ref.read(coordinatorApiProvider);
    if (api == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboard = await ref.read(coordinatorDashboardDataProvider.future);
      final students = await api.getStudents(classId: _selectedClassId);
      if (mounted) {
        setState(() {
          _classes = dashboard.classes;
          _students = students;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final branchName = ref.watch(coordinatorDashboardDataProvider).valueOrNull?.branchName ?? 'Branch';

    return Scaffold(
      drawer: const CoordinatorDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        title: Text('Students — $branchName'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load)],
      ),
      body: Column(
        children: [
          if (_classes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).cardTheme.color,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _selectedClassId == null,
                      onTap: () {
                        setState(() {
                          _selectedClassId = null;
                          _loading = true;
                        });
                        _load();
                      },
                    ),
                    ..._classes.map((c) => _FilterChip(
                          label: c['name'] as String? ?? '—',
                          selected: _selectedClassId == c['id'],
                          onTap: () {
                            setState(() {
                              _selectedClassId = c['id'] as String?;
                              _loading = true;
                            });
                            _load();
                          },
                        )),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading
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
                    : _students.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedClassId != null ? 'No students in this class' : 'No students in this branch',
                                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _students.length,
                              itemBuilder: (_, i) => _StudentCard(
                                student: _students[i],
                                onTap: () => context.push('/students/${_students[i]['id']}'),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onTap;

  const _StudentCard({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = student['name'] as String? ?? '';
    final admissionNo = student['admission_number'] as String? ?? '—';
    final className = student['class_name'] as String? ?? '';
    final age = student['age_years'] ?? student['age_months'];
    final ageStr = age is int ? '$age yrs' : (age?.toString() ?? '—');
    final subtitle = [if (className.isNotEmpty) className, ageStr].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.pastelGreen, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.school, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text(admissionNo, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
