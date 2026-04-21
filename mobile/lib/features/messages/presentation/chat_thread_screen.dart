import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/chat_provider.dart';
import '../../../core/theme/app_theme.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.thread});
  final Map<String, dynamic> thread;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  String? _lastId;
  Timer? _poll;
  bool _loading = true;
  bool _sending = false;
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
      _poll = Timer.periodic(const Duration(seconds: 10), (_) => _pollNew());
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
      _poll = Timer.periodic(const Duration(seconds: 10), (_) => _pollNew());
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
      // silent poll failure
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
    final otherName = widget.thread['other_user_name']?.toString() ?? 'Chat';
    final role = widget.thread['other_user_role']?.toString();
    final student = widget.thread['student_name']?.toString();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
                ].join(' · '),
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
                        itemBuilder: (_, i) => _bubble(_messages[i]),
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 2000,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _sending ? null : _send,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final mine = (m['is_mine'] as bool?) ?? false;
    final body = m['body']?.toString() ?? '';
    final when = m['created_at']?.toString();
    final time = when != null ? _fmtTime(when) : '';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
          border: mine ? null : Border.all(color: Colors.black12),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 2),
            bottomRight: Radius.circular(mine ? 2 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              body,
              style: TextStyle(color: mine ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(
                fontSize: 9,
                color: mine ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
