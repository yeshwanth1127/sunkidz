import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/admin_provider.dart';

class AdmissionNewScreen extends ConsumerStatefulWidget {
  const AdmissionNewScreen({super.key});

  @override
  ConsumerState<AdmissionNewScreen> createState() => _AdmissionNewScreenState();
}

class _AdmissionNewScreenState extends ConsumerState<AdmissionNewScreen> {
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _classes = [];
  String? _branchId;
  String? _classId;
  bool _loading = true;
  bool _submitting = false;

  // ── Child ──
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _ageYearsCtrl = TextEditingController();
  final _ageMonthsCtrl = TextEditingController();
  String? _gender;
  final _placeOfBirthCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _motherTongueCtrl = TextEditingController();
  final _religionCtrl = TextEditingController();
  final _bloodGroupCtrl = TextEditingController();

  // ── Medical ──
  final _medAllergyCtrl = TextEditingController();
  final _medSurgeryCtrl = TextEditingController();
  final _medChronicCtrl = TextEditingController();

  // ── Address ──
  final _addressCtrl = TextEditingController();
  final _residentialContactCtrl = TextEditingController();

  // ── Father ──
  final _fatherNameCtrl = TextEditingController();
  final _fatherOccupationCtrl = TextEditingController();
  final _fatherContactCtrl = TextEditingController();
  final _fatherEmailCtrl = TextEditingController();

  // ── Mother ──
  final _motherNameCtrl = TextEditingController();
  final _motherOccupationCtrl = TextEditingController();
  final _motherContactCtrl = TextEditingController();
  final _motherEmailCtrl = TextEditingController();

  // ── Guardian / Emergency ──
  final _guardianNameCtrl = TextEditingController();
  final _guardianRelationCtrl = TextEditingController();
  final _guardianContactCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();

  final _parentNameCtrl = TextEditingController();
  final _parentContactCtrl = TextEditingController();
  String? _parentUserId;

  // ── Parent Search ──
  final _parentSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _parentSearchResults = [];
  bool _parentSearching = false;

  // ── Previous school ──
  bool _attendedPreviously = false;
  final _prevSchoolNameCtrl = TextEditingController();
  final _prevSchoolDurationCtrl = TextEditingController();
  final _prevSchoolClassCtrl = TextEditingController();

  // ── Documents ──
  bool _birthCert = false;
  bool _immunization = false;
  bool _transferCert = false;
  bool _passportPhotos = false;
  bool _progressReport = false;
  bool _passport = false;
  bool _otherMedical = false;

  // ── Transport ──
  bool _transportRequired = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _dobCtrl, _ageYearsCtrl, _ageMonthsCtrl, _placeOfBirthCtrl,
      _nationalityCtrl, _motherTongueCtrl, _religionCtrl, _bloodGroupCtrl,
      _medAllergyCtrl, _medSurgeryCtrl, _medChronicCtrl,
      _addressCtrl, _residentialContactCtrl,
      _fatherNameCtrl, _fatherOccupationCtrl, _fatherContactCtrl, _fatherEmailCtrl,
      _motherNameCtrl, _motherOccupationCtrl, _motherContactCtrl, _motherEmailCtrl,
      _guardianNameCtrl, _guardianRelationCtrl, _guardianContactCtrl,
      _emergencyNameCtrl, _emergencyPhoneCtrl,
      _parentNameCtrl, _parentContactCtrl,
      _prevSchoolNameCtrl, _prevSchoolDurationCtrl, _prevSchoolClassCtrl,
      _parentSearchCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _searchParents(String query) async {
    if (query.length < 3) {
      setState(() => _parentSearchResults = []);
      return;
    }
    final api = ref.read(adminApiProvider);
    if (api == null) return;

    setState(() => _parentSearching = true);
    try {
      final results = await api.searchParents(query);
      if (mounted) setState(() => _parentSearchResults = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _parentSearching = false);
    }
  }

  void _onParentSelected(Map<String, dynamic> parent) {
    setState(() {
      _parentUserId = parent['id'];
      _parentNameCtrl.text = parent['full_name'] ?? '';
      _parentContactCtrl.text = parent['phone'] ?? '';
      _parentSearchCtrl.clear();
      _parentSearchResults = [];
      
      // Attempt to auto-populate other fields if they were in the search results
      // Actually, searchParents might not return everything.
      // But we can at least fill the basics.
      // If we need more, we could fetch full parent profile.
    });
  }

  Future<void> _loadBranches() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      final branches = await api.getBranches();
      if (mounted) setState(() { _branches = branches; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadClasses(String branchId) async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      final classes = await api.getClasses(branchId: branchId);
      if (mounted) setState(() { _classes = classes; _classId = classes.isNotEmpty ? classes.first['id']?.toString() : null; });
    } catch (_) {
      if (mounted) setState(() { _classes = []; _classId = null; });
    }
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dobCtrl.text) ?? DateTime.now().subtract(const Duration(days: 365 * 3));
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (date != null) {
      final now = DateTime.now();
      int years = now.year - date.year;
      int months = now.month - date.month;
      if (now.day < date.day) months--;
      if (months < 0) { years--; months += 12; }
      setState(() {
        _dobCtrl.text = DateFormat('yyyy-MM-dd').format(date);
        _ageYearsCtrl.text = years.toString();
        _ageMonthsCtrl.text = months.toString();
      });
    }
  }

  String? _t(TextEditingController c) { final v = c.text.trim(); return v.isEmpty ? null : v; }

  Future<void> _submit() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    if (_branchId == null || _classId == null) { _snack('Branch and class are required'); return; }
    if (_nameCtrl.text.trim().isEmpty) { _snack('Student name is required'); return; }
    if (_dobCtrl.text.trim().isEmpty) { _snack('Date of birth is required'); return; }
    if (_parentNameCtrl.text.trim().isEmpty) { _snack('Parent name (for login) is required'); return; }

    setState(() => _submitting = true);
    try {
      await api.createDirectAdmission({
        'branch_id': _branchId,
        'class_id': _classId,
        'name': _nameCtrl.text.trim(),
        'date_of_birth': _dobCtrl.text.trim(),
        'gender': _gender,
        'place_of_birth': _t(_placeOfBirthCtrl),
        'nationality': _t(_nationalityCtrl),
        'mother_tongue': _t(_motherTongueCtrl),
        'religion': _t(_religionCtrl),
        'blood_group': _t(_bloodGroupCtrl),
        'medical_allergies': _t(_medAllergyCtrl),
        'medical_surgeries': _t(_medSurgeryCtrl),
        'medical_chronic_illness': _t(_medChronicCtrl),
        'residential_address': _t(_addressCtrl),
        'residential_contact_no': _t(_residentialContactCtrl),
        'parent_name': _parentNameCtrl.text.trim(),
        'parent_contact': _t(_parentContactCtrl),
        'father_name': _t(_fatherNameCtrl),
        'father_occupation': _t(_fatherOccupationCtrl),
        'father_contact_no': _t(_fatherContactCtrl),
        'father_email': _t(_fatherEmailCtrl),
        'mother_name': _t(_motherNameCtrl),
        'mother_occupation': _t(_motherOccupationCtrl),
        'mother_contact_no': _t(_motherContactCtrl),
        'mother_email': _t(_motherEmailCtrl),
        'guardian_name': _t(_guardianNameCtrl),
        'guardian_relation': _t(_guardianRelationCtrl),
        'guardian_contact_no': _t(_guardianContactCtrl),
        'emergency_contact_name': _t(_emergencyNameCtrl),
        'emergency_contact_phone': _t(_emergencyPhoneCtrl),
        'attended_previously': _attendedPreviously,
        'school_daycare_name': _t(_prevSchoolNameCtrl),
        'prev_school_duration': _t(_prevSchoolDurationCtrl),
        'prev_school_class': _t(_prevSchoolClassCtrl),
        'birth_certificate': _birthCert,
        'immunization_record': _immunization,
        'transfer_certificate': _transferCert,
        'passport_photos': _passportPhotos,
        'progress_report': _progressReport,
        'passport': _passport,
        'other_medical_report': _otherMedical,
        'transport_required': _transportRequired,
        if (_parentUserId != null) 'parent_user_id': _parentUserId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admission created successfully! Parent can login with Admission No & DOB.')));
        if (GoRouter.of(context).canPop()) { context.pop(); } else { context.go('/admissions'); }
      }
    } catch (e) {
      if (mounted) _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Direct Admission', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white, elevation: 0, foregroundColor: const Color(0xFF0F172A),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Branch & Class ──
                  _section('Branch & Class', Icons.apartment_rounded, [
                    DropdownButtonFormField<String>(
                      value: _branchId,
                      decoration: const InputDecoration(labelText: 'Branch *', border: OutlineInputBorder()),
                      items: _branches.map((b) => DropdownMenuItem(value: b['id']?.toString(), child: Text(b['name']?.toString() ?? '—'))).toList(),
                      onChanged: (v) { if (v == null) return; setState(() { _branchId = v; _classId = null; _classes = []; }); _loadClasses(v); },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _classId,
                      decoration: const InputDecoration(labelText: 'Class / Grade *', border: OutlineInputBorder()),
                      items: _classes.map((c) => DropdownMenuItem(value: c['id']?.toString(), child: Text(c['name']?.toString() ?? '—'))).toList(),
                      onChanged: (v) => setState(() => _classId = v),
                    ),
                  ]),

                  // ── Child Details ──
                  _section('Child Details', Icons.child_care_rounded, [
                    _field(_nameCtrl, 'Child Full Name *', Icons.person_outline),
                    _row([
                      Expanded(child: TextFormField(controller: _dobCtrl, readOnly: true, onTap: _pickDate, decoration: const InputDecoration(labelText: 'Date of Birth *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today_rounded, size: 18)))),
                    ]),
                    _row([
                      Expanded(child: _field(_ageYearsCtrl, 'Age (Years)', Icons.cake, keyboard: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_ageMonthsCtrl, 'Age (Months)', Icons.cake_outlined, keyboard: TextInputType.number)),
                    ]),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder(), prefixIcon: Icon(Icons.wc)),
                      items: const [DropdownMenuItem(value: 'Male', child: Text('Male')), DropdownMenuItem(value: 'Female', child: Text('Female')), DropdownMenuItem(value: 'Other', child: Text('Other'))],
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 14),
                    _field(_placeOfBirthCtrl, 'Place of Birth', Icons.location_on_outlined),
                    _row([
                      Expanded(child: _field(_nationalityCtrl, 'Nationality', Icons.flag_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_motherTongueCtrl, 'Mother Tongue', Icons.translate)),
                    ]),
                    _row([
                      Expanded(child: _field(_religionCtrl, 'Religion', Icons.auto_awesome)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_bloodGroupCtrl, 'Blood Group', Icons.bloodtype_outlined)),
                    ]),
                  ]),

                  // ── Medical ──
                  _section('Medical History', Icons.local_hospital_rounded, [
                    _field(_medAllergyCtrl, 'Allergies', Icons.warning_amber_rounded),
                    _field(_medSurgeryCtrl, 'Surgeries', Icons.healing),
                    _field(_medChronicCtrl, 'Chronic Illness', Icons.monitor_heart_outlined),
                  ]),

                  // ── Address ──
                  _section('Residential Address', Icons.home_rounded, [
                    TextFormField(controller: _addressCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Full Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on))),
                    const SizedBox(height: 14),
                    _field(_residentialContactCtrl, 'Contact Number', Icons.phone, keyboard: TextInputType.phone),
                  ]),

                  // ── Parent (Login) ──
                  _section('Parent Login Details', Icons.login_rounded, [
                    if (_parentUserId != null)
                      ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(_parentNameCtrl.text),
                        subtitle: Text('ID: $_parentUserId'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _parentUserId = null;
                            _parentNameCtrl.clear();
                            _parentContactCtrl.clear();
                          }),
                        ),
                        tileColor: Colors.blue.withOpacity(0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      )
                    else ...[
                      TextFormField(
                        controller: _parentSearchCtrl,
                        decoration: InputDecoration(
                          labelText: 'Search Existing Parent (Phone)',
                          hintText: 'Enter at least 3 digits to find existing data',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _parentSearching ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: _searchParents,
                      ),
                      if (_parentSearchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _parentSearchResults.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final p = _parentSearchResults[i];
                                return ListTile(
                                  title: Text(p['full_name'] ?? ''),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p['phone'] ?? ''),
                                      if (p['students'] != null && (p['students'] as List).isNotEmpty)
                                        Text(
                                          'Parent of: ${(p['students'] as List).join(", ")}',
                                          style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                  onTap: () => _onParentSelected(p),
                                );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text('Or enter new parent details below:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      _field(_parentNameCtrl, 'Parent Name (for login) *', Icons.person),
                      _field(_parentContactCtrl, 'Parent Contact', Icons.phone, keyboard: TextInputType.phone),
                    ],
                  ]),

                  // ── Father ──
                  _section('Father Details', Icons.man_rounded, [
                    _field(_fatherNameCtrl, 'Father Name', Icons.person_outline),
                    _field(_fatherOccupationCtrl, 'Occupation', Icons.work_outline),
                    _field(_fatherContactCtrl, 'Contact No', Icons.phone_outlined, keyboard: TextInputType.phone),
                    _field(_fatherEmailCtrl, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                  ]),

                  // ── Mother ──
                  _section('Mother Details', Icons.woman_rounded, [
                    _field(_motherNameCtrl, 'Mother Name', Icons.person_outline),
                    _field(_motherOccupationCtrl, 'Occupation', Icons.work_outline),
                    _field(_motherContactCtrl, 'Contact No', Icons.phone_outlined, keyboard: TextInputType.phone),
                    _field(_motherEmailCtrl, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                  ]),

                  // ── Guardian / Emergency ──
                  _section('Guardian & Emergency Contact', Icons.shield_rounded, [
                    _field(_guardianNameCtrl, 'Guardian Name', Icons.person_outline),
                    _field(_guardianRelationCtrl, 'Relation', Icons.family_restroom),
                    _field(_guardianContactCtrl, 'Guardian Contact', Icons.phone, keyboard: TextInputType.phone),
                    const Divider(height: 24),
                    _field(_emergencyNameCtrl, 'Emergency Contact Name', Icons.emergency_rounded),
                    _field(_emergencyPhoneCtrl, 'Emergency Phone', Icons.phone_callback, keyboard: TextInputType.phone),
                  ]),

                  // ── Previous School ──
                  _section('Previous Schooling', Icons.history_edu_rounded, [
                    SwitchListTile(
                      title: const Text('Attended Previously?', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: _attendedPreviously,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _attendedPreviously = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_attendedPreviously) ...[
                      _field(_prevSchoolNameCtrl, 'School / Daycare Name', Icons.school_outlined),
                      _row([
                        Expanded(child: _field(_prevSchoolDurationCtrl, 'Duration', Icons.timelapse)),
                        const SizedBox(width: 12),
                        Expanded(child: _field(_prevSchoolClassCtrl, 'Class', Icons.class_outlined)),
                      ]),
                    ],
                  ]),

                  // ── Documents ──
                  _section('Documents Submitted', Icons.folder_rounded, [
                    _check('Birth Certificate', _birthCert, (v) => setState(() => _birthCert = v!)),
                    _check('Immunization Record', _immunization, (v) => setState(() => _immunization = v!)),
                    _check('Transfer Certificate', _transferCert, (v) => setState(() => _transferCert = v!)),
                    _check('Passport Photos', _passportPhotos, (v) => setState(() => _passportPhotos = v!)),
                    _check('Progress Report', _progressReport, (v) => setState(() => _progressReport = v!)),
                    _check('Passport Copy', _passport, (v) => setState(() => _passport = v!)),
                    _check('Other Medical Report', _otherMedical, (v) => setState(() => _otherMedical = v!)),
                  ]),

                  // ── Transport ──
                  _section('Transport', Icons.directions_bus_rounded, [
                    SwitchListTile(
                      title: const Text('Transport Required?', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: _transportRequired,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _transportRequired = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // ── Submit ──
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.school_rounded),
                    label: Text(_submitting ? 'Processing...' : 'Complete Admission', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ── Helpers ──

  Widget _section(String title, IconData icon, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
      ]),
      const SizedBox(height: 16),
      ...children,
    ]),
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: Icon(icon, size: 18), isDense: true),
    ),
  );

  Widget _row(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: children),
  );

  Widget _check(String label, bool value, ValueChanged<bool?> onChanged) => CheckboxListTile(
    title: Text(label, style: const TextStyle(fontSize: 14)),
    value: value,
    onChanged: onChanged,
    activeColor: AppColors.primary,
    dense: true,
    contentPadding: EdgeInsets.zero,
  );
}
