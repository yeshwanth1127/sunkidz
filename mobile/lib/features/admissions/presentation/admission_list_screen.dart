import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';

class AdmissionListScreen extends ConsumerStatefulWidget {
  const AdmissionListScreen({super.key});

  @override
  ConsumerState<AdmissionListScreen> createState() => _AdmissionListScreenState();
}

class _AdmissionListScreenState extends ConsumerState<AdmissionListScreen> {
  List<Map<String, dynamic>> _admissions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(adminApiProvider);
    if (api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final admissions = await api.getAdmissions();
      if (mounted) setState(() {
        _admissions = admissions;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Admissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _admissions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No admissions yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          Text('Convert enquiries to admissions from the Enquiries screen', style: TextStyle(fontSize: 14, color: Colors.grey.shade500), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _admissions.length,
                      itemBuilder: (_, i) => _AdmissionCard(
                        admission: _admissions[i],
                        onTap: () => context.go('/students/${_admissions[i]['id']}'),
                        onRefresh: _load,
                      ),
                    ),
    );
  }
}

class _AdmissionCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> admission;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  const _AdmissionCard({
    required this.admission,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  ConsumerState<_AdmissionCard> createState() => _AdmissionCardState();
}

class _AdmissionCardState extends ConsumerState<_AdmissionCard> {
  bool _toggling = false;

  Future<void> _toggleBusOpt() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;

    setState(() => _toggling = true);
    try {
      await api.toggleBusOpt(widget.admission['id']);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bus opt status updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.admission['name'] as String? ?? '';
    final admissionNo = widget.admission['admission_number'] as String? ?? '—';
    final branch = widget.admission['branch_name'] as String? ?? '—';
    final className = widget.admission['class_name'] as String? ?? '';
    final age = widget.admission['age_years'] ?? widget.admission['age_months'] ?? '—';
    final ageStr = age is int ? (widget.admission['age_months'] != null ? '$age yrs' : 'Age $age') : age.toString();
    final subtitle = [branch, if (className.isNotEmpty) className, ageStr].join(' • ');
    final busOpted = widget.admission['bus_opted'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.pastelGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.school, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onTap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(admissionNo, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onTap,
                    child: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggling ? null : _toggleBusOpt,
                      icon: _toggling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              busOpted ? Icons.directions_bus : Icons.directions_bus_outlined,
                              size: 18,
                            ),
                      label: Text(busOpted ? 'Bus Opted' : 'Opt Bus'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: busOpted ? Colors.green : Colors.grey,
                        side: BorderSide(
                          color: busOpted ? Colors.green : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
