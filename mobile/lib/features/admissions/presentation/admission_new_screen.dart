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

  final _studentNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _parentContactCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _studentNameCtrl.dispose();
    _dobCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentContactCtrl.dispose();
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
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadClasses(String branchId) async {
    final api = ref.read(adminApiProvider);
    if (api == null) return;
    try {
      final classes = await api.getClasses(branchId: branchId);
      if (mounted) {
        setState(() {
          _classes = classes;
          _classId = classes.isNotEmpty ? classes.first['id']?.toString() : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _classes = [];
          _classId = null;
        });
      }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branch and class are required')));
      return;
    }
    final name = _studentNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student name is required')));
      return;
    }
    final dob = _dobCtrl.text.trim();
    if (dob.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date of birth is required')));
      return;
    }
    final parentName = _parentNameCtrl.text.trim();
    if (parentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parent name is required for login')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await api.createDirectAdmission({
        'branch_id': _branchId,
        'class_id': _classId,
        'name': name,
        'date_of_birth': dob,
        'parent_name': parentName,
        'parent_contact': _parentContactCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admission created successfully. Parent can login with Admission No & DOB.')));
        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/admissions');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Direct Admission', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Branch & Class', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _branchId,
                          decoration: const InputDecoration(labelText: 'Branch *', border: OutlineInputBorder()),
                          items: _branches.map((b) => DropdownMenuItem(value: b['id']?.toString(), child: Text(b['name']?.toString() ?? '—'))).toList(),
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
                          decoration: const InputDecoration(labelText: 'Class / Grade *', border: OutlineInputBorder()),
                          items: _classes.map((c) => DropdownMenuItem(value: c['id']?.toString(), child: Text(c['name']?.toString() ?? '—'))).toList(),
                          onChanged: (v) => setState(() => _classId = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Student & Parent Required Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _studentNameCtrl,
                          decoration: const InputDecoration(labelText: 'Student Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dobCtrl,
                          readOnly: true,
                          onTap: _pickDate,
                          decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD) *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today_rounded)),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _parentNameCtrl,
                          decoration: const InputDecoration(labelText: 'Parent Name (for login) *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.people_outline)),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _parentContactCtrl,
                          decoration: const InputDecoration(labelText: 'Parent Contact Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.school_rounded),
                    label: Text(_submitting ? 'Processing...' : 'Complete Admission', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }
}
