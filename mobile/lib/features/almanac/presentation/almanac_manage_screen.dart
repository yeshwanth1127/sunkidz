import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/api/almanac_provider.dart';
import '../../../core/theme/app_theme.dart';

class AlmanacManageScreen extends ConsumerStatefulWidget {
  const AlmanacManageScreen({
    super.key,
    required this.branchId,
    required this.branchName,
  });

  final String branchId;
  final String branchName;

  @override
  ConsumerState<AlmanacManageScreen> createState() => _AlmanacManageScreenState();
}

class _AlmanacManageScreenState extends ConsumerState<AlmanacManageScreen> {
  Future<void> _addHoliday() async {
    final reasonCtrl = TextEditingController();
    DateTime picked = DateTime.now();
    bool global = false;
    final isAdmin = ref.read(authProvider).role == UserRole.admin;
    final api = ref.read(almanacApiProvider);
    if (api == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: const Text('Add holiday'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Branch: ${widget.branchName}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(DateFormat.yMMMd().format(picked)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: picked,
                      firstDate: DateTime(DateTime.now().year - 1),
                      lastDate: DateTime(DateTime.now().year + 2),
                    );
                    if (p != null) setSt(() => picked = p);
                  },
                ),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                if (isAdmin)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Send to ALL branches'),
                    subtitle: const Text('Holiday will appear for every parent'),
                    value: global,
                    onChanged: (v) => setSt(() => global = v ?? false),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
            ],
          ),
        );
      },
    );
    if (ok != true) return;

    try {
      await api.addHoliday(
        holidayDate: DateFormat('yyyy-MM-dd').format(picked),
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
        branchId: global ? null : widget.branchId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(global
                ? 'Holiday published to all branches'
                : 'Holiday added for ${widget.branchName}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _addEvent() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime picked = DateTime.now();
    bool global = false;
    final isAdmin = ref.read(authProvider).role == UserRole.admin;
    final api = ref.read(almanacApiProvider);
    if (api == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: const Text('Add event / general message'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Branch: ${widget.branchName}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(DateFormat.yMMMd().format(picked)),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: picked,
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 2),
                      );
                      if (p != null) setSt(() => picked = p);
                    },
                  ),
                  TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title *')),
                  TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Description / message')),
                  if (isAdmin)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Broadcast to ALL branches'),
                      subtitle:
                          const Text('Use this for school-wide announcements'),
                      value: global,
                      onChanged: (v) => setSt(() => global = v ?? false),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
            ],
          ),
        );
      },
    );
    if (ok != true || titleCtrl.text.trim().isEmpty) return;

    try {
      await api.createEvent(
        branchId: global ? null : widget.branchId,
        eventDate: DateFormat('yyyy-MM-dd').format(picked),
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        eventType: global ? 'announcement' : 'event',
        isGlobal: global,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(global
                ? 'Broadcast sent to all branches'
                : 'Event added for ${widget.branchName}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider).role == UserRole.admin;
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage — ${widget.branchName}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isAdmin)
            Card(
              color: Colors.indigo.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Tip: tick "Send to all branches" / "Broadcast to all branches" '
                  'when adding a holiday or message that should reach every parent.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.beach_access),
            title: const Text('Add holiday'),
            subtitle: const Text('Branch-specific or all branches'),
            onTap: _addHoliday,
          ),
          ListTile(
            leading: const Icon(Icons.campaign),
            title: const Text('Add event / general message'),
            subtitle: const Text('Reaches every parent if broadcast'),
            onTap: _addEvent,
          ),
        ],
      ),
    );
  }
}
