import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_api.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';

class BranchDetailScreen extends ConsumerStatefulWidget {
  const BranchDetailScreen({super.key, required this.branchId});

  final String branchId;

  @override
  ConsumerState<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends ConsumerState<BranchDetailScreen> {
  Map<String, dynamic>? _branch;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final b = await api.getBranch(widget.branchId);
      setState(() {
        _branch = b;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showEditBranch() {
    if (_branch == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditBranchSheet(
        branch: _branch!,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
        api: ref.read(adminApiProvider)!,
      ),
    );
  }

  Future<void> _confirmDeleteBranch() async {
    if (_branch == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Branch?'),
        content: Text('Are you sure you want to delete "${_branch!['name']}"? This action cannot be undone and will remove all associated data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteBranch();
    }
  }

  Future<void> _deleteBranch() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      await api.deleteBranch(widget.branchId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branch deleted')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')));
      }
    }
  }

  Future<void> _deleteClass(String classId) async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      await api.deleteClass(classId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class deleted')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')));
      }
    }
  }

  void _showAddGrade() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _AddGradeSheet(
        branchId: widget.branchId,
        existingClasses: (_branch?['classes'] as List?)?.map((c) => c['name'] as String).toList() ?? [],
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
        api: ref.read(adminApiProvider)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(_branch?['name'] as String? ?? 'Branch'),
        actions: [
          Builder(
            builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
          ),
          IconButton(icon: const Icon(Icons.edit), onPressed: _branch != null ? _showEditBranch : null),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') _confirmDeleteBranch();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Delete Branch', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _branch == null
                  ? const Center(child: Text('Branch not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoCard(branch: _branch!),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Grades / Classes', style: Theme.of(context).textTheme.titleLarge),
                              TextButton.icon(
                                onPressed: _showAddGrade,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Grade'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _ClassesList(
                            classes: (_branch!['classes'] as List?)?.cast<Map<String, dynamic>>() ?? [],
                            onDelete: _deleteClass,
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> branch;

  const _InfoCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.pastelBlue, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.business, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branch['name'] as String? ?? '', style: Theme.of(context).textTheme.titleMedium),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (branch['status'] == 'active' ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text((branch['status'] as String? ?? '').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: branch['status'] == 'active' ? Colors.green : Colors.grey)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (branch['address'] != null && (branch['address'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.location_on, size: 16, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(branch['address'] as String, style: TextStyle(color: Colors.grey.shade700)))]),
            ],
            if (branch['contact_no'] != null && (branch['contact_no'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [Icon(Icons.phone, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(branch['contact_no'] as String)]),
            ],
            const SizedBox(height: 8),
            Text('Coordinator: ${branch['coordinator_name'] ?? '—'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text('Students: ${branch['student_count'] ?? 0}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _ClassesList extends StatelessWidget {
  final List<Map<String, dynamic>> classes;
  final Function(String) onDelete;

  const _ClassesList({required this.classes, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('No classes yet. Add a grade above.', style: TextStyle(color: Colors.grey.shade600))),
        ),
      );
    }
    return Column(
      children: classes.map((c) {
        final classId = c['id'] as String;
        final className = c['name'] as String? ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.pastelYellow, child: Icon(Icons.school, color: const Color(0xFFCA8A04))),
            title: Text(className),
            subtitle: Text(c['academic_year'] as String? ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Class?'),
                    content: Text('Are you sure you want to delete "$className"? This will remove all students from this class.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) onDelete(classId);
              },
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EditBranchSheet extends StatefulWidget {
  final Map<String, dynamic> branch;
  final VoidCallback onSaved;
  final AdminApi api;

  const _EditBranchSheet({required this.branch, required this.onSaved, required this.api});

  @override
  State<_EditBranchSheet> createState() => _EditBranchSheetState();
}

class _EditBranchSheetState extends State<_EditBranchSheet> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _status;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.branch['name'] as String? ?? '';
    _addrCtrl.text = widget.branch['address'] as String? ?? '';
    _phoneCtrl.text = widget.branch['contact_no'] as String? ?? '';
    _status = widget.branch['status'] as String? ?? 'active';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.updateBranch(
        widget.branch['id'] as String,
        name: _nameCtrl.text.trim(),
        address: _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
        contactNo: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        status: _status,
      );
      widget.onSaved();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit Branch', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
            TextField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Address')),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Contact')),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [DropdownMenuItem(value: 'active', child: Text('Active')), DropdownMenuItem(value: 'pending', child: Text('Pending')), DropdownMenuItem(value: 'inactive', child: Text('Inactive'))],
              onChanged: (v) => setState(() => _status = v),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
          ],
        ),
      ),
    );
  }
}

class _AddGradeSheet extends StatefulWidget {
  final String branchId;
  final List<String> existingClasses;
  final VoidCallback onSaved;
  final AdminApi api;

  const _AddGradeSheet({required this.branchId, required this.existingClasses, required this.onSaved, required this.api});

  @override
  State<_AddGradeSheet> createState() => _AddGradeSheetState();
}

class _AddGradeSheetState extends State<_AddGradeSheet> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim().toLowerCase();
    if (name.isEmpty) {
      setState(() => _error = 'Grade name required');
      return;
    }
    if (widget.existingClasses.any((c) => c.toLowerCase() == name)) {
      setState(() => _error = 'This grade already exists');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.createClass(branchId: widget.branchId, name: name);
      widget.onSaved();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Grade / Class', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Grade name (e.g. ig4, kindergarten)')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add')),
          ],
        ),
      ),
    );
  }
}
