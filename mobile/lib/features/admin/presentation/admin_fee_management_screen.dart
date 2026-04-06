import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/animated_list_item.dart';
import 'fee_receipt_pdf.dart';

class AdminFeeManagementScreen extends ConsumerStatefulWidget {
  final String branchId;
  final String? studentId;
  const AdminFeeManagementScreen({super.key, required this.branchId, this.studentId});

  @override
  ConsumerState<AdminFeeManagementScreen> createState() => _AdminFeeManagementScreenState();
}

class _AdminFeeManagementScreenState extends ConsumerState<AdminFeeManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _students = [];
  String? _selectedBranchId;
  String? _selectedStudentId;
  Map<String, dynamic>? _feeData;
  bool _loading = true;
  bool _loadingFees = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedBranchId = widget.branchId.isEmpty ? null : widget.branchId;
    _selectedStudentId = widget.studentId;
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      final list = await api.getBranches();
      if (mounted) setState(() { _branches = list; _loading = false; });
      if (_selectedBranchId != null) _loadStudents();
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadStudents() async {
    final api = ref.read(adminApiProvider);
    if (api == null || _selectedBranchId == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final list = await api.getAdmissions(branchId: _selectedBranchId!);
      if (mounted) setState(() { _students = list; _loading = false; });
      if (_selectedStudentId != null) _loadFees();
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadFees() async {
    final api = ref.read(adminApiProvider);
    if (api == null || _selectedStudentId == null) return;
    if (mounted) setState(() => _loadingFees = true);
    try {
      final data = await api.getStudentFees(_selectedStudentId!);
      if (mounted) setState(() { _feeData = data; _loadingFees = false; });
    } catch (_) { if (mounted) setState(() => _loadingFees = false); }
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
              child: _selectedBranchId == null 
                ? _buildBranchSelector() 
                : _selectedStudentId == null 
                  ? _buildStudentSelector() 
                  : _buildFeeDashboard(),
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
          IconButton(onPressed: () {
            if (_selectedStudentId != null) {
              setState(() { _selectedStudentId = null; _feeData = null; });
            } else if (_selectedBranchId != null) {
              setState(() => _selectedBranchId = null);
            } else {
              Scaffold.of(context).openDrawer();
            }
          }, icon: Icon((_selectedBranchId != null || _selectedStudentId != null) ? Icons.arrow_back_ios_new_rounded : Icons.menu_rounded, size: 20)),
          const SizedBox(width: 8),
          Text(_selectedStudentId != null ? 'Fee Statement' : _selectedBranchId != null ? 'Select Student' : 'Finance Terminal', 
               style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const Spacer(),
          if (_selectedStudentId != null) IconButton(onPressed: _loadFees, icon: const Icon(Icons.refresh_rounded, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildBranchSelector() {
    if (_loading) return const _StandardLoadingPlaceholder();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _branches.length,
      itemBuilder: (context, i) => AnimatedListItem(
        index: i,
        child: _SelectionCard(
          title: _branches[i]['name'] ?? 'Branch',
          subtitle: _branches[i]['address'] ?? 'Location',
          icon: Icons.apartment_rounded,
          onTap: () { setState(() => _selectedBranchId = _branches[i]['id']); _loadStudents(); },
        ),
      ),
    );
  }

  Widget _buildStudentSelector() {
    if (_loading) return const _StandardLoadingPlaceholder();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, i) => AnimatedListItem(
        index: i,
        child: _SelectionCard(
          title: _students[i]['full_name'] ?? 'Student',
          subtitle: 'ID: ${_students[i]['admission_number'] ?? '—'}',
          icon: Icons.person_rounded,
          onTap: () { setState(() => _selectedStudentId = _students[i]['id']); _loadFees(); },
        ),
      ),
    );
  }

  Widget _buildFeeDashboard() {
    if (_loadingFees) return const _StandardLoadingPlaceholder();
    if (_feeData == null) return const Center(child: Text('No fee data found'));

    return Column(
      children: [
        _buildSummaryCarousel(),
        _buildFeeTabSystem(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStructureView(),
              _buildHistoryView(),
              _buildReportsView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCarousel() {
    final balance = (_feeData!['total_balance'] as num?)?.toDouble() ?? 0.0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [AppShadows.card],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OUTSTANDING BALANCE', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text('₹${NumberFormat('#,##,###').format(balance)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeTabSystem() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(16)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [AppShadows.soft]),
        labelColor: const Color(0xFF0F172A),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        tabs: const [Tab(text: 'STRUCTURE'), Tab(text: 'PAYMENTS'), Tab(text: 'HISTORY')],
      ),
    );
  }

  Widget _buildStructureView() {
    final components = [
      {'label': 'Advance Deposit', 'key': 'advance_fees'},
      {'label': 'Term I Fee', 'key': 'term_fee_1'},
      {'label': 'Term II Fee', 'key': 'term_fee_2'},
      {'label': 'Term III Fee', 'key': 'term_fee_3'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: components.length,
      itemBuilder: (context, i) {
        final key = components[i]['key']!;
        final total = (_feeData![key] as num?)?.toDouble() ?? 0.0;
        final paid = (_feeData!['${key}_paid'] as num?)?.toDouble() ?? 0.0;
        return _FeeComponentCard(label: components[i]['label']!, total: total, paid: paid);
      },
    );
  }

  Widget _buildHistoryView() {
    final payments = (_feeData!['payments'] as List? ?? []);
    if (payments.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No payments recorded yet.', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      itemBuilder: (context, i) {
        final p = payments[i] as Map<String, dynamic>;
        final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
        final date = p['payment_date']?.toString() ?? p['created_at']?.toString() ?? '';
        final mode = p['payment_mode']?.toString() ?? 'Cash';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [AppShadows.soft], border: Border.all(color: const Color(0xFFF1F5F9))),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.accentGreen.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.receipt_long_rounded, color: AppColors.accentGreen, size: 20)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Payment — $mode', style: const TextStyle(fontWeight: FontWeight.w700,fontSize: 14)),
                Text(date.length > 10 ? date.substring(0, 10) : date, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ])),
              Text('₹${NumberFormat('#,###').format(amt)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.accentGreen)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportsView() {
    final total = (_feeData!['total_fees'] as num?)?.toDouble() ?? 0.0;
    final paid = (_feeData!['total_paid'] as num?)?.toDouble() ?? 0.0;
    final balance = (_feeData!['total_balance'] as num?)?.toDouble() ?? 0.0;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SummaryTile(label: 'Total Fees', value: total, icon: Icons.account_balance_wallet_rounded, color: AppColors.primary),
          const SizedBox(height: 12),
          _SummaryTile(label: 'Amount Paid', value: paid, icon: Icons.check_circle_rounded, color: AppColors.accentGreen),
          const SizedBox(height: 12),
          _SummaryTile(label: 'Outstanding Balance', value: balance, icon: Icons.warning_amber_rounded, color: balance > 0 ? Colors.orange : AppColors.accentGreen),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _SelectionCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [AppShadows.soft], border: Border.all(color: const Color(0xFFF1F5F9))),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppColors.primary)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}

class _FeeComponentCard extends StatelessWidget {
  final String label;
  final double total;
  final double paid;
  const _FeeComponentCard({required this.label, required this.total, required this.paid});

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    final isSettled = progress >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF1F5F9)), boxShadow: [AppShadows.soft]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: (isSettled ? AppColors.accentGreen : Colors.amber).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(isSettled ? 'PAID' : 'PENDING', style: TextStyle(color: isSettled ? AppColors.accentGreen : Colors.amber.shade700, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: const Color(0xFFF1F5F9), valueColor: AlwaysStoppedAnimation(isSettled ? AppColors.accentGreen : AppColors.primary)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Paid: ₹${NumberFormat('#,###').format(paid)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
              Text('Total: ₹${NumberFormat('#,###').format(total)}', style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StandardLoadingPlaceholder extends StatelessWidget {
  const _StandardLoadingPlaceholder();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: ShimmerLoading.rectangular(height: 100, width: double.infinity),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  const _SummaryTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [AppShadows.soft], border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B)))),
          Text('₹${NumberFormat('#,##,###').format(value)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
        ],
      ),
    );
  }
}
