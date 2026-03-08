import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../dashboard/data/teacher_dashboard_provider.dart';
import '../providers/syllabus_provider.dart';

class GalleryUploadScreen extends ConsumerStatefulWidget {
  const GalleryUploadScreen({super.key});

  @override
  ConsumerState<GalleryUploadScreen> createState() => _GalleryUploadScreenState();
}

class _GalleryUploadScreenState extends ConsumerState<GalleryUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedClassId;
  DateTime _uploadDate = DateTime.now();
  PlatformFile? _selectedFile;
  bool _uploading = false;
  bool _uploadToAllGrades = false;

  List<Map<String, dynamic>> _classes = [];
  bool _loadingClasses = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final auth = ref.read(authProvider);
    final classes = <Map<String, dynamic>>[];

    try {
      if (auth.role == UserRole.admin) {
        final api = ref.read(adminApiProvider);
        if (api == null) {
          setState(() => _loadingClasses = false);
          return;
        }
        final branches = await api.getBranches();
        for (final branch in branches) {
          if (branch['classes'] != null) {
            for (final cls in branch['classes']) {
              classes.add({'id': cls['id'], 'name': '${cls['name']} - ${branch['name']}'});
            }
          }
        }
      } else if (auth.role == UserRole.coordinator) {
        final api = ref.read(coordinatorApiProvider);
        if (api == null) {
          setState(() => _loadingClasses = false);
          return;
        }
        final dashboard = await api.getDashboard();
        final branchClasses = dashboard['classes'] as List? ?? [];
        final branchName = dashboard['branch_name'] ?? '';
        
        // Add "All Grades" option for coordinators
        classes.add({'id': 'all_grades', 'name': 'All Grades'});
        
        for (final cls in branchClasses) {
          classes.add({'id': cls['id'], 'name': '${cls['name']} - $branchName'});
        }
      } else if (auth.role == UserRole.teacher) {
        final dashboard = await ref.read(teacherDashboardDataProvider.future);
        final classId = dashboard?.classId;
        final className = dashboard?.className;
        if (classId != null && className != null) {
          classes.add({'id': classId, 'name': '$className - ${dashboard?.branchName ?? ''}'});
        }
      }

      setState(() {
        _classes = classes;
        _loadingClasses = false;
      });
    } catch (_) {
      setState(() => _loadingClasses = false);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.single);
    }
  }

  Future<MultipartFile> _buildMultipartFile() async {
    if (_selectedFile == null) {
      throw Exception('Please select an image');
    }

    if (_selectedFile!.bytes != null) {
      return MultipartFile.fromBytes(_selectedFile!.bytes!, filename: _selectedFile!.name);
    }

    if (!kIsWeb && _selectedFile!.path != null) {
      return MultipartFile.fromFile(_selectedFile!.path!, filename: _selectedFile!.name);
    }

    throw Exception('Unable to read selected image');
  }

  Future<void> _uploadGalleryImage() async {
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a class')));
      return;
    }
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _uploading = true);
    try {
      final service = ref.read(syllabusServiceProvider);
      
      if (_selectedClassId == 'all_grades') {
        // Upload to all classes for coordinators
        final classIds = _classes
            .where((cls) => cls['id'] != 'all_grades')
            .map((cls) => cls['id'] as String)
            .toList();
        
        for (final classId in classIds) {
          final file = await _buildMultipartFile();
          await service.uploadGalleryImage(
            classId: classId,
            uploadDate: _uploadDate,
            title: _titleController.text,
            description: _descriptionController.text,
            file: file,
          );
        }
      } else {
        // Upload to single class
        final file = await _buildMultipartFile();
        await service.uploadGalleryImage(
          classId: _selectedClassId!,
          uploadDate: _uploadDate,
          title: _titleController.text,
          description: _descriptionController.text,
          file: file,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gallery image uploaded successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(title: const Text('Upload Gallery Image')),
      body: _loadingClasses
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Select Class *',
                        border: OutlineInputBorder(),
                      ),
                      items: _classes
                          .map((cls) => DropdownMenuItem<String>(
                                value: cls['id'] as String,
                                child: Text(cls['name'] as String),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedClassId = value),
                      validator: (value) => value == null ? 'Please select a class' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_selectedFile?.name ?? 'Select Image *'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _uploading ? null : _uploadGalleryImage,
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(_uploading ? 'Uploading...' : 'Upload to Gallery'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
