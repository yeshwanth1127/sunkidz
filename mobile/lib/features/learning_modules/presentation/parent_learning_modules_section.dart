import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ParentLearningModulesSection extends StatelessWidget {
  final String studentId;

  const ParentLearningModulesSection({
    super.key,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Learning Modules',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/learning-modules'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade100.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.calendar_today, color: Colors.orange.shade700, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'View Learning Calendar',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Day-wise videos for your child\'s class',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.orange.shade400),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
