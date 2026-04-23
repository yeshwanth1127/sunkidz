import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/chat_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class ChatThreadsScreen extends ConsumerStatefulWidget {
  const ChatThreadsScreen({super.key});

  @override
  ConsumerState<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends ConsumerState<ChatThreadsScreen> {
  static const Duration _pollInterval = Duration(seconds: 6);
  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(_pollInterval, (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    final api = ref.read(chatApiProvider);
    if (api == null) return;
    if (!silent) setState(() => _loading = true);
    try {
      final data = await api.listThreads();
      if (!mounted) return;
      setState(() {
        _threads = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load chats';
        _loading = false;
      });
    }
  }

  Future<void> _startNewChat() async {
    final auth = ref.read(authProvider);
    final api = ref.read(chatApiProvider);
    if (api == null) return;

    if (auth.role == UserRole.parent) {
      final staff = await _pickStaff(api);
      if (staff == null) return;
      try {
        final t = await api.startThread(otherUserId: staff['user_id']);
        if (!mounted) return;
        _openThread(t);
      } catch (e) {
        _showError('Could not start chat: $e');
      }
    } else {
      final picked = await _pickParent(api);
      if (picked == null) return;
      try {
        final t = await api.startThread(
          otherUserId: picked['user_id'],
          studentId: picked['student_id'],
        );
        if (!mounted) return;
        _openThread(t);
      } catch (e) {
        _showError('Could not start chat: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> _pickStaff(dynamic api) async {
    List<Map<String, dynamic>> staffList = [];
    try {
      staffList = await api.eligibleStaffForParent();
    } catch (_) {
      _showError('Could not load contacts');
      return null;
    }
    if (!mounted) return null;
    if (staffList.isEmpty) {
      _showError('No teachers/admin available to message yet. Contact admin.');
      return null;
    }
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _StaffPicker(staff: staffList),
    );
  }

  Future<Map<String, dynamic>?> _pickParent(dynamic api) async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ParentPicker(api: api),
    );
  }

  void _openThread(Map<String, dynamic> thread) {
    context.push('/chat/thread', extra: thread).then((_) => _refresh(silent: true));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewChat,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading && _threads.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _threads.isEmpty
                ? _emptyState(_error!, isError: true)
                : _threads.isEmpty
                    ? _emptyState('No chats yet.\nTap the button below to start one.')
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _threads.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => _threadTile(_threads[i]),
                      ),
      ),
    );
  }

  Widget _emptyState(String msg, {bool isError = false}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          isError ? Icons.error_outline : Icons.chat_bubble_outline,
          size: 64,
          color: isError ? Colors.redAccent : Colors.black26,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _threadTile(Map<String, dynamic> t) {
    final unread = (t['unread_count'] as int? ?? 0);
    final name = t['other_user_name']?.toString() ?? 'Unknown';
    final role = t['other_user_role']?.toString();
    final last = t['last_message']?.toString() ?? '';
    final student = t['student_name']?.toString();
    final when = t['last_message_at']?.toString();
    String subtitle = last;
    if (student != null && student.isNotEmpty) {
      subtitle = '($student) $last';
    }

    return InkWell(
      onTap: () => _openThread(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (role != null)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.pastelBlue.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread > 0 ? Colors.black87 : Colors.black54,
                      fontSize: 14,
                      fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (when != null)
                  Text(
                    _fmtTime(when),
                    style: TextStyle(
                      fontSize: 11,
                      color: unread > 0 ? AppColors.accentGreen : Colors.black45,
                      fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                const SizedBox(height: 6),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}

class _StaffPicker extends StatelessWidget {
  const _StaffPicker({required this.staff});
  final List<Map<String, dynamic>> staff;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select teacher/admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: staff.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = staff[i];
                  return ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(s['full_name']?.toString() ?? ''),
                    subtitle: Text(s['role']?.toString() ?? ''),
                    onTap: () => Navigator.of(context).pop(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentPicker extends StatefulWidget {
  const _ParentPicker({required this.api});
  final dynamic api;

  @override
  State<_ParentPicker> createState() => _ParentPickerState();
}

class _ParentPickerState extends State<_ParentPicker> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _parents = [];
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.eligibleParentsForStaff(query: _ctrl.text);
      if (!mounted) return;
      setState(() {
        _parents = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _parents = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select parent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by name or phone',
                  isDense: true,
                ),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), _load);
                },
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _parents.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No matching parents')),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _parents.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = _parents[i];
                            final students = (p['students'] as List?) ?? [];
                            return ExpansionTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(p['full_name']?.toString() ?? ''),
                              subtitle: Text(p['phone']?.toString() ?? ''),
                              children: students.isEmpty
                                  ? [
                                      ListTile(
                                        title: const Text('Open chat (no student)'),
                                        onTap: () => Navigator.of(context).pop({
                                          'user_id': p['user_id'],
                                        }),
                                      ),
                                    ]
                                  : [
                                      for (final s in students)
                                        ListTile(
                                          title: Text((s as Map)['name']?.toString() ?? ''),
                                          subtitle: Text(s['admission_number']?.toString() ?? ''),
                                          onTap: () => Navigator.of(context).pop({
                                            'user_id': p['user_id'],
                                            'student_id': s['id'],
                                          }),
                                        ),
                                      ListTile(
                                        leading: const Icon(Icons.chat_outlined, size: 20),
                                        title: const Text('General chat (no student)'),
                                        onTap: () => Navigator.of(context).pop({
                                          'user_id': p['user_id'],
                                        }),
                                      ),
                                    ],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
