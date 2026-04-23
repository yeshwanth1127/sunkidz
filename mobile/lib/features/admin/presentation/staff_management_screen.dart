import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/api/admin_api.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/animated_list_item.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  int _tabIndex = 0; // 0: all, 1: teachers, 2: coordinators, 3: bus_staff
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _branches = [];
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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final role = _tabIndex == 1 ? 'teacher' : _tabIndex == 2 ? 'coordinator' : _tabIndex == 3 ? 'bus_staff' : null;
      final users = await api.getUsers(role: role);
      final branches = await api.getBranches();
      if (mounted) {
        setState(() {
          _users = users;
          _branches = branches;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _showAddUser() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddUserSheet(
        branches: _branches,
        role: _tabIndex == 2 ? 'coordinator' : _tabIndex == 3 ? 'bus_staff' : 'teacher',
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
        api: ref.read(adminApiProvider)!,
      ),
    );
  }

  void _showEditStaff(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditStaffSheet(
        user: user,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
        api: ref.read(adminApiProvider)!,
      ),
    );
  }

  void _confirmDeleteStaff(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff?'),
        content: Text('Are you sure you want to remove ${user['full_name']}? This action is permanent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminApiProvider)!.deleteUser(user['id'] as String);
                _load();
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

  void _showReassign(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReassignSheet(
        user: user,
        branches: _branches,
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildCategoryFilters(),
            Expanded(
              child: _loading
                  ? const _StaffLoadingPlaceholder()
                  : _error != null
                      ? _buildErrorState()
                      : _users.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                itemCount: _users.length,
                                itemBuilder: (context, i) => AnimatedListItem(
                                  index: i,
                                  child: _StaffCard(
                                    user: _users[i],
                                    onEdit: () => _showEditStaff(_users[i]),
                                    onReassign: () => _showReassign(_users[i]),
                                    onDelete: () => _confirmDeleteStaff(_users[i]),
                                  ),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUser,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          ),
          const SizedBox(width: 8),
          const Text(
            'Staff Directory',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: Icon(Icons.sync_rounded, color: _loading ? Colors.grey : AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final filters = [
      {'label': 'All', 'index': 0, 'icon': Icons.groups_rounded},
      {'label': 'Teachers', 'index': 1, 'icon': Icons.school_rounded},
      {'label': 'Coordinators', 'index': 2, 'icon': Icons.admin_panel_settings_rounded},
      {'label': 'Logistics', 'index': 3, 'icon': Icons.local_shipping_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _FilterItem(
            label: f['label'] as String,
            icon: f['icon'] as IconData,
            selected: _tabIndex == f['index'],
            onTap: () {
              setState(() => _tabIndex = f['index'] as int);
              _load();
            },
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(child: Text(_error ?? 'Unknown error', style: const TextStyle(color: Colors.red)));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No staff members found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterItem({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected ? [AppShadows.glow(AppColors.primary)] : [AppShadows.soft],
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onReassign;
  final VoidCallback onDelete;

  const _StaffCard({required this.user, required this.onEdit, required this.onReassign, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final role = user['role'] as String? ?? '';
    final isCoord = role == 'coordinator';
    final isBusStaff = role == 'bus_staff';
    
    final Color accentColor = isCoord 
        ? Colors.indigo.shade600 
        : isBusStaff ? Colors.orange.shade600 : AppColors.accentGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppShadows.soft],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isCoord ? Icons.verified_user_rounded : isBusStaff ? Icons.local_shipping_rounded : Icons.school_rounded,
                color: accentColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['full_name'] ?? 'Staff Member',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isBusStaff ? 'Logistics / Bus Staff' : '${user['branch_name'] ?? 'Unassigned'}${user['class_name'] != null ? ' • ${user['class_name']}' : ''}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'reassign') onReassign();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit Details')])),
                if (!isBusStaff) const PopupMenuItem(value: 'reassign', child: Row(children: [Icon(Icons.swap_horiz_rounded, size: 18), SizedBox(width: 8), Text('Reassign Role')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete Account', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffLoadingPlaceholder extends StatelessWidget {
  const _StaffLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          children: [
            const ShimmerLoading.circular(width: 56, height: 56),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading.rectangular(height: 16, width: MediaQuery.of(context).size.width * 0.4),
                  const SizedBox(height: 8),
                  ShimmerLoading.rectangular(height: 12, width: MediaQuery.of(context).size.width * 0.2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddUserSheet extends StatefulWidget {
  final List<Map<String, dynamic>> branches;
  final String role;
  final VoidCallback onSaved;
  final AdminApi api;

  const _AddUserSheet({required this.branches, required this.role, required this.onSaved, required this.api});

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _branchId;
  String? _classId;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getClassesForBranch(String branchId) {
    final branch = widget.branches.firstWhere((b) => b['id'] == branchId, orElse: () => {});
    if (branch.isEmpty) return [];
    final classes = branch['classes'] as List? ?? [];
    return List<Map<String, dynamic>>.from(classes);
  }

  bool get _needsBranch => widget.role == 'teacher' || widget.role == 'coordinator';

  bool get _needsClass => widget.role == 'teacher';

  String get _sheetTitle {
    switch (widget.role) {
      case 'coordinator':
        return 'New Coordinator';
      case 'bus_staff':
        return 'New Logistics Staff';
      default:
        return 'New Teacher';
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Full name is required'); return; }
    if (email.isEmpty) { setState(() => _error = 'Email is required'); return; }
    if (pass.isEmpty) { setState(() => _error = 'Password is required'); return; }
    if (_needsBranch && _branchId == null) { setState(() => _error = 'Branch is required'); return; }
    if (_needsClass && _classId == null) { setState(() => _error = 'Class is required'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.api.createUser(
        email: email,
        password: pass,
        fullName: name,
        role: widget.role,
        phone: phone.isEmpty ? null : phone,
        branchId: _needsBranch ? _branchId : null,
        classId: _needsClass ? _classId : null,
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
    final selectedBranchClasses = _branchId != null ? _getClassesForBranch(_branchId!) : [];
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text(_sheetTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded))),
            const SizedBox(height: 16),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.alternate_email_rounded))),
            const SizedBox(height: 16),
            TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded))),
            const SizedBox(height: 16),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number (Optional)', prefixIcon: Icon(Icons.phone_outlined))),
            if (_needsBranch) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _branchId,
                decoration: const InputDecoration(
                  labelText: 'Branch *',
                  prefixIcon: Icon(Icons.location_city_rounded),
                  border: OutlineInputBorder(),
                ),
                items: widget.branches.map((branch) {
                  return DropdownMenuItem(
                    value: branch['id'] as String,
                    child: Text(branch['name'] as String? ?? 'Unknown Branch'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _branchId = value;
                    _classId = null;
                  });
                },
              ),
            ],
            if (_needsClass && _branchId != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _classId,
                decoration: const InputDecoration(
                  labelText: 'Class *',
                  prefixIcon: Icon(Icons.school_rounded),
                  border: OutlineInputBorder(),
                ),
                items: selectedBranchClasses.map((cls) {
                  return DropdownMenuItem(
                    value: cls['id'] as String,
                    child: Text(cls['name'] as String? ?? 'Unknown Class'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _classId = value);
                },
              ),
            ],
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                 onPressed: _loading ? null : _submit,
                 child: _loading
                     ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                     : const Text('CREATE ACCOUNT', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditStaffSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSaved;
  final AdminApi api;
  const _EditStaffSheet({required this.user, required this.onSaved, required this.api});
  @override State<_EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends State<_EditStaffSheet> {
  late final _nameCtrl = TextEditingController(text: widget.user['full_name']?.toString() ?? '');
  late final _emailCtrl = TextEditingController(text: widget.user['email']?.toString() ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.user['phone']?.toString() ?? '');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Name is required'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.api.updateUser(
        widget.user['id'] as String,
        fullName: name,
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
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
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Edit Staff Member', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline_rounded))),
            const SizedBox(height: 16),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.alternate_email_rounded))),
            const SizedBox(height: 16),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone),
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReassignSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> branches;
  final VoidCallback onSaved;
  final AdminApi api;
  const _ReassignSheet({required this.user, required this.branches, required this.onSaved, required this.api});
  @override State<_ReassignSheet> createState() => _ReassignSheetState();
}

class _ReassignSheetState extends State<_ReassignSheet> {
  String? _branchId;
  String? _classId;
  List<Map<String, dynamic>> _classes = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _branchId = widget.user['branch_id']?.toString();
    if (_branchId != null) _loadClasses(_branchId!);
  }

  Future<void> _loadClasses(String branchId) async {
    try {
      final classes = await widget.api.getClasses(branchId: branchId);
      if (mounted) setState(() => _classes = classes);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_branchId == null) { setState(() => _error = 'Select a branch'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      // Use existing assignment or create one
      final assignments = await widget.api.getAssignments();
      final existing = assignments.where((a) => a['user_id']?.toString() == widget.user['id']?.toString()).toList();
      if (existing.isEmpty) {
        await widget.api.createAssignment(userId: widget.user['id'], branchId: _branchId!, classId: _classId);
      } else {
        await widget.api.updateAssignment(existing.first['id'], branchId: _branchId, classId: _classId);
      }
      widget.onSaved();
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Reassign ${widget.user['full_name'] ?? 'Staff'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _branchId,
              decoration: const InputDecoration(labelText: 'Branch *', border: OutlineInputBorder()),
              items: widget.branches.map((b) => DropdownMenuItem(value: b['id']?.toString(), child: Text(b['name']?.toString() ?? '—'))).toList(),
              onChanged: (v) {
                setState(() { _branchId = v; _classId = null; _classes = []; });
                if (v != null) _loadClasses(v);
              },
            ),
            if (_classes.isNotEmpty) ...[const SizedBox(height: 16), DropdownButtonFormField<String>(
              value: _classId,
              decoration: const InputDecoration(labelText: 'Class (optional)', border: OutlineInputBorder()),
              items: [const DropdownMenuItem(value: null, child: Text('No class')), ..._classes.map((c) => DropdownMenuItem(value: c['id']?.toString(), child: Text(c['name']?.toString() ?? '—')))],
              onChanged: (v) => setState(() => _classId = v),
            )],
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('SAVE ASSIGNMENT', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
