import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/student_profile_provider.dart';
import '../../../core/auth/auth_provider.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  final String studentId;

  const StudentProfileScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _student;
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(studentProfileApiProvider);
    if (api == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Not authorized';
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final student = await api.getStudent(widget.studentId);
      if (mounted) {
        setState(() {
          _student = student;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _showEdit(BuildContext context) {
    final api = ref.read(studentProfileApiProvider);
    if (api?.updateStudent == null || _student == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditStudentSheet(
        student: _student!,
        onSaved: (updated) {
          Navigator.pop(ctx);
          setState(() => _student = updated);
        },
        updateStudent: api!.updateStudent!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goBack = () => context.canPop() ? context.pop() : context.go(ref.read(authProvider).role == UserRole.coordinator ? '/coordinator/students' : '/admissions');
    if (_loading) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: goBack), title: const Text('Student Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: goBack), title: const Text('Student Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final s = _student!;
    final name = s['name'] as String? ?? '—';
    final admissionNo = s['admission_number'] as String? ?? '—';
    final classInfo = [s['class_name'], s['branch_name']].where((x) => x != null && x.toString().isNotEmpty).join(' • ');
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: goBack),
        title: const Text('Student Profile'),
        actions: [
          if (ref.read(studentProfileApiProvider)?.updateStudent != null)
            IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEdit(context)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: Theme.of(context).cardTheme.color,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                const SizedBox(height: 16),
                Text(name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                  child: Text(admissionNo, style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                ),
                if (classInfo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(classInfo, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                ],
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Details'),
              Tab(text: 'Attendance'),
              Tab(text: 'Report Cards'),
              Tab(text: 'Fees'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DetailsTab(student: s),
                const Center(child: Text('Attendance tab')),
                const Center(child: Text('Report Cards tab')),
                const Center(child: Text('Fees tab')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final Map<String, dynamic> student;

  const _DetailsTab({required this.student});

  String _get(dynamic key) => student[key]?.toString() ?? '—';

  String _getWithFallback(String key, String? fallback) {
    final v = student[key]?.toString();
    if (v != null && v.isNotEmpty) return v;
    return fallback ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final parentName = (student['parent_name'] ?? student['father_name'] ?? student['mother_name'])?.toString() ?? '—';
    final parentPhone = (student['parent_phone'] ?? student['father_contact_no'] ?? student['mother_contact_no'] ?? student['residential_contact_no'])?.toString();
    final y = student['age_years'] as int?;
    final m = student['age_months'] as int?;
    final ageStr = y != null ? (m != null && m > 0 ? '$y years $m months' : '$y years') : '—';
    final dob = student['date_of_birth'] as String?;
    String dobFormatted = '—';
    if (dob != null && dob.isNotEmpty) {
      try {
        final d = DateTime.parse(dob);
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        dobFormatted = '${months[d.month - 1]} ${d.day}, ${d.year} ($ageStr)';
      } catch (_) {
        dobFormatted = dob;
      }
    }
    final declDate = student['declaration_date'] as String?;
    String declFormatted = '—';
    if (declDate != null && declDate.isNotEmpty) {
      try {
        final d = DateTime.parse(declDate);
        declFormatted = '${d.day}/${d.month}/${d.year}';
      } catch (_) {
        declFormatted = declDate;
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'Primary Contact',
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(parentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Parent', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                if (parentPhone != null && parentPhone.isNotEmpty)
                  IconButton(icon: const Icon(Icons.phone), onPressed: () {}),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Personal Information',
            child: Column(
              children: [
                _InfoRow(icon: Icons.cake, label: 'Date of Birth', value: dobFormatted),
                _InfoRow(icon: Icons.wc, label: 'Gender', value: _get('gender')),
                _InfoRow(icon: Icons.location_on, label: 'Address', value: _get('residential_address')),
                _InfoRow(icon: Icons.bloodtype, label: 'Blood Group', value: _get('blood_group')),
                _InfoRow(icon: Icons.place, label: 'Place of Birth', value: _get('place_of_birth')),
                _InfoRow(icon: Icons.flag, label: 'Nationality', value: _get('nationality')),
                _InfoRow(icon: Icons.translate, label: 'Mother Tongue', value: _get('mother_tongue')),
                _InfoRow(icon: Icons.church, label: 'Religion', value: _get('religion')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Father',
            child: Column(
              children: [
                _InfoRow(icon: Icons.person, label: 'Name', value: _getWithFallback('father_name', parentName != '—' ? parentName : null)),
                _InfoRow(icon: Icons.work, label: 'Occupation', value: _get('father_occupation')),
                _InfoRow(icon: Icons.phone, label: 'Contact', value: _getWithFallback('father_contact_no', parentPhone)),
                _InfoRow(icon: Icons.email, label: 'Email', value: _get('father_email')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Mother',
            child: Column(
              children: [
                _InfoRow(icon: Icons.person, label: 'Name', value: _getWithFallback('mother_name', parentName != '—' ? parentName : null)),
                _InfoRow(icon: Icons.work, label: 'Occupation', value: _get('mother_occupation')),
                _InfoRow(icon: Icons.phone, label: 'Contact', value: _getWithFallback('mother_contact_no', parentPhone)),
                _InfoRow(icon: Icons.email, label: 'Email', value: _get('mother_email')),
              ],
            ),
          ),
          if (_get('guardian_name') != '—') ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Guardian',
              child: Column(
                children: [
                  _InfoRow(icon: Icons.person, label: 'Name', value: _get('guardian_name')),
                  _InfoRow(icon: Icons.family_restroom, label: 'Relation', value: _get('guardian_relation')),
                  _InfoRow(icon: Icons.phone, label: 'Contact', value: _get('guardian_contact_no')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Emergency Contact',
            child: Column(
              children: [
                _InfoRow(icon: Icons.person, label: 'Name', value: _getWithFallback('emergency_contact_name', parentName != '—' ? parentName : null)),
                _InfoRow(icon: Icons.phone, label: 'Phone', value: _getWithFallback('emergency_contact_phone', parentPhone)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Academic',
            child: Column(
              children: [
                _InfoRow(icon: Icons.school, label: 'Branch', value: _get('branch_name')),
                _InfoRow(icon: Icons.class_, label: 'Class', value: _get('class_name')),
                _InfoRow(icon: Icons.calendar_today, label: 'Admission Date', value: declFormatted),
                _InfoRow(icon: Icons.directions_bus, label: 'Transport', value: student['transport_required'] == true ? 'Yes' : 'No'),
              ],
            ),
          ),
          if (_get('medical_allergies') != '—' || _get('medical_surgeries') != '—' || _get('medical_chronic_illness') != '—') ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Medical',
              child: Column(
                children: [
                  if (_get('medical_allergies') != '—') _InfoRow(icon: Icons.medical_services, label: 'Allergies', value: _get('medical_allergies')),
                  if (_get('medical_surgeries') != '—') _InfoRow(icon: Icons.medical_services, label: 'Surgeries', value: _get('medical_surgeries')),
                  if (_get('medical_chronic_illness') != '—') _InfoRow(icon: Icons.medical_services, label: 'Chronic', value: _get('medical_chronic_illness')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary.withValues(alpha: 0.6), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditStudentSheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final void Function(Map<String, dynamic>) onSaved;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>) updateStudent;

  const _EditStudentSheet({required this.student, required this.onSaved, required this.updateStudent});

  @override
  State<_EditStudentSheet> createState() => _EditStudentSheetState();
}

class _EditStudentSheetState extends State<_EditStudentSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _fatherNameCtrl;
  late final TextEditingController _fatherContactCtrl;
  late final TextEditingController _motherNameCtrl;
  late final TextEditingController _motherContactCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _emergencyNameCtrl;
  late final TextEditingController _emergencyPhoneCtrl;
  bool _transport = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.student['name']?.toString() ?? '');
    _fatherNameCtrl = TextEditingController(text: widget.student['father_name']?.toString() ?? '');
    _fatherContactCtrl = TextEditingController(text: widget.student['father_contact_no']?.toString() ?? '');
    _motherNameCtrl = TextEditingController(text: widget.student['mother_name']?.toString() ?? '');
    _motherContactCtrl = TextEditingController(text: widget.student['mother_contact_no']?.toString() ?? '');
    _addressCtrl = TextEditingController(text: widget.student['residential_address']?.toString() ?? '');
    _emergencyNameCtrl = TextEditingController(text: widget.student['emergency_contact_name']?.toString() ?? '');
    _emergencyPhoneCtrl = TextEditingController(text: widget.student['emergency_contact_phone']?.toString() ?? '');
    _transport = widget.student['transport_required'] == true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fatherNameCtrl.dispose();
    _fatherContactCtrl.dispose();
    _motherNameCtrl.dispose();
    _motherContactCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        setState(() {
          _saving = false;
          _error = 'Student name is required';
        });
        return;
      }
      final data = <String, dynamic>{
        'name': name,
        'father_name': _fatherNameCtrl.text.trim().isEmpty ? null : _fatherNameCtrl.text.trim(),
        'father_contact_no': _fatherContactCtrl.text.trim().isEmpty ? null : _fatherContactCtrl.text.trim(),
        'mother_name': _motherNameCtrl.text.trim().isEmpty ? null : _motherNameCtrl.text.trim(),
        'mother_contact_no': _motherContactCtrl.text.trim().isEmpty ? null : _motherContactCtrl.text.trim(),
        'residential_address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'emergency_contact_name': _emergencyNameCtrl.text.trim().isEmpty ? null : _emergencyNameCtrl.text.trim(),
        'emergency_contact_phone': _emergencyPhoneCtrl.text.trim().isEmpty ? null : _emergencyPhoneCtrl.text.trim(),
        'transport_required': _transport,
      };
      data.removeWhere((_, v) => v == null);
      final updated = await widget.updateStudent(widget.student['id'] as String, data);
      if (mounted) {
        widget.onSaved(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit Student', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Student Name')),
              const SizedBox(height: 12),
              TextField(controller: _fatherNameCtrl, decoration: const InputDecoration(labelText: 'Father Name')),
              TextField(controller: _fatherContactCtrl, decoration: const InputDecoration(labelText: 'Father Contact'), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextField(controller: _motherNameCtrl, decoration: const InputDecoration(labelText: 'Mother Name')),
              TextField(controller: _motherContactCtrl, decoration: const InputDecoration(labelText: 'Mother Contact'), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: _emergencyNameCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Name')),
              TextField(controller: _emergencyPhoneCtrl, decoration: const InputDecoration(labelText: 'Emergency Phone'), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              SwitchListTile(title: const Text('Transport Required'), value: _transport, onChanged: (v) => setState(() => _transport = v)),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
