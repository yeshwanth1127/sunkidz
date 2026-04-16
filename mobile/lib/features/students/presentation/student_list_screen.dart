import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/admin_api.dart';

import '../../../shared/widgets/dob_picker.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/animated_list_item.dart';

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
      if (mounted) {
        setState(() {
          _branches = branches;
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
      if (mounted) {
        setState(() {
          _classes = classes;
          _selectedClassId = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStudents() async {
    final api = ref.read(adminApiProvider);
    if (api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final students = await api.getAdmissions(
        branchId: _selectedBranchId,
        classId: _selectedClassId,
      );
      if (mounted) {
        setState(() {
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

  void _onBranchChanged(String? branchId) {
    setState(() {
      _selectedBranchId = branchId;
      _classes = [];
      _selectedClassId = null;
    });
    if (branchId != null) {
      _loadClasses(branchId).then((_) => _loadStudents());
    } else {
      _loadStudents();
    }
  }

  void _onClassChanged(String? classId) {
    setState(() => _selectedClassId = classId);
    _loadStudents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildFilters(),
            Expanded(
              child: _loading
                  ? const _StudentLoadingPlaceholder()
                  : _error != null
                      ? _buildErrorState()
                      : _students.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadStudents,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: _students.length,
                                itemBuilder: (context, i) => AnimatedListItem(
                                  index: i,
                                  child: _StudentCard(
                                    student: _students[i],
                                    onTap: () => context.push('/students/${_students[i]['id']}'),
                                    onDelete: () => _confirmDeleteStudent(_students[i]),
                                    onBusOptToggle: () => _toggleBusOpt(_students[i]),
                                    onShiftBranch: () => _showShiftBranchDialog(_students[i]),
                                  ),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admissions/new'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/admin');
              }
            },
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Student Directory',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loading ? null : _loadStudents,
            icon: Icon(Icons.refresh_rounded, color: _loading ? Colors.grey : AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppShadows.soft],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                value: _selectedBranchId,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.apartment_rounded, size: 18),
                  hintText: 'Branch',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Branches')),
                  ..._branches.map((b) => DropdownMenuItem(value: b['id'] as String?, child: Flexible(child: Text(b['name']?.toString() ?? '—', overflow: TextOverflow.ellipsis)))),
                ],
                onChanged: _onBranchChanged,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                value: _selectedClassId,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.grid_3x3_rounded, size: 18),
                  hintText: 'Grade',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Grades')),
                  ..._classes.map((c) => DropdownMenuItem(value: c['id'] as String?, child: Flexible(child: Text(c['name']?.toString() ?? '—', overflow: TextOverflow.ellipsis)))),
                ],
                onChanged: _onClassChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(child: Text(_error ?? 'Unknown Error', style: const TextStyle(color: Colors.red)));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No students found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _confirmDeleteStudent(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text('Are you sure you want to remove ${student['name']}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminApiProvider)!.deleteStudent(student['id']);
                _loadStudents();
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
      await ref.read(adminApiProvider)!.toggleBusOpt(student['id']);
      _loadStudents();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showShiftBranchDialog(Map<String, dynamic> student) async {
    // Navigate to student profile where branch transfer is available
    context.push('/students/${student['id']}');
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onBusOptToggle;
  final VoidCallback onShiftBranch;

  const _StudentCard({required this.student, required this.onTap, required this.onDelete, required this.onBusOptToggle, required this.onShiftBranch});

  @override
  Widget build(BuildContext context) {
    final name = student['name'] ?? 'Unknown';
    final admissionNo = student['admission_number'] ?? '—';
    final branch = student['branch_name'] ?? 'Branch';
    final className = student['class_name'] ?? '';
    final busOpted = student['bus_opted'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppShadows.soft],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.indigo.shade400, Colors.indigo.shade700]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A))),
                        Text('$branch ${className.isNotEmpty ? "• $className" : ""}', 
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                      if (v == 'bus') onBusOptToggle();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'bus', child: Row(children: [Icon(busOpted ? Icons.bus_alert : Icons.directions_bus, size: 18), const SizedBox(width: 8), Text(busOpted ? 'Disable Bus' : 'Enable Bus')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
              Row(
                children: [
                  Text('ID: $admissionNo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                  const Spacer(),
                  if (busOpted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.directions_bus_rounded, size: 12, color: Colors.amber.shade700),
                          const SizedBox(width: 4),
                          Text('BUS OPTED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.amber.shade700)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentLoadingPlaceholder extends StatelessWidget {
  const _StudentLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Column(
        children: [
          Row(
            children: [
              const ShimmerLoading.circular(width: 56, height: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoading.rectangular(height: 16, width: MediaQuery.of(context).size.width * 0.5),
                    const SizedBox(height: 8),
                    ShimmerLoading.rectangular(height: 12, width: MediaQuery.of(context).size.width * 0.3),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
