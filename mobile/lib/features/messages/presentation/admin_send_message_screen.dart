import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/theme/app_theme.dart';

class AdminSendMessageScreen extends ConsumerStatefulWidget {
  const AdminSendMessageScreen({super.key});

  @override
  ConsumerState<AdminSendMessageScreen> createState() =>
      _AdminSendMessageScreenState();
}

class _AdminSendMessageScreenState
    extends ConsumerState<AdminSendMessageScreen> {
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

  // For particular student search
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Map<String, dynamic>? _selectedStudent;

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchParents(String query) async {
    if (query.trim().length < 3) {
      if (mounted) {
        setState(() {
          _searching = false;
          _searchResults = [];
        });
      }
      return;
    }
    setState(() => _searching = true);
    try {
      final api = ref.read(adminApiProvider);
      if (api == null) return;
      final results = await api.searchStudents(query.trim());
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final api = ref.read(adminApiProvider);
    if (api == null) return;

    final needsBranch = [
      'branch_staff',
      'branch_parents',
      'branch_all',
    ].contains(_targetType);
    final needsClass = _targetType == 'grade_teachers';
    final needsParent = _targetType == 'particular_user';

    if (needsBranch && _branchId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a branch')));
      return;
    }
    if (needsClass && _classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a grade/class')),
      );
      return;
    }
    if (needsParent && _selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and select a student')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final res =
          needsParent
              ? await api.sendMessage(
                title: _titleController.text.trim(),
                message: _messageController.text.trim(),
                targetType: 'particular_user',
                targetUserId: _selectedStudent!['parent_user_id']?.toString(),
                targetStudentId: _selectedStudent!['id'].toString(),
              )
              : await api.sendMessage(
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
        String errorMsg = 'Failed to send message';
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map && data['detail'] != null) {
            errorMsg = data['detail'].toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 5),
          ),
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
          style: TextStyle(
            color: Color(0xFF2D2323),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body:
          _loadingMeta
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
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Send to'),
                        items: const [
                          DropdownMenuItem(
                            value: 'all_staff',
                            child: Text('All Staff'),
                          ),
                          DropdownMenuItem(
                            value: 'all_parents',
                            child: Text('All Parents'),
                          ),
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Everyone (Staff + Parents)'),
                          ),
                          DropdownMenuItem(
                            value: 'branch_staff',
                            child: Text('Branch Staff Only'),
                          ),
                          DropdownMenuItem(
                            value: 'branch_parents',
                            child: Text('Branch Parents Only'),
                          ),
                          DropdownMenuItem(
                            value: 'branch_all',
                            child: Text('Branch (Staff + Parents)'),
                          ),
                          DropdownMenuItem(
                            value: 'grade_teachers',
                            child: Text('Grade/Class Teachers'),
                          ),
                          DropdownMenuItem(
                            value: 'particular_user',
                            child: Text('Particular Parent'),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _targetType = v ?? _targetType;
                            if (![
                              'branch_staff',
                              'branch_parents',
                              'branch_all',
                            ].contains(_targetType)) {
                              _branchId = null;
                            }
                            if (_targetType != 'grade_teachers')
                              _classId = null;
                            if (_targetType != 'particular_user') {
                              _selectedStudent = null;
                              _searchResults = [];
                              _searchController.clear();
                            }
                          });
                        },
                      ),
                      if (_targetType == 'particular_user') ...[
                        const SizedBox(height: 16),
                        if (_selectedStudent != null)
                          ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(_selectedStudent!['name'] ?? ''),
                            subtitle: Text(
                              '${_selectedStudent!['admission_number'] ?? ''}${(_selectedStudent!['parent_name'] ?? '').toString().isNotEmpty ? ' • ${_selectedStudent!['parent_name']}' : ''}${(_selectedStudent!['parent_contact'] ?? '').toString().isNotEmpty ? ' • ${_selectedStudent!['parent_contact']}' : ''}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed:
                                  () => setState(() => _selectedStudent = null),
                            ),
                            tileColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )
                        else ...[
                          TextFormField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search by Student Name',
                              hintText: 'Student name, parent name, or admission no',
                              suffixIcon:
                                  _searching
                                      ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : IconButton(
                                        icon: const Icon(Icons.search),
                                        onPressed:
                                            () => _searchParents(
                                              _searchController.text,
                                            ),
                                      ),
                            ),
                            onChanged: _searchParents,
                          ),
                          if (!_searching &&
                              _searchController.text.trim().length >= 3 &&
                              _searchResults.isEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'No parents found. Try full student name, parent name, or phone.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          if (_searchResults.isNotEmpty)
                            Material(
                              color: Colors.white,
                              elevation: 2,
                              shadowColor: Colors.black.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              clipBehavior: Clip.antiAlias,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 260,
                                ),
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true, // Important for ListView in Column
                                  itemCount: _searchResults.length,
                                  separatorBuilder:
                                      (ctx, i) => const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final s = _searchResults[i];
                                    return ListTile(
                                      title: Text(s['name'] ?? ''),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${s['admission_number'] ?? ''}${(s['parent_name'] ?? '').toString().isNotEmpty ? ' • ${s['parent_name']}' : ''}${(s['parent_contact'] ?? '').toString().isNotEmpty ? ' • ${s['parent_contact']}' : ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedStudent = s;
                                          _searchResults = [];
                                          _searchController.clear();
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ],
                      if ([
                        'branch_staff',
                        'branch_parents',
                        'branch_all',
                      ].contains(_targetType)) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _branchId,
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                          ),
                          items:
                              _branches
                                  .map(
                                    (b) => DropdownMenuItem(
                                      value: b['id'] as String?,
                                      child: Text(b['name'] as String? ?? ''),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            setState(() {
                              _branchId = v;
                              _classId = null;
                              _selectedStudent = null;
                              _searchResults = [];
                              _searchController.clear();
                            });
                          },
                        ),
                      ],
                      if (_targetType == 'grade_teachers') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _classId,
                          decoration: const InputDecoration(
                            labelText: 'Grade/Class',
                          ),
                          items:
                              _classes
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c['id'] as String?,
                                      child: Text(c['name'] as String? ?? ''),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            setState(() {
                              _classId = v;
                              _selectedStudent = null;
                              _searchResults = [];
                              _searchController.clear();
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
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
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon:
                            _sending
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
