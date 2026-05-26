import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/learning_modules_provider.dart';
import '../data/learning_modules_service.dart';

class AssignModuleDialog extends ConsumerStatefulWidget {
  final String moduleId;
  final Function() onAssignmentComplete;

  const AssignModuleDialog({
    Key? key,
    required this.moduleId,
    required this.onAssignmentComplete,
  }) : super(key: key);

  @override
  ConsumerState<AssignModuleDialog> createState() => _AssignModuleDialogState();
}

class _AssignModuleDialogState extends ConsumerState<AssignModuleDialog> {
  List<String> selectedStudentIds = [];
  bool isLoading = false;
  String? error;

  Future<void> _assignModule() async {
    if (selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service != null) {
        for (final studentId in selectedStudentIds) {
          await service.assignModuleToStudent(widget.moduleId, studentId);
        }
        widget.onAssignmentComplete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Module assigned successfully'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Module to Students'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          const SizedBox(
            width: 300,
            height: 200,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Note: Integration with student list requires fetching from API.\n'
            'For now, enter student IDs manually.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!isLoading)
          ElevatedButton(
            onPressed: selectedStudentIds.isNotEmpty ? _assignModule : null,
            child: const Text('Assign'),
          ),
      ],
    );
  }
}
