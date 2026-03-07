import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_api.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';

class BranchListScreen extends ConsumerStatefulWidget {
  const BranchListScreen({super.key});

  @override
  ConsumerState<BranchListScreen> createState() => _BranchListScreenState();
}

class _BranchListScreenState extends ConsumerState<BranchListScreen> {
  int _filterIndex = 0;
  final _searchController = TextEditingController();
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
    if (api == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = await api.getBranches();
      setState(() {
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

  void _showAddBranch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddBranchSheet(
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
        api: ref.read(adminApiProvider)!,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        title: const Text('Branches'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: _showAddBranch),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or city...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'All', selected: _filterIndex == 0, onTap: () => setState(() => _filterIndex = 0)),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Active', selected: _filterIndex == 1, onTap: () => setState(() => _filterIndex = 1)),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Pending', selected: _filterIndex == 2, onTap: () => setState(() => _filterIndex = 2)),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Full Capacity', selected: _filterIndex == 3, onTap: () => setState(() => _filterIndex = 3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _branches.length,
                        itemBuilder: (_, i) => _BranchCard(
                          branch: _branches[i],
                          onTap: () => context.push('/branches/${_branches[i]['id']}'),
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
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? Colors.white : Colors.grey)),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> branch;
  final VoidCallback onTap;

  const _BranchCard({required this.branch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = branch['status'] as String? ?? 'active';
    final statusColor = status == 'active' ? Colors.green : status == 'full' ? Colors.orange : Colors.grey;
    final name = branch['name'] as String? ?? '';
    final coordinator = branch['coordinator_name'] as String? ?? '—';
    final students = branch['student_count'] as int? ?? 0;
    final address = branch['address'] as String? ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.pastelBlue, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.business, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                        child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COORDINATOR', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      Row(children: [Icon(Icons.person, size: 14), const SizedBox(width: 4), Expanded(child: Text(coordinator, style: TextStyle(fontWeight: FontWeight.w500)))])
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STUDENTS', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      Row(children: [Icon(Icons.groups, size: 14), const SizedBox(width: 4), Text('$students Students', style: TextStyle(fontWeight: FontWeight.w500))])
                    ],
                  ),
                ),
              ],
            ),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ADDRESS', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(address, style: TextStyle(fontSize: 14, color: Colors.grey.shade700))),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddBranchSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final AdminApi api;

  const _AddBranchSheet({required this.onSaved, required this.api});

  @override
  State<_AddBranchSheet> createState() => _AddBranchSheetState();
}

class _AddBranchSheetState extends State<_AddBranchSheet> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _status = 'active';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
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
      await widget.api.createBranch(
        name: _nameCtrl.text.trim(),
        code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim().toLowerCase(),
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
            Text('Add Branch', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
            TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Code (e.g. acs, mun, ash for admission numbers)')),
            TextField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Address')),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Contact')),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add Branch')),
          ],
        ),
      ),
    );
  }
}
