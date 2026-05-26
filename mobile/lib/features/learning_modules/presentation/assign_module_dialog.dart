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
  Set<String> selectedClassIds = {};
  Set<String> selectedBranchIds = {};
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

  Future<void> _assignToClasses() async {
    if (selectedClassIds.isEmpty) return;

    setState(() => isLoading = true);
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service != null) {
        for (String classId in selectedClassIds) {
          await service.assignModuleToClass(widget.moduleId, classId);
        }
        widget.onAssignmentComplete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Module assigned to ${selectedClassIds.length} class(es) successfully'),
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

  Future<void> _assignToBranches() async {
    if (selectedBranchIds.isEmpty) return;

    setState(() => isLoading = true);
    try {
      final service = ref.read(learningModulesServiceProvider);
      if (service != null) {
        for (String branchId in selectedBranchIds) {
          await service.assignModuleToBranch(widget.moduleId, branchId);
        }
        widget.onAssignmentComplete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Module assigned to ${selectedBranchIds.length} branch(es) successfully'),
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
              'Select Classes',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...classes.map((c) => CheckboxListTile(
              dense: true,
              value: selectedClassIds.contains(c['id']),
              onChanged: isLoading ? null : (value) {
                setState(() {
                  if (value ?? false) {
                    selectedClassIds.add(c['id']!);
                  } else {
                    selectedClassIds.remove(c['id']);
                  }
                });
              },
              title: Text(c['name']!),
            )),
            const SizedBox(height: 20),
            const Text(
              'Select Branches',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...branches.map((b) => CheckboxListTile(
              dense: true,
              value: selectedBranchIds.contains(b['id']),
              onChanged: isLoading ? null : (value) {
                setState(() {
                  if (value ?? false) {
                    selectedBranchIds.add(b['id']!);
                  } else {
                    selectedBranchIds.remove(b['id']);
                  }
                });
              },
              title: Text(b['name']!),
            )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (selectedClassIds.isNotEmpty)
          FilledButton(
            onPressed: isLoading ? null : _assignToClasses,
            child: const Text('Assign to Classes'),
          ),
        if (selectedBranchIds.isNotEmpty)
          FilledButton(
            onPressed: isLoading ? null : _assignToBranches,
            child: const Text('Assign to Branches'),
          ),
      ],
    );
  }
}
