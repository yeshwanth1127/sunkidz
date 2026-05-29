import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/daily_report_provider.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String classId;
  final String className;

  const ReportScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _report;
  List<TextEditingController> _timingCtrls = [];
  List<TextEditingController> _descCtrls = [];
  bool _loading = true;
  bool _isSaving = false;
  bool _isSending = false;
  bool _isParsingExcel = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _timingCtrls) { c.dispose(); }
    for (final c in _descCtrls) { c.dispose(); }
  }

  // Rebuilds controllers from the current _report slots (or empty list).
  void _rebuildControllers(List<Map<String, dynamic>> slots) {
    _disposeControllers();
    _timingCtrls = slots
        .map((s) => TextEditingController(text: s['timing']?.toString() ?? ''))
        .toList();
    _descCtrls = slots
        .map((s) => TextEditingController(text: s['description']?.toString() ?? ''))
        .toList();
  }

  List<Map<String, dynamic>> _buildSlotsFromControllers() {
    return List.generate(_timingCtrls.length, (i) => {
          'timing': _timingCtrls[i].text.trim(),
          'description': _descCtrls[i].text.trim(),
          'slot_order': i,
        });
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  String _fmtDate(DateTime d) => DateFormat('MMM d, yyyy').format(d);

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    _disposeControllers();
    _timingCtrls = [];
    _descCtrls = [];
    _report = null;
    try {
      final service = ref.read(dailyReportServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      final data = await service.getReport(widget.classId, _dateStr);
      final slots = data != null
          ? List<Map<String, dynamic>>.from(data['slots'] ?? [])
          : <Map<String, dynamic>>[];
      _report = data;
      _rebuildControllers(slots);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _addSlot() => setState(() {
        _timingCtrls.add(TextEditingController());
        _descCtrls.add(TextEditingController());
      });

  void _removeSlot(int i) => setState(() {
        _timingCtrls[i].dispose();
        _descCtrls[i].dispose();
        _timingCtrls.removeAt(i);
        _descCtrls.removeAt(i);
      });

  Future<void> _save() async {
    final service = ref.read(dailyReportServiceProvider);
    if (service == null) return;
    setState(() => _isSaving = true);
    try {
      final slots = _buildSlotsFromControllers();
      final Map<String, dynamic> result;
      if (_report == null) {
        result = await service.createReport(widget.classId, _dateStr, slots);
      } else {
        result = await service.updateReport(_report!['id'] as String, slots);
      }
      if (mounted) {
        setState(() => _report = result);
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendToParents() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send to Parents'),
        content: Text('This will notify all parents of ${widget.className}. Proceed?'),
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
    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);
    try {
      final service = ref.read(dailyReportServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      final result = await service.sendToParents(_report!['id'] as String);
      if (mounted) {
        setState(() => _report!['sent_to_parents'] = true);
        final count = result['parent_count'] ?? result['count'];
        final msg = count != null ? 'Sent to $count parents' : (result['message']?.toString() ?? 'Sent!');
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
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _importExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _isParsingExcel = true);
    try {
      final service = ref.read(dailyReportServiceProvider);
      if (service == null) throw Exception('Not authenticated');
      final parsed = await service.parseExcel(result.files.first);

      final matchedId = parsed['matched_class_id'] as String?;
      final detectedGrade = parsed['detected_grade'] as String?;
      final slots = List<Map<String, dynamic>>.from(parsed['slots'] as List? ?? []);

      if (!mounted) return;

      // Grade mismatch — ask user to confirm before loading
      if (matchedId != null && matchedId != widget.classId) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Grade Mismatch'),
            content: Text(
              'This Excel file is for "$detectedGrade", but you are editing "${widget.className}".\n\nLoad these timings anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Load Anyway'),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) {
          setState(() => _isParsingExcel = false);
          return;
        }
      }

      // Warn when grade detected but no class matched
      if (detectedGrade != null && matchedId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Grade "$detectedGrade" not found in system. Timings loaded — please verify.',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 4),
        ));
      }

      // Warn when grade couldn't be detected at all
      if (detectedGrade == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not detect grade from file. Please verify the timings.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ));
      }

      setState(() => _rebuildControllers(slots));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isParsingExcel = false);
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

  bool get _alreadySent => _report?['sent_to_parents'] as bool? ?? false;
  bool get _hasSlotsToShow => _timingCtrls.isNotEmpty;

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
      bottomNavigationBar: _loading ? null : _buildBottomBar(),
      body: Column(
        children: [
          // Date navigation
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _loading ? null : _prevDay,
                  color: Colors.grey.shade700,
                ),
                GestureDetector(
                  onTap: _loading ? null : _pickDate,
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
                          _fmtDate(_selectedDate),
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
                  onPressed: _loading ? null : _nextDay,
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : !_hasSlotsToShow && _report == null
                    ? _buildEmptyState()
                    : _buildSlotList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
            Text(
              _fmtDate(_selectedDate),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addSlot,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create Report', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isParsingExcel ? null : _importExcel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: BorderSide(color: Colors.teal.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isParsingExcel
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal.shade400),
                      )
                    : const Icon(Icons.table_chart_outlined),
                label: Text(
                  _isParsingExcel ? 'Reading file…' : 'Import from Excel',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        // Column headers
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 36),
          child: Row(
            children: [
              Expanded(
                flex: 2,
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
                flex: 3,
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

        for (int i = 0; i < _timingCtrls.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _timingCtrls[i],
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
                    flex: 3,
                    child: TextField(
                      controller: _descCtrls[i],
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
                      onPressed: () => _removeSlot(i),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addSlot,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Row'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: BorderSide(color: Colors.orange.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isParsingExcel ? null : _importExcel,
                icon: _isParsingExcel
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal.shade400),
                      )
                    : const Icon(Icons.table_chart_outlined, size: 18),
                label: Text(_isParsingExcel ? 'Reading…' : 'Import Excel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: BorderSide(color: Colors.teal.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildBottomBar() {
    final sent = _alreadySent;
    return BottomAppBar(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
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
              onPressed: (_report == null || sent || _isSending) ? null : _sendToParents,
              style: FilledButton.styleFrom(
                backgroundColor: sent ? Colors.grey.shade300 : Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(sent ? Icons.check_circle_outline : Icons.send_rounded, size: 16),
              label: Text(
                sent ? 'Sent ✓' : 'Send to Parents',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
