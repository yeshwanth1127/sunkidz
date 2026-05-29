import 'package:flutter/material.dart';
import './upload_content_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../core/api/teacher_provider.dart';
import '../../../core/api/parent_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../data/learning_modules_provider.dart';

const _kAllClasses = '__all__';
const _kAllBranches = '__all_branches__';

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
  bool get _isAllBranches => _selectedBranchId == _kAllBranches;

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
    if (branchId == _kAllBranches) {
      setState(() {
        _selectedBranchId = _kAllBranches;
        _classes = _allClasses;
        _selectedClassId = _kAllClasses;
        _videoByDay = {};
        _days = [];
      });
      _loadCalendar();
      return;
    }
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

  String _academicYearStartFromDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      final year = d.month >= 6 ? d.year : d.year - 1;
      return '$year-06-01';
    } catch (_) {
      final now = DateTime.now();
      final year = now.month >= 6 ? now.year : now.year - 1;
      return '$year-06-01';
    }
  }

  void _tapDay(int dayIndex) {
    if (!_isAdmin && _isAllClasses) return;
    final dayData = _days[dayIndex];
    final dayNum = dayData['day'] as int;
    final date = dayData['date'] as String? ?? '';
    final ayStart = _academicYearStartFromDate(date);

    if (_isAllClasses) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _AllBranchesDaySheet(
          day: dayNum,
          date: date,
          academicYearStart: ayStart,
          classes: _classes,
          isAdmin: _isAdmin,
          isAllBranches: _isAllBranches,
        ),
      );
      return;
    }

    if (_selectedClassId != null) {
      context.push(
        '/learning-modules/day/$_selectedClassId/$dayNum',
        extra: {'date': date, 'academicYearStart': ayStart},
      );
    }
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
    if (_isAdmin) {
      items.add(const DropdownMenuItem(
        value: _kAllClasses,
        child: Text('All Classes', style: TextStyle(fontWeight: FontWeight.bold)),
      ));
    }
    for (final c in _classes) {
      final label = _isAllBranches
          ? '${c['branch_name']} – ${c['name']}'
          : (c['name']?.toString() ?? '');
      items.add(DropdownMenuItem(
        value: c['id']?.toString(),
        child: Text(label, overflow: TextOverflow.ellipsis),
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
                    items: [
                      const DropdownMenuItem<String>(
                        value: _kAllBranches,
                        child: Text('All Branches', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      ..._branches.map((b) => DropdownMenuItem<String>(
                        value: b['id']?.toString(),
                        child: Text(b['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                      )),
                    ],
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
                            _isAllBranches
                                ? 'Tap any day to upload a video to all classes in ALL branches'
                                : 'Tap any day to upload a video to all classes in this branch',
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

// ─── All-branches / all-classes day sheet ────────────────────────────────────

class _AllBranchesDaySheet extends ConsumerStatefulWidget {
  final int day;
  final String date;
  final String academicYearStart;
  final List<Map<String, dynamic>> classes;
  final bool isAdmin;
  final bool isAllBranches;

  const _AllBranchesDaySheet({
    required this.day,
    required this.date,
    required this.academicYearStart,
    required this.classes,
    required this.isAdmin,
    required this.isAllBranches,
  });

  @override
  ConsumerState<_AllBranchesDaySheet> createState() => _AllBranchesDaySheetState();
}

class _AllBranchesDaySheetState extends ConsumerState<_AllBranchesDaySheet> {
  Map<String, List<Map<String, dynamic>>> _foldersByClass = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      final entries = await Future.wait(
        widget.classes.map((c) async {
          try {
            final folders = await service.getDayFolders(
              c['id'] as String, widget.day, widget.academicYearStart,
            );
            return MapEntry(c['id'] as String, folders);
          } catch (_) {
            return MapEntry(c['id'] as String, <Map<String, dynamic>>[]);
          }
        }),
      );
      setState(() => _foldersByClass = Map.fromEntries(entries));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByGrade() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final c in widget.classes) {
      grouped.putIfAbsent(c['name'] as String? ?? 'Unknown', () => []).add(c);
    }
    return grouped;
  }

  Future<void> _addSubjectToAll(String name) async {
    if (name.isEmpty) return;
    final service = ref.read(learningModulesServiceProvider);
    if (service == null) return;
    setState(() => _loading = true);
    try {
      await Future.wait(widget.classes.map((c) => service.createDayFolder(
        c['id'] as String, widget.day, name, widget.academicYearStart,
      )));
      await _loadAll();
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  String _formatDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${mo[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByGrade();
    final accent = widget.isAllBranches ? Colors.deepPurple : Colors.blue;
    final label  = widget.isAllBranches ? 'All Branches' : 'All Classes';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: accent.shade100, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text('${widget.day}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accent.shade800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Day ${widget.day}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_formatDate(widget.date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      Text(label, style: TextStyle(fontSize: 11, color: accent.shade600, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (widget.isAdmin)
                  IconButton(
                    icon: Icon(Icons.create_new_folder_outlined, color: accent.shade600),
                    tooltip: 'Add subject to all grades',
                    onPressed: () async {
                      final ctrl = TextEditingController();
                      final name = await showDialog<String>(
                        context: context,
                        builder: (dctx) => AlertDialog(
                          title: const Text('Add Subject', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Subject name',
                              hintText: 'e.g. Maths, Science',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (v) => Navigator.pop(dctx, v.trim()),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
                              style: FilledButton.styleFrom(backgroundColor: accent),
                              child: const Text('Create'),
                            ),
                          ],
                        ),
                      );
                      if (name != null && name.isNotEmpty) await _addSubjectToAll(name);
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.orange)))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAll,
                color: Colors.orange,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: grouped.entries.map((e) => _GradeCard(
                    grade: e.key,
                    classes: e.value,
                    foldersByClass: _foldersByClass,
                    isAdmin: widget.isAdmin,
                    showBranch: widget.isAllBranches,
                    onRefresh: _loadAll,
                  )).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  final String grade;
  final List<Map<String, dynamic>> classes;
  final Map<String, List<Map<String, dynamic>>> foldersByClass;
  final bool isAdmin;
  final bool showBranch;
  final VoidCallback onRefresh;

  const _GradeCard({
    required this.grade,
    required this.classes,
    required this.foldersByClass,
    required this.isAdmin,
    required this.showBranch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.school_outlined, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Text(grade, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade900)),
              ],
            ),
          ),
          ...classes.asMap().entries.map((entry) {
            final idx = entry.key;
            final cls  = entry.value;
            final folders = foldersByClass[cls['id'] as String] ?? [];
            final branchName = cls['branch_name'] as String? ?? '';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (idx > 0) const Divider(height: 1, indent: 14, endIndent: 14),
                if (showBranch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: Text(branchName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                  ),
                if (folders.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, showBranch ? 4 : 12, 14, 12),
                    child: Text('No subjects yet', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  )
                else
                  ...folders.map((f) => _SubjectRow(folder: f, isAdmin: isAdmin, onRefresh: onRefresh)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _SubjectRow extends ConsumerWidget {
  final Map<String, dynamic> folder;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const _SubjectRow({required this.folder, required this.isAdmin, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name  = folder['name'] as String? ?? 'Subject';
    final count = folder['content_count'] as int? ?? 0;

    return InkWell(
      onTap: () => context.push('/learning-modules/folder/${folder['id']}', extra: {'folderName': name}),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.folder_rounded, color: Colors.orange.shade400, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('$count item${count != 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            if (isAdmin)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                padding: EdgeInsets.zero,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'upload', child: Row(children: [Icon(Icons.upload_outlined, size: 16), SizedBox(width: 8), Text('Upload')])),
                  const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Rename')])),
                ],
                onSelected: (action) async {
                  if (action == 'upload') {
                    showDialog(
                      context: context,
                      builder: (_) => UploadContentDialog(folderId: folder['id'] as String, onUploaded: onRefresh),
                    );
                  } else if (action == 'rename') {
                    final ctrl = TextEditingController(text: name);
                    final newName = await showDialog<String>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Rename Subject', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: TextField(
                          controller: ctrl,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Subject name', border: OutlineInputBorder()),
                          onSubmitted: (v) => Navigator.pop(dctx, v.trim()),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
                            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                            child: const Text('Rename'),
                          ),
                        ],
                      ),
                    );
                    if (newName != null && newName.isNotEmpty && newName != name) {
                      try {
                        final service = ref.read(learningModulesServiceProvider);
                        if (service != null) await service.renameDayFolder(folder['id'] as String, newName);
                        onRefresh();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  }
                },
              ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}

