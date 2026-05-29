import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../core/auth/auth_provider.dart';
import 'repertory_report_screen.dart';

class GradeListScreen extends ConsumerStatefulWidget {
  const GradeListScreen({super.key});

  @override
  ConsumerState<GradeListScreen> createState() => _GradeListScreenState();
}

class _GradeListScreenState extends ConsumerState<GradeListScreen> {
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
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
        // Use auth.branchId (set at login) as the authoritative filter,
        // falling back to the branch_id field on each class if present.
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
        // Teacher is assigned to exactly one class; use auth.classId to
        // guarantee we only ever show that class.
        final assignedClassId = auth.classId ?? dashboard['class_id']?.toString() ?? '';
        final classId = dashboard['class_id']?.toString() ?? '';
        final className = dashboard['class_name']?.toString() ?? '';
        final branchName = dashboard['branch_name']?.toString() ?? '';
        if (classId.isNotEmpty && (assignedClassId.isEmpty || classId == assignedClassId)) {
          classes.add({'id': classId, 'name': className, 'branch_name': branchName});
        }
      }
      setState(() { _classes = classes; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
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
                          onPressed: () {
                            setState(() { _loading = true; _error = null; });
                            _loadClasses();
                          },
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
                        childAspectRatio: 1.2,
                      ),
                      itemCount: _classes.length,
                      itemBuilder: (context, index) {
                        final cls = _classes[index];
                        return _ClassCard(
                          className: cls['name'] as String,
                          branchName: cls['branch_name'] as String,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RepertoryReportScreen(
                                classId: cls['id'] as String,
                                className: cls['name'] as String,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String className;
  final String branchName;
  final VoidCallback onTap;

  const _ClassCard({
    required this.className,
    required this.branchName,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.class_outlined, color: Colors.orange.shade600, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              className,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (branchName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                branchName,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
