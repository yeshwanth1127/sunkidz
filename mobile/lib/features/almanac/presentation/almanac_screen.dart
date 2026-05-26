import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../core/api/parent_provider.dart';
import '../../../core/api/almanac_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'almanac_manage_screen.dart';

class AlmanacScreen extends ConsumerStatefulWidget {
  const AlmanacScreen({super.key});

  @override
  ConsumerState<AlmanacScreen> createState() => _AlmanacScreenState();
}

class _AlmanacScreenState extends ConsumerState<AlmanacScreen> {
  String? _branchId;
  String? _classId;
  String _branchName = '';
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _days = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initScope();
  }

  Future<void> _initScope() async {
    final auth = ref.read(authProvider);
    try {
      if (auth.role == UserRole.admin) {
        final api = ref.read(adminApiProvider);
        if (api != null) {
          final branches = await api.getBranches();
          if (branches.isNotEmpty) {
            final b = branches.first;
            _branchId = b['id']?.toString();
            _branchName = b['name']?.toString() ?? '';
            for (final cls in (b['classes'] as List? ?? [])) {
              _classes.add({
                'id': cls['id'],
                'name': cls['name'],
              });
            }
          }
        }
      } else if (auth.role == UserRole.coordinator) {
        final api = ref.read(coordinatorApiProvider);
        if (api != null) {
          final dash = await api.getDashboard();
          _branchId = dash['branch_id']?.toString();
          _branchName = dash['branch_name']?.toString() ?? '';
          for (final cls in (dash['classes'] as List? ?? [])) {
            _classes.add({'id': cls['id'], 'name': cls['name']});
          }
        }
      } else if (auth.role == UserRole.teacher) {
        final api = ref.read(teacherApiProvider);
        if (api != null) {
          final assigned = await api.getMyClasses();
          if (assigned.isNotEmpty) {
            _branchId = assigned.first['branch_id']?.toString();
            _branchName = assigned.first['branch_name']?.toString() ?? '';
            _classId = assigned.first['class_id']?.toString();
            for (final c in assigned) {
              _classes.add({'id': c['class_id'], 'name': c['class_name']});
            }
          } else {
            final dash = await api.getDashboard();
            _branchId = dash['branch_id']?.toString();
            _branchName = dash['branch_name']?.toString() ?? '';
            _classId = dash['class_id']?.toString();
          }
        }
      } else if (auth.role == UserRole.parent) {
        final api = ref.read(parentApiProvider);
        if (api != null) {
          final children = await api.getChildren();
          final list = (children['children'] as List?) ?? [];
          if (list.isNotEmpty) {
            final child = list.first as Map<String, dynamic>;
            _classId = child['class_id']?.toString();
            _branchId = child['branch_id']?.toString();
          }
        }
      }
    } catch (_) {}

    if (_branchId != null) await _loadCalendar();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCalendar() async {
    final api = ref.read(almanacApiProvider);
    if (api == null || _branchId == null) return;
    setState(() => _loading = true);
    try {
      final data = await api.getCalendar(
        branchId: _branchId!,
        classId: _classId,
      );
      if (!mounted) return;
      setState(() {
        _days = List<Map<String, dynamic>>.from(data['days'] as List? ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canManage {
    final role = ref.watch(authProvider).role;
    return role == UserRole.admin || role == UserRole.coordinator;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Almanac${_branchName.isNotEmpty ? ' — $_branchName' : ''}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_canManage && _branchId != null)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlmanacManageScreen(
                      branchId: _branchId!,
                      branchName: _branchName,
                    ),
                  ),
                );
                _loadCalendar();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_classes.length > 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _classId,
                decoration: const InputDecoration(labelText: 'Class (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All classes')),
                  ..._classes.map((c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String? ?? ''),
                      )),
                ],
                onChanged: (v) {
                  setState(() => _classId = v);
                  _loadCalendar();
                },
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _days.length,
                    itemBuilder: (_, i) {
                      final d = _days[i];
                      final events = (d['events'] as List?) ?? [];
                      final holidays = (d['holidays'] as List?) ?? [];
                      final syllabusCount = d['syllabus_count'] as int? ?? 0;
                      return Card(
                        child: ExpansionTile(
                          title: Text('Day ${d['day']} — ${d['date']}'),
                          subtitle: Text(
                            [
                              if (holidays.isNotEmpty) '${holidays.length} holiday(s)',
                              if (events.isNotEmpty) '${events.length} event(s)',
                              if (syllabusCount > 0) '$syllabusCount syllabus',
                            ].join(' · '),
                          ),
                          children: [
                            if (holidays.isNotEmpty)
                              ...holidays.map((h) {
                                final m = h as Map<String, dynamic>;
                                final isGlobal = m['is_global'] == true;
                                final scope = isGlobal
                                    ? 'All branches'
                                    : (m['branch_name']?.toString() ??
                                        _branchName);
                                return ListTile(
                                  leading: Icon(
                                    Icons.beach_access,
                                    color: isGlobal ? Colors.red : Colors.orange,
                                  ),
                                  title: Text(m['reason']?.toString() ?? 'Holiday'),
                                  subtitle: Text(scope),
                                  trailing: isGlobal
                                      ? const Chip(
                                          label: Text('All',
                                              style: TextStyle(fontSize: 10)),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        )
                                      : null,
                                );
                              }),
                            if (events.isNotEmpty)
                              ...events.map((e) {
                                final m = e as Map<String, dynamic>;
                                final isGlobal = m['is_global'] == true;
                                final cls = m['class_name']?.toString();
                                final br = m['branch_name']?.toString();
                                final scope = isGlobal
                                    ? 'Broadcast · All branches'
                                    : [
                                        if (br != null && br.isNotEmpty) br,
                                        if (cls != null && cls.isNotEmpty) cls,
                                      ].join(' · ');
                                return ListTile(
                                  leading: Icon(
                                    isGlobal
                                        ? Icons.campaign
                                        : Icons.event,
                                    color: isGlobal
                                        ? Colors.deepPurple
                                        : AppColors.primary,
                                  ),
                                  title: Text(m['title']?.toString() ?? ''),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (scope.isNotEmpty)
                                        Text(scope,
                                            style: const TextStyle(fontSize: 12)),
                                      if (m['description'] != null)
                                        Text(m['description'].toString()),
                                    ],
                                  ),
                                );
                              }),
                            if (syllabusCount > 0)
                              ListTile(
                                leading: const Icon(Icons.menu_book),
                                title: Text('$syllabusCount syllabus item(s)'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
