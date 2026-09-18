import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/animated_list_item.dart';

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

  Future<void> _loadFees({bool showSpinner = true}) async {
    final api = ref.read(adminApiProvider);
    if (api == null || _selectedStudentId == null) return;
    if (mounted && showSpinner && _feeData == null) setState(() => _loadingFees = true);
    try {
      final data = await api.getStudentFees(_selectedStudentId!);
      if (mounted) setState(() { _feeData = data; _loadingFees = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingFees = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh fees: $e')),
        );
      }
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
              Navigator.of(context).pop();
            }
          }, icon: Icon((_selectedBranchId != null || _selectedStudentId != null) ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back, size: 20)),
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
          title: _students[i]['name'] ?? 'Student',
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

    return Stack(
      children: [
        Column(
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
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'pay',
                backgroundColor: AppColors.accentGreen,
                onPressed: () => _showRecordPaymentSheet(),
                child: const Icon(Icons.payment_rounded, color: Colors.white),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'edit',
                backgroundColor: AppColors.primary,
                onPressed: () => _showEditFeeSheet(),
                child: const Icon(Icons.edit_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Parse an amount field exactly as typed. Empty means 0. Anything that is not
  /// a valid non-negative number returns null so the caller can block the save
  /// instead of silently substituting a default.
  double? _parseAmount(String raw) {
    final s = raw.replaceAll(RegExp(r'[,\s₹]'), '');
    if (s.isEmpty) return 0.0;
    final v = double.tryParse(s);
    if (v == null || v < 0 || v.isNaN || v.isInfinite) return null;
    return v;
  }

  /// Show a whole number without a trailing ".0" so the field round-trips cleanly.
  String _fmtAmount(dynamic v) {
    final d = (v as num?)?.toDouble() ?? 0.0;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }

  String _slugify(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  Widget _sheetError(String? msg) {
    if (msg == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  void _showEditFeeSheet() {
    final advCtrl = TextEditingController(text: _fmtAmount(_feeData!['advance_fees']));
    final t1Ctrl = TextEditingController(text: _fmtAmount(_feeData!['term_fee_1']));
    final t2Ctrl = TextEditingController(text: _fmtAmount(_feeData!['term_fee_2']));
    final t3Ctrl = TextEditingController(text: _fmtAmount(_feeData!['term_fee_3']));

    final customRows = <_CustomFeeRow>[
      for (final cf in (_feeData!['custom_fields'] as List? ?? []))
        _CustomFeeRow(
          originalKey: cf['key'] as String?,
          label: TextEditingController(text: (cf['label'] as String?) ?? ''),
          amount: TextEditingController(text: _fmtAmount(cf['amount'])),
        ),
    ];
    String? errText;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const Text('Edit Fee Structure', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),
                _sheetError(errText),
                _feeField(advCtrl, 'Advance Deposit (₹)'),
                _feeField(t1Ctrl, 'Term I Fee (₹)'),
                _feeField(t2Ctrl, 'Term II Fee (₹)'),
                _feeField(t3Ctrl, 'Term III Fee (₹)'),
                const SizedBox(height: 4),
                Row(children: [
                  const Text('Custom Fees', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setS(() => customRows.add(_CustomFeeRow(
                      originalKey: null,
                      label: TextEditingController(),
                      amount: TextEditingController(),
                    ))),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ]),
                for (int i = 0; i < customRows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(flex: 3, child: TextFormField(
                        controller: customRows[i].label,
                        decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), isDense: true),
                      )),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: TextFormField(
                        controller: customRows[i].amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '₹', border: OutlineInputBorder(), isDense: true),
                      )),
                      IconButton(
                        onPressed: () => setS(() => customRows.removeAt(i)),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Remove',
                      ),
                    ]),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: saving ? null : () async {
                    final built = _buildFeeStructureBody(advCtrl, t1Ctrl, t2Ctrl, t3Ctrl, customRows);
                    if (built.error != null) {
                      setS(() => errText = built.error);
                      return; // nothing sent; error is shown in the sheet
                    }
                    setS(() { errText = null; saving = true; });
                    Navigator.pop(ctx);
                    await _submitFeeStructure(built.body!);
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(saving ? 'Saving…' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// Validate + assemble the exact request body. Returns an error message (and no
  /// body) when anything is invalid — never silently coerces a bad value.
  ({String? error, Map<String, dynamic>? body}) _buildFeeStructureBody(
    TextEditingController adv,
    TextEditingController t1,
    TextEditingController t2,
    TextEditingController t3,
    List<_CustomFeeRow> customRows,
  ) {
    final bad = <String>[];
    final advVal = _parseAmount(adv.text);
    final t1Val = _parseAmount(t1.text);
    final t2Val = _parseAmount(t2.text);
    final t3Val = _parseAmount(t3.text);
    if (advVal == null) bad.add('Advance Deposit');
    if (t1Val == null) bad.add('Term I');
    if (t2Val == null) bad.add('Term II');
    if (t3Val == null) bad.add('Term III');

    final customPayload = <Map<String, dynamic>>[];
    final seenKeys = <String>{};
    for (var i = 0; i < customRows.length; i++) {
      final row = customRows[i];
      final label = row.label.text.trim();
      final amtText = row.amount.text.trim();
      if (label.isEmpty && amtText.isEmpty) continue; // untouched blank row
      final amt = _parseAmount(amtText);
      if (label.isEmpty) { bad.add('custom fee #${i + 1} name'); continue; }
      if (amt == null) { bad.add('"$label" amount'); continue; }
      final key = (row.originalKey != null && row.originalKey!.isNotEmpty)
          ? row.originalKey!
          : _slugify(label);
      if (key.isEmpty) { bad.add('"$label" (use letters or numbers)'); continue; }
      if (!seenKeys.add(key)) { bad.add('duplicate "$label"'); continue; }
      customPayload.add({'key': key, 'label': label, 'amount': amt});
    }

    if (bad.isNotEmpty) {
      return (error: 'Enter a valid non-negative amount for: ${bad.join(", ")}', body: null);
    }
    return (
      error: null,
      body: {
        'advance_fees': advVal,
        'term_fee_1': t1Val,
        'term_fee_2': t2Val,
        'term_fee_3': t3Val,
        'custom_fields': customPayload,
      },
    );
  }

  Future<void> _submitFeeStructure(Map<String, dynamic> body) async {
    final api = ref.read(adminApiProvider);
    if (api == null || _selectedStudentId == null) return;
    try {
      final updated = await api.updateStudentFees(_selectedStudentId!, body);
      if (!mounted) return;
      // Show the exact saved structure across every tab immediately,
      // then reconcile with a fresh fetch from the server.
      setState(() => _feeData = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fees updated!')));
      await _loadFees(showSpinner: false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showRecordPaymentSheet() {
    final amtCtrl = TextEditingController();
    String mode = 'cash';
    String component = 'advance_fees';
    String? errText;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const Text('Record Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            _sheetError(errText),
            TextFormField(
              controller: amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₹) *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: mode,
              decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payment)),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
                DropdownMenuItem(value: 'net_banking', child: Text('Net Banking')),
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
              ],
              onChanged: (v) => setS(() => mode = v ?? 'cash'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: component,
              decoration: const InputDecoration(labelText: 'Fee Category *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_rounded)),
              items: [
                const DropdownMenuItem(value: 'advance_fees', child: Text('Advance Deposit')),
                const DropdownMenuItem(value: 'term_fee_1', child: Text('Term I Fee')),
                const DropdownMenuItem(value: 'term_fee_2', child: Text('Term II Fee')),
                const DropdownMenuItem(value: 'term_fee_3', child: Text('Term III Fee')),
                for (final cf in (_feeData?['custom_fields'] as List? ?? []))
                  DropdownMenuItem(
                    value: cf['key'] as String,
                    child: Text((cf['label'] as String?) ?? (cf['key'] as String)),
                  ),
              ],
              onChanged: (v) => setS(() => component = v ?? 'advance_fees'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : () async {
                final amt = _parseAmount(amtCtrl.text);
                if (amt == null) {
                  setS(() => errText = 'Enter a valid amount — numbers only.');
                  return;
                }
                if (amt <= 0) {
                  setS(() => errText = 'Amount must be greater than 0.');
                  return;
                }
                setS(() { errText = null; saving = true; });
                Navigator.pop(ctx);
                await _submitPayment(component: component, amount: amt, mode: mode);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.accentGreen, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(saving ? 'Recording…' : 'Record Payment', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ]),
        ),
      )),
    );
  }

  Future<void> _submitPayment({required String component, required double amount, required String mode}) async {
    final api = ref.read(adminApiProvider);
    if (api == null || _selectedStudentId == null) return;
    try {
      final res = await api.recordFeePayment(_selectedStudentId!, {
        'amount_paid': amount,
        'payment_mode': mode,
        'component': component,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded!')));
      await _loadFees(showSpinner: false); // Payments tab reflects it immediately
      _promptSendReceipt(res['id']?.toString());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _promptSendReceipt(String? paymentId) {
    if (paymentId == null || paymentId.isEmpty || !mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment recorded'),
        content: const Text('Send the receipt to the parent portal now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); _sendReceipt(paymentId); },
            child: const Text('Send Receipt'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReceipt(String paymentId) async {
    final api = ref.read(adminApiProvider);
    if (api == null || _selectedStudentId == null) return;
    try {
      final res = await api.sendFeeReceipt(_selectedStudentId!, paymentId);
      if (!mounted) return;
      final alreadySent = res['already_sent'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(alreadySent
            ? 'Receipt was already sent to the parent.'
            : 'Receipt sent to parent portal ✓'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _feeField(TextEditingController ctrl, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.currency_rupee, size: 18), isDense: true)),
  );

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

  /// Minimal underline tab bar for the Fee Statement. Purely presentational —
  /// it drives the same [_tabController] the TabBarView below already uses.
  Widget _buildFeeTabSystem() {
    const labelStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.1);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: const Color(0xFF475569),
        labelStyle: labelStyle,
        unselectedLabelStyle: labelStyle,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: const Color(0xFFE2E8F0),
        dividerHeight: 1,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        tabs: const [
          Tab(text: 'Structure'),
          Tab(text: 'Payments'),
          Tab(text: 'Summary'),
        ],
      ),
    );
  }

  Widget _buildStructureView() {
    const standard = [
      {'label': 'Advance Deposit', 'key': 'advance_fees'},
      {'label': 'Term I Fee', 'key': 'term_fee_1'},
      {'label': 'Term II Fee', 'key': 'term_fee_2'},
      {'label': 'Term III Fee', 'key': 'term_fee_3'},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final c in standard)
          _FeeComponentCard(
            label: c['label']!,
            total: (_feeData![c['key']] as num?)?.toDouble() ?? 0.0,
            paid: (_feeData!['${c['key']}_paid'] as num?)?.toDouble() ?? 0.0,
          ),
        for (final cf in (_feeData!['custom_fields'] as List? ?? []))
          _FeeComponentCard(
            label: (cf['label'] as String?) ?? (cf['key'] as String? ?? 'Custom Fee'),
            total: (cf['amount'] as num?)?.toDouble() ?? 0.0,
            paid: (cf['paid'] as num?)?.toDouble() ?? 0.0,
          ),
      ],
    );
  }

  static const _modeLabels = {
    'cash': 'Cash',
    'upi': 'UPI',
    'net_banking': 'Net Banking',
    'cheque': 'Cheque',
    'bank_transfer': 'Bank Transfer',
  };

  String _componentLabel(String key) {
    const standard = {
      'advance_fees': 'Advance Deposit',
      'term_fee_1': 'Term I Fee',
      'term_fee_2': 'Term II Fee',
      'term_fee_3': 'Term III Fee',
    };
    if (standard.containsKey(key)) return standard[key]!;
    for (final cf in (_feeData?['custom_fields'] as List? ?? [])) {
      if (cf['key'] == key) return (cf['label'] as String?) ?? key;
    }
    return key;
  }

  Widget _buildHistoryView() {
    final payments = (_feeData!['payments'] as List? ?? []);
    if (payments.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No payments recorded yet.', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      itemBuilder: (context, i) {
        final p = payments[i] as Map<String, dynamic>;
        final amt = (p['amount_paid'] as num?)?.toDouble() ?? 0.0;
        final date = p['payment_date']?.toString() ?? p['created_at']?.toString() ?? '';
        final rawMode = p['payment_mode']?.toString() ?? 'cash';
        final mode = _modeLabels[rawMode] ?? rawMode;
        final component = _componentLabel(p['component']?.toString() ?? '');
        final paymentId = p['id']?.toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [AppShadows.soft], border: Border.all(color: const Color(0xFFF1F5F9))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.accentGreen.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.receipt_long_rounded, color: AppColors.accentGreen, size: 20)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$component — $mode', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(date.length > 10 ? date.substring(0, 10) : date, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ])),
                  Text('₹${NumberFormat('#,###').format(amt)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.accentGreen)),
                ],
              ),
              if (paymentId != null) ...[
                const Divider(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _sendReceipt(paymentId),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Send Receipt'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary, visualDensity: VisualDensity.compact),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportsView() {
    final total = (_feeData!['total_due'] as num?)?.toDouble() ?? 0.0;
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

/// One editable custom-fee row in the Edit Fee Structure sheet.
class _CustomFeeRow {
  /// Key of an already-saved custom fee; kept on save so recorded payments stay
  /// linked even if the admin renames the label. Null for a newly added row.
  final String? originalKey;
  final TextEditingController label;
  final TextEditingController amount;
  _CustomFeeRow({this.originalKey, required this.label, required this.amount});
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
