import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'marks_card_form.dart';

/// Read-only parent view of a Marks Card the Admin saved and sent.
///
/// Renders the **exact same** Sun Kidz PERFORMANCE PROFILE layout as the
/// Admin / Teacher card by reusing [MarksCardForm] in [MarksCardForm.readOnly]
/// mode, driven by the same free-form JSONB `data` blob returned by
/// `GET /parent/marks-cards`. There are no text fields, dropdowns, a "Save
/// Marks" button, or any other editing control — the one exception is the
/// **Parent** signature slot, which a parent may upload when
/// [onUploadSignature] is provided.
class MarksCardView extends StatelessWidget {
  const MarksCardView({
    super.key,
    required this.marksCard,
    this.onUploadSignature,
    this.signatureBaseUrl,
  });

  /// One element of `GET /parent/marks-cards` → `marks_cards[]`.
  final Map<String, dynamic> marksCard;

  /// Uploads the Parent signature image. `role` is always `'parent'` here.
  final Future<String?> Function(String role, Uint8List bytes, String filename)?
  onUploadSignature;

  final String? signatureBaseUrl;

  @override
  Widget build(BuildContext context) {
    final mc = marksCard;
    return MarksCardForm(
      readOnly: true,
      academicYear: mc['academic_year']?.toString() ?? '—',
      initialData: Map<String, dynamic>.from(mc['data'] as Map? ?? const {}),
      student: {
        'id': mc['student_id'],
        'name': mc['student_name'],
        'father_name': mc['father_name'],
        'mother_name': mc['mother_name'],
        'parent_name': mc['parent_name'],
        'date_of_birth': mc['date_of_birth'],
        'class_name': mc['class_name'],
        'branch_name': mc['branch_name'],
      },
      onUploadSignature: onUploadSignature,
      signatureUploadRoles:
          onUploadSignature != null ? const {'parent'} : const {},
      signatureBaseUrl: signatureBaseUrl,
    );
  }
}
