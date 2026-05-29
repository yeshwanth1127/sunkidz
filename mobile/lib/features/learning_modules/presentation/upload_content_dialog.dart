import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/learning_modules_provider.dart';

class UploadContentDialog extends ConsumerStatefulWidget {
  final String folderId;
  final VoidCallback onUploaded;

  const UploadContentDialog({
    super.key,
    required this.folderId,
    required this.onUploaded,
  });

  @override
  ConsumerState<UploadContentDialog> createState() => _UploadContentDialogState();
}

class _UploadContentDialogState extends ConsumerState<UploadContentDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  PlatformFile? _pickedFile;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _pickedFile = file;
        if (_titleCtrl.text.isEmpty) {
          final dot = file.name.lastIndexOf('.');
          _titleCtrl.text = dot > 0 ? file.name.substring(0, dot) : file.name;
        }
      });
    }
  }

  Future<void> _upload() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a title');
      return;
    }
    if (_pickedFile == null) {
      setState(() => _error = 'Please select a file');
      return;
    }
    setState(() { _uploading = true; _error = null; });
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      await service.uploadFolderContent(widget.folderId, _pickedFile!, title, desc);
      widget.onUploaded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _uploading = false; _error = e.toString(); });
    }
  }

  IconData _fileIcon(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    if ({'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'}.contains(ext)) return Icons.videocam_outlined;
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if ({'doc', 'docx'}.contains(ext)) return Icons.description_outlined;
    if ({'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(ext)) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Content', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickFile,
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text(
                _pickedFile?.name ?? 'Pick file (video or document)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_pickedFile != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(_fileIcon(_pickedFile!.name), size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _pickedFile!.name,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _uploading ? null : _upload,
          style: FilledButton.styleFrom(backgroundColor: Colors.orange),
          child: _uploading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Upload'),
        ),
      ],
    );
  }
}
