import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/parent_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/parent_drawer.dart';
import '../../admin/presentation/fee_receipt_pdf.dart';

class ParentReceiptsScreen extends ConsumerStatefulWidget {
  const ParentReceiptsScreen({super.key});

  @override
  ConsumerState<ParentReceiptsScreen> createState() => _ParentReceiptsScreenState();
}

class _ParentReceiptsScreenState extends ConsumerState<ParentReceiptsScreen> {
  List<Map<String, dynamic>> _receipts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(parentApiProvider);
    if (api == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await api.getReceipts();
      if (mounted) {
        setState(() {
          _receipts = List<Map<String, dynamic>>.from(res['receipts'] as List? ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _downloadReceipt(Map<String, dynamic> receipt) {
    final payment = {
      'id': receipt['payment_id'],
      'component': receipt['component'],
      'amount_paid': receipt['amount_paid'],
      'payment_mode': receipt['payment_mode'],
      'payment_date': receipt['payment_date'],
      'created_at': receipt['created_at'],
    };
    final feeData = Map<String, dynamic>.from(
      (receipt['fee_data'] as Map<String, dynamic>?) ?? {},
    );
    feeData['student_name'] = receipt['student_name'];
    feeData['admission_number'] = receipt['admission_number'];

    FeeReceiptPdf.printReceipt(
      payment: payment,
      feeData: feeData,
      student: {
        'name': receipt['student_name'],
        'admission_number': receipt['admission_number'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const ParentDrawer(),
      appBar: AppBar(
        title: const Text('Fee Receipts'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No receipts yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Receipts will appear here once the school pushes them.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Group by student name
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in _receipts) {
      final name = r['student_name'] as String? ?? 'Unknown';
      grouped.putIfAbsent(name, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...entry.value.map((receipt) => _ReceiptCard(
              receipt: receipt,
              onDownload: () => _downloadReceipt(receipt),
            )),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final VoidCallback onDownload;

  const _ReceiptCard({required this.receipt, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final amount = (receipt['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final moneyFmt = NumberFormat('#,##0.00', 'en_IN');
    final componentLabel = receipt['component_label'] as String? ?? receipt['component'] ?? '—';
    final mode = receipt['payment_mode'] as String? ?? '—';
    final receiptRef = receipt['receipt_ref'] as String? ?? '—';
    final dateRaw = receipt['payment_date'] as String?;
    final dateStr = dateRaw != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(dateRaw))
        : '—';
    final pushedRaw = receipt['created_at'] as String?;
    final pushedStr = pushedRaw != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(pushedRaw))
        : '—';

    final feeData = receipt['fee_data'] as Map<String, dynamic>? ?? {};
    final balance = (feeData['total_balance'] as num?)?.toDouble() ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#$receiptRef',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Rs. ${moneyFmt.format(amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Row(icon: Icons.category_outlined, label: componentLabel),
            _Row(icon: Icons.payment_outlined, label: mode),
            _Row(icon: Icons.calendar_today_outlined, label: 'Paid: $dateStr'),
            if (balance > 0)
              _Row(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Balance: Rs. ${moneyFmt.format(balance)}',
                color: Colors.red.shade700,
              )
            else
              _Row(icon: Icons.check_circle_outline, label: 'Fully paid', color: Colors.green.shade700),
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('Pushed: $pushedStr', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Download PDF'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _Row({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade700;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: c)),
        ],
      ),
    );
  }
}
