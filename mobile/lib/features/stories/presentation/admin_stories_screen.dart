import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/admin_drawer.dart';
import '../providers/stories_provider.dart';

class AdminStoriesScreen extends ConsumerStatefulWidget {
  const AdminStoriesScreen({super.key});

  @override
  ConsumerState<AdminStoriesScreen> createState() => _AdminStoriesScreenState();
}

class _AdminStoriesScreenState extends ConsumerState<AdminStoriesScreen> {
  List<Map<String, dynamic>> _stories = [];
  bool _loading = true;
  bool _showUpload = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(storiesApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final list = await api.listStories(includeInactive: true);
      if (mounted) {
        setState(() {
          _stories = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete story?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final api = ref.read(storiesApiProvider);
    if (api == null) return;
    try {
      await api.deleteStory(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(_showUpload ? 'Upload Story' : 'Bedtime & Daily Stories'),
        leading: _showUpload
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showUpload = false),
              )
            : null,
      ),
      drawer: _showUpload ? null : const AdminDrawer(),
      floatingActionButton: _showUpload
          ? null
          : FloatingActionButton.extended(
              onPressed: () => setState(() => _showUpload = true),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('Upload'),
            ),
      body: _showUpload
          ? _StoryUploadForm(onDone: () {
              setState(() => _showUpload = false);
              _load();
            })
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _stories.isEmpty
                  ? const Center(child: Text('No stories yet. Tap Upload to add one.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _stories.length,
                        itemBuilder: (_, i) {
                          final s = _stories[i];
                          return _StoryAdminCard(story: s, onDelete: () => _delete(s['id'].toString()));
                        },
                      ),
                    ),
    );
  }
}

class _StoryAdminCard extends StatelessWidget {
  const _StoryAdminCard({required this.story, required this.onDelete});

  final Map<String, dynamic> story;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final type = story['story_type']?.toString() ?? 'daily';
    final kind = story['media_kind']?.toString() ?? '';
    final active = story['is_active'] == true;
    final branches = story['branches'] as List? ?? [];
    final classes = story['classes'] as List? ?? [];
    final allBranches = story['all_branches'] == true;
    final allClasses = story['all_classes'] == true;

    String scope = '';
    if (allBranches && allClasses) {
      scope = 'All branches & classes';
    } else {
      final parts = <String>[];
      if (allBranches) {
        parts.add('All branches');
      } else if (branches.isNotEmpty) {
        parts.add(branches.map((b) => b['name']).join(', '));
      }
      if (allClasses) {
        parts.add('all classes');
      } else if (classes.isNotEmpty) {
        parts.add(classes.map((c) => c['name']).join(', '));
      }
      scope = parts.join(' · ');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: type == 'bedtime' ? Colors.indigo.shade100 : Colors.orange.shade100,
          child: Icon(
            kind == 'video' ? Icons.play_circle : Icons.image,
            color: AppColors.primary,
          ),
        ),
        title: Text(story['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${type == 'bedtime' ? 'Bedtime' : 'Daily'} · ${kind == 'video' ? 'Video' : 'Image'}${active ? '' : ' · Hidden'}'),
            if (scope.isNotEmpty)
              Text(scope, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: onDelete),
      ),
    );
  }
}

class _StoryUploadForm extends ConsumerStatefulWidget {
  const _StoryUploadForm({required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<_StoryUploadForm> createState() => _StoryUploadFormState();
}

class _StoryUploadFormState extends ConsumerState<_StoryUploadForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _storyType = 'daily';
  bool _allBranches = true;
  bool _allClasses = true;
  final Set<String> _selectedBranches = {};
  final Set<String> _selectedClasses = {};
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _allClassOptions = [];
  PlatformFile? _file;
  bool _uploading = false;
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final admin = ref.read(adminApiProvider);
    if (admin == null) {
      setState(() => _loadingMeta = false);
      return;
    }
    try {
      final branches = await admin.getBranches();
      final classes = <Map<String, dynamic>>[];
      for (final b in branches) {
        final bid = b['id']?.toString();
        final bname = b['name']?.toString() ?? '';
        final clsList = b['classes'] as List? ?? [];
        for (final c in clsList) {
          classes.add({
            'id': c['id']?.toString(),
            'name': '${c['name']} — $bname',
            'branch_id': bid,
          });
        }
      }
      setState(() {
        _branches = branches;
        _allClassOptions = classes;
        _loadingMeta = false;
      });
    } catch (_) {
      setState(() => _loadingMeta = false);
    }
  }

  List<Map<String, dynamic>> get _filteredClasses {
    if (_allBranches) return _allClassOptions;
    return _allClassOptions.where((c) => _selectedBranches.contains(c['branch_id'])).toList();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'webm', 'mkv', '3gp'],
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _file = result.files.single);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _file == null) {
      if (_file == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an image or video')));
      }
      return;
    }
    if (!_allBranches && _selectedBranches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one branch or choose All branches')));
      return;
    }
    if (!_allClasses && _selectedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one class or choose All classes')));
      return;
    }

    final storiesApi = ref.read(storiesApiProvider);
    if (storiesApi == null) return;

    setState(() => _uploading = true);
    try {
      MultipartFile multipart;
      if (_file!.bytes != null) {
        multipart = MultipartFile.fromBytes(_file!.bytes!, filename: _file!.name);
      } else if (!kIsWeb && _file!.path != null) {
        multipart = await MultipartFile.fromFile(_file!.path!, filename: _file!.name);
      } else {
        throw Exception('Could not read file');
      }

      await storiesApi.uploadStory(
        title: _title.text.trim(),
        storyType: _storyType,
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        branchIds: _allBranches ? [] : _selectedBranches.toList(),
        classIds: _allClasses ? [] : _selectedClasses.toList(),
        file: multipart,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story uploaded')));
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMeta) return const Center(child: CircularProgressIndicator());

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _storyType,
            decoration: const InputDecoration(labelText: 'Story type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Daily story')),
              DropdownMenuItem(value: 'bedtime', child: Text('Bedtime story')),
            ],
            onChanged: (v) => setState(() => _storyType = v ?? 'daily'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          const Text('Who can see this?', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('All branches'),
            value: _allBranches,
            onChanged: (v) => setState(() {
              _allBranches = v;
              if (v) _selectedBranches.clear();
            }),
          ),
          if (!_allBranches) ...[
            const Text('Branches', style: TextStyle(fontSize: 12, color: Colors.black54)),
            Wrap(
              spacing: 6,
              children: _branches.map((b) {
                final id = b['id']?.toString() ?? '';
                final selected = _selectedBranches.contains(id);
                return FilterChip(
                  label: Text(b['name']?.toString() ?? ''),
                  selected: selected,
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _selectedBranches.add(id);
                    } else {
                      _selectedBranches.remove(id);
                      _selectedClasses.removeWhere(
                        (cid) => _allClassOptions.any((c) => c['id'] == cid && c['branch_id'] == id),
                      );
                    }
                  }),
                );
              }).toList(),
            ),
          ],
          SwitchListTile(
            title: const Text('All classes (within selected branches)'),
            value: _allClasses,
            onChanged: (v) => setState(() {
              _allClasses = v;
              if (v) _selectedClasses.clear();
            }),
          ),
          if (!_allClasses) ...[
            const Text('Classes', style: TextStyle(fontSize: 12, color: Colors.black54)),
            Wrap(
              spacing: 6,
              children: _filteredClasses.map((c) {
                final id = c['id']?.toString() ?? '';
                return FilterChip(
                  label: Text(c['name']?.toString() ?? ''),
                  selected: _selectedClasses.contains(id),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _selectedClasses.add(id);
                    } else {
                      _selectedClasses.remove(id);
                    }
                  }),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file),
            label: Text(_file?.name ?? 'Pick image or video'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _uploading ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: _uploading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Publish story'),
          ),
        ],
      ),
    );
  }
}
