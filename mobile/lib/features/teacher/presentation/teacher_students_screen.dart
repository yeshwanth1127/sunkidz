import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../shared/widgets/teacher_drawer.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  ConsumerState<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(teacherApiProvider);
    if (api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await api.getMyStudents();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      drawer: const TeacherDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        title: const Text('My Students'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load)],
      ),
      body: _loading
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
                          Text('No students in your class', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _students.length,
                      itemBuilder: (_, i) => _StudentCard(
                        student: _students[i],
                        onTap: () => context.go('/teacher/students/${_students[i]['id']}'),
                      ),
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
    final branch = student['branch_name'] as String? ?? '—';
    final className = student['class_name'] as String? ?? '';
    final age = student['age_years'] ?? student['age_months'];
    final ageStr = age is int ? (student['age_months'] != null ? '$age yrs' : 'Age $age') : (age?.toString() ?? '—');
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
