import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Small inline copy icon shown next to a student's admission number.
/// Renders nothing when there's no real number to copy (null / empty / '—').
class CopyAdmissionNumberButton extends StatelessWidget {
  final String? admissionNumber;
  final Color? color;
  final double size;

  const CopyAdmissionNumberButton({
    super.key,
    required this.admissionNumber,
    this.color,
    this.size = 14,
  });

  static bool hasValue(String? value) {
    final v = value?.trim() ?? '';
    return v.isNotEmpty && v != '—' && v != '?' && v != 'N/A';
  }

  static Future<void> copy(BuildContext context, String admissionNumber) async {
    await Clipboard.setData(ClipboardData(text: admissionNumber.trim()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Admission number ${admissionNumber.trim()} copied'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final value = admissionNumber;
    if (!hasValue(value)) return const SizedBox.shrink();
    return Tooltip(
      message: 'Copy admission number',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => copy(context, value!),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.copy_rounded,
            size: size,
            color: color ?? Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
