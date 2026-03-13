import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/student_profile_provider.dart';
import '../../admin/presentation/fee_receipt_pdf.dart';

class ParentFeesScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> student;
  final Map<String, dynamic>? initialFeeData;

  const ParentFeesScreen({super.key, required this.student, this.initialFeeData});

  @override
  ConsumerState<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

class _ParentFeesScreenState extends ConsumerState<ParentFeesScreen> {
  Map<String, dynamic>? _feeData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Use initial fee data if provided
    if (widget.initialFeeData != null) {
      _feeData = widget.initialFeeData;
      _loading = false;
    }
    _loadFees();
  }

  Future<void> _loadFees() async {
    final api = ref.read(studentProfileApiProvider);
    if (api == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      if (api.getStudentFees == null) {
        setState(() => _loading = false);
        return;
      }
      final res = await api.getStudentFees!(widget.student['id'] as String);
      if (mounted) {
        setState(() {
          _feeData = res;
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading fees: $e');
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(
        title: const Text('Fee Details'),
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
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFees,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _feeData == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text('Fee structure not set up yet'),
                      ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFees,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildStudentHeader(),
                          const SizedBox(height: 24),
                          _buildTotalSummary(),
                          const SizedBox(height: 24),
                          _buildFeeBreakdown(),
                          const SizedBox(height: 24),
                          _buildRecentPayments(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStudentHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _feeData!['student_name'] ?? 'N/A',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Admission #: ${_feeData!['admission_number'] ?? 'N/A'}',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTotalSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fee Summary',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[400]!, Colors.blue[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryMetric(
                'Total Due',
                '₹${(_feeData!['total_due'] ?? 0.0).toStringAsFixed(2)}',
                Colors.white,
              ),
              _buildSummaryMetric(
                'Total Paid',
                '₹${(_feeData!['total_paid'] ?? 0.0).toStringAsFixed(2)}',
                Colors.white,
              ),
              _buildSummaryMetric(
                'Balance',
                '₹${(_feeData!['total_balance'] ?? 0.0).toStringAsFixed(2)}',
                Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryMetric(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fee Breakdown',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildFeeComponentCard(
          'Advance Fees',
          _feeData!['advance_fees'] ?? 0.0,
          _feeData!['advance_fees_paid'] ?? 0.0,
          _feeData!['advance_fees_balance'] ?? 0.0,
        ),
        const SizedBox(height: 12),
        _buildFeeComponentCard(
          'Term Fee 1',
          _feeData!['term_fee_1'] ?? 0.0,
          _feeData!['term_fee_1_paid'] ?? 0.0,
          _feeData!['term_fee_1_balance'] ?? 0.0,
        ),
        const SizedBox(height: 12),
        _buildFeeComponentCard(
          'Term Fee 2',
          _feeData!['term_fee_2'] ?? 0.0,
          _feeData!['term_fee_2_paid'] ?? 0.0,
          _feeData!['term_fee_2_balance'] ?? 0.0,
        ),
        const SizedBox(height: 12),
        _buildFeeComponentCard(
          'Term Fee 3',
          _feeData!['term_fee_3'] ?? 0.0,
          _feeData!['term_fee_3_paid'] ?? 0.0,
          _feeData!['term_fee_3_balance'] ?? 0.0,
        ),
        ...(_feeData!['custom_fields'] as List? ?? []).map((cf) => Column(
          children: [
            const SizedBox(height: 12),
            _buildFeeComponentCard(
              cf['label'] as String? ?? cf['key'] as String,
              (cf['amount'] as num?)?.toDouble() ?? 0.0,
              (cf['paid'] as num?)?.toDouble() ?? 0.0,
              (cf['balance'] as num?)?.toDouble() ?? 0.0,
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildFeeComponentCard(
    String title,
    double dueAmount,
    double paidAmount,
    double balance,
  ) {
    final isFullyPaid = balance <= 0;
    return Card(
      elevation: 0,
      color: isFullyPaid ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFullyPaid ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isFullyPaid ? 'PAID' : 'PENDING',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFeeMetric('Due', dueAmount),
                _buildFeeMetric('Paid', paidAmount),
                _buildFeeMetric('Balance', balance),
              ],
            ),
            if (balance > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: paidAmount / dueAmount,
                minHeight: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFullyPaid ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeeMetric(String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static const _componentKeys = [
    'advance_fees',
    'term_fee_1',
    'term_fee_2',
    'term_fee_3',
  ];

  static const _componentLabels = {
    'advance_fees': 'Advance Fees',
    'term_fee_1': 'Term Fee 1',
    'term_fee_2': 'Term Fee 2',
    'term_fee_3': 'Term Fee 3',
  };

  static const _modeLabels = {
    'cash': 'Cash',
    'upi': 'UPI',
    'net_banking': 'Net Banking',
    'cheque': 'Cheque',
    'bank_transfer': 'Bank Transfer',
  };

  Widget _buildRecentPayments() {
    final allPayments = (_feeData!['payments'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    if (allPayments.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group by component
    final customFields = (_feeData!['custom_fields'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final allComponentKeys = [
      ..._componentKeys,
      ...customFields.map((cf) => cf['key'] as String),
    ];
    final allLabels = {
      ..._componentLabels,
      for (final cf in customFields) cf['key'] as String: cf['label'] as String,
    };
    // Group by component
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final key in allComponentKeys) {
      grouped[key] = allPayments.where((p) => p['component'] == key).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...allComponentKeys.map((comp) {
          final compPayments = grouped[comp] ?? [];
          if (compPayments.isEmpty) return const SizedBox.shrink();
          final totalPaid = compPayments.fold<double>(
            0.0,
            (sum, p) =>
                sum + ((p['amount_paid'] as num?)?.toDouble() ?? 0.0),
          );
          final label = allLabels[comp] ?? comp;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: ExpansionTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green[100],
                child:
                    Icon(Icons.check, size: 16, color: Colors.green[700]),
              ),
              title: Text(
                label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                '${compPayments.length} transaction${compPayments.length != 1 ? 's' : ''}'
                ' • ₹${totalPaid.toStringAsFixed(2)} paid',
                style:
                    TextStyle(color: Colors.green[800], fontSize: 12),
              ),
              children: compPayments
                  .map((payment) => _buildPaymentRow(payment))
                  .toList(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPaymentRow(Map<String, dynamic> payment) {
    final dateRaw = payment['payment_date'] as String?;
    final dateStr = dateRaw != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(dateRaw))
        : 'N/A';
    final amount =
        (payment['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final mode =
        _modeLabels[payment['payment_mode']] ?? payment['payment_mode'] ?? 'N/A';

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        color: Colors.white,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: const Icon(Icons.receipt_long_outlined,
            color: Colors.blueGrey, size: 20),
        title: Text(
          '₹${amount.toStringAsFixed(2)}',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '$dateStr  •  $mode',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.print_outlined,
              color: Colors.indigo, size: 20),
          tooltip: 'Print / Download Receipt',
          onPressed: () => FeeReceiptPdf.printReceipt(
            payment: payment,
            feeData: _feeData!,
            student: widget.student,
          ),
        ),
      ),
    );
  }

}
