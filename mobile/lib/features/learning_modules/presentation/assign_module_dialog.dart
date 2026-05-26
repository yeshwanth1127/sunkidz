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
  String? selectedClassId;
  String? selectedBranchId;
  bool isLoading = false;
  String? error;

  // Sample classes and branches - in a real app, fetch these from API
  final List<Map<String, String>> classes = [
    {'id': 'class-kg', 'name': 'Kindergarten'},
    {'id': 'class-1', 'name': 'Class 1'},
    {'id': 'class-2', 'name': 'Class 2'},
    {'id': 'class-3', 'name': 'Class 3'},
    {'id': 'class-4', 'name': 'Class 4'},
    {'id': 'class-5', 'name': 'Class 5'},
  ];

  final List<Map<String, String>> branches = [
    {'id': 'branch-main', 'name': 'Main Branch'},
    {'id': 'branch-secondary', 'name': 'Secondary Branch'},
  ];

  Future<void> _assignToClass() async {
    if (selectedClassId == null) return;

    setState(() => isLoading = true);
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service != null) {
        await service.assignModuleToClass(widget.moduleId, selectedClassId!);
        widget.onAssignmentComplete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Module assigned to class successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => error = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _assignToBranch() async {
    if (selectedBranchId == null) return;

    setState(() => isLoading = true);
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service != null) {
        await service.assignModuleToBranch(widget.moduleId, selectedBranchId!);
        widget.onAssignmentComplete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Module assigned to branch successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => error = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Module'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                  ),
                ),
              ),
            const Text(
              'Assign to Class',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedClassId,
              hint: const Text('Select a class'),
              onChanged: isLoading ? null : (value) => setState(() => selectedClassId = value),
              items: classes
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['id'],
                      child: Text(c['name']!),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Assign to Branch',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedBranchId,
              hint: const Text('Select a branch'),
              onChanged: isLoading ? null : (value) => setState(() => selectedBranchId = value),
              items: branches
                  .map(
                    (b) => DropdownMenuItem(
                      value: b['id'],
                      child: Text(b['name']!),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (selectedClassId != null)
          FilledButton(
            onPressed: isLoading ? null : _assignToClass,
            child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Assign to Class'),
          ),
        if (selectedBranchId != null)
          FilledButton(
            onPressed: isLoading ? null : _assignToBranch,
            child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Assign to Branch'),
          ),
      ],
    );
  }
}
