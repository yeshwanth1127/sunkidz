import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../data/learning_modules_provider.dart';

class ModuleCalendarScreen extends ConsumerStatefulWidget {
  final String moduleId;
  final String moduleName;

  const ModuleCalendarScreen({
    super.key,
    required this.moduleId,
    required this.moduleName,
  });

  @override
  ConsumerState<ModuleCalendarScreen> createState() => _ModuleCalendarScreenState();
}

class _ModuleCalendarScreenState extends ConsumerState<ModuleCalendarScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  // day number → video map (null = no video)
  Map<int, Map<String, dynamic>> _videoByDay = {};
  List<Map<String, dynamic>> _days = [];

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
          setState(() { _isLoading = false; _error = 'Not authenticated'; });
          return;
        }
        final branches = await api.getBranches();
        for (final branch in branches) {
          for (final cls in (branch['classes'] as List? ?? [])) {
            classes.add({'id': cls['id']?.toString(), 'name': '${cls['name']} - ${branch['name']}'});
          }
        }
      } else if (auth.role == UserRole.coordinator) {
        final api = ref.read(coordinatorApiProvider);
        if (api == null) {
          setState(() { _isLoading = false; _error = 'Not authenticated'; });
          return;
        }
        final dashboard = await api.getDashboard();
        final branchName = dashboard['branch_name'] ?? '';
        for (final cls in (dashboard['classes'] as List? ?? [])) {
          classes.add({'id': cls['id']?.toString(), 'name': '${cls['name']} - $branchName'});
        }
      } else if (auth.role == UserRole.teacher) {
        final api = ref.read(teacherApiProvider);
        if (api != null) {
          final dashboard = await api.getDashboard();
          final classId = dashboard['class_id']?.toString();
          final className = dashboard['class_name']?.toString() ?? '';
          final branchName = dashboard['branch_name']?.toString() ?? '';
          if (classId != null) {
            classes.add({'id': classId, 'name': '$className - $branchName'});
          }
        }
      } else {
        setState(() { _isLoading = false; _error = 'Not authorized to view calendar'; });
        return;
      }
      setState(() {
        _classes = classes;
        _selectedClassId = classes.isNotEmpty ? classes.first['id']?.toString() : null;
      });
      if (_selectedClassId != null) await _loadCalendar();
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadCalendar() async {
    if (_selectedClassId == null) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      final cal = await service.fetchModuleCalendar(widget.moduleId, _selectedClassId!);
      final days = (cal['days'] as List).cast<Map<String, dynamic>>();
      final Map<int, Map<String, dynamic>> byDay = {};
      for (final d in days) {
        final vids = (d['videos'] as List?) ?? [];
        if (vids.isNotEmpty) {
          byDay[d['day'] as int] = (vids.first as Map<String, dynamic>)
            ..['_date'] = d['date'];
        }
      }
      setState(() {
        _days = days;
        _videoByDay = byDay;
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _tapDay(int day) {
    final date = _days.firstWhere((d) => d['day'] == day, orElse: () => {})['date'] as String? ?? '';
    final video = _videoByDay[day];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DayBottomSheet(
        day: day,
        date: date,
        video: video,
        moduleId: widget.moduleId,
        onUploaded: () {
          Navigator.pop(ctx);
          _loadCalendar();
        },
        onPlay: (v) {
          Navigator.pop(ctx);
          context.push(
            '/learning-modules/video/${v['id']}',
            extra: {'title': v['title'] ?? 'Day $day Video', 'file_path': v['file_path'] ?? ''},
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          widget.moduleName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF2D2323), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_classes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _classes.map((c) => DropdownMenuItem<String>(
                      value: c['id']?.toString(),
                      child: Text(c['name']?.toString() ?? 'Unnamed'),
                    )).toList(),
                    onChanged: (v) async {
                      setState(() { _selectedClassId = v; _videoByDay = {}; _days = []; });
                      await _loadCalendar();
                    },
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Legend(color: Colors.orange.shade400, label: 'Video uploaded'),
                    const SizedBox(width: 16),
                    _Legend(color: Colors.grey.shade300, label: 'No video'),
                  ],
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.orange)))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else if (_days.isEmpty)
            const Expanded(child: Center(child: Text('Select a class to view calendar')))
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 9,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemCount: _days.length,
                itemBuilder: (context, index) {
                  final dayNum = _days[index]['day'] as int;
                  final hasVideo = _videoByDay.containsKey(dayNum);
                  return GestureDetector(
                    onTap: () => _tapDay(dayNum),
                    child: Container(
                      decoration: BoxDecoration(
                        color: hasVideo ? Colors.orange.shade400 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: hasVideo ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}

class _DayBottomSheet extends ConsumerStatefulWidget {
  final int day;
  final String date;
  final Map<String, dynamic>? video;
  final String moduleId;
  final VoidCallback onUploaded;
  final void Function(Map<String, dynamic>) onPlay;

  const _DayBottomSheet({
    required this.day,
    required this.date,
    required this.video,
    required this.moduleId,
    required this.onUploaded,
    required this.onPlay,
  });

  @override
  ConsumerState<_DayBottomSheet> createState() => _DayBottomSheetState();
}

class _DayBottomSheetState extends ConsumerState<_DayBottomSheet> {
  PlatformFile? _pickedFile;
  final _titleCtrl = TextEditingController();
  bool _uploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = 'Day ${widget.day} Video';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null) return;
    setState(() { _uploading = true; _uploadError = null; });
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      await service.uploadVideo(
        widget.moduleId,
        _pickedFile!,
        _titleCtrl.text.isEmpty ? 'Day ${widget.day} Video' : _titleCtrl.text,
        null,
        widget.day,
        null,
      );
      widget.onUploaded();
    } catch (e) {
      setState(() { _uploadError = e.toString(); _uploading = false; });
    }
  }

  String _formatDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text('${widget.day}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day ${widget.day}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_formatDate(widget.date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.video != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.play_circle_fill, color: Colors.orange.shade600, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.video!['title'] as String? ?? 'Video',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => widget.onPlay(widget.video!),
                    style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Play'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text('Replace video', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Video title',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(_pickedFile?.name ?? 'Pick video file'),
          ),
          if (_uploadError != null) ...[
            const SizedBox(height: 8),
            Text(_uploadError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_pickedFile == null || _uploading) ? null : _upload,
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              child: _uploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.video != null ? 'Replace Video' : 'Upload Video for Day ${widget.day}'),
            ),
          ),
        ],
      ),
    );
  }
}
