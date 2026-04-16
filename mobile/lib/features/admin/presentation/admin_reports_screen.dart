import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_provider.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  Map<String, dynamic>? _analyticsData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final api = ref.read(adminApiProvider);
    if (api == null) {
      setState(() {
        _error = 'API not available';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await api.getAnalytics();
      if (mounted) {
        setState(() {
          _analyticsData = data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(title: const Text('Analytics & Reports'), elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAnalytics,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRevenueCard(),
                    const SizedBox(height: 24),
                    _buildStudentsByGradeChart(),
                    const SizedBox(height: 24),
                    _buildEnquiriesAdmissionsChart(),
                    const SizedBox(height: 24),
                    _buildEnquiryStatsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRevenueCard() {
    final revenue = _analyticsData?['revenue'] as Map<String, dynamic>?;
    if (revenue == null) return const SizedBox();

    final totalCollected =
        (revenue['total_collected'] as num?)?.toDouble() ?? 0.0;
    final totalDue = (revenue['total_due'] as num?)?.toDouble() ?? 0.0;
    final outstanding = (revenue['outstanding'] as num?)?.toDouble() ?? 0.0;
    final collectionRate =
        (revenue['collection_rate'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Revenue Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${collectionRate.toStringAsFixed(1)}% collected',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _RevenueStatItem(
                    label: 'Total Collected',
                    amount: totalCollected,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _RevenueStatItem(
                    label: 'Total Due',
                    amount: totalDue,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RevenueStatItem(
                    label: 'Outstanding',
                    amount: outstanding,
                    color: Colors.orange,
                  ),
                ),
                Expanded(child: Container()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsByGradeChart() {
    final studentsByGrade =
        _analyticsData?['students_by_grade'] as List<dynamic>?;
    if (studentsByGrade == null || studentsByGrade.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No student data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Students by Grade and Branch',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sections: List.generate(studentsByGrade.length, (
                          index,
                        ) {
                          final item =
                              studentsByGrade[index] as Map<String, dynamic>;
                          final count = (item['count'] as num?)?.toInt() ?? 0;
                          final total = studentsByGrade.fold<int>(
                            0,
                            (sum, e) =>
                                sum + ((e['count'] as num?)?.toInt() ?? 0),
                          );
                          final percentage = total > 0
                              ? (count / total * 100)
                              : 0.0;

                          return PieChartSectionData(
                            color: colors[index % colors.length],
                            value: count.toDouble(),
                            title: '${percentage.toStringAsFixed(1)}%',
                            radius: 80,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }),
                        sectionsSpace: 2,
                        centerSpaceRadius: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: studentsByGrade.length,
                      itemBuilder: (context, index) {
                        final item =
                            studentsByGrade[index] as Map<String, dynamic>;
                        final branch = item['branch'] as String? ?? 'Unknown';
                        final grade = item['grade'] as String? ?? '—';
                        final count = (item['count'] as num?)?.toInt() ?? 0;
                        final previousBranch = index > 0
                            ? ((studentsByGrade[index - 1]
                                          as Map<String, dynamic>)['branch']
                                      as String? ??
                                  'Unknown')
                            : null;
                        final showBranchHeader = previousBranch != branch;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showBranchHeader)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    bottom: 4,
                                  ),
                                  child: Text(
                                    branch,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              Row(
                                children: [
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: colors[index % colors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$grade: $count',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnquiriesAdmissionsChart() {
    final enquiries = _analyticsData?['enquiries_by_month'] as List<dynamic>?;
    final admissions = _analyticsData?['admissions_by_month'] as List<dynamic>?;

    if (enquiries == null || admissions == null) {
      return const SizedBox();
    }

    final maxValue = [
      ...enquiries.map((e) => (e['count'] as num?)?.toDouble() ?? 0.0),
      ...admissions.map((e) => (e['count'] as num?)?.toDouble() ?? 0.0),
    ].reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enquiries & Admissions (Last 6 Months)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  maxY: maxValue + 5,
                  barGroups: List.generate(enquiries.length, (index) {
                    final enqCount =
                        (enquiries[index]['count'] as num?)?.toDouble() ?? 0.0;
                    final admCount =
                        (admissions[index]['count'] as num?)?.toDouble() ?? 0.0;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: enqCount,
                          color: Colors.blue,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: admCount,
                          color: Colors.green,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                      barsSpace: 4,
                    );
                  }),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < 0 ||
                              value.toInt() >= enquiries.length) {
                            return const SizedBox();
                          }
                          final month =
                              enquiries[value.toInt()]['month'] as String? ??
                              '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              month.split(
                                ' ',
                              )[0], // Show only month abbreviation
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ChartLegend(color: Colors.blue, label: 'Enquiries'),
                const SizedBox(width: 24),
                _ChartLegend(color: Colors.green, label: 'Admissions'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnquiryStatsCard() {
    final enquiryStats =
        _analyticsData?['enquiry_stats'] as Map<String, dynamic>?;
    if (enquiryStats == null) return const SizedBox();

    final total = (enquiryStats['total'] as num?)?.toInt() ?? 0;
    final converted = (enquiryStats['converted'] as num?)?.toInt() ?? 0;
    final pending = (enquiryStats['pending'] as num?)?.toInt() ?? 0;
    final rejected = (enquiryStats['rejected'] as num?)?.toInt() ?? 0;
    final conversionRate =
        (enquiryStats['conversion_rate'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enquiry Conversion Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Pie chart + stats side by side
            if (total > 0) ...[
              Row(
                children: [
                  // Pie chart
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            if (converted > 0)
                              PieChartSectionData(
                                value: converted.toDouble(),
                                title: '$converted',
                                color: Colors.green,
                                radius: 60,
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            if (pending > 0)
                              PieChartSectionData(
                                value: pending.toDouble(),
                                title: '$pending',
                                color: Colors.orange,
                                radius: 60,
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            if (rejected > 0)
                              PieChartSectionData(
                                value: rejected.toDouble(),
                                title: '$rejected',
                                color: Colors.red,
                                radius: 60,
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Legend
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _EnquiryStatItem(
                          label: 'Total Enquiries',
                          value: total,
                          color: Colors.blue,
                          icon: Icons.people,
                        ),
                        const SizedBox(height: 12),
                        _EnquiryStatItem(
                          label: 'Converted',
                          value: converted,
                          color: Colors.green,
                          icon: Icons.check_circle,
                        ),
                        const SizedBox(height: 12),
                        _EnquiryStatItem(
                          label: 'Pending',
                          value: pending,
                          color: Colors.orange,
                          icon: Icons.pending,
                        ),
                        const SizedBox(height: 12),
                        _EnquiryStatItem(
                          label: 'Rejected',
                          value: rejected,
                          color: Colors.red,
                          icon: Icons.cancel,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No enquiry data available',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.trending_up, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Conversion Rate: ${conversionRate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueStatItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _RevenueStatItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          formatter.format(amount),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EnquiryStatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _EnquiryStatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
