import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/chat_provider.dart';
import '../../../core/theme/app_theme.dart';

class StaffLeaveScreen extends ConsumerStatefulWidget {
  const StaffLeaveScreen({super.key});

  @override
  ConsumerState<StaffLeaveScreen> createState() => _StaffLeaveScreenState();
}

class _StaffLeaveScreenState extends ConsumerState<StaffLeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, List<Map<String, dynamic>>> _bucket = {
    'pending': [],
    'approved': [],
    'rejected': [],
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(leaveApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final all = await api.listLeaves();
      final b = <String, List<Map<String, dynamic>>>{
        'pending': [],
        'approved': [],
        'rejected': [],
      };
      for (final a in all) {
        final s = (a['status']?.toString() ?? 'pending').toLowerCase();
        b[s]?.add(a);
      }
      if (!mounted) return;
      setState(() {
        _bucket = b;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _review(Map<String, dynamic> a, String status) async {
    final note = await showDialog<String?>(
      context: context,
      builder: (ctx) => _NoteDialog(title: status == 'approved' ? 'Approve leave' : 'Reject leave'),
    );
    if (note == null) return;
    final api = ref.read(leaveApiProvider);
    if (api == null) return;
    try {
      await api.reviewLeave(leaveId: a['id'], status: status, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave $status')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Pending (${_bucket['pending']?.length ?? 0})'),
            Tab(text: 'Approved (${_bucket['approved']?.length ?? 0})'),
            Tab(text: 'Rejected (${_bucket['rejected']?.length ?? 0})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _tabList('pending'),
                _tabList('approved'),
                _tabList('rejected'),
              ],
            ),
    );
  }

  Widget _tabList(String key) {
    final items = _bucket[key] ?? [];
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 150),
            Icon(Icons.event_note, size: 64, color: Colors.black26),
            SizedBox(height: 16),
            Center(child: Text('Nothing here.', style: TextStyle(color: Colors.black54))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _tile(items[i], key),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> a, String key) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a['student_name']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${a['student_admission_number'] ?? ''}  •  ${a['parent_name'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text('${a['start_date']} → ${a['end_date']}'),
            const SizedBox(height: 4),
            Text(a['reason']?.toString() ?? ''),
            if (key == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                      label: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () => _review(a, 'rejected'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _review(a, 'approved'),
                    ),
                  ),
                ],
              ),
            ] else if ((a['review_note']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Note: ${a['review_note']}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title});
  final String title;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        maxLines: 3,
        maxLength: 500,
        decoration: const InputDecoration(
          hintText: 'Optional note for parent',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
