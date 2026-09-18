import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/documents_provider.dart';

/// Lets an admin/teacher/coordinator upload a scanned admission form (image
/// or PDF) for automatic OCR extraction instead of typing it in by hand.
/// Branch AND class are selected here, up front -- OCR can extract the
/// child/parent details but can't reliably tell which of the branch's
/// classes a child belongs in, so that's fixed at upload time (same as the
/// manual admission form). Once OCR finishes, the backend applies the result
/// automatically -- no separate "confirm and apply" step in the normal case.
class DocumentUploadScreen extends ConsumerStatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  ConsumerState<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  List<Map<String, dynamic>> _branches = [];
  String? _branchId;
  List<Map<String, dynamic>> _classes = [];
  String? _classId;
  bool _loadingClasses = false;
  bool _loadingBranches = true;
  String? _loadError;

  PlatformFile? _selectedFile;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBranches());
  }

  Future<void> _loadBranches() async {
    final api = ref.read(documentsApiProvider);
    if (api == null) {
      setState(() {
        _loadingBranches = false;
        _loadError = 'You are signed out. Please log in again.';
      });
      return;
    }
    try {
      final branches = await api.listBranchOptions();
      setState(() {
        _branches = branches;
        _branchId = branches.length == 1 ? branches.first['id'] as String : null;
        _loadingBranches = false;
      });
      if (_branchId != null) await _loadClasses(_branchId!);
    } catch (e) {
      setState(() {
        _loadingBranches = false;
        _loadError = 'Failed to load branches: $e';
      });
    }
  }

  Future<void> _loadClasses(String branchId) async {
    final api = ref.read(documentsApiProvider);
    if (api == null) return;
    setState(() {
      _loadingClasses = true;
      _classId = null;
      _classes = [];
    });
    try {
      final classes = await api.listClassOptions(branchId);
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _classId = classes.length == 1 ? classes.first['id'] as String : null;
        _loadingClasses = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingClasses = false);
        _snack('Failed to load classes: $e');
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.single);
    }
  }

  Future<MultipartFile> _buildMultipartFile() async {
    final file = _selectedFile!;
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }
    if (!kIsWeb && file.path != null) {
      return MultipartFile.fromFile(file.path!, filename: file.name);
    }
    throw Exception('Unable to read selected file');
  }

  Future<void> _upload() async {
    if (_branchId == null) {
      _snack('Please select a branch');
      return;
    }
    if (_classId == null) {
      _snack('Please select a class');
      return;
    }
    if (_selectedFile == null) {
      _snack('Please select an admission form image or PDF');
      return;
    }
    final api = ref.read(documentsApiProvider);
    if (api == null) {
      _snack('You are signed out. Please log in again.');
      return;
    }
    setState(() => _uploading = true);
    try {
      final multipart = await _buildMultipartFile();
      await api.uploadDocument(branchId: _branchId!, classId: _classId!, file: multipart);
      if (!mounted) return;
      _snack('Uploaded. The student will be added automatically once OCR finishes.');
      context.pop(true);
    } catch (e) {
      if (mounted) _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Upload Admission Form'), centerTitle: true),
      body: _loadingBranches
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_loadError!)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Upload a photo or scanned PDF of a filled admission form. '
                        'It will be OCR-processed and, if the child and parent details '
                        'come through clearly, added to Admissions automatically. If '
                        'anything is missing or looks like a possible duplicate, it will '
                        'wait here for you to check instead.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _branchId,
                        decoration: const InputDecoration(
                          labelText: 'Branch *',
                          border: OutlineInputBorder(),
                        ),
                        items: _branches
                            .map((b) => DropdownMenuItem<String>(
                                  value: b['id'] as String,
                                  child: Text(b['name'] as String),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _branchId = v);
                          if (v != null) _loadClasses(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _classId,
                        decoration: InputDecoration(
                          labelText: 'Class *',
                          border: const OutlineInputBorder(),
                          helperText: _loadingClasses ? 'Loading classes…' : null,
                        ),
                        items: _classes
                            .map((c) => DropdownMenuItem<String>(
                                  value: c['id'] as String,
                                  child: Text(c['name'] as String),
                                ))
                            .toList(),
                        onChanged: _loadingClasses ? null : (v) => setState(() => _classId = v),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: Text(_selectedFile?.name ?? 'Select image or PDF'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _uploading ? null : _upload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        child: _uploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Upload'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
