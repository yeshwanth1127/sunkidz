import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/student_profile_provider.dart';

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

  Widget _buildRecentPayments() {
    final payments = _feeData!['payments'] as List? ?? [];
    if (payments.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Payments',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...payments.take(5).map((payment) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getComponentLabel(payment['component'] ?? ''),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getModeLabel(payment['payment_mode'] ?? ''),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${(payment['amount_paid'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment['payment_date'] ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
        if (payments.length > 5)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () {
                // Show all payments dialog
              },
              child: Text('View all ${payments.length} payments'),
            ),
          ),
      ],
    );
  }

  String _getComponentLabel(String component) {
    const labels = {
      'advance_fees': 'Advance Fees',
      'term_fee_1': 'Term Fee 1',
      'term_fee_2': 'Term Fee 2',
      'term_fee_3': 'Term Fee 3',
    };
    return labels[component] ?? component;
  }

  String _getModeLabel(String mode) {
    const labels = {
      'cash': '💵 Cash',
      'upi': '📱 UPI',
      'net_banking': '🏦 Net Banking',
      'cheque': '📄 Cheque',
      'bank_transfer': '🏧 Bank Transfer',
    };
    return labels[mode] ?? mode;
  }
}
