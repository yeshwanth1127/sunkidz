import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_api.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = _tabIndex == 1
          ? 'teacher'
          : _tabIndex == 2
              ? 'coordinator'
              : _tabIndex == 3
                  ? 'bus_staff'
                  : null;
      final users = await api.getUsers(role: role);
      final branches = await api.getBranches();
      setState(() {
        _users = users;
        _branches = branches;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Shows role-picker first, then opens the Add sheet
  void _showAddUser() {
    // When on a specific tab, skip the role picker
    if (_tabIndex != 0) {
      final role = _tabIndex == 2
          ? 'coordinator'
          : _tabIndex == 3
              ? 'bus_staff'
              : 'teacher';
      _openAddSheet(role);
      return;
    }
    // On "All" tab — ask which role to add
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Add Staff — Select Role', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.pastelGreen, child: const Icon(Icons.person, color: Color(0xFF16A34A))),
                title: const Text('Teacher'),
                subtitle: const Text('Assigned to a branch & class'),
                onTap: () { Navigator.pop(ctx); _openAddSheet('teacher'); },
              ),
              ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.pastelBlue, child: Icon(Icons.supervisor_account, color: AppColors.primary)),
                title: const Text('Coordinator'),
                subtitle: const Text('Manages a branch'),
                onTap: () { Navigator.pop(ctx); _openAddSheet('coordinator'); },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFFFEDD5), child: Icon(Icons.directions_bus, color: Color(0xFFEA580C))),
                title: const Text('Bus Staff'),
                subtitle: const Text('Manages student bus routes'),
                onTap: () { Navigator.pop(ctx); _openAddSheet('bus_staff'); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddSheet(String role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddUserSheet(
        branches: _branches,
        role: role,
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
        title: const Text('Delete Staff'),
        content: Text(
          'Are you sure you want to delete ${user['full_name']}? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminApiProvider)!.deleteUser(user['id'] as String);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${user['full_name']} deleted')),
                  );
                  _load();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
                  );
                }
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
      backgroundColor: const Color(0xFFFFF4E0),
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Staff Management'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddUser),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(label: 'All', selected: _tabIndex == 0, onTap: () { setState(() => _tabIndex = 0); _load(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Teachers', selected: _tabIndex == 1, onTap: () { setState(() => _tabIndex = 1); _load(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Coordinators', selected: _tabIndex == 2, onTap: () { setState(() => _tabIndex = 2); _load(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Bus Staff', selected: _tabIndex == 3, onTap: () { setState(() => _tabIndex = 3); _load(); }),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else if (_users.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_off, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No staff found', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _showAddUser,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Staff'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (_, i) => _StaffCard(
                  user: _users[i],
                  onEdit: () => _showEditStaff(_users[i]),
                  onReassign: () => _showReassign(_users[i]),
                  onDelete: () => _confirmDeleteStaff(_users[i]),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.grey,
          ),
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
    final Color avatarColor = isCoord
        ? AppColors.pastelBlue
        : isBusStaff
            ? const Color(0xFFFFEDD5)
            : AppColors.pastelGreen;
    final Color iconColor = isCoord
        ? AppColors.primary
        : isBusStaff
            ? const Color(0xFFEA580C)
            : const Color(0xFF16A34A);
    final IconData icon = isCoord
        ? Icons.supervisor_account
        : isBusStaff
            ? Icons.directions_bus
            : Icons.person;

    final isActive = (user['is_active'] as String? ?? 'true') == 'true';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarColor,
          child: Icon(icon, color: iconColor),
        ),
        title: Row(
          children: [
            Expanded(child: Text(user['full_name'] as String? ?? '')),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                child: Text('INACTIVE', style: TextStyle(fontSize: 9, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBusStaff
                  ? 'Bus Staff'
                  : isCoord
                      ? 'Coordinator • ${user['branch_name'] ?? 'Unassigned'}'
                      : '${user['branch_name'] ?? 'Unassigned'}${user['class_name'] != null ? ' • ${user['class_name']}' : ''}',
              style: const TextStyle(fontSize: 13),
            ),
            if ((user['email'] as String?) != null)
              Text(user['email'] as String, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'reassign') onReassign();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit details')])),
            if (user['role'] != 'bus_staff')
              const PopupMenuItem(value: 'reassign', child: Row(children: [Icon(Icons.swap_horiz, size: 18), SizedBox(width: 8), Text('Reassign')])),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Staff Sheet ─────────────────────────────────────────────────────────

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
  // Track if user was created so we don't double-create on assignment failure
  String? _createdUserId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validate
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Full name is required');
      return;
    }
    if (_passCtrl.text.isEmpty) {
      setState(() => _error = 'Password is required');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Email is required for login');
      return;
    }
    if (widget.role == 'teacher' && _branchId == null) {
      setState(() => _error = 'Please select a branch');
      return;
    }
    if (widget.role == 'coordinator' && _branchId == null) {
      setState(() => _error = 'Please select a branch');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Step 1: Create user (if not already created from a previous failed attempt)
      String userId = _createdUserId ?? '';
      if (_createdUserId == null) {
        final created = await widget.api.createUser(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          fullName: _nameCtrl.text.trim(),
          role: widget.role,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        );
        userId = created['id'] as String;
        _createdUserId = userId; // Remember in case step 2 fails
      }

      // Step 2: Assign to branch (teachers and coordinators only)
      if (_branchId != null && widget.role != 'bus_staff') {
        await widget.api.createAssignment(
          userId: userId,
          branchId: _branchId!,
          classId: widget.role == 'teacher' ? _classId : null,
        );
      }

      widget.onSaved();
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        // If user was already created, tell the admin specifically what failed
        _error = _createdUserId != null && !msg.contains('already')
            ? 'Staff created but branch assignment failed: $msg\nTap Save again to retry assignment.'
            : msg;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = widget.role == 'coordinator'
        ? 'Coordinator'
        : widget.role == 'bus_staff'
            ? 'Bus Staff'
            : 'Teacher';
    final branch = widget.branches
        .cast<Map<String, dynamic>?>()
        .firstWhere((b) => b!['id'] == _branchId, orElse: () => null);
    final classes = (branch?['classes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add $roleLabel', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full Name *'),
            ),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email * (used for login)'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Password *'),
              obscureText: true,
            ),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            if (widget.role != 'bus_staff')
              DropdownButtonFormField<String>(
                value: _branchId,
                decoration: InputDecoration(
                  labelText: 'Branch *',
                  helperText: widget.role == 'coordinator'
                      ? 'Coordinator manages the whole branch'
                      : 'Select which branch this teacher belongs to',
                ),
                items: widget.branches
                    .map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _branchId = v;
                  _classId = null;
                }),
              ),
            if (widget.role == 'teacher' && _branchId != null && classes.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _classId,
                decoration: const InputDecoration(labelText: 'Class (optional)', helperText: 'Assign to a specific class'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— No class yet —')),
                  ...classes.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))),
                ],
                onChanged: (v) => setState(() => _classId = v),
              ),
            if (widget.role == 'teacher' && _branchId != null && classes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('⚠ No classes in selected branch yet', style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_createdUserId != null ? 'Retry Assignment' : 'Add $roleLabel'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Staff Sheet ─────────────────────────────────────────────────────────

class _EditStaffSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSaved;
  final AdminApi api;

  const _EditStaffSheet({required this.user, required this.onSaved, required this.api});

  @override
  State<_EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends State<_EditStaffSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late String _isActive;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user['full_name'] as String? ?? '');
    _emailCtrl = TextEditingController(text: widget.user['email'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: widget.user['phone'] as String? ?? '');
    _isActive = widget.user['is_active'] as String? ?? 'true';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
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
      await widget.api.updateUser(
        widget.user['id'] as String,
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        isActive: _isActive,
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
            Text('Edit ${widget.user['full_name']}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            DropdownButtonFormField<String>(
              value: _isActive,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'true', child: Text('Active')),
                DropdownMenuItem(value: 'false', child: Text('Inactive')),
              ],
              onChanged: (v) => setState(() => _isActive = v ?? 'true'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reassign Sheet ───────────────────────────────────────────────────────────

class _ReassignSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> branches;
  final VoidCallback onSaved;
  final AdminApi api;

  const _ReassignSheet({required this.user, required this.branches, required this.onSaved, required this.api});

  @override
  State<_ReassignSheet> createState() => _ReassignSheetState();
}

class _ReassignSheetState extends State<_ReassignSheet> {
  String? _branchId;
  String? _classId;
  bool _loading = false;
  bool _loadingAssignment = true;
  String? _error;
  String? _existingAssignmentId;

  @override
  void initState() {
    super.initState();
    // Pre-populate with current assignment
    _branchId = widget.user['branch_id'] as String?;
    _classId = widget.user['class_id'] as String?;
    _loadAssignmentId();
  }

  Future<void> _loadAssignmentId() async {
    try {
      final assignments = await widget.api.getAssignments();
      final a = assignments.cast<Map<String, dynamic>?>().firstWhere(
        (x) => x!['user_id'] == widget.user['id'],
        orElse: () => null,
      );
      if (mounted) {
        setState(() {
          _existingAssignmentId = a?['id'] as String?;
          _loadingAssignment = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAssignment = false);
    }
  }

  Future<void> _submit() async {
    if (_branchId == null) {
      setState(() => _error = 'Please select a branch');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_existingAssignmentId != null) {
        await widget.api.updateAssignment(
          _existingAssignmentId!,
          branchId: _branchId,
          classId: widget.user['role'] == 'teacher' ? _classId : null,
        );
      } else {
        await widget.api.createAssignment(
          userId: widget.user['id'] as String,
          branchId: _branchId!,
          classId: widget.user['role'] == 'teacher' ? _classId : null,
        );
      }
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
    final branch = widget.branches
        .cast<Map<String, dynamic>?>()
        .firstWhere((b) => b!['id'] == _branchId, orElse: () => null);
    final classes = (branch?['classes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reassign ${widget.user['full_name']}', style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${widget.user['role'] == 'coordinator' ? 'Coordinator' : 'Teacher'} — currently: ${widget.user['branch_name'] ?? 'Unassigned'}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            if (_loadingAssignment)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else ...[
              DropdownButtonFormField<String>(
                value: _branchId,
                decoration: const InputDecoration(labelText: 'Branch *'),
                items: widget.branches
                    .map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _branchId = v;
                  _classId = null;
                }),
              ),
              if (widget.user['role'] == 'teacher' && classes.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _classId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— None —')),
                    ...classes.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))),
                  ],
                  onChanged: (v) => setState(() => _classId = v),
                ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_loading || _loadingAssignment) ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Assignment'),
            ),
          ],
        ),
      ),
    );
  }
}
