import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/animated_list_item.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  Map<String, dynamic>? _attendanceData;
  Map<String, dynamic>? _historyData;
  Map<String, dynamic>? _staffAttendanceData;
  List<Map<String, dynamic>> _branches = [];
  String? _filterBranchId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 1) _loadHistory();
        if (_tabController.index == 2) _loadStaffAttendance();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBranches();
      _loadAttendance();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      final list = await api.getBranches();
      if (mounted) setState(() => _branches = list);
    } catch (_) {}
  }

  Future<void> _loadAttendance() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final res = await api.getAttendance(
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        branchId: _filterBranchId,
      );
      if (mounted) setState(() { _attendanceData = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _attendanceData = null; _loading = false; });
    }
  }

  Future<void> _loadHistory() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final res = await api.getAttendanceHistory(period: 'week', branchId: _filterBranchId);
      if (mounted) setState(() { _historyData = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _historyData = null; _loading = false; });
    }
  }

  Future<void> _loadStaffAttendance() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final res = await api.getStaffAttendance(
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        branchId: _filterBranchId,
      );
      if (mounted) setState(() { _staffAttendanceData = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _staffAttendanceData = null; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildTabSelector(),
            _buildFilterBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDailyView(),
                  _buildHistoryView(),
                  _buildStaffView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B))),
          const SizedBox(width: 8),
          const Text('Attendance Live', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const Spacer(),
          IconButton(onPressed: _loadAttendance, icon: const Icon(Icons.history_rounded, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(16)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [AppShadows.soft]),
        labelColor: Color(0xFF0F172A),
        unselectedLabelColor: Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: 'Daily'), Tab(text: 'History'), Tab(text: 'Staff')],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2023), lastDate: DateTime.now());
                if (d != null) { setState(() => _selectedDate = d); _loadAttendance(); }
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(DateFormat('EEE, MMM d').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterBranchId,
                hint: const Text('Branch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Branches')),
                  ..._branches.map((b) => DropdownMenuItem(value: b['id'] as String?, child: Text(b['name'] as String? ?? '—'))),
                ],
                onChanged: (v) { setState(() => _filterBranchId = v); _loadAttendance(); },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyView() {
    if (_loading) return const _AttendanceLoadingPlaceholder();
    final list = _attendanceData?['by_branch_class'] as List? ?? [];
    if (list.isEmpty) return const Center(child: Text('No attendance records'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final item = list[i] as Map<String, dynamic>;
        return AnimatedListItem(
          index: i,
          child: _AttendanceGroupCard(data: item),
        );
      },
    );
  }

  Widget _buildHistoryView() {
    if (_loading) return const _AttendanceLoadingPlaceholder();
    final weekly = _historyData?['weekly_summary'] as List? ?? [];
    if (weekly.isEmpty) return const Center(child: Text('No attendance history for this period.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: weekly.length,
      itemBuilder: (context, i) {
        final item = weekly[i] as Map<String, dynamic>;
        final present = (item['present'] as num?)?.toInt() ?? 0;
        final total = (item['total'] as num?)?.toInt() ?? 0;
        final pct = total > 0 ? present / total : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [AppShadows.soft]),
          child: Row(
            children: [
              Expanded(child: Text(item['date']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('$present/$total', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
              const SizedBox(width: 12),
              SizedBox(width: 80, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: const Color(0xFFF1F5F9), valueColor: AlwaysStoppedAnimation(pct > 0.8 ? AppColors.accentGreen : Colors.amber)))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaffView() {
    if (_loading) return const _AttendanceLoadingPlaceholder();
    final list = _staffAttendanceData?['by_branch'] as List? ?? [];
    if (list.isEmpty) return const Center(child: Text('No staff attendance records for this date.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final item = list[i] as Map<String, dynamic>;
        final staff = List<Map<String, dynamic>>.from(item['staff'] as List? ?? []);
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [AppShadows.soft]),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            title: Text(item['branch']?.toString() ?? 'Branch', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${staff.length} staff members', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            children: staff.map((s) => ListTile(
              dense: true,
              leading: CircleAvatar(radius: 14, backgroundColor: const Color(0xFFF1F5F9), child: Text(s['name']?[0] ?? '?', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              title: Text(s['name'] ?? 'Staff', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              trailing: _StatusBadge(status: s['status'] ?? 'present'),
            )).toList(),
          ),
        );
      },
    );
  }
}

class _AttendanceGroupCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AttendanceGroupCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final branch = data['branch'] as String? ?? '—';
    final cls = data['class'] as String? ?? '—';
    final students = List<Map<String, dynamic>>.from(data['students'] as List? ?? []);
    
    int p = students.where((s) => s['status'] == 'present').length;
    int a = students.where((s) => s['status'] == 'absent').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [AppShadows.soft], border: Border.all(color: const Color(0xFFF1F5F9))),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text('$branch • $cls', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
        subtitle: Row(
          children: [
            _StatMini(label: 'PRESENT', count: p, color: AppColors.accentGreen),
            const SizedBox(width: 12),
            _StatMini(label: 'ABSENT', count: a, color: const Color(0xFFE11D48)),
          ],
        ),
        children: students.map((s) => ListTile(
          dense: true,
          leading: CircleAvatar(radius: 14, backgroundColor: const Color(0xFFF1F5F9), child: Text(s['name']?[0] ?? '?', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          title: Text(s['name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          trailing: _StatusBadge(status: s['status'] ?? 'present'),
        )).toList(),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatMini({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$count $label', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final isP = status == 'present';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: (isP ? AppColors.accentGreen : const Color(0xFFE11D48)).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: isP ? AppColors.accentGreen : const Color(0xFFE11D48), fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}

class _AttendanceLoadingPlaceholder extends StatelessWidget {
  const _AttendanceLoadingPlaceholder();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            ShimmerLoading.rectangular(height: 80, width: double.infinity),
          ],
        ),
      ),
    );
  }
}
