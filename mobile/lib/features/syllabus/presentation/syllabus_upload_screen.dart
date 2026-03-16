import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../dashboard/data/teacher_dashboard_provider.dart';
import '../providers/syllabus_provider.dart';

class SyllabusUploadScreen extends ConsumerStatefulWidget {
  const SyllabusUploadScreen({super.key});

  @override
  ConsumerState<SyllabusUploadScreen> createState() => _SyllabusUploadScreenState();
}

class _SyllabusUploadScreenState extends ConsumerState<SyllabusUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedClassId;
  String? _selectedClassName;
  bool _uploadForAllBranches = false;
  int _schoolDay = 1;
  PlatformFile? _selectedFile;
  String? _selectedFileName;
  bool _uploading = false;

  List<Map<String, dynamic>> _classes = [];
  List<String> _gradeNames = [];
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
              classes.add({
                'id': cls['id'],
                'name': '${cls['name']} - ${branch['name']}',
              });
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
        for (final cls in branchClasses) {
          classes.add({
            'id': cls['id'],
            'name': '${cls['name']} - $branchName',
          });
        }
      } else if (auth.role == UserRole.teacher) {
        final dashboardAsync = await ref.read(teacherDashboardDataProvider.future);
        if (dashboardAsync != null && dashboardAsync.classId != null && dashboardAsync.className != null) {
          classes.add({
            'id': dashboardAsync.classId!,
            'name': '${dashboardAsync.className!} - ${dashboardAsync.branchName ?? ""}',
          });
        }
      }

      if (auth.role == UserRole.admin) {
        try {
          final service = ref.read(syllabusServiceProvider);
          final grades = await service.fetchGradeNames();
          setState(() => _gradeNames = grades);
        } catch (_) {}
      }

      setState(() {
        _classes = classes;
        _loadingClasses = false;
      });
    } catch (e) {
      setState(() => _loadingClasses = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.single;
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<MultipartFile> _buildMultipartFile() async {
    if (_selectedFile == null) {
      throw Exception('Please select a file');
    }

    if (_selectedFile!.bytes != null) {
      return MultipartFile.fromBytes(
        _selectedFile!.bytes!,
        filename: _selectedFile!.name,
      );
    }

    if (!kIsWeb && _selectedFile!.path != null) {
      return MultipartFile.fromFile(
        _selectedFile!.path!,
        filename: _selectedFile!.name,
      );
    }

    throw Exception('Unable to read selected file');
  }

  Future<void> _uploadSyllabus() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_uploadForAllBranches && _selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class')),
      );
      return;
    }
    if (_uploadForAllBranches && (_selectedClassName == null || _selectedClassName!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a grade')),
      );
      return;
    }
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      final file = await _buildMultipartFile();
      final service = ref.read(syllabusServiceProvider);
      await service.uploadSyllabus(
        classId: _uploadForAllBranches ? null : _selectedClassId,
        className: _uploadForAllBranches ? _selectedClassName : null,
        title: _titleController.text,
        schoolDay: _schoolDay,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        file: file,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _uploadForAllBranches
                  ? 'Syllabus uploaded to all branches for $_selectedClassName'
                  : 'Syllabus uploaded successfully',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading syllabus: $e')),
        );
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
      appBar: AppBar(
        title: const Text('Upload Syllabus'),
        centerTitle: true,
      ),
      body: _loadingClasses
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Upload for all branches (admin only)
                    if (ref.read(authProvider).role == UserRole.admin) ...[
                      SwitchListTile(
                        title: const Text('Upload for all branches (grade-wise)'),
                        subtitle: const Text('Same syllabus to all classes of this grade across branches'),
                        value: _uploadForAllBranches,
                        onChanged: (v) {
                          setState(() {
                            _uploadForAllBranches = v;
                            if (v) {
                              _selectedClassId = null;
                            } else {
                              _selectedClassName = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Class or Grade selector
                    if (_uploadForAllBranches && ref.read(authProvider).role == UserRole.admin)
                      DropdownButtonFormField<String>(
                        value: _selectedClassName,
                        decoration: const InputDecoration(
                          labelText: 'Select Grade *',
                          border: OutlineInputBorder(),
                        ),
                        items: _gradeNames
                            .map((name) => DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(name),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedClassName = value),
                        validator: (value) {
                          if (_uploadForAllBranches && (value == null || value.isEmpty)) {
                            return 'Please select a grade';
                          }
                          return null;
                        },
                      )
                    else
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
                        validator: (value) {
                          if (!_uploadForAllBranches && value == null) {
                            return 'Please select a class';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // School day (1-180)
                    DropdownButtonFormField<int>(
                      value: _schoolDay,
                      decoration: const InputDecoration(
                        labelText: 'School Day (1-180) *',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(180, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('Day $d'))).toList(),
                      onChanged: (v) => setState(() => _schoolDay = v ?? 1),
                    ),
                    const SizedBox(height: 16),

                    // File picker
                    OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.attach_file),
                      label: Text(_selectedFileName ?? 'Select File *'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    if (_selectedFileName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Selected: $_selectedFileName',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Upload button
                    ElevatedButton(
                      onPressed: _uploading ? null : _uploadSyllabus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: _uploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Upload Syllabus'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
