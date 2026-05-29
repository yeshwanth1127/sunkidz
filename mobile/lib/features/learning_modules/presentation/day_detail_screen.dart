import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../data/learning_modules_provider.dart';
import 'create_folder_dialog.dart';

class DayDetailScreen extends ConsumerStatefulWidget {
  final String classId;
  final int schoolDay;
  final String date;
  final String academicYearStart;

  const DayDetailScreen({
    super.key,
    required this.classId,
    required this.schoolDay,
    required this.date,
    required this.academicYearStart,
  });

  @override
  ConsumerState<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends ConsumerState<DayDetailScreen> {
  List<Map<String, dynamic>> _folders = [];
  bool _loading = true;
  String? _error;

  bool get _isAdmin => ref.read(authProvider).role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      final folders = await service.getDayFolders(
        widget.classId,
        widget.schoolDay,
        widget.academicYearStart,
      );
      setState(() => _folders = folders);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _renameFolder(String folderId, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Subject', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Subject name', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == currentName || !mounted) return;
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) return;
      await service.renameDayFolder(folderId, newName);
      _loadFolders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder'),
        content: const Text('Delete this folder and all its contents?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) return;
      await service.deleteDayFolder(folderId);
      _loadFolders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) { return raw; }
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
          onPressed: () => context.canPop() ? context.pop() : context.go('/learning-modules'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Day ${widget.schoolDay}',
              style: const TextStyle(
                color: Color(0xFF2D2323),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              _formatDate(widget.date),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              backgroundColor: Colors.orange,
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CreateFolderDialog(
                  classId: widget.classId,
                  schoolDay: widget.schoolDay,
                  academicYearStart: widget.academicYearStart,
                  onCreated: _loadFolders,
                ),
              ),
              child: const Icon(Icons.create_new_folder_outlined),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  color: Colors.orange,
                  onRefresh: _loadFolders,
                  child: _folders.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No subjects yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (_isAdmin) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap + to create a subject',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _folders.length,
                          itemBuilder: (context, index) {
                            final folder = _folders[index];
                            final name = folder['name'] as String? ?? 'Folder';
                            final contentCount = folder['content_count'] as int? ?? 0;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              color: Colors.white,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.folder_rounded,
                                    color: Colors.orange.shade600,
                                    size: 26,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                subtitle: Text(
                                  contentCount == 1 ? '1 item' : '$contentCount items',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isAdmin) ...[
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, color: Colors.grey.shade500, size: 20),
                                        onPressed: () => _renameFolder(folder['id'] as String, name),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
                                        onPressed: () => _deleteFolder(folder['id'] as String),
                                      ),
                                    ],
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                                onTap: () => context.push(
                                  '/learning-modules/folder/${folder['id']}',
                                  extra: {'folderName': name},
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
