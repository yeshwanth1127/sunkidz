import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/chat_provider.dart';
import '../../../core/api/parent_provider.dart';
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
  String? _selectedBranchId;

  /// threadId -> set of branch ids that thread could belong to, resolved
  /// client-side from existing student/admissions data (never from the
  /// thread payload itself, which carries no branch field).
  Map<String, Set<String>> _threadBranchIds = {};

  /// branchId -> display name, collected while resolving the map above.
  Map<String, String> _branchNames = {};

  List<Map<String, String>> get _availableBranches {
    final entries =
        _branchNames.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    return entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  List<Map<String, dynamic>> get _visibleThreads {
    if (_selectedBranchId == null) return _threads;
    return _threads.where((t) {
      final ids = _threadBranchIds[t['id']?.toString()];
      return ids != null && ids.contains(_selectedBranchId);
    }).toList();
  }

  /// Builds the thread -> branch mapping from data the app already has
  /// access to elsewhere (Students screen for admin, "My Children" for
  /// parent). Every chat thread is parent<->staff, never staff<->staff, so:
  /// - admin: other party is always a parent -> resolve via that parent's
  ///   admitted children (student_id directly, or parent_user_id when the
  ///   thread has no student context).
  /// - parent: other party is always staff -> resolve via the thread's own
  ///   student_id against the parent's own children.
  /// - teacher/coordinator/other staff: their visible threads are already
  ///   confined to one branch by backend authority rules, so no branch data
  ///   is fetched and the filter simply stays hidden (unchanged behavior).
  Future<void> _resolveBranches() async {
    final auth = ref.read(authProvider);
    final threadBranches = <String, Set<String>>{};
    final branchNames = <String, String>{};

    if (auth.role == UserRole.admin) {
      final api = ref.read(adminApiProvider);
      if (api == null) return;
      List<Map<String, dynamic>> admissions;
      try {
        admissions = await api.getAdmissions();
      } catch (_) {
        return;
      }
      // Dropdown options must list every branch that exists, not just ones
      // with an admitted student — deriving names from admissions alone
      // silently drops branches with zero (or very few) admissions.
      try {
        final branches = await api.getBranches();
        for (final b in branches) {
          final branchId = b['id']?.toString();
          final branchName = b['name']?.toString();
          if (branchId != null &&
              branchId.isNotEmpty &&
              branchName != null &&
              branchName.isNotEmpty) {
            branchNames[branchId] = branchName;
          }
        }
      } catch (_) {
        // If the branch list can't be fetched, fall back to whatever names
        // the admissions loop below discovers rather than showing nothing.
      }
      final studentBranch = <String, String>{};
      final parentBranches = <String, Set<String>>{};
      for (final s in admissions) {
        final branchId = s['branch_id']?.toString();
        if (branchId == null || branchId.isEmpty) continue;
        final branchName = s['branch_name']?.toString();
        if (branchName != null &&
            branchName.isNotEmpty &&
            !branchNames.containsKey(branchId)) {
          branchNames[branchId] = branchName;
        }
        final studentId = s['id']?.toString();
        if (studentId != null) studentBranch[studentId] = branchId;
        final parentId = s['parent_user_id']?.toString();
        if (parentId != null) {
          parentBranches.putIfAbsent(parentId, () => <String>{}).add(branchId);
        }
      }
      for (final t in _threads) {
        final threadId = t['id']?.toString();
        if (threadId == null) continue;
        final studentId = t['student_id']?.toString();
        final otherId = t['other_user_id']?.toString();
        if (studentId != null && studentBranch.containsKey(studentId)) {
          threadBranches[threadId] = {studentBranch[studentId]!};
        } else if (otherId != null && parentBranches.containsKey(otherId)) {
          threadBranches[threadId] = parentBranches[otherId]!;
        }
      }
    } else if (auth.role == UserRole.parent) {
      final api = ref.read(parentApiProvider);
      if (api == null) return;
      Map<String, dynamic> data;
      try {
        data = await api.getChildren();
      } catch (_) {
        return;
      }
      final children =
          (data['children'] as List? ?? []).cast<Map<String, dynamic>>();
      final studentBranch = <String, String>{};
      final allBranches = <String>{};
      for (final c in children) {
        final branchId = c['branch_id']?.toString();
        if (branchId == null || branchId.isEmpty) continue;
        final branchName = c['branch_name']?.toString();
        if (branchName != null && branchName.isNotEmpty) {
          branchNames[branchId] = branchName;
        }
        final studentId = c['id']?.toString();
        if (studentId != null) studentBranch[studentId] = branchId;
        allBranches.add(branchId);
      }
      for (final t in _threads) {
        final threadId = t['id']?.toString();
        if (threadId == null) continue;
        final studentId = t['student_id']?.toString();
        if (studentId != null && studentBranch.containsKey(studentId)) {
          threadBranches[threadId] = {studentBranch[studentId]!};
        } else if (allBranches.length == 1) {
          // General chat with no student context is only unambiguous when
          // the parent has children in exactly one branch.
          threadBranches[threadId] = {allBranches.first};
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _threadBranchIds = threadBranches;
      _branchNames = branchNames;
    });
  }

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
      await _resolveBranches();
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
    context
        .push('/chat/thread', extra: thread)
        .then((_) => _refresh(silent: true));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final branches = _availableBranches;
    final visibleThreads = _visibleThreads;
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
      body: Column(
        children: [
          if (branches.isNotEmpty) _buildBranchFilter(branches),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child:
                  _loading && _threads.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null && _threads.isEmpty
                      ? _emptyState(_error!, isError: true)
                      : _threads.isEmpty
                      ? _emptyState(
                        'No chats yet.\nTap the button below to start one.',
                      )
                      : visibleThreads.isEmpty
                      ? _emptyState('No chats for this branch.')
                      : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: visibleThreads.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => _threadTile(visibleThreads[i]),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchFilter(List<Map<String, String>> branches) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedBranchId,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.apartment_rounded, size: 18),
            hintText: 'Branch',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Branches')),
            ...branches.map(
              (b) => DropdownMenuItem(
                value: b['id'],
                child: Text(b['name'] ?? '—', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _selectedBranchId = v),
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
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (role != null)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
                      fontWeight:
                          unread > 0 ? FontWeight.w600 : FontWeight.normal,
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
                      color:
                          unread > 0 ? AppColors.accentGreen : Colors.black45,
                      fontWeight:
                          unread > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                const SizedBox(height: 6),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select teacher/admin',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select parent',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
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
              child:
                  _loading
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
                            children:
                                students.isEmpty
                                    ? [
                                      ListTile(
                                        title: const Text(
                                          'Open chat (no student)',
                                        ),
                                        onTap:
                                            () => Navigator.of(
                                              context,
                                            ).pop({'user_id': p['user_id']}),
                                      ),
                                    ]
                                    : [
                                      for (final s in students)
                                        ListTile(
                                          title: Text(
                                            (s as Map)['name']?.toString() ??
                                                '',
                                          ),
                                          subtitle: Text(
                                            s['admission_number']?.toString() ??
                                                '',
                                          ),
                                          onTap:
                                              () => Navigator.of(context).pop({
                                                'user_id': p['user_id'],
                                                'student_id': s['id'],
                                              }),
                                        ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.chat_outlined,
                                          size: 20,
                                        ),
                                        title: const Text(
                                          'General chat (no student)',
                                        ),
                                        onTap:
                                            () => Navigator.of(
                                              context,
                                            ).pop({'user_id': p['user_id']}),
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
