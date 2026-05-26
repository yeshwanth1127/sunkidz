import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/stories_provider.dart';
import 'story_player_screen.dart';

class ParentStoriesScreen extends ConsumerStatefulWidget {
  const ParentStoriesScreen({super.key, this.studentId});

  final String? studentId;

  @override
  ConsumerState<ParentStoriesScreen> createState() => _ParentStoriesScreenState();
}

class _ParentStoriesScreenState extends ConsumerState<ParentStoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _daily = [];
  List<Map<String, dynamic>> _bedtime = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(storiesApiProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final daily = await api.listStories(storyType: 'daily', studentId: widget.studentId);
      final bedtime = await api.listStories(storyType: 'bedtime', studentId: widget.studentId);
      if (mounted) {
        setState(() {
          _daily = daily;
          _bedtime = bedtime;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Map<String, dynamic> story) {
    final api = ref.read(storiesApiProvider);
    if (api == null) return;
    final id = story['id']?.toString() ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryPlayerScreen(
          title: story['title']?.toString() ?? 'Story',
          mediaKind: story['media_kind']?.toString() ?? 'video',
          fileUrl: api.fileUrl(id),
          description: story['description']?.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Stories'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Daily stories'),
            Tab(text: 'Bedtime stories'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _StoryGrid(stories: _daily, onTap: _open, onRefresh: _load, fileUrl: (id) => ref.read(storiesApiProvider)!.fileUrl(id)),
                _StoryGrid(stories: _bedtime, onTap: _open, onRefresh: _load, fileUrl: (id) => ref.read(storiesApiProvider)!.fileUrl(id)),
              ],
            ),
    );
  }
}

class _StoryGrid extends StatelessWidget {
  const _StoryGrid({
    required this.stories,
    required this.onTap,
    required this.onRefresh,
    required this.fileUrl,
  });

  final List<Map<String, dynamic>> stories;
  final void Function(Map<String, dynamic>) onTap;
  final Future<void> Function() onRefresh;
  final String Function(String id) fileUrl;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No stories available for your child yet.', textAlign: TextAlign.center),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: stories.length,
        itemBuilder: (_, i) {
          final s = stories[i];
          final id = s['id']?.toString() ?? '';
          final kind = s['media_kind']?.toString() ?? '';
          final url = fileUrl(id);

          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTap(s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: kind == 'image'
                          ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity)
                          : Container(
                              color: Colors.indigo.shade50,
                              child: const Center(
                                child: Icon(Icons.play_circle_fill, size: 56, color: AppColors.primary),
                              ),
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      s['title']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
