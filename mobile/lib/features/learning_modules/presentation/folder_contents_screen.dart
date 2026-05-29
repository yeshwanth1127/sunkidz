import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../data/learning_modules_provider.dart';
import 'upload_content_dialog.dart';

class FolderContentsScreen extends ConsumerStatefulWidget {
  final String folderId;
  final String folderName;

  const FolderContentsScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  ConsumerState<FolderContentsScreen> createState() => _FolderContentsScreenState();
}

class _FolderContentsScreenState extends ConsumerState<FolderContentsScreen> {
  List<Map<String, dynamic>> _contents = [];
  bool _loading = true;
  String? _error;

  bool get _isAdmin => ref.read(authProvider).role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _loadContents();
  }

  Future<void> _loadContents() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      final contents = await service.getFolderContents(widget.folderId);
      setState(() => _contents = contents);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteContent(String contentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Content'),
        content: const Text('Remove this item from the folder?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) return;
      await service.deleteFolderContent(contentId);
      _loadContents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
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
          onPressed: () => context.canPop() ? context.pop() : context.go('/learning-modules'),
        ),
        title: Text(
          widget.folderName,
          style: const TextStyle(
            color: Color(0xFF2D2323),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              backgroundColor: Colors.orange,
              onPressed: () => showDialog(
                context: context,
                builder: (_) => UploadContentDialog(
                  folderId: widget.folderId,
                  onUploaded: _loadContents,
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  color: Colors.orange,
                  onRefresh: _loadContents,
                  child: _contents.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No content yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (_isAdmin) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap + to upload a video or document',
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
                          itemCount: _contents.length,
                          itemBuilder: (context, index) {
                            final item = _contents[index];
                            final isVideo = item['content_type'] == 'video';
                            return _ContentTile(
                              item: item,
                              isVideo: isVideo,
                              isAdmin: _isAdmin,
                              onDelete: () => _deleteContent(item['id'] as String),
                              onPlay: isVideo
                                  ? () => context.push(
                                        '/learning-modules/video/${item['id']}',
                                        extra: {
                                          'title': item['title'] ?? '',
                                          'file_path': item['file_path'] ?? '',
                                        },
                                      )
                                  : null,
                            );
                          },
                        ),
                ),
    );
  }
}

class _ContentTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isVideo;
  final bool isAdmin;
  final VoidCallback onDelete;
  final VoidCallback? onPlay;

  const _ContentTile({
    required this.item,
    required this.isVideo,
    required this.isAdmin,
    required this.onDelete,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? 'Untitled';
    final description = item['description'] as String?;
    final fileName = item['file_name'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isVideo ? Colors.orange.shade100 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                isVideo ? Icons.play_circle_outline : Icons.description_outlined,
                color: isVideo ? Colors.orange.shade600 : Colors.blue.shade600,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (description != null && description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    fileName,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isVideo && onPlay != null)
              IconButton(
                icon: Icon(Icons.play_circle_fill, color: Colors.orange.shade600, size: 28),
                onPressed: onPlay,
              ),
            if (isAdmin)
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
