import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../features/dashboard/data/coordinator_dashboard_provider.dart';
import '../../../shared/widgets/coordinator_drawer.dart';

class CoordinatorTeachersScreen extends ConsumerStatefulWidget {
  const CoordinatorTeachersScreen({super.key});

  @override
  ConsumerState<CoordinatorTeachersScreen> createState() => _CoordinatorTeachersScreenState();
}

class _CoordinatorTeachersScreenState extends ConsumerState<CoordinatorTeachersScreen> {
  List<Map<String, dynamic>> _teachers = [];
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
      final teachers = await api.getTeachers();
      if (mounted) {
        setState(() {
          _teachers = teachers;
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
        title: Text('Teachers — $branchName'),
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
              : _teachers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No teachers in this branch', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _teachers.length,
                        itemBuilder: (_, i) => _TeacherCard(teacher: _teachers[i]),
                      ),
                    ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  final Map<String, dynamic> teacher;

  const _TeacherCard({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final name = teacher['full_name'] as String? ?? '—';
    final email = teacher['email'] as String? ?? '';
    final phone = teacher['phone'] as String? ?? '';
    final className = teacher['class_name'] as String? ?? '';
    final subtitle = [if (className.isNotEmpty) className, if (email.isNotEmpty) email].where((e) => e.isNotEmpty).join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.pastelBlue, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.person, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  if (phone.isNotEmpty) Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
