import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/documents_provider.dart';
import 'document_review_screen.dart';

const _statusFilters = <String, String>{
  'failed': 'Needs Attention',
  'all': 'All',
  'pending': 'Pending OCR',
  'processing': 'Processing',
  'needs_review': 'Needs Review',
  'applied': 'Applied',
  'rejected': 'Rejected',
};

class DocumentQueueScreen extends ConsumerStatefulWidget {
  const DocumentQueueScreen({super.key});

  @override
  ConsumerState<DocumentQueueScreen> createState() => _DocumentQueueScreenState();
}

class _DocumentQueueScreenState extends ConsumerState<DocumentQueueScreen> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'failed';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = ref.read(documentsApiProvider);
    if (api == null) {
      setState(() {
        _loading = false;
        _error = 'You are signed out. Please log in again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await api.listDocuments(
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _docs = docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load documents: $e';
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'needs_review':
        return Colors.orange;
      case 'applied':
        return Colors.green;
      case 'failed':
      case 'rejected':
        return Colors.red;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Admission Documents'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final loc = GoRouterState.of(context).matchedLocation;
          final uploaded = await context.push<bool>('$loc/upload');
          if (uploaded == true) _load();
        },
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: _statusFilters.entries.map((e) {
                  final selected = _statusFilter == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _statusFilter = e.key);
                        _load();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                      : _docs.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(48),
                                  child: Center(child: Text('No documents in this status.')),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              itemCount: _docs.length,
                              itemBuilder: (context, i) {
                                final doc = _docs[i];
                                final status = doc['status'] as String? ?? 'pending';
                                final createdAt = doc['created_at'] as String?;
                                String createdLabel = '';
                                if (createdAt != null) {
                                  final parsed = DateTime.tryParse(createdAt);
                                  if (parsed != null) {
                                    createdLabel = DateFormat('MMM d, yyyy • h:mm a').format(parsed.toLocal());
                                  }
                                }
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                                      child: Icon(Icons.description_rounded, color: _statusColor(status)),
                                    ),
                                    title: Text(doc['file_name'] as String? ?? 'Document'),
                                    subtitle: Text(
                                      '${doc['branch_name'] ?? ''} • uploaded by ${doc['uploader_name'] ?? '—'}'
                                      '${createdLabel.isNotEmpty ? '\n$createdLabel' : ''}',
                                    ),
                                    isThreeLine: createdLabel.isNotEmpty,
                                    trailing: Chip(
                                      label: Text(
                                        _statusFilters[status] ?? status,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                                    ),
                                    onTap: () async {
                                      final changed = await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) => DocumentReviewScreen(documentId: doc['id'] as String),
                                        ),
                                      );
                                      if (changed == true) _load();
                                    },
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
