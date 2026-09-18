import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunkidz_lms/shared/widgets/marks_card_form.dart';
import 'package:sunkidz_lms/shared/widgets/marks_card_view.dart';

const _student = {
  'id': 'stu-1',
  'name': 'Sample Child',
  'father_name': 'Sample Father',
  'mother_name': 'Sample Mother',
  'date_of_birth': '2021-05-04',
  'class_name': 'IG2',
  'branch_name': 'Marathahalli',
};

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

Future<String?> _fakeUpload(
  String role,
  Uint8List bytes,
  String filename,
) async => 'uploads/marks_signatures/new_$role.png';

Future<void> _pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(500, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(_host(w));
  await t.pump(); // no pumpAndSettle: don't drive Image.network loads
}

void main() {
  testWidgets('editable card: an Upload control in every signature slot', (
    t,
  ) async {
    await _pump(
      t,
      MarksCardForm(
        student: const {..._student},
        academicYear: '2026-27',
        initialData: const {},
        onSave: (_) async {},
        onUploadSignature: _fakeUpload,
        signatureUploadRoles: const {'parent', 'class_teacher', 'principal'},
        signatureBaseUrl: 'http://x',
      ),
    );

    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Class Teacher'), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Upload'), findsNWidgets(3));
    expect(find.widgetWithText(TextButton, 'Replace'), findsNothing);
  });

  testWidgets('read-only parent card: Upload only in the Parent slot', (
    t,
  ) async {
    await _pump(
      t,
      MarksCardForm(
        readOnly: true,
        student: const {..._student},
        academicYear: '2026-27',
        initialData: const {},
        onUploadSignature: _fakeUpload,
        signatureUploadRoles: const {'parent'},
        signatureBaseUrl: 'http://x',
      ),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Save Marks'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Upload'), findsOneWidget);
  });

  testWidgets('no signature callback: no upload controls at all', (t) async {
    await _pump(
      t,
      MarksCardForm(
        readOnly: true,
        student: const {..._student},
        academicYear: '2026-27',
        initialData: const {},
      ),
    );
    expect(find.widgetWithText(TextButton, 'Upload'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Replace'), findsNothing);
  });

  testWidgets('a saved signature is shown as an image + a Replace control', (
    t,
  ) async {
    await _pump(
      t,
      MarksCardForm(
        student: const {..._student},
        academicYear: '2026-27',
        initialData: const {'sig_parent': 'uploads/marks_signatures/abc.png'},
        onSave: (_) async {},
        onUploadSignature: _fakeUpload,
        signatureUploadRoles: const {'parent', 'class_teacher', 'principal'},
        signatureBaseUrl: 'http://host',
      ),
    );

    final images = t.widgetList<Image>(find.byType(Image)).toList();
    expect(images.length, 1);
    final provider = images.single.image;
    expect(provider, isA<NetworkImage>());
    expect(
      (provider as NetworkImage).url,
      'http://host/uploads/marks_signatures/abc.png',
    );

    expect(find.widgetWithText(TextButton, 'Replace'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Upload'), findsNWidgets(2));
  });

  testWidgets(
    'MarksCardView passes the parent signature-upload wiring through',
    (t) async {
      await _pump(
        t,
        MarksCardView(
          marksCard: const {
            'student_id': 'stu-1',
            'student_name': 'Sample Child',
            'academic_year': '2026-27',
            'data': {'sig_class_teacher': 'uploads/marks_signatures/ct.png'},
          },
          signatureBaseUrl: 'http://host',
          onUploadSignature: _fakeUpload,
        ),
      );

      expect(
        find.byType(Image),
        findsOneWidget,
      ); // class-teacher signature (read only)
      expect(
        find.widgetWithText(TextButton, 'Upload'),
        findsOneWidget,
      ); // parent only
    },
  );
}
