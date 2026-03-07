import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _classes = [];
  String? _selectedBranchId;
  String? _selectedClassId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final api = ref.read(adminApiProvider);
    if (api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final branches = await api.getBranches();
      if (mounted) setState(() {
        _branches = branches;
        _classes = [];
        _selectedClassId = null;
      });
      final allClasses = await api.getClasses();
      if (mounted) {
        setState(() {
          _classes = allClasses;
        });
      }
      await _loadStudents();
      if (_selectedBranchId != null) await _loadClasses(_selectedBranchId!);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
    if (api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await api.getAdmissions(
        branchId: _selectedBranchId,
        classId: _selectedClassId,
      );
      if (mounted) setState(() {
        _students = students;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _onBranchChanged(String? branchId) {
    setState(() {
      _selectedBranchId = branchId;
      _classes = [];
      _selectedClassId = null;
    });
    if (branchId != null) {
      _loadClasses(branchId).then((_) => _loadStudents());
    } else {
      final api = ref.read(adminApiProvider);
      if (api != null) {
        api.getClasses().then((classes) {
          if (mounted) {
            setState(() {
              _classes = classes;
            });
          }
          _loadStudents();
        }).catchError((_) {
          _loadStudents();
        });
      } else {
        _loadStudents();
      }
    }
  }

  void _onClassChanged(String? classId) {
    setState(() => _selectedClassId = classId);
    _loadStudents();
  }

  void _confirmDeleteStudent(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete ${student['name']} (${student['admission_number']})? '
          'This will remove all related data (attendance, marks cards, parent link) and cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminApiProvider)!.deleteStudent(student['id'] as String);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student deleted')));
                  _loadStudents();
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBusOpt(Map<String, dynamic> student) async {
    try {
      final result = await ref.read(adminApiProvider)!.toggleBusOpt(student['id'] as String);
      if (mounted) {
        final busOpted = result['bus_opted'] as bool? ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(busOpted ? 'Bus service enabled' : 'Bus service disabled')),
        );
        _loadStudents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
        title: const Text('Students'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardTheme.color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBranchId,
                        decoration: const InputDecoration(
                          labelText: 'Branch',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All branches')),
                          ..._branches.map((b) => DropdownMenuItem(
                                value: b['id'] as String?,
                                child: Text(b['name']?.toString() ?? '—'),
                              )),
                        ],
                        onChanged: _onBranchChanged,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedClassId,
                        decoration: const InputDecoration(
                          labelText: 'Grade',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All grades')),
                          ...(() {
                            final seen = <String>{};
                            final uniqueClasses = _classes.where((c) {
                              final id = (c['id']?.toString() ?? '').trim();
                              if (id.isEmpty) return false;
                              final key = id.toLowerCase();
                              if (seen.contains(key)) return false;
                              seen.add(key);
                              return true;
                            }).toList();
                            return uniqueClasses.map((c) => DropdownMenuItem(
                                  value: c['id'] as String?,
                                  child: Text(
                                    [
                                      c['name']?.toString() ?? '—',
                                      if ((c['branch_name']?.toString() ?? '').isNotEmpty) c['branch_name'].toString(),
                                      if ((c['academic_year']?.toString() ?? '').isNotEmpty) c['academic_year'].toString(),
                                    ].join(' • '),
                                  ),
                                ));
                          })(),
                        ],
                        onChanged: _onClassChanged,
                      ),
                    ),
                  ],
                ),
              ],
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
                                  'No students found',
                                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedBranchId != null || _selectedClassId != null
                                      ? 'Try adjusting your filters'
                                      : 'Convert enquiries to admissions from the Enquiries screen',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _students.length,
                            itemBuilder: (_, i) => _StudentCard(
                              student: _students[i],
                              onTap: () => context.go('/students/${_students[i]['id']}'),
                              onDelete: () => _confirmDeleteStudent(_students[i]),
                              onBusOptToggle: () => _toggleBusOpt(_students[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    await _loadBranches();
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onBusOptToggle;

  const _StudentCard({
    required this.student,
    required this.onTap,
    required this.onDelete,
    required this.onBusOptToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = student['name'] as String? ?? '';
    final admissionNo = student['admission_number'] as String? ?? '—';
    final branch = student['branch_name'] as String? ?? '—';
    final className = student['class_name'] as String? ?? '';
    final age = student['age_years'] ?? student['age_months'];
    final ageStr = age is int ? (student['age_months'] != null ? '$age yrs' : 'Age $age') : (age?.toString() ?? '—');
    final busOpted = student['bus_opted'] as bool? ?? false;

    final subtitle = [branch, if (className.isNotEmpty) className, ageStr].join(' • ');

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
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.pastelGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                          Text(
                            admissionNo,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                      onSelected: (v) {
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onBusOptToggle,
                        icon: Icon(
                          busOpted ? Icons.check_circle : Icons.directions_bus,
                          size: 18,
                          color: busOpted ? Colors.green : Colors.grey,
                        ),
                        label: Text(
                          busOpted ? 'Bus Opted' : 'Opt Bus',
                          style: TextStyle(
                            color: busOpted ? Colors.green : Colors.grey.shade700,
                            fontWeight: busOpted ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: busOpted ? Colors.green : Colors.grey.shade300,
                            width: busOpted ? 2 : 1,
                          ),
                          backgroundColor: busOpted ? Colors.green.withValues(alpha: 0.1) : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
