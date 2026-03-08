import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/config/api_config.dart';
import '../../../core/api/coordinator_provider.dart';
import '../../../features/syllabus/domain/models/syllabus_model.dart';
import '../../../features/syllabus/providers/syllabus_provider.dart';
import '../../../shared/widgets/coordinator_drawer.dart';

class CoordinatorGalleryScreen extends ConsumerStatefulWidget {
  const CoordinatorGalleryScreen({super.key});

  @override
  ConsumerState<CoordinatorGalleryScreen> createState() =>
      _CoordinatorGalleryScreenState();
}

class _CoordinatorGalleryScreenState
    extends ConsumerState<CoordinatorGalleryScreen> {
  final List<Map<String, dynamic>> _classes = [];
  List<GalleryItem> _items = [];
  List<_GalleryDisplayItem> _displayItems = [];
  String? _selectedClassId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await _loadClasses();
    await _loadGallery();
  }

  Future<void> _loadClasses() async {
    final api = ref.read(coordinatorApiProvider);
    if (api == null) return;
    try {
      final dashboard = await api.getDashboard();
      final branchClasses = dashboard['classes'] as List? ?? [];
      final classes = <Map<String, dynamic>>[
        {'id': '', 'name': 'All Grades'},
      ];
      for (final cls in branchClasses) {
        classes.add({'id': cls['id'], 'name': cls['name']});
      }
      if (mounted) {
        setState(() {
          _classes
            ..clear()
            ..addAll(classes);
          _selectedClassId ??= '';
        });
      }
    } catch (_) {
      // Keep screen functional even if class metadata fails.
    }
  }

  Future<void> _loadGallery() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(syllabusServiceProvider);
      final items = await service.fetchGallery(
        classId: (_selectedClassId == null || _selectedClassId!.isEmpty)
            ? null
            : _selectedClassId,
      );
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        final classCount = _classes
            .where((c) => (c['id'] as String? ?? '').isNotEmpty)
            .length;
        setState(() {
          _items = items;
          _displayItems = _buildDisplayItems(items, classCount);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _items = [];
          _displayItems = [];
          _loading = false;
        });
      }
    }
  }

  List<_GalleryDisplayItem> _buildDisplayItems(
    List<GalleryItem> items,
    int classCount,
  ) {
    // Group likely duplicate records created when one upload is saved per class.
    if (!(_selectedClassId == null || _selectedClassId!.isEmpty)) {
      return items
          .map(
            (e) => _GalleryDisplayItem(
              item: e,
              classNames: {e.className},
              uploadedToAllGrades: false,
            ),
          )
          .toList();
    }

    final grouped = <String, List<GalleryItem>>{};
    for (final item in items) {
      final key = [
        item.uploadedBy,
        item.uploadDate.toIso8601String().substring(0, 10),
        (item.title ?? '').trim().toLowerCase(),
        (item.description ?? '').trim().toLowerCase(),
        item.fileSize ?? '',
      ].join('|');
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final result = <_GalleryDisplayItem>[];
    for (final group in grouped.values) {
      group.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final classNames = group.map((g) => g.className).toSet();
      final isAllGrades = classCount > 0 && classNames.length == classCount;
      result.add(
        _GalleryDisplayItem(
          item: group.first,
          classNames: classNames,
          uploadedToAllGrades: isAllGrades,
        ),
      );
    }
    result.sort((a, b) => b.item.createdAt.compareTo(a.item.createdAt));
    return result;
  }

  static String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final token = auth.token;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      drawer: const CoordinatorDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Gallery'),
        actions: [
          IconButton(
            tooltip: 'Upload Image',
            onPressed: () => context
                .push('/coordinator/gallery-upload')
                .then((_) => _loadGallery()),
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGallery,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_classes.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedClassId,
                decoration: const InputDecoration(
                  labelText: 'Filter by Grade',
                  border: OutlineInputBorder(),
                ),
                items: _classes
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c['id'] as String,
                        child: Text(c['name'] as String? ?? 'Unknown'),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  setState(() => _selectedClassId = value ?? '');
                  await _loadGallery();
                },
              ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_displayItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 40,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 10),
                    Text('No gallery images found'),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _displayItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemBuilder: (_, index) {
                  final viewItem = _displayItems[index];
                  final item = viewItem.item;
                  final imageUrl =
                      '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/gallery/${item.id}/file${token != null ? '?token=$token' : ''}';
                  final title =
                      (item.title == null || item.title!.trim().isEmpty)
                      ? item.fileName
                      : item.title!;
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                viewItem.uploadedToAllGrades
                                    ? 'Uploaded to all grades'
                                    : '${viewItem.classNames.join(', ')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: viewItem.uploadedToAllGrades
                                      ? Colors.green.shade700
                                      : Colors.grey.shade700,
                                  fontWeight: viewItem.uploadedToAllGrades
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(item.uploadDate),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context
            .push('/coordinator/gallery-upload')
            .then((_) => _loadGallery()),
        icon: const Icon(Icons.cloud_upload_outlined),
        label: const Text('Upload'),
      ),
    );
  }
}

class _GalleryDisplayItem {
  final GalleryItem item;
  final Set<String> classNames;
  final bool uploadedToAllGrades;

  const _GalleryDisplayItem({
    required this.item,
    required this.classNames,
    required this.uploadedToAllGrades,
  });
}
