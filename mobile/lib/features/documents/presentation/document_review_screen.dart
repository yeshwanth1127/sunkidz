import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/documents_provider.dart';
import '../../../shared/widgets/copy_admission_number_button.dart';

/// Reviewer screen for one uploaded admission document: shows the original
/// file next to the OCR-extracted fields (editable, pre-filled from
/// `extracted_data`), and lets an admin/teacher/coordinator confirm ("Apply")
/// or dismiss ("Reject") it. Applying is the only action that actually
/// writes to the Student/User/ParentStudentLink tables — nothing n8n sends
/// back is trusted without this explicit human step.
class DocumentReviewScreen extends ConsumerStatefulWidget {
  final String documentId;
  const DocumentReviewScreen({super.key, required this.documentId});

  @override
  ConsumerState<DocumentReviewScreen> createState() => _DocumentReviewScreenState();
}

const _fieldLabels = <String, String>{
  'name': "Child's Name *",
  'gender': 'Gender',
  'place_of_birth': 'Place of Birth',
  'nationality': 'Nationality',
  'mother_tongue': 'Mother Tongue',
  'religion': 'Religion',
  'blood_group': 'Blood Group',
  'medical_allergies': 'Allergies',
  'medical_surgeries': 'Surgeries',
  'medical_chronic_illness': 'Chronic Illness',
  'residential_address': 'Residential Address',
  'residential_contact_no': 'Residential Contact No.',
  'school_daycare_name': 'Previous School/Daycare Name',
  'prev_school_duration': 'Duration Attended',
  'prev_school_class': 'Previous Class',
  'parent_name': "Parent's Full Name (for login) *",
  'parent_contact': 'Parent Contact (phone/email)',
  'father_name': "Father's Name",
  'father_occupation': "Father's Occupation",
  'father_contact_no': "Father's Contact No.",
  'father_email': "Father's Email",
  'mother_name': "Mother's Name",
  'mother_occupation': "Mother's Occupation",
  'mother_contact_no': "Mother's Contact No.",
  'mother_email': "Mother's Email",
  'guardian_name': 'Guardian Name',
  'guardian_relation': 'Guardian Relation',
  'guardian_contact_no': 'Guardian Contact No.',
  'emergency_contact_name': 'Emergency Contact Name',
  'emergency_contact_phone': 'Emergency Contact Phone',
};

const _documentFlags = <String, String>{
  'birth_certificate': 'Birth Certificate',
  'immunization_record': 'Immunization Record',
  'transfer_certificate': 'Transfer Certificate',
  'passport_photos': 'Passport Photos',
  'progress_report': 'Progress Report',
  'passport': 'Passport',
  'other_medical_report': 'Other Medical Report',
};

class _DocumentReviewScreenState extends ConsumerState<DocumentReviewScreen> {
  Map<String, dynamic>? _doc;
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  final Map<String, TextEditingController> _controllers = {
    for (final k in _fieldLabels.keys) k: TextEditingController(),
  };
  final Map<String, bool> _flags = {for (final k in _documentFlags.keys) k: false};
  DateTime? _dob;
  bool _attendedPreviously = false;
  bool _transportRequired = false;

  String _mode = 'create_student';
  String? _studentId;
  String? _parentUserId;
  bool _forceNewStudent = false;
  bool _forceNewParent = false;

  String? _classId;
  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(documentsApiProvider);
    if (api == null) {
      setState(() {
        _loading = false;
        _error = 'You are signed out. Please log in again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await api.getDocument(widget.documentId);
      final extracted = Map<String, dynamic>.from(doc['extracted_data'] as Map? ?? {});
      for (final key in _fieldLabels.keys) {
        final v = extracted[key];
        if (v != null) _controllers[key]!.text = v.toString();
      }
      for (final key in _documentFlags.keys) {
        _flags[key] = extracted[key] == true;
      }
      _attendedPreviously = extracted['attended_previously'] == true;
      _transportRequired = extracted['transport_required'] == true;
      final dobStr = extracted['date_of_birth']?.toString();
      if (dobStr != null) _dob = _parseOcrDate(dobStr);

      final classes = await api.listClassOptions(doc['branch_id'] as String);

      if (!mounted) return;
      setState(() {
        _doc = doc;
        _classes = classes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load document: $e';
      });
    }
  }

  /// OCR output isn't always ISO `YYYY-MM-DD` — Indian admission forms
  /// typically read as `DD/MM/YYYY` or `DD-MM-YYYY`. Try ISO first, then
  /// those, before giving up and leaving the date picker for manual entry.
  DateTime? _parseOcrDate(String raw) {
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    final match = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(raw.trim());
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  double? _confidenceFor(String key) {
    final scores = _doc?['confidence_scores'];
    if (scores is! Map) return null;
    final v = scores[key];
    if (v is num) return v.toDouble();
    return null;
  }

  Widget _textField(String key, {TextInputType? keyboardType, int maxLines = 1}) {
    final confidence = _confidenceFor(key);
    final lowConfidence = confidence != null && confidence < 0.6;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: _fieldLabels[key],
          border: const OutlineInputBorder(),
          helperText: lowConfidence ? 'Low OCR confidence — please verify' : null,
          helperStyle: const TextStyle(color: Colors.orange),
          suffixIcon: lowConfidence ? const Icon(Icons.warning_amber_rounded, color: Colors.orange) : null,
        ),
      ),
    );
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'mode': _mode,
      if (_studentId != null) 'student_id': _studentId,
      'force_new_student': _forceNewStudent,
      'force_new_parent': _forceNewParent,
      'branch_id': _doc!['branch_id'],
      'class_id': _classId,
      'name': _controllers['name']!.text.trim(),
      'date_of_birth': _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : null,
      'gender': _controllers['gender']!.text.trim().isEmpty ? null : _controllers['gender']!.text.trim(),
      'place_of_birth': _controllers['place_of_birth']!.text.trim(),
      'nationality': _controllers['nationality']!.text.trim(),
      'mother_tongue': _controllers['mother_tongue']!.text.trim(),
      'religion': _controllers['religion']!.text.trim(),
      'blood_group': _controllers['blood_group']!.text.trim(),
      'medical_allergies': _controllers['medical_allergies']!.text.trim(),
      'medical_surgeries': _controllers['medical_surgeries']!.text.trim(),
      'medical_chronic_illness': _controllers['medical_chronic_illness']!.text.trim(),
      'residential_address': _controllers['residential_address']!.text.trim(),
      'residential_contact_no': _controllers['residential_contact_no']!.text.trim(),
      'attended_previously': _attendedPreviously,
      'school_daycare_name': _controllers['school_daycare_name']!.text.trim(),
      'prev_school_duration': _controllers['prev_school_duration']!.text.trim(),
      'prev_school_class': _controllers['prev_school_class']!.text.trim(),
      for (final key in _documentFlags.keys) key: _flags[key],
      'parent_user_id': _parentUserId,
      'parent_name': _controllers['parent_name']!.text.trim(),
      'parent_contact': _controllers['parent_contact']!.text.trim(),
      'father_name': _controllers['father_name']!.text.trim(),
      'father_occupation': _controllers['father_occupation']!.text.trim(),
      'father_contact_no': _controllers['father_contact_no']!.text.trim(),
      'father_email': _controllers['father_email']!.text.trim(),
      'mother_name': _controllers['mother_name']!.text.trim(),
      'mother_occupation': _controllers['mother_occupation']!.text.trim(),
      'mother_contact_no': _controllers['mother_contact_no']!.text.trim(),
      'mother_email': _controllers['mother_email']!.text.trim(),
      'guardian_name': _controllers['guardian_name']!.text.trim(),
      'guardian_relation': _controllers['guardian_relation']!.text.trim(),
      'guardian_contact_no': _controllers['guardian_contact_no']!.text.trim(),
      'emergency_contact_name': _controllers['emergency_contact_name']!.text.trim(),
      'emergency_contact_phone': _controllers['emergency_contact_phone']!.text.trim(),
      'transport_required': _transportRequired,
    };
  }

  Future<void> _apply() async {
    if (_controllers['name']!.text.trim().isEmpty) {
      _snack('Child name is required');
      return;
    }
    if (_dob == null) {
      _snack('Date of birth is required');
      return;
    }
    if (_classId == null) {
      _snack('Please select a class');
      return;
    }
    if (_controllers['parent_name']!.text.trim().isEmpty) {
      _snack('Parent name is required');
      return;
    }
    if (_mode == 'update_student' && (_studentId == null || _studentId!.isEmpty)) {
      _snack('Select an existing student to update, or switch to "New Student"');
      return;
    }

    final api = ref.read(documentsApiProvider);
    if (api == null) return;
    setState(() => _submitting = true);
    try {
      await api.applyDocument(widget.documentId, _buildPayload());
      if (!mounted) return;
      _snack('Saved to the student database.');
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 && e.response?.data is Map) {
        final detail = (e.response!.data as Map)['detail'];
        if (detail is Map) {
          await _handleConflict(Map<String, dynamic>.from(detail));
          return;
        }
      }
      _snack('Failed to apply: ${_errorMessage(e)}');
    } catch (e) {
      _snack('Failed to apply: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is Map && d['message'] != null) return d['message'].toString();
      return d.toString();
    }
    return e.message ?? 'Unknown error';
  }

  Future<void> _handleConflict(Map<String, dynamic> detail) async {
    final candidates = List<Map<String, dynamic>>.from(detail['candidates'] as List? ?? []);
    final isStudentConflict = candidates.isNotEmpty && candidates.first.containsKey('admission_number');
    final message = detail['message']?.toString() ?? 'Possible duplicate found';

    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Possible duplicate found'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 12),
                for (final c in candidates)
                  Card(
                    child: ListTile(
                      dense: true,
                      title: Text(c['name']?.toString() ?? ''),
                      subtitle: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              isStudentConflict
                                  ? 'Admission #: ${c['admission_number'] ?? '—'}'
                                  : 'Phone: ${c['phone'] ?? '—'}',
                            ),
                          ),
                          if (isStudentConflict)
                            CopyAdmissionNumberButton(
                              admissionNumber: c['admission_number']?.toString(),
                              size: 13,
                            ),
                        ],
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.pop(ctx, c['id'] as String),
                        child: const Text('Use this'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, '__force_new__'),
            child: const Text("It's a new person"),
          ),
        ],
      ),
    );
    if (choice == null) return;
    setState(() {
      if (choice == '__force_new__') {
        if (isStudentConflict) {
          _forceNewStudent = true;
        } else {
          _forceNewParent = true;
        }
      } else if (isStudentConflict) {
        _mode = 'update_student';
        _studentId = choice;
      } else {
        _parentUserId = choice;
      }
    });
    _apply();
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject document'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = ref.read(documentsApiProvider);
    if (api == null) return;
    setState(() => _submitting = true);
    try {
      await api.rejectDocument(widget.documentId, reason: reasonController.text.trim());
      if (!mounted) return;
      _snack('Document rejected.');
      Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Failed to reject: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _retryOcr() async {
    final api = ref.read(documentsApiProvider);
    if (api == null) return;
    setState(() => _submitting = true);
    try {
      await api.retryOcr(widget.documentId);
      if (!mounted) return;
      _snack('Re-queued for OCR.');
      Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Failed to retry: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _filePreview(dynamic api) {
    final mime = _doc!['file_mime'] as String? ?? '';
    final url = api.fileUrl(widget.documentId);
    if (mime.startsWith('image/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: 220,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox(
            height: 100,
            child: Center(child: Text('Preview unavailable')),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.picture_as_pdf_rounded),
      label: const Text('Open original PDF'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(documentsApiProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Review Admission Document'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : _buildBody(api),
    );
  }

  Widget _buildBody(dynamic api) {
    final doc = _doc!;
    final status = doc['status'] as String? ?? 'pending';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Chip(label: Text(status)),
              const SizedBox(width: 8),
              Expanded(child: Text(doc['file_name'] as String? ?? '', overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          Center(child: _filePreview(api)),
          const SizedBox(height: 16),
          if (status == 'pending' || status == 'processing')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Waiting for OCR to finish. Pull to refresh, or use "Retry OCR" below if this is stuck.',
                textAlign: TextAlign.center,
              ),
            )
          else if (status == 'applied')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Already applied to student record${doc['matched_student_name'] != null ? ' "${doc['matched_student_name']}"' : ''}.',
                textAlign: TextAlign.center,
              ),
            )
          else if (status == 'rejected')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Rejected. ${doc['error_message'] ?? ''}', textAlign: TextAlign.center),
            )
          else ...[
            if (status == 'failed' && doc['error_message'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('OCR failed: ${doc['error_message']}', style: const TextStyle(color: Colors.red)),
              ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'create_student', label: Text('New Student')),
                ButtonSegment(value: 'update_student', label: Text('Update Existing')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 12),
            const Text('Child Information', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _textField('name'),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime.now().subtract(const Duration(days: 365 * 3)),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dob = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date of Birth *', border: OutlineInputBorder()),
                child: Text(_dob != null ? DateFormat('MMM d, yyyy').format(_dob!) : 'Select date'),
              ),
            ),
            const SizedBox(height: 12),
            _textField('gender'),
            _textField('place_of_birth'),
            _textField('nationality'),
            _textField('mother_tongue'),
            _textField('religion'),
            _textField('blood_group'),
            DropdownButtonFormField<String>(
              initialValue: _classId,
              decoration: const InputDecoration(labelText: 'Class *', border: OutlineInputBorder()),
              items: _classes
                  .map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Text(c['name'] as String)))
                  .toList(),
              onChanged: (v) => setState(() => _classId = v),
            ),
            const SizedBox(height: 20),
            const Text('Medical', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _textField('medical_allergies'),
            _textField('medical_surgeries'),
            _textField('medical_chronic_illness'),
            const SizedBox(height: 20),
            const Text('Address', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _textField('residential_address', maxLines: 2),
            _textField('residential_contact_no', keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            const Text('Previous School', style: TextStyle(fontWeight: FontWeight.bold)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Attended school/daycare previously'),
              value: _attendedPreviously,
              onChanged: (v) => setState(() => _attendedPreviously = v),
            ),
            if (_attendedPreviously) ...[
              _textField('school_daycare_name'),
              _textField('prev_school_duration'),
              _textField('prev_school_class'),
            ],
            const SizedBox(height: 20),
            const Text('Documents Submitted', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              children: _documentFlags.entries
                  .map((e) => FilterChip(
                        label: Text(e.value),
                        selected: _flags[e.key] ?? false,
                        onSelected: (v) => setState(() => _flags[e.key] = v),
                      ))
                  .map((chip) => Padding(padding: const EdgeInsets.only(right: 8, bottom: 8), child: chip))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('Parent / Guardian', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _textField('parent_name'),
            _textField('parent_contact'),
            _textField('father_name'),
            _textField('father_occupation'),
            _textField('father_contact_no', keyboardType: TextInputType.phone),
            _textField('father_email', keyboardType: TextInputType.emailAddress),
            _textField('mother_name'),
            _textField('mother_occupation'),
            _textField('mother_contact_no', keyboardType: TextInputType.phone),
            _textField('mother_email', keyboardType: TextInputType.emailAddress),
            _textField('guardian_name'),
            _textField('guardian_relation'),
            _textField('guardian_contact_no', keyboardType: TextInputType.phone),
            _textField('emergency_contact_name'),
            _textField('emergency_contact_phone', keyboardType: TextInputType.phone),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transport required'),
              value: _transportRequired,
              onChanged: (v) => setState(() => _transportRequired = v),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _reject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Apply to Student Record'),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'pending' || status == 'processing' || status == 'failed') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _retryOcr,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry OCR'),
            ),
          ],
        ],
      ),
    );
  }
}
