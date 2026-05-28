import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/admin_provider.dart';
import '../data/learning_modules_provider.dart';

class AssignModuleDialog extends ConsumerStatefulWidget {
  final String moduleId;
  final Function() onAssignmentComplete;

  const AssignModuleDialog({
    super.key,
    required this.moduleId,
    required this.onAssignmentComplete,
  });

  @override
  ConsumerState<AssignModuleDialog> createState() => _AssignModuleDialogState();
}

class _AssignModuleDialogState extends ConsumerState<AssignModuleDialog> {
  Set<String> selectedClassIds = {};
  Set<String> selectedBranchIds = {};
  bool isLoading = false;
  bool isLoadingMeta = true;
  String? error;
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> branches = [];
  Map<String, String>? branchNameById;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta());
  }

  Future<void> _loadMeta() async {
    final api = ref.read(adminApiProvider);
    if (api == null) {
      if (mounted) setState(() => isLoadingMeta = false);
      return;
    }
    try {
      final branchList = await api.getBranches();
      final classList = await api.getClasses();
      final branchNames = <String, String>{};
      for (final branch in branchList) {
        final id = branch['id']?.toString();
        if (id != null) {
          branchNames[id] = branch['name']?.toString() ?? 'Unnamed Branch';
        }
      }
      if (mounted) {
        setState(() {
          branches = branchList;
          classes = classList;
          branchNameById = branchNames;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => isLoadingMeta = false);
    }
  }

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
    final branchNames = branchNameById ?? const <String, String>{};
    final sortedClasses = List<Map<String, dynamic>>.from(classes);
    sortedClasses.sort((a, b) {
      final aBranch = branchNames[a['branch_id']?.toString()] ?? '';
      final bBranch = branchNames[b['branch_id']?.toString()] ?? '';
      final branchCompare = aBranch.compareTo(bBranch);
      if (branchCompare != 0) return branchCompare;
      final aName = a['name']?.toString() ?? '';
      final bName = b['name']?.toString() ?? '';
      return aName.compareTo(bName);
    });

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
            if (isLoadingMeta)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (classes.isEmpty)
              const Text('No classes found')
            else
              ...sortedClasses.map((c) {
                final id = c['id']?.toString();
                if (id == null) return const SizedBox.shrink();
                final name = c['name']?.toString() ?? 'Unnamed Class';
                final branchId = c['branch_id']?.toString();
                final branchName = branchNames[branchId] ?? 'Unknown Branch';
                return CheckboxListTile(
                  dense: true,
                  value: selectedClassIds.contains(id),
                  onChanged: isLoading ? null : (value) {
                    setState(() {
                      if (value ?? false) {
                        selectedClassIds.add(id);
                      } else {
                        selectedClassIds.remove(id);
                      }
                    });
                  },
                  title: Text(name),
                  subtitle: Text(branchName),
                );
              }),
            const SizedBox(height: 20),
            const Text(
              'Select Branches',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (isLoadingMeta)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (branches.isEmpty)
              const Text('No branches found')
            else
              ...branches.map((b) {
                final id = b['id']?.toString();
                if (id == null) return const SizedBox.shrink();
                final name = b['name']?.toString() ?? 'Unnamed Branch';
                return CheckboxListTile(
                  dense: true,
                  value: selectedBranchIds.contains(id),
                  onChanged: isLoading ? null : (value) {
                    setState(() {
                      if (value ?? false) {
                        selectedBranchIds.add(id);
                      } else {
                        selectedBranchIds.remove(id);
                      }
                    });
                  },
                  title: Text(name),
                );
              }),
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
