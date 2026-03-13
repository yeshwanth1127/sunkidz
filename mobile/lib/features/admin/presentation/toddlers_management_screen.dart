import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_api.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';

class ToddlersManagementScreen extends ConsumerStatefulWidget {
  const ToddlersManagementScreen({super.key});

  @override
  ConsumerState<ToddlersManagementScreen> createState() => _ToddlersManagementScreenState();
}

class _ToddlersManagementScreenState extends ConsumerState<ToddlersManagementScreen> {
  List<Map<String, dynamic>> _users = [];
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
      final users = await api.getUsers(role: 'toddlers');
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
      builder: (ctx) => _AddToddlersUserSheet(
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
      builder: (ctx) => _EditToddlersUserSheet(
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
        title: const Text('Delete Toddlers User'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        title: const Text('Toddlers Management'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddUser),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (_, i) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.child_care)),
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
                ),
    );
  }
}

class _AddToddlersUserSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final AdminApi api;
  const _AddToddlersUserSheet({required this.onSaved, required this.api});

  @override
  State<_AddToddlersUserSheet> createState() => _AddToddlersUserSheetState();
}

class _AddToddlersUserSheetState extends State<_AddToddlersUserSheet> {
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
      await widget.api.createToddlersUser(
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
              Text('Add Toddlers User', style: Theme.of(context).textTheme.titleLarge),
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

class _EditToddlersUserSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSaved;
  final AdminApi api;
  const _EditToddlersUserSheet({required this.user, required this.onSaved, required this.api});

  @override
  State<_EditToddlersUserSheet> createState() => _EditToddlersUserSheetState();
}

class _EditToddlersUserSheetState extends State<_EditToddlersUserSheet> {
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
              Text('Edit Toddlers User', style: Theme.of(context).textTheme.titleLarge),
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
