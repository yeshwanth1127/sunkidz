import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/parent_provider.dart';
import '../../../core/config/api_config.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/parent_drawer.dart';

class ParentDaycareUpdatesScreen extends ConsumerStatefulWidget {
  const ParentDaycareUpdatesScreen({super.key});

  @override
  ConsumerState<ParentDaycareUpdatesScreen> createState() => _ParentDaycareUpdatesScreenState();
}

class _ParentDaycareUpdatesScreenState extends ConsumerState<ParentDaycareUpdatesScreen> {
  List<Map<String, dynamic>> _updates = [];
  List<Map<String, dynamic>> _children = [];
  String? _selectedChildId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    final api = ref.read(parentApiProvider);
    if (api == null) return;
    try {
      final res = await api.getChildren();
      final children = List<Map<String, dynamic>>.from(res['children'] as List? ?? []);
      if (mounted) {
        setState(() {
          _children = children;
          if (_selectedChildId == null && children.isNotEmpty) {
            _selectedChildId = children.first['id'] as String?;
          }
        });
        _load();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    final api = ref.read(parentApiProvider);
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final updates = await api.getDaycareDailyUpdates(studentId: _selectedChildId);
      if (mounted) {
        setState(() {
          _updates = updates;
          _loading = false;
        });
      }
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
    final token = ref.watch(authProvider).token;

    return Scaffold(
      drawer: const ParentDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Daycare Daily Updates'),
        actions: [
          if (_children.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (id) {
                setState(() {
                  _selectedChildId = id;
                  _load();
                });
              },
              itemBuilder: (_) => _children
                  .map((c) => PopupMenuItem(
                        value: c['id'] as String? ?? '',
                        child: Text(c['name'] as String? ?? ''),
                      ))
                  .toList(),
            ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : RefreshIndicator(
              onRefresh: () async {
                await _loadChildren();
                await _load();
              },
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _updates.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.notes, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No daycare updates yet',
                                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _updates.length,
                          itemBuilder: (_, i) => _UpdateCard(
                            update: _updates[i],
                            token: token,
                          ),
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
                  backgroundColor: Colors.teal.withValues(alpha: 0.2),
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
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
