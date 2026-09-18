import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../stories/presentation/story_player_screen.dart';
import '../providers/gallery_provider.dart';

/// Supported upload extensions -- kept in sync with the backend
/// `STORY_EXTENSIONS` in `app/services/media_files.py`.
const _imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
const _videoExts = ['mp4', 'mov', 'webm', 'mkv', '3gp'];

/// Client-side "reasonable size" guard. The backend hard cap is larger; this
/// just stops obviously-too-big uploads before they start.
const int _maxUploadBytes = 500 * 1024 * 1024; // 500 MB

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _branchOptions = [];
  bool _loading = true;
  String? _error;

  String? _branchFilter; // null = all branches
  String _mediaFilter = 'all'; // all | image | video

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = ref.read(galleryApiProvider);
    if (api == null) {
      setState(() {
        _loading = false;
        _error = 'You are signed out. Please log in again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = await api.listBranchOptions();
      final items = await api.listItems(
        branchId: _branchFilter,
        mediaType: _mediaFilter == 'all' ? null : _mediaFilter,
      );
      if (!mounted) return;
      setState(() {
        _branchOptions = branches;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _refreshItemsOnly() async {
    final api = ref.read(galleryApiProvider);
    if (api == null) return;
    try {
      final items = await api.listItems(
        branchId: _branchFilter,
        mediaType: _mediaFilter == 'all' ? null : _mediaFilter,
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) _snack(_friendlyError(e));
    }
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      if (e.type == DioExceptionType.connectionError) {
        return 'Could not reach the server. Check your connection.';
      }
    }
    return 'Something went wrong. Pull to refresh.';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _canUpload =>
      canManageGallery(ref.read(authProvider).role) && _branchOptions.isNotEmpty;

  Future<void> _openUpload() async {
    final uploaded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _GalleryUploadSheet(branchOptions: _branchOptions),
    );
    if (uploaded == true) {
      _snack('Uploaded to gallery');
      _refreshItemsOnly();
    }
  }

  Future<void> _openViewer(Map<String, dynamic> item) async {
    final api = ref.read(galleryApiProvider);
    if (api == null) return;
    final id = item['id'].toString();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryPlayerScreen(
          title: (item['title']?.toString().trim().isNotEmpty ?? false)
              ? item['title'].toString()
              : (item['file_name']?.toString() ?? 'Gallery'),
          mediaKind: item['media_type']?.toString() == 'video' ? 'video' : 'image',
          fileUrl: api.fileUrl(id),
          description: item['description']?.toString(),
        ),
      ),
    );
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final titleCtrl =
        TextEditingController(text: item['title']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: item['description']?.toString() ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save != true) return;
    final api = ref.read(galleryApiProvider);
    if (api == null) return;
    try {
      await api.updateItem(
        item['id'].toString(),
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
      );
      _snack('Updated');
      _refreshItemsOnly();
    } catch (e) {
      _snack(_friendlyError(e));
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this item?'),
        content: const Text('The photo/video will be removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final api = ref.read(galleryApiProvider);
    if (api == null) return;
    try {
      await api.deleteItem(item['id'].toString());
      _snack('Deleted');
      _refreshItemsOnly();
    } catch (e) {
      _snack(_friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Gallery'),
      ),
      floatingActionButton: _canUpload
          ? FloatingActionButton.extended(
              onPressed: _openUpload,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Upload'),
            )
          : null,
      body: Column(
        children: [
          _FilterBar(
            branchOptions: _branchOptions,
            branchFilter: _branchFilter,
            mediaFilter: _mediaFilter,
            onBranchChanged: (v) {
              setState(() => _branchFilter = v);
              _refreshItemsOnly();
            },
            onMediaChanged: (v) {
              setState(() => _mediaFilter = v);
              _refreshItemsOnly();
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _MessageState(
        icon: Icons.error_outline_rounded,
        title: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            const _MessageState(
              icon: Icons.photo_library_outlined,
              title: 'No photos or videos yet',
              subtitle: 'Uploads from staff will show up here.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          return _GalleryTile(
            item: item,
            thumbUrl: ref.read(galleryApiProvider)?.fileUrl(item['id'].toString()),
            onTap: () => _openViewer(item),
            onEdit: item['can_manage'] == true ? () => _editItem(item) : null,
            onDelete: item['can_manage'] == true ? () => _deleteItem(item) : null,
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.branchOptions,
    required this.branchFilter,
    required this.mediaFilter,
    required this.onBranchChanged,
    required this.onMediaChanged,
  });

  final List<Map<String, dynamic>> branchOptions;
  final String? branchFilter;
  final String mediaFilter;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<String> onMediaChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          if (branchOptions.length > 1)
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: branchFilter,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All branches')),
                  ...branchOptions.map(
                    (b) => DropdownMenuItem(
                      value: b['id'].toString(),
                      child: Text(b['name']?.toString() ?? ''),
                    ),
                  ),
                ],
                onChanged: onBranchChanged,
              ),
            ),
          if (branchOptions.length > 1) const SizedBox(width: 10),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'image', icon: Icon(Icons.image_outlined)),
              ButtonSegment(value: 'video', icon: Icon(Icons.videocam_outlined)),
            ],
            selected: {mediaFilter},
            onSelectionChanged: (s) => onMediaChanged(s.first),
          ),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.item,
    required this.thumbUrl,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Map<String, dynamic> item;
  final String? thumbUrl;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isVideo = item['media_type']?.toString() == 'video';
    final title = item['title']?.toString().trim() ?? '';
    final uploader = item['uploader_name']?.toString() ?? '';
    final branch = item['branch_name']?.toString() ?? '';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isVideo || thumbUrl == null)
                    Container(
                      color: Colors.black87,
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: thumbUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey.shade200),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isVideo ? 'VIDEO' : 'PHOTO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: PopupMenuButton<String>(
                        icon: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.more_vert,
                              color: Colors.white, size: 16),
                        ),
                        onSelected: (v) {
                          if (v == 'edit') onEdit?.call();
                          if (v == 'delete') onDelete?.call();
                        },
                        itemBuilder: (_) => [
                          if (onEdit != null)
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit details')),
                          if (onDelete != null)
                            const PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isNotEmpty ? title : (isVideo ? 'Video' : 'Photo'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [branch, uploader].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _GalleryUploadSheet extends ConsumerStatefulWidget {
  const _GalleryUploadSheet({required this.branchOptions});

  final List<Map<String, dynamic>> branchOptions;

  @override
  ConsumerState<_GalleryUploadSheet> createState() => _GalleryUploadSheetState();
}

class _GalleryUploadSheetState extends ConsumerState<_GalleryUploadSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _branchId;
  PlatformFile? _file;
  bool _uploading = false;
  double _progress = 0;
  String? _formError;

  @override
  void initState() {
    super.initState();
    if (widget.branchOptions.length == 1) {
      _branchId = widget.branchOptions.single['id'].toString();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [..._imageExts, ..._videoExts],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final ext = (f.extension ?? '').toLowerCase();
    if (!_imageExts.contains(ext) && !_videoExts.contains(ext)) {
      setState(() => _formError = 'Unsupported file type: .$ext');
      return;
    }
    if (f.size > _maxUploadBytes) {
      setState(() => _formError =
          'File is too large (${(f.size / (1024 * 1024)).toStringAsFixed(0)} MB). Max 500 MB.');
      return;
    }
    setState(() {
      _file = f;
      _formError = null;
    });
  }

  Future<void> _submit() async {
    final api = ref.read(galleryApiProvider);
    if (api == null) return;
    if (_branchId == null) {
      setState(() => _formError = 'Choose a branch');
      return;
    }
    if (_file == null) {
      setState(() => _formError = 'Pick a photo or video');
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0;
      _formError = null;
    });

    try {
      MultipartFile multipart;
      if (_file!.bytes != null) {
        multipart = MultipartFile.fromBytes(_file!.bytes!, filename: _file!.name);
      } else if (!kIsWeb && _file!.path != null) {
        multipart =
            await MultipartFile.fromFile(_file!.path!, filename: _file!.name);
      } else {
        throw Exception('Could not read the selected file');
      }

      await api.uploadItem(
        branchId: _branchId!,
        title: _title.text.trim(),
        description: _description.text.trim(),
        file: multipart,
        onProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = sent / total);
          }
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      String msg = 'Upload failed. Please try again.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) msg = data['detail'].toString();
      }
      setState(() {
        _uploading = false;
        _formError = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isVideo = _file != null &&
        _videoExts.contains((_file!.extension ?? '').toLowerCase());

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Upload to gallery',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  onPressed:
                      _uploading ? null : () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.branchOptions.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _branchId,
                decoration: const InputDecoration(
                  labelText: 'Branch *',
                  border: OutlineInputBorder(),
                ),
                items: widget.branchOptions
                    .map((b) => DropdownMenuItem(
                          value: b['id'].toString(),
                          child: Text(b['name']?.toString() ?? ''),
                        ))
                    .toList(),
                onChanged:
                    _uploading ? null : (v) => setState(() => _branchId = v),
              )
            else
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  border: OutlineInputBorder(),
                ),
                child: Text(widget.branchOptions.isEmpty
                    ? '—'
                    : widget.branchOptions.single['name']?.toString() ?? '—'),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pick,
              icon: Icon(isVideo ? Icons.videocam_rounded : Icons.upload_file),
              label: Text(
                _file?.name ?? 'Pick photo or video',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              enabled: !_uploading,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              enabled: !_uploading,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_formError != null) ...[
              const SizedBox(height: 12),
              Text(_formError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            if (_uploading) ...[
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 6),
              Text(
                _progress == 0
                    ? 'Starting upload…'
                    : 'Uploading ${(_progress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ] else
              FilledButton.icon(
                onPressed: _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Upload'),
              ),
          ],
        ),
      ),
    );
  }
}
