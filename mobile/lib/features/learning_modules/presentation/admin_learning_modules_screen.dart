import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../data/learning_modules_provider.dart';
import './assign_module_dialog.dart';

class AdminLearningModulesScreen extends ConsumerStatefulWidget {
  const AdminLearningModulesScreen({super.key});

  @override
  ConsumerState<AdminLearningModulesScreen> createState() => _AdminLearningModulesScreenState();
}

class _AdminLearningModulesScreenState extends ConsumerState<AdminLearningModulesScreen> {
  bool _showCreateModule = false;
  bool _showUploadVideo = false;
  final _moduleNameCtrl = TextEditingController();
  final _moduleDescCtrl = TextEditingController();
  final _videoTitleCtrl = TextEditingController();
  final _videoDescCtrl = TextEditingController();
  String? _selectedModuleId;
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _moduleNameCtrl.dispose();
    _moduleDescCtrl.dispose();
    _videoTitleCtrl.dispose();
    _videoDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _selectedFile = result.files.first);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick file: $e');
    }
  }

  Future<void> _createModule() async {
    if (_moduleNameCtrl.text.isEmpty) {
      _showErrorSnackBar('Module name is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) {
        _showErrorSnackBar('Not authenticated');
        return;
      }

      await service.createModule(
        _moduleNameCtrl.text,
        _moduleDescCtrl.text.isEmpty ? null : _moduleDescCtrl.text,
      );

      _moduleNameCtrl.clear();
      _moduleDescCtrl.clear();
      setState(() {
        _showCreateModule = false;
        _isLoading = false;
      });

      ref.refresh(learningModulesProvider);
      _showSuccessSnackBar('Module created successfully');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      _showErrorSnackBar(_error!);
    }
  }

  Future<void> _uploadVideo() async {
    if (_selectedModuleId == null || _selectedModuleId!.isEmpty) {
      _showErrorSnackBar('Please select a module');
      return;
    }
    if (_videoTitleCtrl.text.isEmpty) {
      _showErrorSnackBar('Video title is required');
      return;
    }
    if (_selectedFile == null) {
      _showErrorSnackBar('Please select a video file');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) {
        _showErrorSnackBar('Not authenticated');
        return;
      }

      await service.uploadVideo(
        _selectedModuleId!,
        _selectedFile!,
        _videoTitleCtrl.text,
        _videoDescCtrl.text.isEmpty ? null : _videoDescCtrl.text,
      );

      _selectedModuleId = null;
      _selectedFile = null;
      _videoTitleCtrl.clear();
      _videoDescCtrl.clear();
      setState(() {
        _showUploadVideo = false;
        _isLoading = false;
      });

      ref.refresh(learningModulesProvider);
      _showSuccessSnackBar('Video uploaded successfully');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      _showErrorSnackBar(_error!);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(learningModulesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Manage Learning Modules',
          style: TextStyle(
            color: Color(0xFF2D2323),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: modulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error.toString(), style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(learningModulesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (modules) => Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showCreateModule = true),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Module'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                if (modules.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.library_books_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No modules yet. Create one to get started!',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  ...modules.map((m) => _ModuleAdminCard(
                        module: m,
                        onUploadVideo: () {
                          setState(() {
                            _selectedModuleId = m['id'];
                            _showUploadVideo = true;
                          });
                        },
                        onAssignStudents: () {
                          setState(() {
                            _selectedModuleId = m["id"];
                          });
                          showDialog(
                            context: context,
                            builder: (ctx) => AssignModuleDialog(
                              moduleId: m["id"],
                              onAssignmentComplete: () {
                                ref.refresh(learningModulesProvider);
                              },
                            ),
                          );
                        },
                        onDelete: () async {
                          try {
                            final service = ref.read(learningModulesServiceProvider);
                            if (service != null) {
                              await service.deleteModule(m['id']);
                              ref.refresh(learningModulesProvider);
                              _showSuccessSnackBar('Module deleted');
                            }
                          } catch (e) {
                            _showErrorSnackBar('Failed to delete: $e');
                          }
                        },
                      )),
              ],
            ),
            if (_showCreateModule)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: _CreateModuleDialog(
                      nameCtrl: _moduleNameCtrl,
                      descCtrl: _moduleDescCtrl,
                      isLoading: _isLoading,
                      onCreate: _createModule,
                      onClose: () => setState(() => _showCreateModule = false),
                    ),
                  ),
                ),
              ),
            if (_showUploadVideo)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: _UploadVideoDialog(
                      modules: modules,
                      selectedModuleId: _selectedModuleId,
                      onModuleChanged: (id) => setState(() => _selectedModuleId = id),
                      titleCtrl: _videoTitleCtrl,
                      descCtrl: _videoDescCtrl,
                      selectedFile: _selectedFile,
                      onPickFile: _pickFile,
                      isLoading: _isLoading,
                      onUpload: _uploadVideo,
                      onClose: () => setState(() => _showUploadVideo = false),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModuleAdminCard extends StatelessWidget {
  final Map<String, dynamic> module;
  final VoidCallback onUploadVideo;
  final VoidCallback onAssignStudents;
  final VoidCallback onDelete;

  const _ModuleAdminCard({
    required this.module,
    required this.onUploadVideo,
    required this.onAssignStudents,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = module['name'] as String? ?? 'Untitled';
    final videoCount = module['video_count'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '$videoCount video${videoCount != 1 ? 's' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAssignStudents,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Assign'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onUploadVideo,
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Upload'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateModuleDialog extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final bool isLoading;
  final VoidCallback onCreate;
  final VoidCallback onClose;

  const _CreateModuleDialog({
    required this.nameCtrl,
    required this.descCtrl,
    required this.isLoading,
    required this.onCreate,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create Module', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Module Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: isLoading ? null : onClose,
                style: FilledButton.styleFrom(backgroundColor: Colors.grey),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: isLoading ? null : onCreate,
                child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Create'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadVideoDialog extends StatelessWidget {
  final List<Map<String, dynamic>> modules;
  final String? selectedModuleId;
  final Function(String?) onModuleChanged;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final PlatformFile? selectedFile;
  final VoidCallback onPickFile;
  final bool isLoading;
  final VoidCallback onUpload;
  final VoidCallback onClose;

  const _UploadVideoDialog({
    required this.modules,
    required this.selectedModuleId,
    required this.onModuleChanged,
    required this.titleCtrl,
    required this.descCtrl,
    required this.selectedFile,
    required this.onPickFile,
    required this.isLoading,
    required this.onUpload,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upload Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedModuleId,
              decoration: const InputDecoration(
                labelText: 'Select Module',
                border: OutlineInputBorder(),
              ),
              items: modules.map((m) => DropdownMenuItem<String>(
                    value: m['id'] as String,
                    child: Text(m['name'] ?? 'Untitled'),
                  )).toList(),
              onChanged: onModuleChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Video Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isLoading ? null : onPickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(selectedFile?.name ?? 'Pick Video File'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton(
                  onPressed: isLoading ? null : onClose,
                  style: FilledButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isLoading ? null : onUpload,
                  child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Upload'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
