import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/chat_provider.dart';
import '../../../core/api/parent_provider.dart';
import '../../../core/theme/app_theme.dart';

class ParentLeaveScreen extends ConsumerStatefulWidget {
  const ParentLeaveScreen({super.key});

  @override
  ConsumerState<ParentLeaveScreen> createState() => _ParentLeaveScreenState();
}

class _ParentLeaveScreenState extends ConsumerState<ParentLeaveScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  List<Map<String, dynamic>> _children = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadList(), _loadChildren()]);
  }

  Future<void> _loadList() async {
    final api = ref.read(leaveApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final items = await api.listLeaves();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadChildren() async {
    final api = ref.read(parentApiProvider);
    if (api == null) return;
    try {
      final data = await api.getChildren();
      final list = (data['children'] as List?) ?? (data['students'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _children = List<Map<String, dynamic>>.from(list);
      });
    } catch (_) {
      // keep empty; user can still select from selectedChild
    }
  }

  Future<void> _openCreate() async {
    Map<String, dynamic>? selected = ref.read(selectedChildProvider);
    if (selected == null && _children.isNotEmpty) {
      selected = _children.first;
    }
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _CreateLeaveForm(children: _children, initialChild: selected),
      ),
    );
    if (res == true) _loadList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply Leave'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadList,
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 150),
                      Icon(Icons.event_note, size: 64, color: Colors.black26),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No leave requests yet.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _tile(_items[i]),
                  ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> a) {
    final status = (a['status']?.toString() ?? 'pending').toLowerCase();
    final (color, label) = switch (status) {
      'approved' => (AppColors.accentGreen, 'Approved'),
      'rejected' => (Colors.redAccent, 'Rejected'),
      _ => (Colors.orange, 'Pending'),
    };
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    a['student_name']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${a['start_date']} → ${a['end_date']}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(a['reason']?.toString() ?? ''),
            if ((a['review_note']?.toString() ?? '').isNotEmpty) ...[
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

class _CreateLeaveForm extends ConsumerStatefulWidget {
  const _CreateLeaveForm({required this.children, this.initialChild});
  final List<Map<String, dynamic>> children;
  final Map<String, dynamic>? initialChild;

  @override
  ConsumerState<_CreateLeaveForm> createState() => _CreateLeaveFormState();
}

class _CreateLeaveFormState extends ConsumerState<_CreateLeaveForm> {
  Map<String, dynamic>? _selected;
  final _reason = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialChild ?? (widget.children.isNotEmpty ? widget.children.first : null);
    final today = DateTime.now();
    _start = today;
    _end = today;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final initial = start ? (_start ?? DateTime.now()) : (_end ?? DateTime.now());
    final res = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (res == null) return;
    setState(() {
      if (start) {
        _start = res;
        if (_end != null && _end!.isBefore(res)) _end = res;
      } else {
        _end = res;
      }
    });
  }

  Future<void> _submit() async {
    final api = ref.read(leaveApiProvider);
    if (api == null) return;
    final sid = _selected?['id']?.toString();
    if (sid == null) {
      _showErr('Select a child');
      return;
    }
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      _showErr('Enter a reason');
      return;
    }
    if (_start == null || _end == null) {
      _showErr('Pick start and end dates');
      return;
    }
    setState(() => _saving = true);
    try {
      await api.createLeave(
        studentId: sid,
        reason: reason,
        startDate: _iso(_start!),
        endDate: _iso(_end!),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showErr('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('New leave request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (widget.children.length > 1)
              DropdownButtonFormField<Map<String, dynamic>>(
                isExpanded: true,
                initialValue: _selected,
                decoration: const InputDecoration(labelText: 'Child'),
                items: [
                  for (final c in widget.children)
                    DropdownMenuItem(
                      value: c,
                      child: Text(c['name']?.toString() ?? ''),
                    ),
                ],
                onChanged: (v) => setState(() => _selected = v),
              )
            else if (_selected != null)
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Child'),
                child: Text(_selected!['name']?.toString() ?? ''),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('From: ${_start == null ? '—' : _iso(_start!)}'),
                    onPressed: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('To: ${_end == null ? '—' : _iso(_end!)}'),
                    onPressed: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
