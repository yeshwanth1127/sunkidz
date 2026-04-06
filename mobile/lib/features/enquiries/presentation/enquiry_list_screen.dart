import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/api/admin_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../../dashboard/data/dashboard_provider.dart';

class EnquiryListScreen extends ConsumerStatefulWidget {
  const EnquiryListScreen({super.key});

  @override
  ConsumerState<EnquiryListScreen> createState() => _EnquiryListScreenState();
}

class _EnquiryListScreenState extends ConsumerState<EnquiryListScreen> {
  List<Map<String, dynamic>> _enquiries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final enquiries = await api.getEnquiries();
      if (mounted) {
        setState(() {
          _enquiries = enquiries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _showEnquiryForm() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEnquirySheet(
        onDone: () {
          Navigator.pop(ctx);
          _load();
          ref.invalidate(dashboardDataProvider);
        },
      ),
    );
  }

  Future<void> _rejectEnquiry(Map<String, dynamic> enquiry) async {
    final id = enquiry['id']?.toString();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject enquiry?'),
        content: Text('Reject enquiry for ${enquiry['child_name'] ?? 'this child'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      await api.rejectEnquiry(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enquiry rejected')));
        await _load();
        ref.invalidate(dashboardDataProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _convertEnquiry(Map<String, dynamic> enquiry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConvertEnquirySheet(
        enquiry: enquiry,
        onDone: () {
          Navigator.pop(ctx);
          _load();
          ref.invalidate(dashboardDataProvider);
        },
      ),
    );
  }

  void _showEnquiryDetails(Map<String, dynamic> enquiry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EnquiryDetailSheet(enquiry: enquiry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AdminDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildSummaryHeader(),
            Expanded(
              child: _loading
                  ? const _EnquiryLoadingPlaceholder()
                  : _error != null
                      ? _buildErrorState()
                      : _enquiries.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _enquiries.length,
                                itemBuilder: (context, i) => AnimatedListItem(
                                  index: i,
                                  child: _EnquiryCard(
                                    enquiry: _enquiries[i],
                                    onTap: () => _showEnquiryDetails(_enquiries[i]),
                                    onConvert: () => _convertEnquiry(_enquiries[i]),
                                    onReject: () => _rejectEnquiry(_enquiries[i]),
                                  ),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showEnquiryForm,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_comment_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B)),
          ),
          const SizedBox(width: 8),
          const Text(
            'Admissions Enquiries',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: Icon(Icons.refresh_rounded, color: _loading ? Colors.grey : AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final pendingCount = _enquiries.where((e) {
      final s = e['status']?.toString().toLowerCase() ?? '';
      return s != 'converted' && s != 'rejected';
    }).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [AppShadows.glow(AppColors.primary)],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                const Text('Active Enquiries', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                Text('$pendingCount Needs Attention', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() => Center(child: Text(_error ?? 'Error'));
  Widget _buildEmptyState() => const Center(child: Text('No enquiries yet'));
}

class _EnquiryCard extends StatelessWidget {
  final Map<String, dynamic> enquiry;
  final VoidCallback onTap;
  final VoidCallback onConvert;
  final VoidCallback onReject;

  const _EnquiryCard({required this.enquiry, required this.onTap, required this.onConvert, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final status = enquiry['status']?.toString().toLowerCase() ?? 'pending';
    final Color statusColor = status == 'converted' ? AppColors.accentGreen : status == 'rejected' ? Colors.red : Colors.amber;
    final isActionable = status != 'converted' && status != 'rejected';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppShadows.soft],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.mail_outline_rounded, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(enquiry['child_name'] ?? 'Inquiry', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                        Text(enquiry['branch_name'] ?? 'Branch', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ),
          if (isActionable) ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                      label: const Text('REJECT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: onConvert,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.school_rounded, size: 16),
                      label: const Text('CONVERT TO STUDENT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddEnquirySheet extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const _AddEnquirySheet({required this.onDone});

  @override
  ConsumerState<_AddEnquirySheet> createState() => _AddEnquirySheetState();
}

class _AddEnquirySheetState extends ConsumerState<_AddEnquirySheet> {
  List<Map<String, dynamic>> _branches = [];
  String? _branchId;
  String? _gender;
  bool _loading = true;
  bool _submitting = false;

  // Child
  final _childNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _ageYearsCtrl = TextEditingController();
  final _ageMonthsCtrl = TextEditingController();

  // Father
  final _fatherNameCtrl = TextEditingController();
  final _fatherPhoneCtrl = TextEditingController();
  final _fatherEmailCtrl = TextEditingController();
  final _fatherOccupationCtrl = TextEditingController();
  final _fatherWorkCtrl = TextEditingController();

  // Mother
  final _motherNameCtrl = TextEditingController();
  final _motherPhoneCtrl = TextEditingController();
  final _motherEmailCtrl = TextEditingController();
  final _motherOccupationCtrl = TextEditingController();
  final _motherWorkCtrl = TextEditingController();

  // Address
  final _addressCtrl = TextEditingController();
  final _residentialPhoneCtrl = TextEditingController();

  // Siblings
  final _siblingsInfoCtrl = TextEditingController();
  final _siblingsAgeCtrl = TextEditingController();

  // School notes
  final _challengesCtrl = TextEditingController();
  final _expectationsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _childNameCtrl.dispose(); _dobCtrl.dispose(); _ageYearsCtrl.dispose(); _ageMonthsCtrl.dispose();
    _fatherNameCtrl.dispose(); _fatherPhoneCtrl.dispose(); _fatherEmailCtrl.dispose();
    _fatherOccupationCtrl.dispose(); _fatherWorkCtrl.dispose();
    _motherNameCtrl.dispose(); _motherPhoneCtrl.dispose(); _motherEmailCtrl.dispose();
    _motherOccupationCtrl.dispose(); _motherWorkCtrl.dispose();
    _addressCtrl.dispose(); _residentialPhoneCtrl.dispose();
    _siblingsInfoCtrl.dispose(); _siblingsAgeCtrl.dispose();
    _challengesCtrl.dispose(); _expectationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      final branches = await api.getBranches();
      if (mounted) {
        setState(() {
          _branches = branches;
          if (branches.isNotEmpty) _branchId = branches.first['id']?.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dobCtrl.text) ?? DateTime.now().subtract(const Duration(days: 365 * 3));
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (date != null) setState(() => _dobCtrl.text = DateFormat('yyyy-MM-dd').format(date));
  }

  String? _t(TextEditingController c) { final v = c.text.trim(); return v.isEmpty ? null : v; }

  Future<void> _submit() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    if (_childNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Child name is required')));
      return;
    }
    if (_branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a branch')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'child_name': _childNameCtrl.text.trim(),
        if (_t(_dobCtrl) != null) 'date_of_birth': _t(_dobCtrl),
        if (_t(_ageYearsCtrl) != null) 'age_years': int.tryParse(_ageYearsCtrl.text.trim()),
        if (_t(_ageMonthsCtrl) != null) 'age_months': int.tryParse(_ageMonthsCtrl.text.trim()),
        if (_gender != null) 'gender': _gender,
        if (_t(_fatherNameCtrl) != null) 'father_name': _t(_fatherNameCtrl),
        if (_t(_fatherPhoneCtrl) != null) 'father_contact_no': _t(_fatherPhoneCtrl),
        if (_t(_fatherEmailCtrl) != null) 'father_email': _t(_fatherEmailCtrl),
        if (_t(_fatherOccupationCtrl) != null) 'father_occupation': _t(_fatherOccupationCtrl),
        if (_t(_fatherWorkCtrl) != null) 'father_place_of_work': _t(_fatherWorkCtrl),
        if (_t(_motherNameCtrl) != null) 'mother_name': _t(_motherNameCtrl),
        if (_t(_motherPhoneCtrl) != null) 'mother_contact_no': _t(_motherPhoneCtrl),
        if (_t(_motherEmailCtrl) != null) 'mother_email': _t(_motherEmailCtrl),
        if (_t(_motherOccupationCtrl) != null) 'mother_occupation': _t(_motherOccupationCtrl),
        if (_t(_motherWorkCtrl) != null) 'mother_place_of_work': _t(_motherWorkCtrl),
        if (_t(_addressCtrl) != null) 'residential_address': _t(_addressCtrl),
        if (_t(_residentialPhoneCtrl) != null) 'residential_contact_no': _t(_residentialPhoneCtrl),
        if (_t(_siblingsInfoCtrl) != null) 'siblings_info': _t(_siblingsInfoCtrl),
        if (_t(_siblingsAgeCtrl) != null) 'siblings_age': _t(_siblingsAgeCtrl),
        if (_t(_challengesCtrl) != null) 'challenges_specialities': _t(_challengesCtrl),
        if (_t(_expectationsCtrl) != null) 'expectations_from_school': _t(_expectationsCtrl),
        'branch_id': _branchId,
        'status': 'pending',
      };
      payload.removeWhere((_, v) => v == null);
      await api.createEnquiry(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enquiry saved successfully!')));
        widget.onDone();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _sec(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: AppColors.primary.withOpacity(0.25))),
    ]),
  );

  Widget _f(TextEditingController c, String label, {IconData? ico, TextInputType? kb, int ml = 1, bool ro = false, VoidCallback? tap}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: c, readOnly: ro, onTap: tap, keyboardType: kb, maxLines: ml,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true,
        prefixIcon: ico != null ? Icon(ico, size: 18) : null),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: _loading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : Column(
                children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  Row(children: [
                    const Text('New Enquiry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ]),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 4, bottom: 24),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                        // ── CHILD ───────────────────────────────────────
                        _sec('Child Information', Icons.child_care),
                        _f(_childNameCtrl, 'Child Name *', ico: Icons.person_outline),
                        _f(_dobCtrl, 'Date of Birth', ico: Icons.calendar_today_rounded, ro: true, tap: _pickDate),
                        Row(children: [
                          Expanded(child: _f(_ageYearsCtrl, 'Age (Years)', kb: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(child: _f(_ageMonthsCtrl, 'Age (Months)', kb: TextInputType.number)),
                        ]),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.wc, size: 18)),
                            items: const [
                              DropdownMenuItem(value: 'Male', child: Text('Male')),
                              DropdownMenuItem(value: 'Female', child: Text('Female')),
                              DropdownMenuItem(value: 'Other', child: Text('Other')),
                            ],
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                        ),

                        // ── BRANCH ──────────────────────────────────────
                        _sec('Branch', Icons.school_outlined),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DropdownButtonFormField<String>(
                            value: _branchId,
                            decoration: const InputDecoration(labelText: 'Branch *', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.location_on_outlined, size: 18)),
                            items: _branches.map((b) => DropdownMenuItem(value: b['id']?.toString(), child: Text(b['name']?.toString() ?? '—'))).toList(),
                            onChanged: (v) => setState(() => _branchId = v),
                          ),
                        ),

                        // ── FATHER ──────────────────────────────────────
                        _sec("Father's Details", Icons.man),
                        _f(_fatherNameCtrl, 'Father Name', ico: Icons.person_outline),
                        _f(_fatherPhoneCtrl, 'Contact Number', ico: Icons.phone_outlined, kb: TextInputType.phone),
                        _f(_fatherEmailCtrl, 'Email', ico: Icons.email_outlined, kb: TextInputType.emailAddress),
                        _f(_fatherOccupationCtrl, 'Occupation', ico: Icons.work_outline),
                        _f(_fatherWorkCtrl, 'Place of Work', ico: Icons.business_outlined),

                        // ── MOTHER ──────────────────────────────────────
                        _sec("Mother's Details", Icons.woman),
                        _f(_motherNameCtrl, 'Mother Name', ico: Icons.person_outline),
                        _f(_motherPhoneCtrl, 'Contact Number', ico: Icons.phone_outlined, kb: TextInputType.phone),
                        _f(_motherEmailCtrl, 'Email', ico: Icons.email_outlined, kb: TextInputType.emailAddress),
                        _f(_motherOccupationCtrl, 'Occupation', ico: Icons.work_outline),
                        _f(_motherWorkCtrl, 'Place of Work', ico: Icons.business_outlined),

                        // ── ADDRESS ─────────────────────────────────────
                        _sec('Address & Contact', Icons.home_outlined),
                        _f(_addressCtrl, 'Residential Address', ico: Icons.location_on_outlined, ml: 2),
                        _f(_residentialPhoneCtrl, 'Residential Phone', ico: Icons.phone_outlined, kb: TextInputType.phone),

                        // ── SIBLINGS ────────────────────────────────────
                        _sec('Siblings (Optional)', Icons.people_outline),
                        _f(_siblingsInfoCtrl, 'Siblings Info (name / school)'),
                        _f(_siblingsAgeCtrl, 'Siblings Age(s)'),

                        // ── SCHOOL NOTES ────────────────────────────────
                        _sec('School Notes (Optional)', Icons.notes_outlined),
                        _f(_challengesCtrl, 'Challenges / Special Needs', ml: 2),
                        _f(_expectationsCtrl, 'Expectations from School', ml: 2),

                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _submitting
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save Enquiry', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Bottom sheet: pick branch + class, then POST /admin/admissions/from-enquiry
class _ConvertEnquirySheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> enquiry;
  final VoidCallback onDone;

  const _ConvertEnquirySheet({required this.enquiry, required this.onDone});

  @override
  ConsumerState<_ConvertEnquirySheet> createState() => _ConvertEnquirySheetState();
}

class _ConvertEnquirySheetState extends ConsumerState<_ConvertEnquirySheet> {
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _classes = [];
  String? _branchId;
  String? _classId;
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final api = ref.read(adminApiProvider);
    if (api == null) {
      setState(() {
        _loading = false;
        _loadError = 'Not signed in';
      });
      return;
    }
    
    // Prep form
    final enq = widget.enquiry;
    _nameCtrl.text = enq['child_name']?.toString().trim() ?? '';
    _dobCtrl.text = _isoDateFromEnquiry() ?? '';
    final fatherName = enq['father_name']?.toString().trim() ?? '';
    _parentNameCtrl.text = fatherName.isNotEmpty ? fatherName : (enq['mother_name']?.toString().trim() ?? '');
    _parentPhoneCtrl.text = enq['father_contact_no']?.toString() ?? enq['mother_contact_no']?.toString() ?? '';

    try {
      final branches = await api.getBranches();
      final enqBranch = widget.enquiry['branch_id']?.toString();
      String? branchId = enqBranch;
      if (branchId == null || !branches.any((b) => b['id']?.toString() == branchId)) {
        branchId = branches.isNotEmpty ? branches.first['id']?.toString() : null;
      }
      setState(() {
        _branches = branches;
        _branchId = branchId;
        _loading = false;
      });
      if (branchId != null) await _loadClasses(branchId);
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadClasses(String branchId) async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      final classes = await api.getClasses(branchId: branchId);
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _classId = classes.isNotEmpty ? classes.first['id']?.toString() : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _classes = [];
          _classId = null;
        });
      }
    }
  }

  String? _isoDateFromEnquiry() {
    final v = widget.enquiry['date_of_birth'];
    if (v == null) return null;
    try {
      final d = DateTime.parse(v.toString());
      return DateFormat('yyyy-MM-dd').format(d);
    } catch (_) {
      return null;
    }
  }
  
  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dobCtrl.text) ?? DateTime.now().subtract(const Duration(days: 365*3));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _dobCtrl.text = DateFormat('yyyy-MM-dd').format(date);
      });
    }
  }

  Future<void> _submit() async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    if (_branchId == null || _classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select branch and class')),
      );
      return;
    }
    
    final dob = _dobCtrl.text.trim();
    if (dob.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date of birth is required')),
      );
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Child name is required')),
      );
      return;
    }
    final parentName = _parentNameCtrl.text.trim();
    if (parentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parent name is required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await api.createAdmissionFromEnquiry({
        'enquiry_id': widget.enquiry['id'].toString(),
        'branch_id': _branchId,
        'class_id': _classId,
        'name': name,
        'date_of_birth': dob,
        'parent_name': parentName,
        'parent_contact': _parentPhoneCtrl.text.trim(),
        if (widget.enquiry['residential_address'] != null)
          'residential_address': widget.enquiry['residential_address'].toString(),
        if (widget.enquiry['gender'] != null) 'gender': widget.enquiry['gender'].toString(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Converted to admission — parent can log in with admission number and DOB')),
        );
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: _loading
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : _loadError != null
                  ? Text(_loadError!, style: const TextStyle(color: Colors.red))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Convert to student',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.enquiry['child_name']?.toString() ?? '',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Child Name *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dobCtrl,
                          readOnly: true,
                          onTap: _pickDate,
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth (YYYY-MM-DD) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _parentNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Parent/Guardian Name *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.people_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _parentPhoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Parent Contact (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: _branchId,
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                            border: OutlineInputBorder(),
                          ),
                          items: _branches
                              .map((b) => DropdownMenuItem(
                                    value: b['id']?.toString(),
                                    child: Text(b['name']?.toString() ?? '—'),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _branchId = v;
                              _classId = null;
                              _classes = [];
                            });
                            _loadClasses(v);
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _classId,
                          decoration: const InputDecoration(
                            labelText: 'Class / grade',
                            border: OutlineInputBorder(),
                          ),
                          items: _classes
                              .map((c) => DropdownMenuItem(
                                    value: c['id']?.toString(),
                                    child: Text(c['name']?.toString() ?? '—'),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _classId = v),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Create admission'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _EnquiryLoadingPlaceholder extends StatelessWidget {
  const _EnquiryLoadingPlaceholder();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          children: [
            const ShimmerLoading.circular(width: 48, height: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading.rectangular(height: 16, width: MediaQuery.of(context).size.width * 0.4),
                  const SizedBox(height: 8),
                  ShimmerLoading.rectangular(height: 12, width: MediaQuery.of(context).size.width * 0.2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnquiryDetailSheet extends StatelessWidget {
  final Map<String, dynamic> enquiry;
  const _EnquiryDetailSheet({required this.enquiry});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text('Inquiry Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          _DetailRow(label: 'Child Name', value: enquiry['child_name']),
          _DetailRow(label: 'Father Name', value: enquiry['father_name']),
          _DetailRow(label: 'Contact', value: enquiry['father_contact_no'] ?? enquiry['mother_contact_no']),
          _DetailRow(label: 'Residential', value: enquiry['residential_address']),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE2E8F0))),
              child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final dynamic value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }
}
