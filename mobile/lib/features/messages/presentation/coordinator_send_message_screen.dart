import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/coordinator_drawer.dart';

class CoordinatorSendMessageScreen extends ConsumerStatefulWidget {
  const CoordinatorSendMessageScreen({super.key});

  @override
  ConsumerState<CoordinatorSendMessageScreen> createState() =>
      _CoordinatorSendMessageScreenState();
}

class _CoordinatorSendMessageScreenState
    extends ConsumerState<CoordinatorSendMessageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetType = 'branch_teachers';
  bool _sending = false;

  // For particular parent search
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Map<String, dynamic>? _selectedParent;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchParents(String query) async {
    if (query.length < 3) return;
    final api = ref.read(coordinatorApiProvider);
    if (api == null) return;

    setState(() => _searching = true);
    try {
      final results = await api.searchParents(query);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final api = ref.read(coordinatorApiProvider);
    if (api == null) return;

    if (_targetType == 'particular_user' && _selectedParent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and select a parent')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final res = await api.sendMessage(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        targetType: _targetType,
        targetUserId: _selectedParent?['id'],
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Send Message',
          style: TextStyle(color: Color(0xFF2D2323), fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
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
                  DropdownMenuItem(
                    value: 'branch_teachers',
                    child: Text('Branch Teachers'),
                  ),
                  DropdownMenuItem(
                    value: 'branch_parents',
                    child: Text('Branch Parents'),
                  ),
                  DropdownMenuItem(
                    value: 'particular_user',
                    child: Text('Particular Parent'),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _targetType = v ?? _targetType;
                    if (_targetType != 'particular_user') {
                      _selectedParent = null;
                      _searchResults = [];
                      _searchController.clear();
                    }
                  });
                },
              ),
              if (_targetType == 'particular_user') ...[
                const SizedBox(height: 16),
                if (_selectedParent != null)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(_selectedParent!['full_name'] ?? ''),
                    subtitle: Text(_selectedParent!['phone'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _selectedParent = null),
                    ),
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  )
                else ...[
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by Student Name',
                      hintText: 'Enter at least 3 characters',
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () => _searchParents(_searchController.text),
                            ),
                    ),
                    onChanged: _searchParents,
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _searchResults.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final p = _searchResults[i];
                          return ListTile(
                            title: Text(p['full_name'] ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (p['students'] != null && (p['students'] as List).isNotEmpty)
                                  Text(
                                    'Student: ${(p['students'] as List).join(", ")}',
                                    style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                                  )
                                else
                                  Text(p['phone'] ?? '', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                _selectedParent = p;
                                _searchResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
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
