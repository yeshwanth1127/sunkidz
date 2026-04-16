import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/auth/auth_provider.dart';

import '../../../core/api/admin_provider.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../core/api/parent_provider.dart';
import '../../dashboard/data/teacher_dashboard_provider.dart';
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
  List<Map<String, dynamic>> _classes = [];
  int? _academicYear;

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
        if (api == null) return;
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
        if (api == null) return;
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
        final api = ref.read(teacherApiProvider);
        if (api != null) {
          try {
            final dashboard = await api.getDashboard();
            final classId = dashboard['class_id']?.toString();
            final className = dashboard['class_name']?.toString() ?? '';
            final branchName = dashboard['branch_name']?.toString() ?? '';
            if (classId != null) {
              classes.add({
                'id': classId,
                'name': '$className - $branchName',
              });
            }
          } catch (_) {}
        }
      } else if (auth.role == UserRole.parent) {
        final api = ref.read(parentApiProvider);
        if (api != null) {
          try {
            final response = await api.getChildren();
            final childrenList = (response['children'] as List?) ?? [];
            for (final child in childrenList) {
              final childMap = child as Map<String, dynamic>;
              final classId = childMap['class_id']?.toString();
              final className = childMap['class_name']?.toString() ?? '';
              final childName = childMap['name']?.toString() ?? '';
              if (classId != null) {
                classes.add({
                  'id': classId,
                  'name': '$className ($childName)',
                });
              }
            }
          } catch (_) {}
        }
      }

      setState(() {
        _classes = classes;
        if (_selectedClassId == null && classes.isNotEmpty) {
          _selectedClassId = classes.first['id'] as String;
        }
      });
    } catch (_) {}
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final service = ref.read(syllabusServiceProvider);
        await service.deleteSyllabus(syllabusId);
        setState(() {});
        ref.invalidate(syllabusCalendarProvider(SyllabusCalendarFilter(classId: _selectedClassId!, academicYear: _academicYear)));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syllabus deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showHolidayDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _HolidayMarkDialog(
        onAdd: (startDate, numDays, reason) async {
          try {
            final service = ref.read(syllabusServiceProvider);
            await service.addSyllabusHolidayRange(startDate: startDate, numDays: numDays, reason: reason);
            ref.invalidate(syllabusCalendarProvider(SyllabusCalendarFilter(classId: _selectedClassId!, academicYear: _academicYear)));
            if (mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Holiday marked for $numDays day(s). Syllabus dates will shift automatically.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isAdmin = auth.role == UserRole.admin;
    final canUpload = auth.role == UserRole.admin || auth.role == UserRole.teacher || auth.role == UserRole.coordinator;

    final effectiveClassId = _selectedClassId ?? (_classes.isNotEmpty ? _classes.first['id'] as String? : null);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Syllabus',
          style: TextStyle(color: Color(0xFF2D2323), fontWeight: FontWeight.w800, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.event_busy, color: Colors.black87),
              tooltip: 'Mark Holiday',
              onPressed: _showHolidayDialog,
            ),
          if (canUpload)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black87),
              onPressed: _navigateToUpload,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                if (_classes.length > 1)
                  DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _classes.map((cls) => DropdownMenuItem<String>(value: cls['id'] as String, child: Text(cls['name'] as String))).toList(),
                    onChanged: (value) => setState(() => _selectedClassId = value),
                  )
                else if (_classes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Class: ${_classes.first['name']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: effectiveClassId == null
                ? const Center(child: Text('Select a class to view syllabus'))
                : ref.watch(syllabusCalendarProvider(SyllabusCalendarFilter(classId: effectiveClassId, academicYear: _academicYear))).when(
                      data: (calendar) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: calendar.days.length,
                          itemBuilder: (context, index) {
                            final dayData = calendar.days[index];
                            return _DayCard(
                              day: dayData.day,
                              date: dayData.date,
                              syllabus: dayData.syllabus,
                              academicYearStr: calendar.academicYearStr,
                              isAdmin: isAdmin,
                              onView: (id) => _viewSyllabusFile(id),
                              onDelete: isAdmin ? (id) => _deleteSyllabus(id) : null,
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final int day;
  final String date;
  final List<Map<String, dynamic>> syllabus;
  final String academicYearStr;
  final bool isAdmin;
  final void Function(String id) onView;
  final void Function(String id)? onDelete;

  const _DayCard({
    required this.day,
    required this.date,
    required this.syllabus,
    required this.academicYearStr,
    required this.isAdmin,
    required this.onView,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(date);
    } catch (_) {}
    final dateStr = parsedDate != null ? DateFormat('MMM dd, yyyy').format(parsedDate) : date;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text('$day', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        title: Text('Day $day', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(dateStr),
        children: syllabus.isEmpty
            ? [const ListTile(title: Text('No syllabus uploaded'))]
            : syllabus.map((s) {
                final id = s['id'] as String? ?? '';
                final title = s['title'] as String? ?? '';
                final fileName = s['file_name'] as String? ?? '';
                return ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(title),
                  subtitle: Text(fileName),
                  trailing: PopupMenuButton<String>(
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility), SizedBox(width: 8), Text('View')])),
                      if (isAdmin && onDelete != null)
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                    onSelected: (v) {
                      if (v == 'view') onView(id);
                      if (v == 'delete' && onDelete != null) onDelete!(id);
                    },
                  ),
                );
              }).toList(),
      ),
    );
  }
}

class _HolidayMarkDialog extends StatefulWidget {
  final void Function(DateTime startDate, int numDays, String? reason) onAdd;

  const _HolidayMarkDialog({required this.onAdd});

  @override
  State<_HolidayMarkDialog> createState() => _HolidayMarkDialogState();
}

class _HolidayMarkDialogState extends State<_HolidayMarkDialog> {
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  int _numDays = 1;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark Holiday'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select start date and number of days. Syllabus dates will shift automatically.'),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (d != null) setState(() => _startDate = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Start Date', border: OutlineInputBorder()),
                child: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _numDays,
              decoration: const InputDecoration(labelText: 'Number of days', border: OutlineInputBorder()),
              items: [1, 2, 3, 4, 5, 6, 7].map((n) => DropdownMenuItem(value: n, child: Text('$n day${n > 1 ? 's' : ''}'))).toList(),
              onChanged: (v) => setState(() => _numDays = v ?? 1),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => widget.onAdd(_startDate, _numDays, _reasonController.text.isEmpty ? null : _reasonController.text),
          child: const Text('Mark Holiday'),
        ),
      ],
    );
  }
}
