import 'package:flutter/material.dart';

class AdmissionsChart extends StatelessWidget {
  final int newEnquiries;
  final int convertedEnquiries;
  final int rejectedEnquiries;
  final int admissionsThisMonth;

  const AdmissionsChart({
    super.key,
    required this.newEnquiries,
    required this.convertedEnquiries,
    required this.rejectedEnquiries,
    required this.admissionsThisMonth,
  });

  @override
  Widget build(BuildContext context) {
    final total = newEnquiries + convertedEnquiries + rejectedEnquiries;
    final maxValue = total > 0 ? total : 10; // Prevent division by zero

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enquiry Status Overview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Chart bars
          _BarItem(
            label: 'New Enquiries',
            value: newEnquiries,
            maxValue: maxValue,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _BarItem(
            label: 'Converted',
            value: convertedEnquiries,
            maxValue: maxValue,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _BarItem(
            label: 'Rejected',
            value: rejectedEnquiries,
            maxValue: maxValue,
            color: Colors.red,
          ),
          const SizedBox(height: 24),
          // Admissions this month
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admissions This Month',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      admissionsThisMonth.toString(),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Icon(
                  Icons.trending_up,
                  size: 32,
                  color: Colors.purple.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const _BarItem({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = maxValue > 0 ? (value / maxValue) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
            Text(
              value.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 24,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
