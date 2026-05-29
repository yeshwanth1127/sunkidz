import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../data/daily_report_provider.dart';
import 'report_screen.dart';

class GradeListScreen extends ConsumerStatefulWidget {
  const GradeListScreen({super.key});

  @override
  ConsumerState<GradeListScreen> createState() => _GradeListScreenState();
}

class _GradeListScreenState extends ConsumerState<GradeListScreen> {
  List<Map<String, dynamic>> _classes = [];
  // classId -> 'sent' | 'draft' | 'none'
  Map<String, String> _statuses = {};
  bool _loading = true;
  bool _statusLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() { _loading = true; _error = null; });
    final auth = ref.read(authProvider);
    final classes = <Map<String, dynamic>>[];
    try {
      if (auth.role == UserRole.admin) {
        final api = ref.read(adminApiProvider);
        if (api == null) throw Exception('Not authenticated');
        final branches = await api.getBranches();
        for (final b in branches) {
          final bName = b['name']?.toString() ?? '';
          for (final cls in (b['classes'] as List? ?? [])) {
            classes.add({
              'id': cls['id']?.toString() ?? '',
              'name': cls['name']?.toString() ?? '',
              'branch_name': bName,
            });
          }
        }
      } else if (auth.role == UserRole.coordinator) {
        final api = ref.read(coordinatorApiProvider);
        if (api == null) throw Exception('Not authenticated');
        final dashboard = await api.getDashboard();
        final assignedBranchId = auth.branchId ?? dashboard['branch_id']?.toString() ?? '';
        final branchName = dashboard['branch_name']?.toString() ?? '';
        for (final cls in (dashboard['classes'] as List? ?? [])) {
          final clsMap = cls as Map;
          if (assignedBranchId.isNotEmpty) {
            final clsBranchId = clsMap['branch_id']?.toString() ?? '';
            if (clsBranchId.isNotEmpty && clsBranchId != assignedBranchId) continue;
          }
          classes.add({
            'id': clsMap['id']?.toString() ?? '',
            'name': clsMap['name']?.toString() ?? '',
            'branch_name': branchName,
          });
        }
      } else if (auth.role == UserRole.teacher) {
        final api = ref.read(teacherApiProvider);
        if (api == null) throw Exception('Not authenticated');
        final dashboard = await api.getDashboard();
        final assignedClassId = auth.classId ?? '';
        final classId = dashboard['class_id']?.toString() ?? '';
        final className = dashboard['class_name']?.toString() ?? '';
        final branchName = dashboard['branch_name']?.toString() ?? '';
        if (classId.isNotEmpty && (assignedClassId.isEmpty || classId == assignedClassId)) {
          classes.add({'id': classId, 'name': className, 'branch_name': branchName});
        }
      }
      setState(() { _classes = classes; _loading = false; });
      _loadStatuses(classes);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadStatuses(List<Map<String, dynamic>> classes) async {
    if (classes.isEmpty) return;
    setState(() => _statusLoading = true);
    final service = ref.read(dailyReportServiceProvider);
    if (service == null) {
      setState(() => _statusLoading = false);
      return;
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final Map<String, String> statuses = {};
    await Future.wait(classes.map((cls) async {
      final id = cls['id'] as String;
      try {
        final report = await service.getReport(id, today);
        if (report != null && report.isNotEmpty) {
          statuses[id] = (report['sent_to_parents'] as bool? ?? false) ? 'sent' : 'draft';
        } else {
          statuses[id] = 'none';
        }
      } catch (_) {
        statuses[id] = 'none';
      }
    }));
    if (mounted) setState(() { _statuses = statuses; _statusLoading = false; });
  }

  void _openClass(Map<String, dynamic> cls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportScreen(
          classId: cls['id'] as String,
          className: cls['name'] as String,
        ),
      ),
    ).then((_) => _loadStatuses(_classes));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text(
          'Daily Reports',
          style: TextStyle(
            color: Color(0xFF2D2323),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadClasses,
                          style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _classes.isEmpty
                  ? const Center(child: Text('No classes found'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: _classes.length,
                      itemBuilder: (context, index) {
                        final cls = _classes[index];
                        final id = cls['id'] as String;
                        final status = _statuses[id];
                        return _ClassCard(
                          className: cls['name'] as String,
                          branchName: cls['branch_name'] as String,
                          status: _statusLoading ? null : status,
                          onTap: () => _openClass(cls),
                        );
                      },
                    ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String className;
  final String branchName;
  final String? status; // 'sent' | 'draft' | 'none' | null (loading)
  final VoidCallback onTap;

  const _ClassCard({
    required this.className,
    required this.branchName,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.class_outlined, color: Colors.orange.shade600, size: 26),
                ),
                if (status != null && status != 'none')
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: status == 'sent' ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              className,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (branchName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                branchName,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            _StatusBadge(status: status),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return Container(
        height: 18,
        width: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }
    final Color bg;
    final Color fg;
    final String label;
    switch (status) {
      case 'sent':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'Sent';
      case 'draft':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        label = 'Draft';
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade500;
        label = 'None';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
