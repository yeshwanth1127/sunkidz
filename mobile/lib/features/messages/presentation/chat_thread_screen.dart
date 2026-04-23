import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/chat_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'message_bubble.dart';
import 'message_composer.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.thread});
  final Map<String, dynamic> thread;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 3);
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  String? _lastId;
  Timer? _poll;
  bool _loading = true;
  bool _sending = false;
  bool _creatingLeave = false;
  bool _screenActive = true;

  String get _threadId => widget.thread['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _screenActive = state == AppLifecycleState.resumed;
    if (_screenActive) {
      _poll?.cancel();
      _poll = Timer.periodic(_pollInterval, (_) => _pollNew());
    } else {
      _poll?.cancel();
    }
  }

  Future<void> _initialLoad() async {
    final api = ref.read(chatApiProvider);
    if (api == null) return;
    try {
      final msgs = await api.listMessages(_threadId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs);
        if (_messages.isNotEmpty) _lastId = _messages.last['id']?.toString();
        _loading = false;
      });
      await api.markRead(_threadId);
      _scrollToBottom();
      _poll = Timer.periodic(_pollInterval, (_) => _pollNew());
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pollNew() async {
    if (!_screenActive) return;
    final api = ref.read(chatApiProvider);
    if (api == null) return;
    try {
      final msgs = await api.listMessages(_threadId, afterId: _lastId);
      if (!mounted || msgs.isEmpty) return;
      setState(() {
        _messages.addAll(msgs);
        _lastId = _messages.last['id']?.toString();
      });
      await api.markRead(_threadId);
      _scrollToBottom();
    } catch (_) {
      // Silent poll failure.
    }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    final api = ref.read(chatApiProvider);
    if (api == null) return;
    setState(() => _sending = true);
    final text = body;
    _input.clear();
    try {
      final m = await api.sendMessage(_threadId, text);
      if (!mounted) return;
      setState(() {
        _messages.add(m);
        _lastId = m['id']?.toString();
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _input.text = text;
      final err = e.toString();
      String msg = 'Could not send';
      if (err.contains('429')) msg = 'Too many messages. Slow down.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openLeaveSheet() async {
    if (_creatingLeave) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CreateLeaveFromChatSheet(threadId: _threadId),
      ),
    );
    if (created == true) {
      setState(() => _creatingLeave = true);
      try {
        await _pollNew();
      } finally {
        if (mounted) setState(() => _creatingLeave = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canRequestLeave = auth.role == UserRole.parent && widget.thread['student_id'] != null;
    final otherName = widget.thread['other_user_name']?.toString() ?? 'Chat';
    final role = widget.thread['other_user_role']?.toString();
    final student = widget.thread['student_name']?.toString();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (canRequestLeave)
            IconButton(
              tooltip: 'Request Leave',
              onPressed: _creatingLeave ? null : _openLeaveSheet,
              icon: _creatingLeave
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.event_note_outlined),
            ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(otherName, style: const TextStyle(fontSize: 16)),
            if (role != null || (student != null && student.isNotEmpty))
              Text(
                [
                  if (role != null) role,
                  if (student != null && student.isNotEmpty) 'about $student',
                ].join(' | '),
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No messages yet. Say hi!',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => MessageBubble(message: _messages[i]),
                      ),
          ),
          MessageComposer(controller: _input, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _CreateLeaveFromChatSheet extends ConsumerStatefulWidget {
  const _CreateLeaveFromChatSheet({required this.threadId});

  final String threadId;

  @override
  ConsumerState<_CreateLeaveFromChatSheet> createState() => _CreateLeaveFromChatSheetState();
}

class _CreateLeaveFromChatSheetState extends ConsumerState<_CreateLeaveFromChatSheet> {
  final _reason = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
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
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _start = selected;
        if (_end != null && _end!.isBefore(selected)) _end = selected;
      } else {
        _end = selected;
      }
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final api = ref.read(chatApiProvider);
    if (api == null) return;

    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      _showError('Enter a reason');
      return;
    }
    if (_start == null || _end == null) {
      _showError('Pick start and end dates');
      return;
    }

    setState(() => _saving = true);
    try {
      await api.createLeaveFromThread(
        threadId: widget.threadId,
        reason: reason,
        startDate: _iso(_start!),
        endDate: _iso(_end!),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request sent')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      _showError('Failed to request leave: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _showError(String msg) {
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
            const Text(
              'Request Leave',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('From: ${_start == null ? '-' : _iso(_start!)}'),
                    onPressed: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('To: ${_end == null ? '-' : _iso(_end!)}'),
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
            const SizedBox(height: 6),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_saving ? 'Sending...' : 'Send Leave Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
