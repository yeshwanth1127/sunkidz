import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/animated_list_item.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AdminDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _loading
                  ? const _AdmissionLoadingPlaceholder()
                  : _error != null
                      ? _buildErrorState()
                      : _admissions.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: _admissions.length,
                                itemBuilder: (context, i) => AnimatedListItem(
                                  index: i,
                                  child: _AdmissionCard(
                                    admission: _admissions[i],
                                    onTap: () => context.go('/students/${_admissions[i]['id']}'),
                                    onRefresh: _load,
                                  ),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admissions/new'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B)),
          ),
          const SizedBox(width: 8),
          const Text(
            'Admissions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: Icon(Icons.refresh_rounded, color: _loading ? Colors.grey : AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Color(0xFF64748B)), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No admissions yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          const Text(
            'Convert enquiries to admissions or add manually.',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
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
    final branch = widget.admission['branch_name'] as String? ?? 'Branch';
    final className = widget.admission['class_name'] as String? ?? '';
    final busOpted = widget.admission['bus_opted'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppShadows.soft],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.face_retouching_natural_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('$branch ${className.isNotEmpty ? "• $className" : ""}', 
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),
              Row(
                children: [
                  Text(
                    'ID: $admissionNo',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toggling ? null : _toggleBusOpt,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: busOpted ? Colors.amber.withValues(alpha: 0.1) : Colors.blueGrey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: busOpted ? Colors.amber.withValues(alpha: 0.3) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            busOpted ? Icons.directions_bus_rounded : Icons.directions_bus_outlined,
                            size: 14,
                            color: busOpted ? Colors.amber.shade700 : Colors.blueGrey.shade400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            busOpted ? 'BUS ACTIVE' : 'NO BUS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: busOpted ? Colors.amber.shade700 : Colors.blueGrey.shade400,
                            ),
                          ),
                        ],
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

class _AdmissionLoadingPlaceholder extends StatelessWidget {
  const _AdmissionLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Column(
        children: [
          Row(
            children: [
              const ShimmerLoading.circular(width: 56, height: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoading.rectangular(height: 16, width: MediaQuery.of(context).size.width * 0.5),
                    const SizedBox(height: 8),
                    ShimmerLoading.rectangular(height: 12, width: MediaQuery.of(context).size.width * 0.3),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
