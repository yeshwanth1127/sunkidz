import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../admin/presentation/branch_detail_screen.dart'
    as _unused; // keep analyzer quiet if needed
import '../../../core/api/admin_provider.dart';
import '../../../core/utils/branch_system.dart';
import '../data/learning_modules_provider.dart';

class ModuleCalendarDialog extends ConsumerStatefulWidget {
  final String moduleId;
  const ModuleCalendarDialog({super.key, required this.moduleId});

  @override
  ConsumerState<ModuleCalendarDialog> createState() =>
      _ModuleCalendarDialogState();
}

class _ModuleCalendarDialogState extends ConsumerState<ModuleCalendarDialog> {
  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> classes = [];
  String? selectedClassId;
  Map<String, dynamic>? calendar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClasses());
  }

  Future<void> _loadClasses() async {
    final api = ref.read(adminApiProvider);
    if (api == null) {
      setState(() {
        isLoading = false;
        error = 'Not authenticated';
      });
      return;
    }
    try {
      final cls = sortByCanonicalGrade(
        await api.getClasses(),
        (c) => c['name'] as String?,
      );
      setState(() {
        classes = cls;
        selectedClassId = cls.isNotEmpty ? cls.first['id']?.toString() : null;
      });
      if (selectedClassId != null) await _loadCalendar();
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadCalendar() async {
    if (selectedClassId == null) return;
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      final cal = await service.fetchModuleCalendar(
        widget.moduleId,
        selectedClassId!,
      );
      setState(() {
        calendar = cal;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        calendar = null;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Module Calendar'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedClassId,
              decoration: const InputDecoration(labelText: 'Class'),
              items:
                  classes
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c['id']?.toString(),
                          child: Text(
                            canonicalGradeLabel(c['name']?.toString()),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (v) async {
                setState(() {
                  selectedClassId = v;
                  calendar = null;
                });
                await _loadCalendar();
              },
            ),
            const SizedBox(height: 12),
            if (isLoading) const Center(child: CircularProgressIndicator()),
            if (!isLoading && calendar != null)
              SizedBox(
                height: 320,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (calendar!['academic_year_start'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Academic Year Start: ${calendar!['academic_year_start']}',
                        ),
                      ),
                    ...((calendar!['days'] as List).where(
                      (d) => (d['videos'] as List).isNotEmpty,
                    )).map((d) {
                      final vids = d['videos'] as List;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text('Day ${d['day']} — ${d['date']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                vids
                                    .map<Widget>(
                                      (v) => Text(
                                        v['title'] ?? v['file_name'] ?? 'Video',
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      );
                    }),
                    if (((calendar!['days'] as List).where(
                      (d) => (d['videos'] as List).isNotEmpty,
                    )).isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12.0),
                        child: Text(
                          'No day-wise videos found for selected class.',
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
