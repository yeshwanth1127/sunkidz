import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/api/daycare_provider.dart';
import '../../../core/config/api_config.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/daycare_drawer.dart';

class DaycareDailyUpdatesScreen extends ConsumerStatefulWidget {
  const DaycareDailyUpdatesScreen({super.key});

  @override
  ConsumerState<DaycareDailyUpdatesScreen> createState() => _DaycareDailyUpdatesScreenState();
}

class _DaycareDailyUpdatesScreenState extends ConsumerState<DaycareDailyUpdatesScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _updates = [];
  bool _loadingUpdates = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(daycareApiProvider);
    if (api == null) return;
    setState(() {
      _loadingUpdates = true;
      _error = null;
    });
    try {
      final studentsRes = await api.getMyStudents();
      final students = List<Map<String, dynamic>>.from((studentsRes['students'] as List?) ?? []);
      final updates = await api.listMyUpdates();
      if (mounted) {
        setState(() {
          _students = students;
          _updates = updates;
          _loadingUpdates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingUpdates = false;
        });
      }
    }
  }

  void _showPostUpdate() {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students assigned to your group. Contact admin.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PostUpdateSheet(
        students: _students,
        api: ref.read(daycareApiProvider)!,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      drawer: const DaycareDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Daily Updates'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showPostUpdate),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loadingUpdates)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  else if (_updates.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.notes, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No daily updates yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _showPostUpdate,
                              icon: const Icon(Icons.add),
                              label: const Text('Post first update'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._updates.map((u) => _UpdateCard(
                          update: u,
                          token: ref.read(authProvider).token,
                        )),
                ],
              ),
            ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final Map<String, dynamic> update;
  final String? token;

  const _UpdateCard({required this.update, this.token});

  @override
  Widget build(BuildContext context) {
    final studentName = update['student_name'] as String? ?? 'Unknown';
    final date = update['date'] as String? ?? '';
    final content = update['content'] as String? ?? '';
    final authorName = update['author_name'] as String? ?? '';
    final hasPhoto = update['photo_path'] != null && (update['photo_path'] as String).isNotEmpty;
    final updateId = update['id'] as String?;

    String? photoUrl;
    if (hasPhoto && updateId != null) {
      photoUrl = '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/daycare/updates/$updateId/photo'
          '${token != null ? '?token=$token' : ''}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF85CDCA).withValues(alpha: 0.3),
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFF85CDCA), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(
                        '$date • $authorName',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(content),
            if (photoUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photoUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PostUpdateSheet extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final dynamic api;
  final VoidCallback onSaved;

  const _PostUpdateSheet({
    required this.students,
    required this.api,
    required this.onSaved,
  });

  @override
  State<_PostUpdateSheet> createState() => _PostUpdateSheetState();
}

class _PostUpdateSheetState extends State<_PostUpdateSheet> {
  String? _selectedStudentId;
  final _contentCtrl = TextEditingController();
  String _dateStr = '';
  File? _photo;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dateStr = DateTime.now().toIso8601String().split('T')[0];
    if (widget.students.isNotEmpty && _selectedStudentId == null) {
      _selectedStudentId = widget.students.first['id'] as String?;
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null && mounted) {
      setState(() => _photo = File(x.path));
    }
  }

  Future<void> _save() async {
    final studentId = _selectedStudentId;
    final content = _contentCtrl.text.trim();
    if (studentId == null || studentId.isEmpty) {
      setState(() => _error = 'Select a student');
      return;
    }
    if (content.isEmpty) {
      setState(() => _error = 'Enter update content');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.createDailyUpdate(
        studentId: studentId,
        date: _dateStr,
        content: content,
        photoPath: _photo?.path,
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Post Daily Update', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStudentId,
                decoration: const InputDecoration(labelText: 'Student *'),
                items: widget.students
                    .map((s) => DropdownMenuItem(
                          value: s['id'] as String?,
                          child: Text(s['name'] as String? ?? ''),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStudentId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Update content *',
                  hintText: 'e.g. Had lunch, napped well, played outside...',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_dateStr) ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (d != null && mounted) {
                    setState(() => _dateStr = d.toIso8601String().split('T')[0]);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(_dateStr),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo_library),
                label: Text(_photo != null ? 'Photo selected' : 'Add photo (optional)'),
              ),
              if (_photo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_photo!, height: 80, width: 80, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton(
                      onPressed: _save,
                      child: const Text('Post Update'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
