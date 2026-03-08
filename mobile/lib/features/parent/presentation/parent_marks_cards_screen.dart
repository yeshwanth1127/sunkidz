import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/parent_api.dart';
import '../../../core/api/parent_provider.dart';
import '../../../shared/widgets/marks_card_display.dart';

class ParentMarksCardsScreen extends ConsumerStatefulWidget {
  const ParentMarksCardsScreen({super.key});

  @override
  ConsumerState<ParentMarksCardsScreen> createState() => _ParentMarksCardsScreenState();
}

class _ParentMarksCardsScreenState extends ConsumerState<ParentMarksCardsScreen> {
  List<Map<String, dynamic>> _marksCards = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarksCards();
  }

  Future<void> _loadMarksCards() async {
    final api = ref.read(parentApiProvider);
    if (api == null) {
      setState(() {
        _loading = false;
        _error = 'API not available';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await api.getMarksCards();
      if (mounted) {
        setState(() {
          _marksCards = List<Map<String, dynamic>>.from(res['marks_cards'] as List? ?? []);
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

  void _showMarksCard(BuildContext context, Map<String, dynamic> mc) {
    final data = mc['data'] as Map<String, dynamic>? ?? {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 1,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${mc['student_name']} • ${mc['academic_year']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                child: MarksCardDisplay(
                  studentName: mc['student_name'] as String? ?? '—',
                  academicYear: mc['academic_year'] as String? ?? '—',
                  data: data,
                  fatherName: mc['father_name']?.toString(),
                  motherName: mc['mother_name']?.toString(),
                  dob: (mc['date_of_birth']?.toString() ?? '').split('T').first,
                  className: mc['class_name']?.toString(),
                  branchName: mc['branch_name']?.toString(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(
        title: const Text('Marks Cards'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Error: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMarksCards,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _marksCards.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text('No marks cards available yet'),
                          const SizedBox(height: 8),
                          Text(
                            'Marks cards will appear here once published by your teachers',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMarksCards,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _marksCards.length,
                        itemBuilder: (context, index) {
                          final mc = _marksCards[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MarksCardTile(
                              marksCard: mc,
                              onTap: () => _showMarksCard(context, mc),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _MarksCardTile extends StatelessWidget {
  final Map<String, dynamic> marksCard;
  final VoidCallback onTap;

  const _MarksCardTile({required this.marksCard, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sentAt = marksCard['sent_at'] as String?;
    String sentStr = '—';
    if (sentAt != null && sentAt.length >= 10) {
      final parts = sentAt.substring(0, 10).split('-');
      if (parts.length == 3) sentStr = '${parts[2]}/${parts[1]}/${parts[0]}';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.assignment,
                color: Colors.green.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    marksCard['student_name'] as String? ?? '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${marksCard['class_name'] ?? '—'} • ${marksCard['academic_year'] ?? '—'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Sent',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sentStr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
