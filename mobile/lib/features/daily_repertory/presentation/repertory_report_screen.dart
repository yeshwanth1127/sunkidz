import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/daily_repertory_provider.dart';

class _Slot {
  final TextEditingController timingCtrl;
  final TextEditingController descCtrl;

  _Slot({String timing = '', String desc = ''})
      : timingCtrl = TextEditingController(text: timing),
        descCtrl = TextEditingController(text: desc);

  void dispose() {
    timingCtrl.dispose();
    descCtrl.dispose();
  }

  Map<String, dynamic> toPayload(int order) => {
        'timing': timingCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'slot_order': order,
      };
}

class RepertoryReportScreen extends ConsumerStatefulWidget {
  final String classId;
  final String className;

  const RepertoryReportScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  ConsumerState<RepertoryReportScreen> createState() => _RepertoryReportScreenState();
}

class _RepertoryReportScreenState extends ConsumerState<RepertoryReportScreen> {
  DateTime _selectedDate = DateTime.now();
  List<_Slot> _slots = [];
  String? _savedReportId;
  bool _sentToParents = false;
  bool _loading = true;
  bool _saving = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    for (final s in _slots) {
      s.dispose();
    }
    super.dispose();
  }

  String get _dateStr {
    final d = _selectedDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);

    for (final s in _slots) {
      s.dispose();
    }
    _slots = [];
    _savedReportId = null;
    _sentToParents = false;

    try {
      final service = ref.read(dailyRepertoryServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      final report = await service.getReport(widget.classId, _dateStr);
      if (report != null && report.isNotEmpty) {
        _savedReportId = report['id'] as String?;
        _sentToParents = report['sent_to_parents'] as bool? ?? false;
        final rawSlots = (report['slots'] as List?) ?? [];
        _slots = rawSlots
            .map((s) => _Slot(
                  timing: (s as Map)['timing']?.toString() ?? '',
                  desc: s['description']?.toString() ?? '',
                ))
            .toList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  void _addSlot() => setState(() => _slots.add(_Slot()));

  void _removeSlot(int index) {
    setState(() {
      _slots[index].dispose();
      _slots.removeAt(index);
    });
  }

  Future<void> _save() async {
    final service = ref.read(dailyRepertoryServiceProvider);
    if (service == null) return;
    setState(() => _saving = true);
    try {
      final payload = _slots
          .asMap()
          .entries
          .map((e) => e.value.toPayload(e.key))
          .toList();
      final Map<String, dynamic> result;
      if (_savedReportId == null) {
        result = await service.createReport(widget.classId, _dateStr, payload);
      } else {
        result = await service.updateReport(_savedReportId!, payload);
      }
      if (mounted) {
        setState(() {
          _savedReportId = result['id'] as String?;
          _sentToParents = result['sent_to_parents'] as bool? ?? false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report saved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendToParents() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send to Parents'),
        content: Text(
          'This will notify all parents of ${widget.className}. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _sending = true);
    try {
      final service = ref.read(dailyRepertoryServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      final result = await service.sendToParents(_savedReportId!);
      if (mounted) {
        setState(() => _sentToParents = true);
        final msg = result['message']?.toString() ?? 'Sent to parents!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      _selectedDate = picked;
      _loadReport();
    }
  }

  void _prevDay() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    _loadReport();
  }

  void _nextDay() {
    _selectedDate = _selectedDate.add(const Duration(days: 1));
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.className,
          style: const TextStyle(
            color: Color(0xFF2D2323),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _DateNavBar(
            date: _selectedDate,
            dateLabel: _fmtDate(_selectedDate),
            disabled: _loading,
            onPrev: _prevDay,
            onNext: _nextDay,
            onPick: _pickDate,
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _buildBody(),
          ),
          if (!_loading) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_slots.isEmpty && _savedReportId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No report for this day',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmtDate(_selectedDate),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _addSlot,
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              icon: const Icon(Icons.add),
              label: const Text('Create Report'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        // Column headers
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 32),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'TIMING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),

        ..._slots.asMap().entries.map(
              (e) => _SlotRow(
                key: ObjectKey(e.value),
                slot: e.value,
                onDelete: () => _removeSlot(e.key),
              ),
            ),

        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addSlot,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Row'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: BorderSide(color: Colors.orange.shade300),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 80), // space above bottom bar
      ],
    );
  }

  Widget _buildBottomBar() {
    final canSend = _savedReportId != null && !_sentToParents;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: (canSend && !_sending) ? _sendToParents : null,
              style: FilledButton.styleFrom(
                backgroundColor: _sentToParents ? Colors.grey.shade300 : Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(_sentToParents ? Icons.check_circle_outline : Icons.send_rounded, size: 16),
              label: Text(
                _sentToParents ? 'Sent ✓' : 'Send to Parents',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateNavBar extends StatelessWidget {
  final DateTime date;
  final String dateLabel;
  final bool disabled;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _DateNavBar({
    required this.date,
    required this.dateLabel,
    required this.disabled,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: disabled ? null : onPrev,
            color: Colors.grey.shade700,
          ),
          GestureDetector(
            onTap: disabled ? null : onPick,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 13, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: disabled ? null : onNext,
            color: Colors.grey.shade700,
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final _Slot slot;
  final VoidCallback onDelete;

  const _SlotRow({super.key, required this.slot, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: slot.timingCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: '8:00–9:00 AM',
                  hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: TextField(
                controller: slot.descCtrl,
                style: const TextStyle(fontSize: 13),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What happened / planned…',
                  hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            SizedBox(
              width: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.close, size: 18, color: Colors.red.shade300),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
