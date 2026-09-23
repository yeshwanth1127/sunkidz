import 'package:flutter/material.dart';
import '../../core/utils/branch_system.dart';

/// The app's standard Branch / Grade filter dropdowns (as first used on the
/// Student Directory and Enquiries screens): rounded, borderless, filled,
/// with an "All Branches" / "All Grades" option. Grades come from
/// [kFixedGradeOptions] in canonical order (Playgroup -> IG1 -> IG2 -> IG3);
/// callers filter rows by comparing [canonicalGradeLabel] of the row's class
/// name against the selected grade.

InputDecoration _filterDecoration(IconData icon, String hint, Color fill) =>
    InputDecoration(
      prefixIcon: Icon(icon, size: 18),
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: fill,
    );

class BranchFilterDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> branches;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final Color fillColor;

  const BranchFilterDropdown({
    super.key,
    required this.branches,
    required this.value,
    required this.onChanged,
    this.fillColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: _filterDecoration(
          Icons.apartment_rounded,
          'Branch',
          fillColor,
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('All Branches')),
          ...branches.map(
            (b) => DropdownMenuItem(
              value: b['id']?.toString(),
              child: Text(
                b['name']?.toString() ?? '—',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class GradeFilterDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?>? onChanged;
  final List<String> grades;
  final Color fillColor;

  const GradeFilterDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.grades = kFixedGradeOptions,
    this.fillColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: _filterDecoration(
          Icons.grid_3x3_rounded,
          'Grade',
          fillColor,
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('All Grades')),
          ...grades.map(
            (g) => DropdownMenuItem(
              value: g,
              child: Text(g, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
