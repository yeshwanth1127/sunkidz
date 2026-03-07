import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/api/student_profile_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';

class AdminFeeManagementScreen extends ConsumerStatefulWidget {
  const AdminFeeManagementScreen({
    super.key,
    required this.branchId,
    this.studentId,
  });

  final String branchId;
  final String? studentId;

  @override
  ConsumerState<AdminFeeManagementScreen> createState() =>
      _AdminFeeManagementScreenState();
}

class _AdminFeeManagementScreenState
    extends ConsumerState<AdminFeeManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _students = [];
  String? _selectedBranchId;
  String? _selectedStudentId;
  Map<String, dynamic>? _selectedStudent;
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _feeData;
  bool _loadingFees = false;
  String? _feeError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedStudentId = widget.studentId;
    _selectedBranchId = widget.branchId.isEmpty ? null : widget.branchId;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = await api.getBranches();
      setState(() {
        _branches = List<Map<String, dynamic>>.from(branches);
        _loading = false;
        if (_branches.length == 1 && _selectedBranchId == null) {
          _selectedBranchId = _branches[0]['id'];
          _loadStudents();
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedBranchId == null) return;
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final admissions = await api.getAdmissions(branchId: _selectedBranchId!);
      setState(() {
        _students = List<Map<String, dynamic>>.from(admissions);
        _loading = false;
      });
      if (_selectedStudentId != null) {
        await _loadFees();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _selectBranch(String branchId) {
    setState(() {
      _selectedBranchId = branchId;
      _selectedStudentId = null;
      _selectedStudent = null;
      _students = [];
      _feeData = null;
    });
    _loadStudents();
  }

  Future<void> _loadFees() async {
    if (_selectedStudentId == null) return;
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    setState(() {
      _loadingFees = true;
      _feeError = null;
    });
    try {
      final fees = await api.getStudentFees(_selectedStudentId!);
      setState(() {
        _feeData = fees;
        _loadingFees = false;
      });
    } catch (e) {
      setState(() {
        _feeError = e.toString();
        _loadingFees = false;
      });
    }
  }

  void _selectStudent(String studentId) {
    final student = _students.firstWhere(
      (s) => s['id'] == studentId,
      orElse: () => {},
    );
    setState(() {
      _selectedStudentId = studentId;
      _selectedStudent = student.isNotEmpty ? student : null;
    });
    _loadFees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: const Text('Fee Management'),
        bottom: _selectedStudentId != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Fee Structure'),
                  Tab(text: 'Record Payments'),
                  Tab(text: 'Reports'),
                ],
              )
            : null,
      ),
      body: Container(
        color: Colors.grey[50],
        child: _buildMainContent(context),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (_selectedBranchId == null) {
      return _buildBranchSelectionFlow();
    }
    return _buildFeesFlow(context);
  }

  Widget _buildBranchSelectionFlow() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select a Branch',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: _buildBranchSelector(),
        ),
      ],
    );
  }

  Widget _buildFeesFlow(BuildContext context) {
    if (_selectedStudentId == null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select a Student',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: _buildStudentList(),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _selectedStudentId = null;
                  _selectedStudent = null;
                  _feeData = null;
                }),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Back to Students',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedBranchId = null;
                  _selectedStudentId = null;
                  _selectedStudent = null;
                  _students = [];
                  _feeData = null;
                }),
                child: Row(
                  children: [
                    const Icon(Icons.home, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Branches',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFeeStructureTab(),
              _buildRecordPaymentsTab(),
              _buildReportsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBranchSelector() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_branches.isEmpty) {
      return const Center(child: Text('No branches available'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _branches.length,
      itemBuilder: (context, index) {
        final branch = _branches[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(branch['name'] ?? 'N/A'),
            subtitle: Text(branch['address'] ?? ''),
            onTap: () => _selectBranch(branch['id']),
            trailing: const Icon(Icons.arrow_forward),
          ),
        );
      },
    );
  }

  Widget _buildStudentList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final isSelected = _selectedStudentId == student['id'];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isSelected ? Colors.blue[50] : null,
          child: ListTile(
            title: Text(student['full_name'] ?? student['name'] ?? 'N/A'),
            subtitle: Text(student['admission_number'] ?? ''),
            onTap: () => _selectStudent(student['id']),
            trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : const Icon(Icons.arrow_forward),
          ),
        );
      },
    );
  }

  Widget _buildFeeStructureTab() {
    if (_loadingFees) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feeError != null) {
      return Center(child: Text('Error: $_feeError'));
    }
    if (_feeData == null) {
      return Center(
        child: ElevatedButton(
          onPressed: () => _showSetupFeeStructure(),
          child: const Text('Setup Fee Structure'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student: ${_selectedStudent?['full_name'] ?? _selectedStudent?['name'] ?? _feeData?['student_name'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildFeeCard(
              'Advance Fees',
              _feeData!['advance_fees'] ?? 0.0,
              _feeData!['advance_fees_paid'] ?? 0.0,
            ),
            const SizedBox(height: 16),
            _buildFeeCard(
              'Term Fee 1',
              _feeData!['term_fee_1'] ?? 0.0,
              _feeData!['term_fee_1_paid'] ?? 0.0,
            ),
            const SizedBox(height: 16),
            _buildFeeCard(
              'Term Fee 2',
              _feeData!['term_fee_2'] ?? 0.0,
              _feeData!['term_fee_2_paid'] ?? 0.0,
            ),
            const SizedBox(height: 16),
            _buildFeeCard(
              'Term Fee 3',
              _feeData!['term_fee_3'] ?? 0.0,
              _feeData!['term_fee_3_paid'] ?? 0.0,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showSetupFeeStructure(),
              child: const Text('Edit Fee Structure'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordPaymentsTab() {
    if (_loadingFees) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feeError != null) {
      return Center(child: Text('Error: $_feeError'));
    }
    if (_feeData == null) {
      return const Center(child: Text('No fee structure found'));
    }

    final payments = _feeData!['payments'] as List? ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            children: [
              ElevatedButton(
                onPressed: () => _showRecordPaymentDialog(),
                child: const Text('Record New Payment'),
              ),
              const SizedBox(height: 16),
              if (payments.isEmpty)
                const Text('No payments recorded yet')
              else
                const Divider(),
            ],
          );
        }
        final payment = payments[index - 1] as Map<String, dynamic>;
        return PaymentCard(payment: payment);
      },
    );
  }

  Widget _buildReportsTab() {
    if (_loadingFees) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feeError != null) {
      return Center(child: Text('Error: $_feeError'));
    }
    if (_feeData == null) {
      return const Center(child: Text('No fee structure found'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fee Summary',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              'Total Due',
              _feeData!['total_due']?.toStringAsFixed(2) ?? '0.00',
              Colors.red[100],
            ),
            _buildSummaryRow(
              'Total Paid',
              _feeData!['total_paid']?.toStringAsFixed(2) ?? '0.00',
              Colors.green[100],
            ),
            _buildSummaryRow(
              'Total Balance',
              _feeData!['total_balance']?.toStringAsFixed(2) ?? '0.00',
              Colors.orange[100],
            ),
            const SizedBox(height: 24),
            Text(
              'Component-wise Balance',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildBalanceItem(
              'Advance Fees',
              _feeData!['advance_fees_balance']?.toStringAsFixed(2) ?? '0.00',
            ),
            _buildBalanceItem(
              'Term Fee 1',
              _feeData!['term_fee_1_balance']?.toStringAsFixed(2) ?? '0.00',
            ),
            _buildBalanceItem(
              'Term Fee 2',
              _feeData!['term_fee_2_balance']?.toStringAsFixed(2) ?? '0.00',
            ),
            _buildBalanceItem(
              'Term Fee 3',
              _feeData!['term_fee_3_balance']?.toStringAsFixed(2) ?? '0.00',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeCard(String title, double amount, double paid) {
    final balance = amount - paid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCol('Due', amount),
                _buildMetricCol('Paid', paid),
                _buildMetricCol('Balance', balance),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, double value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '₹${value.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, Color? bgColor) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            '₹$value',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, String balance) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '₹$balance',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showSetupFeeStructure() {
    showDialog(
      context: context,
      builder: (context) => SetupFeeStructureDialog(
        studentId: _selectedStudentId!,
        existingData: _feeData,
        onSaved: () {
          _loadFees();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showRecordPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => RecordPaymentDialog(
        studentId: _selectedStudentId!,
        onSaved: () {
          _loadFees();
          Navigator.pop(context);
        },
      ),
    );
  }
}

class SetupFeeStructureDialog extends ConsumerStatefulWidget {
  const SetupFeeStructureDialog({
    super.key,
    required this.studentId,
    this.existingData,
    required this.onSaved,
  });

  final String studentId;
  final Map<String, dynamic>? existingData;
  final VoidCallback onSaved;

  @override
  ConsumerState<SetupFeeStructureDialog> createState() =>
      _SetupFeeStructureDialogState();
}

class _SetupFeeStructureDialogState
    extends ConsumerState<SetupFeeStructureDialog> {
  late TextEditingController _advanceController;
  late TextEditingController _term1Controller;
  late TextEditingController _term2Controller;
  late TextEditingController _term3Controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _advanceController = TextEditingController(
      text: (widget.existingData?['advance_fees'] ?? 0.0).toStringAsFixed(2),
    );
    _term1Controller = TextEditingController(
      text: (widget.existingData?['term_fee_1'] ?? 0.0).toStringAsFixed(2),
    );
    _term2Controller = TextEditingController(
      text: (widget.existingData?['term_fee_2'] ?? 0.0).toStringAsFixed(2),
    );
    _term3Controller = TextEditingController(
      text: (widget.existingData?['term_fee_3'] ?? 0.0).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _advanceController.dispose();
    _term1Controller.dispose();
    _term2Controller.dispose();
    _term3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Setup Fee Structure'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _advanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Advance Fees',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _term1Controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Term Fee 1',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _term2Controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Term Fee 2',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _term3Controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Term Fee 3',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final api = ref.read(studentProfileApiProvider);
    if (api?.updateStudentFees == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API not available')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await api!.updateStudentFees!(
        widget.studentId,
        {
          'advance_fees': double.parse(_advanceController.text),
          'term_fee_1': double.parse(_term1Controller.text),
          'term_fee_2': double.parse(_term2Controller.text),
          'term_fee_3': double.parse(_term3Controller.text),
        },
      );
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fee structure saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class RecordPaymentDialog extends ConsumerStatefulWidget {
  const RecordPaymentDialog({
    super.key,
    required this.studentId,
    required this.onSaved,
  });

  final String studentId;
  final VoidCallback onSaved;

  @override
  ConsumerState<RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
  late TextEditingController _amountController;
  String _selectedComponent = 'advance_fees';
  String _selectedMode = 'cash';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Fee Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedComponent,
              items: const [
                DropdownMenuItem(value: 'advance_fees', child: Text('Advance Fees')),
                DropdownMenuItem(value: 'term_fee_1', child: Text('Term Fee 1')),
                DropdownMenuItem(value: 'term_fee_2', child: Text('Term Fee 2')),
                DropdownMenuItem(value: 'term_fee_3', child: Text('Term Fee 3')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedComponent = value);
                }
              },
              decoration: const InputDecoration(labelText: 'Fee Component'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount Paid',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedMode,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
                DropdownMenuItem(value: 'net_banking', child: Text('Net Banking')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMode = value);
                }
              },
              decoration: const InputDecoration(labelText: 'Payment Mode'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Record'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter amount')),
      );
      return;
    }

    final api = ref.read(studentProfileApiProvider);
    if (api?.recordFeePayment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API not available')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await api!.recordFeePayment!(
        widget.studentId,
        {
          'component': _selectedComponent,
          'amount_paid': double.parse(_amountController.text),
          'payment_mode': _selectedMode,
        },
      );
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class PaymentCard extends StatelessWidget {
  const PaymentCard({super.key, required this.payment});

  final Map<String, dynamic> payment;

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getComponentLabel(payment['component'] ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  _getModeLabel(payment['payment_mode'] ?? ''),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${(payment['amount_paid'] ?? 0.0).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  payment['payment_date'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
