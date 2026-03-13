import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';
import '../../../shared/widgets/coordinator_drawer.dart';
import '../../../shared/widgets/teacher_drawer.dart';
import '../../../core/api/admin_provider.dart';
import '../providers/syllabus_provider.dart';
import '../domain/models/syllabus_model.dart';
import 'syllabus_upload_screen.dart';

class SyllabusListScreen extends ConsumerStatefulWidget {
  const SyllabusListScreen({super.key});

  @override
  ConsumerState<SyllabusListScreen> createState() => _SyllabusListScreenState();
}

class _SyllabusListScreenState extends ConsumerState<SyllabusListScreen> {
  String? _selectedClassId;
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final auth = ref.read(authProvider);
    if (auth.role != UserRole.admin) {
      setState(() {
        _classes = [];
      });
      return;
    }

    final api = ref.read(adminApiProvider);
    if (api == null) {
      return;
    }
    try {
      final branches = await api.getBranches();
      final classes = <Map<String, dynamic>>[];
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
      setState(() {
        _classes = classes;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _viewSyllabusFile(String syllabusId) async {
    final auth = ref.read(authProvider);
    final token = auth.token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login again to view files')),
        );
      }
      return;
    }

    final encodedToken = Uri.encodeQueryComponent(token);
    final url = '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/syllabus/$syllabusId/file?token=$encodedToken';
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open file')),
      );
    }
  }

  void _navigateToUpload() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SyllabusUploadScreen(),
      ),
    ).then((_) => setState(() {}));
  }

  Future<void> _deleteSyllabus(String syllabusId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Syllabus'),
        content: const Text('Are you sure you want to delete this syllabus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(syllabusServiceProvider);
        await service.deleteSyllabus(syllabusId);
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Syllabus deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting syllabus: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isAdmin = auth.role == UserRole.admin;
    final canUpload = auth.role == UserRole.admin ||
        auth.role == UserRole.teacher ||
        auth.role == UserRole.coordinator;

    final filter = SyllabusFilter(
      classId: _selectedClassId,
      uploadDate: _selectedDate?.toIso8601String().split('T')[0],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      drawer: switch (auth.role) {
        UserRole.admin => const AdminDrawer(),
        UserRole.coordinator => const CoordinatorDrawer(),
        UserRole.teacher => const TeacherDrawer(),
        _ => const TeacherDrawer(),
      },
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Syllabus'),
        centerTitle: true,
        actions: [
          if (canUpload)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _navigateToUpload,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                if (isAdmin) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Class',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Classes'),
                      ),
                      ..._classes.map((cls) => DropdownMenuItem<String>(
                            value: cls['id'] as String,
                            child: Text(cls['name'] as String),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedClassId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                // Date filter
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Filter by Date',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _selectedDate != null
                          ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                          : 'All Dates',
                    ),
                  ),
                ),
                if (_selectedDate != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _selectedDate = null),
                      child: const Text('Clear Date'),
                    ),
                  ),
              ],
            ),
          ),
          // List
          Expanded(
            child: ref.watch(syllabusListProvider(filter)).when(
                  data: (syllabusList) {
                    if (syllabusList.isEmpty) {
                      return const Center(
                        child: Text('No syllabus found'),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: syllabusList.length,
                      itemBuilder: (context, index) {
                        final syllabus = syllabusList[index];
                        return _SyllabusCard(
                          syllabus: syllabus,
                          isAdmin: isAdmin,
                          onView: () => _viewSyllabusFile(syllabus.id),
                          onDelete: isAdmin ? () => _deleteSyllabus(syllabus.id) : null,
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text('Error: $error'),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _SyllabusCard extends StatelessWidget {
  final Syllabus syllabus;
  final bool isAdmin;
  final VoidCallback onView;
  final VoidCallback? onDelete;

  const _SyllabusCard({
    required this.syllabus,
    required this.isAdmin,
    required this.onView,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.description, color: AppColors.primary),
        ),
        title: Text(
          syllabus.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class: ${syllabus.className}'),
            Text('Date: ${DateFormat('MMM dd, yyyy').format(syllabus.uploadDate)}'),
            if (syllabus.uploaderName != null) Text('Uploaded by: ${syllabus.uploaderName}'),
            if (syllabus.fileSize != null) Text('Size: ${syllabus.fileSize}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 8),
                  Text('View'),
                ],
              ),
            ),
            if (isAdmin)
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
          onSelected: (value) {
            if (value == 'view') {
              onView();
            } else if (value == 'delete' && onDelete != null) {
              onDelete!();
            }
          },
        ),
        isThreeLine: true,
      ),
    );
  }
}
