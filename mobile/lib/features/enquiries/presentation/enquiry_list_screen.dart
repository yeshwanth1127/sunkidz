import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_api.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';
import '../../../shared/widgets/dob_picker.dart';

class EnquiryListScreen extends ConsumerStatefulWidget {
  const EnquiryListScreen({super.key});

  @override
  ConsumerState<EnquiryListScreen> createState() => _EnquiryListScreenState();
}

class _EnquiryListScreenState extends ConsumerState<EnquiryListScreen> {
  List<Map<String, dynamic>> _enquiries = [];
  List<Map<String, dynamic>> _branches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(adminApiProvider);
    if (api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final enquiries = await api.getEnquiries();
      final branches = await api.getBranches();
      if (mounted) setState(() {
        _enquiries = enquiries;
        _branches = branches;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showEnquiryForm() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => _EnquiryFormSheet(
        branches: _branches,
        onSaved: () {
          Navigator.of(ctx).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        },
        api: ref.read(adminApiProvider)!,
      ),
    );
  }

  void _showAdmissionForm(Map<String, dynamic> enquiry) {
    if (enquiry['status'] == 'converted') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already converted to admission')));
      return;
    }
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => _AdmissionFormSheet(
        enquiry: enquiry,
        branches: _branches,
        onSaved: () {
          Navigator.of(ctx).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        },
        api: ref.read(adminApiProvider)!,
      ),
    );
  }

  void _showEnquiryDetails(Map<String, dynamic> enquiry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 1,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Enquiry Details', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: _EnquiryDetailView(enquiry: enquiry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        title: const Text('Enquiries'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showEnquiryForm),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _enquiries.length,
                  itemBuilder: (_, i) => _EnquiryCard(
                    enquiry: _enquiries[i],
                    onConvert: () => _showAdmissionForm(_enquiries[i]),
                    onTap: () => _showEnquiryDetails(_enquiries[i]),
                  ),
                ),
    );
  }
}

class _EnquiryCard extends StatelessWidget {
  final Map<String, dynamic> enquiry;
  final VoidCallback onConvert;
  final VoidCallback onTap;

  const _EnquiryCard({required this.enquiry, required this.onConvert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = enquiry['child_name'] as String? ?? '';
    final branch = enquiry['branch_name'] as String? ?? '—';
    final age = enquiry['age_years'] ?? enquiry['age_months'] ?? '—';
    final ageStr = age is int ? (enquiry['age_months'] != null ? '$age yrs' : 'Age $age') : age.toString();
    final status = enquiry['status'] as String? ?? 'pending';
    final isConverted = status == 'converted';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: status == 'pending' ? AppColors.pastelYellow : status == 'converted' ? AppColors.pastelGreen : AppColors.pastelBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.mail, color: status == 'converted' ? const Color(0xFF16A34A) : AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('$branch • $ageStr', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isConverted ? Colors.green.shade100 : status == 'pending' ? Colors.amber.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isConverted ? Colors.green.shade700 : Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            if (!isConverted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onConvert,
                  icon: const Icon(Icons.school, size: 18),
                  label: const Text('Convert to Admission'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnquiryDetailView extends StatelessWidget {
  final Map<String, dynamic> enquiry;

  const _EnquiryDetailView({required this.enquiry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(title: 'Child Information'),
        _InfoRow(label: 'Name', value: enquiry['child_name']),
        _InfoRow(label: 'Date of Birth', value: enquiry['date_of_birth']?.toString().split('T').first ?? '—'),
        _InfoRow(label: 'Age', value: enquiry['age_years'] != null ? '${enquiry['age_years']} years ${enquiry['age_months'] ?? 0} months' : '—'),
        _InfoRow(label: 'Gender', value: enquiry['gender']),
        const SizedBox(height: 16),
        _Section(title: 'Branch'),
        _InfoRow(label: 'Preferred Branch', value: enquiry['branch_name']),
        const SizedBox(height: 16),
        _Section(title: 'Father Details'),
        _InfoRow(label: 'Name', value: enquiry['father_name']),
        _InfoRow(label: 'Occupation', value: enquiry['father_occupation']),
        _InfoRow(label: 'Place of Work', value: enquiry['father_place_of_work']),
        _InfoRow(label: 'Email', value: enquiry['father_email']),
        _InfoRow(label: 'Contact', value: enquiry['father_contact_no']),
        const SizedBox(height: 16),
        _Section(title: 'Mother Details'),
        _InfoRow(label: 'Name', value: enquiry['mother_name']),
        _InfoRow(label: 'Occupation', value: enquiry['mother_occupation']),
        _InfoRow(label: 'Place of Work', value: enquiry['mother_place_of_work']),
        _InfoRow(label: 'Email', value: enquiry['mother_email']),
        _InfoRow(label: 'Contact', value: enquiry['mother_contact_no']),
        const SizedBox(height: 16),
        _Section(title: 'Siblings'),
        _InfoRow(label: 'Siblings Info', value: enquiry['siblings_info']),
        _InfoRow(label: 'Siblings Age', value: enquiry['siblings_age']),
        const SizedBox(height: 16),
        _Section(title: 'Address'),
        _InfoRow(label: 'Residential Address', value: enquiry['residential_address']),
        _InfoRow(label: 'Residential Contact', value: enquiry['residential_contact_no']),
        const SizedBox(height: 16),
        _Section(title: 'Additional Information'),
        _InfoRow(label: 'Challenges / Specialities', value: enquiry['challenges_specialities']),
        _InfoRow(label: 'Expectations from School', value: enquiry['expectations_from_school']),
        const SizedBox(height: 16),
        _Section(title: 'Status'),
        _InfoRow(label: 'Status', value: enquiry['status']),
        _InfoRow(label: 'Created At', value: enquiry['created_at']?.toString().split('T').first ?? '—'),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;

  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final dynamic value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final displayValue = value?.toString().trim();
    if (displayValue == null || displayValue.isEmpty || displayValue == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnquiryFormSheet extends StatefulWidget {
  final List<Map<String, dynamic>> branches;
  final VoidCallback onSaved;
  final AdminApi api;

  const _EnquiryFormSheet({required this.branches, required this.onSaved, required this.api});

  @override
  State<_EnquiryFormSheet> createState() => _EnquiryFormSheetState();
}

class _EnquiryFormSheetState extends State<_EnquiryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _childName = TextEditingController();
  DateTime? _selectedDob;
  final _fatherName = TextEditingController();
  final _fatherOccupation = TextEditingController();
  final _fatherPlace = TextEditingController();
  final _fatherEmail = TextEditingController();
  final _fatherPhone = TextEditingController();
  final _motherName = TextEditingController();
  final _motherOccupation = TextEditingController();
  final _motherPlace = TextEditingController();
  final _motherEmail = TextEditingController();
  final _motherPhone = TextEditingController();
  final _siblingsInfo = TextEditingController();
  final _siblingsAge = TextEditingController();
  final _address = TextEditingController();
  final _residentialPhone = TextEditingController();
  final _challenges = TextEditingController();
  final _expectations = TextEditingController();
  String? _branchId;
  String? _gender;
  bool _loading = false;

  @override
  void dispose() {
    _childName.dispose();
    _fatherName.dispose();
    _fatherOccupation.dispose();
    _fatherPlace.dispose();
    _fatherEmail.dispose();
    _fatherPhone.dispose();
    _motherName.dispose();
    _motherOccupation.dispose();
    _motherPlace.dispose();
    _motherEmail.dispose();
    _motherPhone.dispose();
    _siblingsInfo.dispose();
    _siblingsAge.dispose();
    _address.dispose();
    _residentialPhone.dispose();
    _challenges.dispose();
    _expectations.dispose();
    super.dispose();
  }

  Map<String, dynamic> _toData() {
    final (ageYears, ageMonths) = _selectedDob != null ? DobPicker.calculateAge(_selectedDob!) : (0, 0);
    return {
      'child_name': _childName.text.trim(),
      'date_of_birth': _selectedDob?.toIso8601String().split('T').first,
      'age_years': _selectedDob != null ? ageYears : null,
      'age_months': _selectedDob != null ? ageMonths : null,
      'gender': _gender,
      'father_name': _fatherName.text.trim().isEmpty ? null : _fatherName.text.trim(),
      'father_occupation': _fatherOccupation.text.trim().isEmpty ? null : _fatherOccupation.text.trim(),
      'father_place_of_work': _fatherPlace.text.trim().isEmpty ? null : _fatherPlace.text.trim(),
      'father_email': _fatherEmail.text.trim().isEmpty ? null : _fatherEmail.text.trim(),
      'father_contact_no': _fatherPhone.text.trim().isEmpty ? null : _fatherPhone.text.trim(),
      'mother_name': _motherName.text.trim().isEmpty ? null : _motherName.text.trim(),
      'mother_occupation': _motherOccupation.text.trim().isEmpty ? null : _motherOccupation.text.trim(),
      'mother_place_of_work': _motherPlace.text.trim().isEmpty ? null : _motherPlace.text.trim(),
      'mother_email': _motherEmail.text.trim().isEmpty ? null : _motherEmail.text.trim(),
      'mother_contact_no': _motherPhone.text.trim().isEmpty ? null : _motherPhone.text.trim(),
      'siblings_info': _siblingsInfo.text.trim().isEmpty ? null : _siblingsInfo.text.trim(),
      'siblings_age': _siblingsAge.text.trim().isEmpty ? null : _siblingsAge.text.trim(),
      'residential_address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'residential_contact_no': _residentialPhone.text.trim().isEmpty ? null : _residentialPhone.text.trim(),
      'challenges_specialities': _challenges.text.trim().isEmpty ? null : _challenges.text.trim(),
      'expectations_from_school': _expectations.text.trim().isEmpty ? null : _expectations.text.trim(),
      'branch_id': _branchId,
      'status': 'pending',
    };
  }

  Future<void> _submit() async {
    if (_childName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Child name required')));
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.api.createEnquiry(_toData());
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('New Enquiry', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _section('Child'),
                TextField(controller: _childName, decoration: const InputDecoration(labelText: 'Child Name *')),
                DobPicker(value: _selectedDob, onChanged: (d) => setState(() => _selectedDob = d)),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [DropdownMenuItem(value: 'male', child: Text('Male')), DropdownMenuItem(value: 'female', child: Text('Female')), DropdownMenuItem(value: 'other', child: Text('Other'))],
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 16),
                _section('Father'),
                TextField(controller: _fatherName, decoration: const InputDecoration(labelText: 'Father Name')),
                TextField(controller: _fatherOccupation, decoration: const InputDecoration(labelText: 'Occupation')),
                TextField(controller: _fatherPlace, decoration: const InputDecoration(labelText: 'Place of Work')),
                TextField(controller: _fatherEmail, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                TextField(controller: _fatherPhone, decoration: const InputDecoration(labelText: 'Contact')),
                const SizedBox(height: 16),
                _section('Mother'),
                TextField(controller: _motherName, decoration: const InputDecoration(labelText: 'Mother Name')),
                TextField(controller: _motherOccupation, decoration: const InputDecoration(labelText: 'Occupation')),
                TextField(controller: _motherPlace, decoration: const InputDecoration(labelText: 'Place of Work')),
                TextField(controller: _motherEmail, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                TextField(controller: _motherPhone, decoration: const InputDecoration(labelText: 'Contact')),
                const SizedBox(height: 16),
                _section('Siblings'),
                TextField(controller: _siblingsInfo, decoration: const InputDecoration(labelText: 'Siblings Info'), maxLines: 2),
                TextField(controller: _siblingsAge, decoration: const InputDecoration(labelText: 'Siblings Age')),
                const SizedBox(height: 16),
                _section('Address'),
                TextField(controller: _address, decoration: const InputDecoration(labelText: 'Residential Address'), maxLines: 2),
                TextField(controller: _residentialPhone, decoration: const InputDecoration(labelText: 'Residential Contact')),
                const SizedBox(height: 16),
                _section('Other'),
                TextField(controller: _challenges, decoration: const InputDecoration(labelText: 'Challenges / Specialities'), maxLines: 2),
                TextField(controller: _expectations, decoration: const InputDecoration(labelText: 'Expectations from School'), maxLines: 2),
                DropdownButtonFormField<String>(
                  value: _branchId,
                  decoration: const InputDecoration(labelText: 'Preferred Branch'),
                  items: widget.branches.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String))).toList(),
                  onChanged: (v) => setState(() => _branchId = v),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Enquiry')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)));
}

class _AdmissionFormSheet extends StatefulWidget {
  final Map<String, dynamic> enquiry;
  final List<Map<String, dynamic>> branches;
  final VoidCallback onSaved;
  final AdminApi api;

  const _AdmissionFormSheet({required this.enquiry, required this.branches, required this.onSaved, required this.api});

  @override
  State<_AdmissionFormSheet> createState() => _AdmissionFormSheetState();
}

class _AdmissionFormSheetState extends State<_AdmissionFormSheet> {
  late final TextEditingController _name;
  DateTime? _selectedDob;
  late final TextEditingController _address;
  late final TextEditingController _contact;
  late final TextEditingController _parentName;
  late final TextEditingController _parentContact;
  late final TextEditingController _fatherName;
  late final TextEditingController _fatherOccupation;
  late final TextEditingController _fatherContact;
  late final TextEditingController _fatherEmail;
  late final TextEditingController _motherName;
  late final TextEditingController _motherOccupation;
  late final TextEditingController _motherContact;
  late final TextEditingController _motherEmail;
  late final TextEditingController _guardianName;
  late final TextEditingController _guardianRelation;
  late final TextEditingController _guardianContact;
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyPhone;
  late final TextEditingController _placeOfBirth;
  late final TextEditingController _nationality;
  late final TextEditingController _religion;
  late final TextEditingController _motherTongue;
  late final TextEditingController _bloodGroup;
  late final TextEditingController _medicalAllergies;
  late final TextEditingController _medicalSurgeries;
  late final TextEditingController _medicalChronic;
  late final TextEditingController _prevSchool;
  late final TextEditingController _prevDuration;
  late final TextEditingController _prevClass;
  String? _branchId;
  String? _classId;
  String? _gender;
  bool _attendedPrev = false;
  bool _transportRequired = false;
  bool _birthCert = false;
  bool _immunization = false;
  bool _transferCert = false;
  bool _passportPhotos = false;
  bool _progressReport = false;
  bool _passport = false;
  bool _otherMedical = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.enquiry['child_name'] as String? ?? '');
    final dobStr = widget.enquiry['date_of_birth'] as String?;
    if (dobStr != null && dobStr.isNotEmpty) {
      _selectedDob = DateTime.tryParse(dobStr);
    }
    _address = TextEditingController(text: widget.enquiry['residential_address'] as String? ?? '');
    _contact = TextEditingController(text: widget.enquiry['residential_contact_no'] as String? ?? widget.enquiry['father_contact_no'] as String? ?? widget.enquiry['mother_contact_no'] as String? ?? '');
    _parentName = TextEditingController(text: (widget.enquiry['father_name'] ?? widget.enquiry['mother_name']) as String? ?? '');
    _parentContact = TextEditingController(text: (widget.enquiry['father_contact_no'] ?? widget.enquiry['mother_contact_no']) as String? ?? '');
    _fatherName = TextEditingController(text: widget.enquiry['father_name'] as String? ?? '');
    _fatherOccupation = TextEditingController(text: widget.enquiry['father_occupation'] as String? ?? '');
    _fatherContact = TextEditingController(text: widget.enquiry['father_contact_no'] as String? ?? '');
    _fatherEmail = TextEditingController(text: widget.enquiry['father_email'] as String? ?? '');
    _motherName = TextEditingController(text: widget.enquiry['mother_name'] as String? ?? '');
    _motherOccupation = TextEditingController(text: widget.enquiry['mother_occupation'] as String? ?? '');
    _motherContact = TextEditingController(text: widget.enquiry['mother_contact_no'] as String? ?? '');
    _motherEmail = TextEditingController(text: widget.enquiry['mother_email'] as String? ?? '');
    _guardianName = TextEditingController();
    _guardianRelation = TextEditingController();
    _guardianContact = TextEditingController();
    _emergencyName = TextEditingController();
    _emergencyPhone = TextEditingController();
    _placeOfBirth = TextEditingController();
    _nationality = TextEditingController();
    _religion = TextEditingController();
    _motherTongue = TextEditingController();
    _bloodGroup = TextEditingController();
    _medicalAllergies = TextEditingController();
    _medicalSurgeries = TextEditingController();
    _medicalChronic = TextEditingController();
    _prevSchool = TextEditingController();
    _prevDuration = TextEditingController();
    _prevClass = TextEditingController();
    _gender = widget.enquiry['gender'] as String?;
    _branchId = widget.enquiry['branch_id'] as String?;
    if (_branchId == null && widget.branches.isNotEmpty) _branchId = widget.branches.first['id'] as String?;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _contact.dispose();
    _parentName.dispose();
    _parentContact.dispose();
    _fatherName.dispose();
    _fatherOccupation.dispose();
    _fatherContact.dispose();
    _fatherEmail.dispose();
    _motherName.dispose();
    _motherOccupation.dispose();
    _motherContact.dispose();
    _motherEmail.dispose();
    _guardianName.dispose();
    _guardianRelation.dispose();
    _guardianContact.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _placeOfBirth.dispose();
    _nationality.dispose();
    _religion.dispose();
    _motherTongue.dispose();
    _bloodGroup.dispose();
    _medicalAllergies.dispose();
    _medicalSurgeries.dispose();
    _medicalChronic.dispose();
    _prevSchool.dispose();
    _prevDuration.dispose();
    _prevClass.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _classes {
    if (_branchId == null) return [];
    final b = widget.branches.cast<Map<String, dynamic>?>().firstWhere((x) => x!['id'] == _branchId, orElse: () => null);
    return (b?['classes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Date of Birth required (tap to select)')));
      return;
    }
    if (_branchId == null || _classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select branch and class')));
      return;
    }
    if (_parentName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parent name required (for login)')));
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final res = await widget.api.createAdmissionFromEnquiry({
        'enquiry_id': widget.enquiry['id'],
        'branch_id': _branchId,
        'class_id': _classId,
        'name': _name.text.trim(),
        'date_of_birth': _selectedDob!.toIso8601String().split('T').first,
        'gender': _gender,
        'place_of_birth': _placeOfBirth.text.trim().isEmpty ? null : _placeOfBirth.text.trim(),
        'nationality': _nationality.text.trim().isEmpty ? null : _nationality.text.trim(),
        'religion': _religion.text.trim().isEmpty ? null : _religion.text.trim(),
        'mother_tongue': _motherTongue.text.trim().isEmpty ? null : _motherTongue.text.trim(),
        'blood_group': _bloodGroup.text.trim().isEmpty ? null : _bloodGroup.text.trim(),
        'medical_allergies': _medicalAllergies.text.trim().isEmpty ? null : _medicalAllergies.text.trim(),
        'medical_surgeries': _medicalSurgeries.text.trim().isEmpty ? null : _medicalSurgeries.text.trim(),
        'medical_chronic_illness': _medicalChronic.text.trim().isEmpty ? null : _medicalChronic.text.trim(),
        'residential_address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'residential_contact_no': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        'attended_previously': _attendedPrev,
        'school_daycare_name': _prevSchool.text.trim().isEmpty ? null : _prevSchool.text.trim(),
        'prev_school_duration': _prevDuration.text.trim().isEmpty ? null : _prevDuration.text.trim(),
        'prev_school_class': _prevClass.text.trim().isEmpty ? null : _prevClass.text.trim(),
        'birth_certificate': _birthCert,
        'immunization_record': _immunization,
        'transfer_certificate': _transferCert,
        'passport_photos': _passportPhotos,
        'progress_report': _progressReport,
        'passport': _passport,
        'other_medical_report': _otherMedical,
        'parent_name': _parentName.text.trim(),
        'parent_contact': _parentContact.text.trim().isEmpty ? null : _parentContact.text.trim(),
        'father_name': _fatherName.text.trim().isEmpty ? null : _fatherName.text.trim(),
        'father_occupation': _fatherOccupation.text.trim().isEmpty ? null : _fatherOccupation.text.trim(),
        'father_contact_no': _fatherContact.text.trim().isEmpty ? null : _fatherContact.text.trim(),
        'father_email': _fatherEmail.text.trim().isEmpty ? null : _fatherEmail.text.trim(),
        'mother_name': _motherName.text.trim().isEmpty ? null : _motherName.text.trim(),
        'mother_occupation': _motherOccupation.text.trim().isEmpty ? null : _motherOccupation.text.trim(),
        'mother_contact_no': _motherContact.text.trim().isEmpty ? null : _motherContact.text.trim(),
        'mother_email': _motherEmail.text.trim().isEmpty ? null : _motherEmail.text.trim(),
        'guardian_name': _guardianName.text.trim().isEmpty ? null : _guardianName.text.trim(),
        'guardian_relation': _guardianRelation.text.trim().isEmpty ? null : _guardianRelation.text.trim(),
        'guardian_contact_no': _guardianContact.text.trim().isEmpty ? null : _guardianContact.text.trim(),
        'emergency_contact_name': _emergencyName.text.trim().isEmpty ? null : _emergencyName.text.trim(),
        'emergency_contact_phone': _emergencyPhone.text.trim().isEmpty ? null : _emergencyPhone.text.trim(),
        'transport_required': _transportRequired,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Admission created: ${res['admission_number']}. Parent login: admission_number + DOB'),
          duration: const Duration(seconds: 5),
        ));
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Convert to Admission', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Admission number format: skz(branch)(year)(date). Parent login: admission_number + DOB', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              _section('Child'),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Child Name *')),
              DobPicker(value: _selectedDob, onChanged: (d) => setState(() => _selectedDob = d)),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [DropdownMenuItem(value: 'male', child: Text('Male')), DropdownMenuItem(value: 'female', child: Text('Female')), DropdownMenuItem(value: 'other', child: Text('Other'))],
                onChanged: (v) => setState(() => _gender = v),
              ),
              TextField(controller: _placeOfBirth, decoration: const InputDecoration(labelText: 'Place of Birth')),
              TextField(controller: _nationality, decoration: const InputDecoration(labelText: 'Nationality')),
              TextField(controller: _religion, decoration: const InputDecoration(labelText: 'Religion')),
              TextField(controller: _motherTongue, decoration: const InputDecoration(labelText: 'Mother Tongue')),
              TextField(controller: _bloodGroup, decoration: const InputDecoration(labelText: 'Blood Group')),
              const SizedBox(height: 16),
              _section('Medical'),
              TextField(controller: _medicalAllergies, decoration: const InputDecoration(labelText: 'Allergies'), maxLines: 2),
              TextField(controller: _medicalSurgeries, decoration: const InputDecoration(labelText: 'Surgeries'), maxLines: 2),
              TextField(controller: _medicalChronic, decoration: const InputDecoration(labelText: 'Chronic Illness'), maxLines: 2),
              const SizedBox(height: 16),
              _section('Father'),
              TextField(controller: _fatherName, decoration: const InputDecoration(labelText: 'Father Name')),
              TextField(controller: _fatherOccupation, decoration: const InputDecoration(labelText: 'Occupation')),
              TextField(controller: _fatherContact, decoration: const InputDecoration(labelText: 'Contact')),
              TextField(controller: _fatherEmail, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _section('Mother'),
              TextField(controller: _motherName, decoration: const InputDecoration(labelText: 'Mother Name')),
              TextField(controller: _motherOccupation, decoration: const InputDecoration(labelText: 'Occupation')),
              TextField(controller: _motherContact, decoration: const InputDecoration(labelText: 'Contact')),
              TextField(controller: _motherEmail, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _section('Guardian (if different from parents)'),
              TextField(controller: _guardianName, decoration: const InputDecoration(labelText: 'Guardian Name')),
              TextField(controller: _guardianRelation, decoration: const InputDecoration(labelText: 'Relation')),
              TextField(controller: _guardianContact, decoration: const InputDecoration(labelText: 'Contact')),
              const SizedBox(height: 16),
              _section('Address'),
              TextField(controller: _address, decoration: const InputDecoration(labelText: 'Residential Address'), maxLines: 2),
              TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact')),
              const SizedBox(height: 16),
              _section('Emergency Contact'),
              TextField(controller: _emergencyName, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: _emergencyPhone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 16),
              _section('Other'),
              SwitchListTile(title: const Text('Transport required'), value: _transportRequired, onChanged: (v) => setState(() => _transportRequired = v)),
              const SizedBox(height: 16),
              _section('Branch & Class'),
              DropdownButtonFormField<String>(
                value: _branchId,
                decoration: const InputDecoration(labelText: 'Branch *'),
                items: widget.branches.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String))).toList(),
                onChanged: (v) => setState(() {
                  _branchId = v;
                  _classId = null;
                }),
              ),
              if (_classes.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _classId,
                  decoration: const InputDecoration(labelText: 'Class *'),
                  items: _classes.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
                  onChanged: (v) => setState(() => _classId = v),
                ),
              const SizedBox(height: 16),
              _section('Previous School'),
              SwitchListTile(title: const Text('Attended previously'), value: _attendedPrev, onChanged: (v) => setState(() => _attendedPrev = v)),
              TextField(controller: _prevSchool, decoration: const InputDecoration(labelText: 'School/Daycare Name')),
              TextField(controller: _prevDuration, decoration: const InputDecoration(labelText: 'Duration')),
              TextField(controller: _prevClass, decoration: const InputDecoration(labelText: 'Class')),
              const SizedBox(height: 16),
              _section('Documents'),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(label: const Text('Birth Certificate'), selected: _birthCert, onSelected: (v) => setState(() => _birthCert = v)),
                  FilterChip(label: const Text('Immunization'), selected: _immunization, onSelected: (v) => setState(() => _immunization = v)),
                  FilterChip(label: const Text('Transfer Cert'), selected: _transferCert, onSelected: (v) => setState(() => _transferCert = v)),
                  FilterChip(label: const Text('Passport Photos'), selected: _passportPhotos, onSelected: (v) => setState(() => _passportPhotos = v)),
                  FilterChip(label: const Text('Progress Report'), selected: _progressReport, onSelected: (v) => setState(() => _progressReport = v)),
                  FilterChip(label: const Text('Passport'), selected: _passport, onSelected: (v) => setState(() => _passport = v)),
                  FilterChip(label: const Text('Other Medical'), selected: _otherMedical, onSelected: (v) => setState(() => _otherMedical = v)),
                ],
              ),
              const SizedBox(height: 16),
              _section('Parent (for login)'),
              Text('Parent will login with admission_number + date_of_birth', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              TextField(controller: _parentName, decoration: const InputDecoration(labelText: 'Parent Name *')),
              TextField(controller: _parentContact, decoration: const InputDecoration(labelText: 'Parent Contact')),
              const SizedBox(height: 24),
              FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create Admission')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)));
}
