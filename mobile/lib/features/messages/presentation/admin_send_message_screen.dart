import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/admin_drawer.dart';

class AdminSendMessageScreen extends ConsumerStatefulWidget {
  const AdminSendMessageScreen({super.key});

  @override
  ConsumerState<AdminSendMessageScreen> createState() =>
      _AdminSendMessageScreenState();
}

class _AdminSendMessageScreenState extends ConsumerState<AdminSendMessageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetType = 'all_staff';
  String? _branchId;
  String? _classId;
  bool _sending = false;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _classes = [];
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta());
  }

  Future<void> _loadMeta() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      final branches = await api.getBranches();
      final classes = await api.getClasses();
      if (mounted) {
        setState(() {
          _branches = branches;
          _classes = classes;
          _loadingMeta = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final api = ref.read(adminApiProvider);
    if (api == null) return;

    final needsBranch = ['branch_staff', 'branch_parents', 'branch_all'].contains(_targetType);
    final needsClass = _targetType == 'grade_teachers';
    if (needsBranch && _branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a branch')),
      );
      return;
    }
    if (needsClass && _classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a grade/class')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final res = await api.sendMessage(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        targetType: _targetType,
        branchId: _branchId,
        classId: _classId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'Sent')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
        title: const Text('Send Message'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _targetType,
                      decoration: const InputDecoration(labelText: 'Send to'),
                      items: const [
                        DropdownMenuItem(value: 'all_staff', child: Text('All Staff')),
                        DropdownMenuItem(value: 'all_parents', child: Text('All Parents')),
                        DropdownMenuItem(value: 'all', child: Text('Everyone (Staff + Parents)')),
                        DropdownMenuItem(value: 'branch_staff', child: Text('Branch Staff Only')),
                        DropdownMenuItem(value: 'branch_parents', child: Text('Branch Parents Only')),
                        DropdownMenuItem(value: 'branch_all', child: Text('Branch (Staff + Parents)')),
                        DropdownMenuItem(value: 'grade_teachers', child: Text('Grade/Class Teachers')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _targetType = v ?? _targetType;
                          if (!['branch_staff', 'branch_parents', 'branch_all'].contains(_targetType)) {
                            _branchId = null;
                          }
                          if (_targetType != 'grade_teachers') _classId = null;
                        });
                      },
                    ),
                    if (['branch_staff', 'branch_parents', 'branch_all'].contains(_targetType)) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _branchId,
                        decoration: const InputDecoration(labelText: 'Branch'),
                        items: _branches
                            .map((b) => DropdownMenuItem(
                                  value: b['id'] as String?,
                                  child: Text(b['name'] as String? ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _branchId = v;
                          _classId = null;
                        }),
                      ),
                    ],
                    if (_targetType == 'grade_teachers') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _classId,
                        decoration: const InputDecoration(labelText: 'Grade/Class'),
                        items: _classes
                            .map((c) => DropdownMenuItem(
                                  value: c['id'] as String?,
                                  child: Text(c['name'] as String? ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _classId = v),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_sending ? 'Sending...' : 'Send Message'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
