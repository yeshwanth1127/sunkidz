import 'package:flutter/material.dart';

/// Date of Birth picker with auto-calculated age display.
class DobPicker extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const DobPicker({super.key, required this.value, required this.onChanged});

  static (int years, int months) calculateAge(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    int months = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) months--;
    months = months % 12;
    return (years, months);
  }

  @override
  Widget build(BuildContext context) {
    final (years, months) = value != null ? calculateAge(value!) : (0, 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now().subtract(const Duration(days: 365 * 3)),
              firstDate: DateTime(2010),
              lastDate: DateTime.now(),
            );
            if (picked != null) onChanged(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Date of Birth',
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(
              value != null ? '${value!.day}/${value!.month}/${value!.year}' : 'Tap to select',
              style: TextStyle(color: value != null ? null : Colors.grey),
            ),
          ),
        ),
        if (value != null) ...[
          const SizedBox(height: 8),
          Text(
            months > 0 ? 'Age: $years years $months months' : 'Age: $years years',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }
}
