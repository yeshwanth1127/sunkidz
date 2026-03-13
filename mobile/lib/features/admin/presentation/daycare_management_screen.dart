import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/admin_api.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';

class DaycareManagementScreen extends ConsumerStatefulWidget {
  const DaycareManagementScreen({super.key});

  @override
  ConsumerState<DaycareManagementScreen> createState() => _DaycareManagementScreenState();
}

class _DaycareManagementScreenState extends ConsumerState<DaycareManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  bool _loadingGroups = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    _loadGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await api.getUsers(role: 'daycare');
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showAddUser() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddDaycareUserSheet(
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
        api: ref.read(adminApiProvider)!,
      ),
    );
  }

  void _showEditUser(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditDaycareUserSheet(
        user: user,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
        api: ref.read(adminApiProvider)!,
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Daycare User'),
        content: Text('Delete ${user['full_name']}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminApiProvider)!.deleteUser(user['id'] as String);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted')));
                  _load();
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

  Future<void> _loadGroups() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() => _loadingGroups = true);
    try {
      final groups = await api.getDaycareGroups();
      setState(() {
        _groups = groups;
        _loadingGroups = false;
      });
    } catch (e) {
      setState(() {
        _loadingGroups = false;
      });
    }
  }

  void _showAddGroup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddDaycareGroupSheet(
        onSaved: () {
          Navigator.pop(ctx);
          _loadGroups();
        },
        api: ref.read(adminApiProvider)!,
        daycareUsers: _users,
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
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        title: const Text('Daycare Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Users', icon: Icon(Icons.person)),
            Tab(text: 'Groups', icon: Icon(Icons.group)),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) => IconButton(
              icon: const Icon(Icons.add),
              onPressed: _tabController.index == 0 ? _showAddUser : _showAddGroup,
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildGroupsTab(),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_loading)
      return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (_, i) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.child_friendly)),
          title: Text(_users[i]['full_name'] ?? ''),
          subtitle: Text('${_users[i]['email'] ?? ''}${(_users[i]['date_of_birth'] != null) ? ' • DOB: ${_users[i]['date_of_birth']}' : ''}'),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _showEditUser(_users[i]);
              else if (v == 'delete') _confirmDelete(_users[i]);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
          onTap: () => _showEditUser(_users[i]),
        ),
      ),
    );
  }

  Widget _buildGroupsTab() {
    if (_loadingGroups) return const Center(child: CircularProgressIndicator());
    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No daycare groups yet', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _showAddGroup,
              icon: const Icon(Icons.add),
              label: const Text('Create first group'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groups.length,
      itemBuilder: (_, i) {
        final g = _groups[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.group)),
            title: Text(g['name'] ?? ''),
            subtitle: Text('${g['branch_name'] ?? ''} • ${g['daycare_staff_name'] ?? ''} • ${g['student_count'] ?? 0} students'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'add_student') {
                  _showAddStudentToGroup(g['id'] as String);
                } else if (v == 'delete') {
                  _confirmDeleteGroup(g);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'add_student', child: Text('Add student')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
            onTap: () => _showAddStudentToGroup(g['id'] as String),
          ),
        );
      },
    );
  }

  void _showAddStudentToGroup(String groupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddStudentToGroupSheet(
        groupId: groupId,
        onSaved: () {
          Navigator.pop(ctx);
          _loadGroups();
        },
        api: ref.read(adminApiProvider)!,
      ),
    );
  }

  void _confirmDeleteGroup(Map<String, dynamic> g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Daycare Group'),
        content: Text('Delete ${g['name']}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminApiProvider)!.deleteDaycareGroup(g['id'] as String);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group deleted')));
                  _loadGroups();
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
}

class _AddDaycareGroupSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final AdminApi api;
  final List<Map<String, dynamic>> daycareUsers;

  const _AddDaycareGroupSheet({
    required this.onSaved,
    required this.api,
    required this.daycareUsers,
  });

  @override
  State<_AddDaycareGroupSheet> createState() => _AddDaycareGroupSheetState();
}

class _AddDaycareGroupSheetState extends State<_AddDaycareGroupSheet> {
  final _nameCtrl = TextEditingController();
  String? _branchId;
  String? _daycareStaffId;
  List<Map<String, dynamic>> _branches = [];
  bool _loadingBranches = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await widget.api.getBranches();
      if (mounted) {
        setState(() {
          _branches = branches;
          _loadingBranches = false;
          if (_branchId == null && branches.isNotEmpty) _branchId = branches.first['id'] as String?;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBranches = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (_branchId == null) {
      setState(() => _error = 'Select a branch');
      return;
    }
    if (_daycareStaffId == null) {
      setState(() => _error = 'Select daycare staff');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.createDaycareGroup(
        name: name,
        branchId: _branchId!,
        daycareStaffId: _daycareStaffId!,
      );
      widget.onSaved();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Create Daycare Group', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Group Name *')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _branchId,
                decoration: const InputDecoration(labelText: 'Branch *'),
                items: _branches
                    .map((b) => DropdownMenuItem(
                          value: b['id'] as String?,
                          child: Text(b['name'] as String? ?? ''),
                        ))
                    .toList(),
                onChanged: _loadingBranches ? null : (v) => setState(() => _branchId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _daycareStaffId,
                decoration: const InputDecoration(labelText: 'Daycare Staff *'),
                items: widget.daycareUsers
                    .map((u) => DropdownMenuItem(
                          value: u['id'] as String?,
                          child: Text(u['full_name'] as String? ?? ''),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _daycareStaffId = v),
              ),
              const SizedBox(height: 16),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              _saving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(onPressed: _save, child: const Text('Create')),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddStudentToGroupSheet extends StatefulWidget {
  final String groupId;
  final VoidCallback onSaved;
  final AdminApi api;

  const _AddStudentToGroupSheet({
    required this.groupId,
    required this.onSaved,
    required this.api,
  });

  @override
  State<_AddStudentToGroupSheet> createState() => _AddStudentToGroupSheetState();
}

class _AddStudentToGroupSheetState extends State<_AddStudentToGroupSheet> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _groupStudents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final group = await widget.api.getDaycareGroup(widget.groupId);
      final students = await widget.api.getAdmissions();
      final groupStudents = List<Map<String, dynamic>>.from((group['students'] as List?) ?? []);
      final existingIds = groupStudents.map((s) => s['student_id'] as String?).toSet();
      final available = students.where((s) => !existingIds.contains(s['id'])).toList();
      if (mounted) {
        setState(() {
          _groupStudents = groupStudents;
          _students = available;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _addStudent(String studentId) async {
    setState(() => _error = null);
    try {
      await widget.api.addStudentToDaycareGroup(widget.groupId, studentId);
      _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _removeStudent(String studentId) async {
    setState(() => _error = null);
    try {
      await widget.api.removeStudentFromDaycareGroup(widget.groupId, studentId);
      _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Group Students', style: Theme.of(context).textTheme.titleMedium),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Current students', style: Theme.of(context).textTheme.titleSmall),
                      ..._groupStudents.map((s) => ListTile(
                            title: Text(s['student_name'] ?? ''),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => _removeStudent(s['student_id'] as String),
                            ),
                          )),
                      const SizedBox(height: 16),
                      Text('Add student', style: Theme.of(context).textTheme.titleSmall),
                      ..._students.map((s) => ListTile(
                            title: Text(s['name'] ?? ''),
                            subtitle: Text(s['admission_number'] ?? ''),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _addStudent(s['id'] as String),
                            ),
                          )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddDaycareUserSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final AdminApi api;
  const _AddDaycareUserSheet({required this.onSaved, required this.api});

  @override
  State<_AddDaycareUserSheet> createState() => _AddDaycareUserSheetState();
}

class _AddDaycareUserSheetState extends State<_AddDaycareUserSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _save() async {
    final email = _emailCtrl.text.trim();
    final dob = _dobCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Email is required for login');
      return;
    }
    if (dob.isEmpty) {
      setState(() => _error = 'Date of birth is required for login');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.createDaycareUser(
        fullName: _nameCtrl.text.trim(),
        email: email,
        dateOfBirth: dob,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      widget.onSaved();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Daycare User', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
              const SizedBox(height: 8),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email * (login)'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: _dobCtrl, decoration: const InputDecoration(labelText: 'Date of Birth * (YYYY-MM-DD, for login)')),
              const SizedBox(height: 8),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 16),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditDaycareUserSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSaved;
  final AdminApi api;
  const _EditDaycareUserSheet({required this.user, required this.onSaved, required this.api});

  @override
  State<_EditDaycareUserSheet> createState() => _EditDaycareUserSheetState();
}

class _EditDaycareUserSheetState extends State<_EditDaycareUserSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _phoneCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user['full_name'] as String? ?? '');
    _emailCtrl = TextEditingController(text: widget.user['email'] as String? ?? '');
    _dobCtrl = TextEditingController(text: widget.user['date_of_birth'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: widget.user['phone'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _emailCtrl.text.trim();
    final dob = _dobCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Email is required for login');
      return;
    }
    if (dob.isEmpty) {
      setState(() => _error = 'Date of birth is required for login');
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
        email: email,
        dateOfBirth: dob,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      widget.onSaved();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Daycare User', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
              const SizedBox(height: 8),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email * (login)'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: _dobCtrl, decoration: const InputDecoration(labelText: 'Date of Birth * (YYYY-MM-DD, for login)')),
              const SizedBox(height: 8),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 16),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
