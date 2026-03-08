import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../dashboard/data/teacher_dashboard_provider.dart';
import '../providers/syllabus_provider.dart';

class HomeworkUploadScreen extends ConsumerStatefulWidget {
  const HomeworkUploadScreen({super.key});

  @override
  ConsumerState<HomeworkUploadScreen> createState() => _HomeworkUploadScreenState();
}

class _HomeworkUploadScreenState extends ConsumerState<HomeworkUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedClassId;
  DateTime _uploadDate = DateTime.now();
  DateTime? _dueDate;
  PlatformFile? _selectedFile;
  String? _selectedFileName;
  bool _uploading = false;
  
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
        // Admin: Load all branches and classes
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
        // Coordinator: Load classes from their branch
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
        // Teacher: Load their assigned class from dashboard provider
        final dashboardAsync = await ref.read(teacherDashboardDataProvider.future);
        if (dashboardAsync != null && dashboardAsync.classId != null && dashboardAsync.className != null) {
          classes.add({
            'id': dashboardAsync.classId!,
            'name': '${dashboardAsync.className!} - ${dashboardAsync.branchName ?? ""}',
          });
        }
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

  Future<void> _uploadHomework() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class')),
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
      await service.uploadHomework(
        classId: _selectedClassId!,
        title: _titleController.text,
        uploadDate: _uploadDate,
        dueDate: _dueDate,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        file: file,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Homework uploaded successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading homework: $e')),
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
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(
        title: const Text('Upload Homework'),
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
                    // Class selector
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
                      onChanged: (value) {
                        setState(() {
                          _selectedClassId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
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

                    // Upload date
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _uploadDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setState(() {
                            _uploadDate = date;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Upload Date *',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(_uploadDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Due date
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setState(() {
                            _dueDate = date;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Due Date (optional)',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _dueDate != null
                              ? DateFormat('MMM dd, yyyy').format(_dueDate!)
                              : 'Select due date',
                        ),
                      ),
                    ),
                    if (_dueDate != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() => _dueDate = null),
                          child: const Text('Clear Due Date'),
                        ),
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
                      onPressed: _uploading ? null : _uploadHomework,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: _uploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Upload Homework'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
