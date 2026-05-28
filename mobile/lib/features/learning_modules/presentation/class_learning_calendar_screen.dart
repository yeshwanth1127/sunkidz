import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../core/api/parent_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../data/learning_modules_provider.dart';

const _kAllClasses = '__all__';

class ClassLearningCalendarScreen extends ConsumerStatefulWidget {
  const ClassLearningCalendarScreen({super.key});

  @override
  ConsumerState<ClassLearningCalendarScreen> createState() => _ClassLearningCalendarScreenState();
}

class _ClassLearningCalendarScreenState extends ConsumerState<ClassLearningCalendarScreen> {
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;

  List<Map<String, dynamic>> _allClasses = [];
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;

  Map<int, List<Map<String, dynamic>>> _videoByDay = {};
  List<Map<String, dynamic>> _days = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool get _isAdmin => ref.read(authProvider).role == UserRole.admin;
  bool get _isAllClasses => _selectedClassId == _kAllClasses;

  Future<void> _loadData() async {
    final auth = ref.read(authProvider);
    try {
      if (auth.role == UserRole.admin) {
        final api = ref.read(adminApiProvider);
        if (api == null) {
          setState(() { _isLoading = false; _error = 'Not authenticated'; });
          return;
        }
        final branches = await api.getBranches();
        final branchList = <Map<String, dynamic>>[];
        final allClasses = <Map<String, dynamic>>[];
        for (final b in branches) {
          final bId = b['id']?.toString() ?? '';
          final bName = b['name']?.toString() ?? '';
          branchList.add({'id': bId, 'name': bName});
          for (final cls in (b['classes'] as List? ?? [])) {
            allClasses.add({
              'id': cls['id']?.toString(),
              'name': cls['name']?.toString() ?? '',
              'branch_id': bId,
              'branch_name': bName,
            });
          }
        }
        final firstBranchId = branchList.isNotEmpty ? branchList.first['id'] as String? : null;
        final filteredClasses = allClasses.where((c) => c['branch_id'] == firstBranchId).toList();
        setState(() {
          _branches = branchList;
          _allClasses = allClasses;
          _selectedBranchId = firstBranchId;
          _classes = filteredClasses;
          _selectedClassId = filteredClasses.isNotEmpty ? filteredClasses.first['id']?.toString() : null;
        });
      } else if (auth.role == UserRole.coordinator) {
        final api = ref.read(coordinatorApiProvider);
        if (api == null) {
          setState(() { _isLoading = false; _error = 'Not authenticated'; });
          return;
        }
        final dashboard = await api.getDashboard();
        final branchName = dashboard['branch_name'] ?? '';
        final classes = <Map<String, dynamic>>[];
        for (final cls in (dashboard['classes'] as List? ?? [])) {
          classes.add({'id': cls['id']?.toString(), 'name': cls['name']?.toString() ?? '', 'branch_name': branchName});
        }
        setState(() {
          _classes = classes;
          _selectedClassId = classes.isNotEmpty ? classes.first['id']?.toString() : null;
        });
      } else if (auth.role == UserRole.teacher) {
        final api = ref.read(teacherApiProvider);
        if (api != null) {
          final dashboard = await api.getDashboard();
          final classId = dashboard['class_id']?.toString();
          final className = dashboard['class_name']?.toString() ?? '';
          final branchName = dashboard['branch_name']?.toString() ?? '';
          if (classId != null) {
            setState(() {
              _classes = [{'id': classId, 'name': '$className – $branchName'}];
              _selectedClassId = classId;
            });
          }
        }
      } else if (auth.role == UserRole.parent) {
        final api = ref.read(parentApiProvider);
        if (api != null) {
          final data = await api.getChildren();
          final classes = <Map<String, dynamic>>[];
          final seen = <String>{};
          for (final child in (data['children'] as List? ?? [])) {
            final classId = child['class_id']?.toString();
            if (classId != null && seen.add(classId)) {
              final className = child['class_name']?.toString() ?? '';
              final branchName = child['branch_name']?.toString() ?? '';
              classes.add({'id': classId, 'name': '$className – $branchName'});
            }
          }
          setState(() {
            _classes = classes;
            _selectedClassId = classes.isNotEmpty ? classes.first['id']?.toString() : null;
          });
        }
      } else {
        setState(() { _isLoading = false; _error = 'Not authorized'; });
        return;
      }
      if (_selectedClassId != null) await _loadCalendar();
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _onBranchChanged(String? branchId) {
    final filtered = _allClasses.where((c) => c['branch_id'] == branchId).toList();
    final firstClassId = filtered.isNotEmpty ? filtered.first['id']?.toString() : null;
    setState(() {
      _selectedBranchId = branchId;
      _classes = filtered;
      _selectedClassId = firstClassId;
      _videoByDay = {};
      _days = [];
    });
    if (firstClassId != null) _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) throw Exception('Not authenticated');

      // For "All Classes" mode, use first real class to get the date mapping
      final fetchClassId = _isAllClasses
          ? (_classes.isNotEmpty ? _classes.first['id']?.toString() : null)
          : _selectedClassId;
      if (fetchClassId == null) {
        setState(() { _isLoading = false; _days = []; _videoByDay = {}; });
        return;
      }

      final cal = await service.fetchClassCalendar(fetchClassId);
      final days = (cal['days'] as List).cast<Map<String, dynamic>>();
      final Map<int, List<Map<String, dynamic>>> byDay = {};

      if (!_isAllClasses) {
        for (final d in days) {
          final vids = (d['videos'] as List?) ?? [];
          if (vids.isNotEmpty) {
            byDay[d['day'] as int] = vids.map((v) => Map<String, dynamic>.from(v as Map)).toList();
          }
        }
      }
      // In all-classes mode, show grid with no video status (all grey)

      setState(() { _days = days; _videoByDay = byDay; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _tapDay(int dayIndex) {
    if (!_isAdmin && _isAllClasses) return; // non-admin can't use all-classes mode
    final dayData = _days[dayIndex];
    final dayNum = dayData['day'] as int;
    final date = dayData['date'] as String? ?? '';
    final videos = _videoByDay[dayNum] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DayBottomSheet(
        day: dayNum,
        date: date,
        videos: videos,
        classId: _isAllClasses ? (_classes.isNotEmpty ? _classes.first['id']?.toString() ?? '' : '') : (_selectedClassId ?? ''),
        branchId: _selectedBranchId,
        isAdmin: _isAdmin,
        isAllClasses: _isAllClasses,
        onUploaded: () {
          Navigator.pop(ctx);
          _loadCalendar();
        },
        onPlay: (v) {
          Navigator.pop(ctx);
          context.push(
            '/learning-modules/video/${v['id']}',
            extra: {'title': v['title'] ?? 'Day $dayNum Video', 'file_path': v['file_path'] ?? ''},
          );
        },
      ),
    );
  }

  String _shortDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[d.month - 1]} ${d.day}';
    } catch (_) { return ''; }
  }

  List<DropdownMenuItem<String>> _classDropdownItems() {
    final items = <DropdownMenuItem<String>>[];
    if (_isAdmin && _selectedBranchId != null) {
      items.add(const DropdownMenuItem(
        value: _kAllClasses,
        child: Text('All Classes', style: TextStyle(fontWeight: FontWeight.bold)),
      ));
    }
    for (final c in _classes) {
      items.add(DropdownMenuItem(
        value: c['id']?.toString(),
        child: Text(c['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
      ));
    }
    return items;
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
        title: const Text(
          'Learning Modules',
          style: TextStyle(color: Color(0xFF2D2323), fontWeight: FontWeight.w800, fontSize: 18),
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
                if (_branches.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('branch-$_selectedBranchId'),
                    initialValue: _selectedBranchId,
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _branches.map((b) => DropdownMenuItem<String>(
                      value: b['id']?.toString(),
                      child: Text(b['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: _isLoading ? null : _onBranchChanged,
                  ),
                  const SizedBox(height: 8),
                ],
                if (_classes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey('class-$_selectedBranchId-$_selectedClassId'),
                    initialValue: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _classDropdownItems(),
                    onChanged: _isLoading ? null : (v) {
                      setState(() { _selectedClassId = v; _videoByDay = {}; _days = []; });
                      _loadCalendar();
                    },
                  ),
                const SizedBox(height: 8),
                if (_isAllClasses)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tap any day to upload a video to all classes in this branch',
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                          ),
                        ),
                      ],
                    ),
                  )
                else
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
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  childAspectRatio: 0.82,
                ),
                itemCount: _days.length,
                itemBuilder: (context, index) {
                  final dayNum = _days[index]['day'] as int;
                  final dateStr = _days[index]['date'] as String? ?? '';
                  final hasVideo = !_isAllClasses && _videoByDay.containsKey(dayNum);
                  return GestureDetector(
                    onTap: () => _tapDay(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isAllClasses
                            ? Colors.blue.shade50
                            : (hasVideo ? Colors.orange.shade400 : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _isAllClasses
                                  ? Colors.blue.shade700
                                  : (hasVideo ? Colors.white : Colors.grey.shade700),
                            ),
                          ),
                          Text(
                            _shortDate(dateStr),
                            style: TextStyle(
                              fontSize: 8,
                              color: _isAllClasses
                                  ? Colors.blue.shade400
                                  : (hasVideo ? Colors.white70 : Colors.grey.shade500),
                            ),
                          ),
                        ],
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
  final List<Map<String, dynamic>> videos;
  final String classId;
  final String? branchId;
  final bool isAdmin;
  final bool isAllClasses;
  final VoidCallback onUploaded;
  final void Function(Map<String, dynamic>) onPlay;

  const _DayBottomSheet({
    required this.day,
    required this.date,
    required this.videos,
    required this.classId,
    required this.branchId,
    required this.isAdmin,
    required this.isAllClasses,
    required this.onUploaded,
    required this.onPlay,
  });

  @override
  ConsumerState<_DayBottomSheet> createState() => _DayBottomSheetState();
}

class _DayBottomSheetState extends ConsumerState<_DayBottomSheet> {
  PlatformFile? _pickedFile;
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
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
    _subjectCtrl.dispose();
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
      final title = _titleCtrl.text.isEmpty ? 'Day ${widget.day} Video' : _titleCtrl.text;
      final subject = _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim();

      if (widget.isAllClasses) {
        await service.uploadVideoForAllClasses(
          widget.branchId!,
          _pickedFile!,
          title,
          subject,
          null,
          widget.day,
          null,
        );
      } else {
        await service.uploadVideoForClass(
          widget.classId,
          _pickedFile!,
          title,
          null,
          widget.day,
          null,
          subjectName: subject,
        );
      }
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

  Map<String, List<Map<String, dynamic>>> _groupBySubject() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final v in widget.videos) {
      final subject = (v['subject_name'] as String?)?.trim();
      final key = (subject == null || subject.isEmpty) ? 'General' : subject;
      grouped.putIfAbsent(key, () => []).add(v);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupBySubject();
    final hasVideos = widget.videos.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: widget.isAllClasses ? Colors.blue.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text('${widget.day}', style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16,
                    color: widget.isAllClasses ? Colors.blue.shade800 : Colors.orange.shade800,
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Day ${widget.day}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_formatDate(widget.date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      if (widget.isAllClasses)
                        Text('Upload to all classes', style: TextStyle(fontSize: 11, color: Colors.blue.shade600, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Existing videos grouped by subject (shown when not all-classes mode)
            if (!widget.isAllClasses && hasVideos) ...[
              ...grouped.entries.map((entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      entry.key,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                  ...entry.value.map((v) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_fill, color: Colors.orange.shade600, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            v['title'] as String? ?? 'Video',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        FilledButton(
                          onPressed: () => widget.onPlay(v),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Play', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  )),
                ],
              )),
              if (widget.isAdmin) ...[
                const Divider(),
                Text(
                  'Add another video',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
              ],
            ],

            // Upload form (admin only)
            if (widget.isAdmin) ...[
              TextField(
                controller: _subjectCtrl,
                decoration: InputDecoration(
                  labelText: 'Subject name (optional)',
                  hintText: 'e.g. Maths, Science, English',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.subject, color: Colors.orange.shade400, size: 18),
                ),
              ),
              const SizedBox(height: 8),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.isAllClasses ? Colors.blue.shade600 : Colors.orange,
                  ),
                  child: _uploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(widget.isAllClasses
                          ? 'Upload to All Classes – Day ${widget.day}'
                          : (hasVideos ? 'Add Video for Day ${widget.day}' : 'Upload Video for Day ${widget.day}')),
                ),
              ),
            ],

            // Non-admin, no videos
            if (!widget.isAdmin && !hasVideos)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No video uploaded for this day yet.', style: TextStyle(color: Colors.grey.shade500)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
