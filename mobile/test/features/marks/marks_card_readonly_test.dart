import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunkidz_lms/shared/widgets/marks_card_form.dart';
import 'package:sunkidz_lms/shared/widgets/marks_card_view.dart';

// One entry as returned by GET /parent/marks-cards -> marks_cards[].
const _parentPayload = {
  'id': 'card-1',
  'student_id': 'stu-1',
  'student_name': 'Sample Child',
  'admission_number': 'SS-001',
  'branch_name': 'Marathahalli',
  'class_name': 'IG2',
  'academic_year': '2026-27',
  'father_name': 'Sample Father',
  'mother_name': 'Sample Mother',
  'parent_name': 'Sample Father',
  'date_of_birth': '2021-05-04',
  'sent_at': '2026-06-01T00:00:00+00:00',
  'data': {
    'attendance': '182 / 210',
    'english': {
      'Writing': {'pt1': '18', 'ca1': 'A+', 'hy': '17'},
    },
    'co_discipline_t1': 'A+',
    'co_confidence_t2': 'B-',
    'remarks': 'Consistent effort throughout the year.',
    'passed_to': 'IG3',
  },
};

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('read-only MarksCardForm has no editing controls at all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        const MarksCardForm(
          readOnly: true,
          student: {
            'id': 'stu-1',
            'name': 'Sample Child',
            'father_name': 'Sample Father',
            'mother_name': 'Sample Mother',
            'date_of_birth': '2021-05-04',
            'class_name': 'IG2',
            'branch_name': 'Marathahalli',
          },
          academicYear: '2026-27',
          initialData: {
            'attendance': '182 / 210',
            'english': {
              'Writing': {'pt1': '18', 'ca1': 'A+', 'hy': '17'},
            },
            'co_discipline_t1': 'A+',
            'remarks': 'Great year.',
            'passed_to': 'IG3',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Absolutely no editable widgets.
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.text('Save Marks'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);

    // Same PERFORMANCE PROFILE structure + the saved values are visible.
    expect(find.text('PERFORMANCE PROFILE'), findsOneWidget);
    expect(find.text('SCHOLASTIC AREA'), findsOneWidget);
    expect(find.text('CO-SCHOLASTIC AREA'), findsOneWidget);
    expect(find.text('Sample Child'), findsOneWidget);
    expect(find.text('Sample Father'), findsOneWidget);
    expect(find.text('Sample Mother'), findsOneWidget);
    expect(find.text('182 / 210'), findsOneWidget); // attendance
    expect(find.text('Great year.'), findsOneWidget); // remarks
    expect(find.text('IG3'), findsOneWidget); // passed to
    // arbitrary-string scholastic + co-scholastic values render verbatim
    expect(find.text('A+'), findsWidgets);
    expect(find.text('17'), findsOneWidget);
  });

  testWidgets(
    'editable MarksCardForm still shows its controls (no regression)',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          MarksCardForm(
            student: const {'id': 'stu-1', 'name': 'Sample Child'},
            academicYear: '2026-27',
            initialData: const {},
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Save Marks'), findsOneWidget);
    },
  );

  testWidgets(
    'Father Name and Mother Name each come from their OWN field — never copied',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          const MarksCardForm(
            readOnly: true,
            student: {
              'id': 'stu-9',
              'name': 'Sample Child',
              'father_name': 'Ramesh Rao',
              'mother_name': 'Anitha Rao',
              // A linked-account name must NEVER leak into either cell.
              'parent_name': 'Raju',
            },
            academicYear: '2026-27',
            initialData: {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ramesh Rao'), findsOneWidget);
      expect(find.text('Anitha Rao'), findsOneWidget);
      expect(find.text('Raju'), findsNothing);
    },
  );

  testWidgets(
    'a blank parent field shows "—" — not the other parent, not the login name',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          const MarksCardForm(
            readOnly: true,
            student: {
              'id': 'stu-9',
              'name': 'Sample Child',
              'father_name': 'Raju', // father set
              // mother_name absent
              'date_of_birth': '2021-05-04',
              'class_name': 'IG2',
              'branch_name': 'Marathahalli',
              'parent_name': 'Raju', // linked account — must not leak
            },
            academicYear: '2026-27',
            initialData: {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The regression: "Raju" used to appear twice (father field + mother
      // fallback). It must now appear exactly once, and the empty Mother cell
      // renders the "—" placeholder.
      expect(find.text('Raju'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    },
  );

  testWidgets('MarksCardView renders the saved card from the parent payload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(const MarksCardView(marksCard: _parentPayload)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Save Marks'), findsNothing);

    expect(find.text('Sample Child'), findsOneWidget);
    expect(find.text('182 / 210'), findsOneWidget);
    expect(find.text('Consistent effort throughout the year.'), findsOneWidget);
    expect(find.text('IG3'), findsOneWidget);
    expect(find.text('B-'), findsOneWidget); // co_confidence_t2
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'parent scholastic table matches Admin exactly: 10 columns in order, with '
    'calculated Term 1 / Term 2 / Total, read-only',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const payload = {
        'student_id': 'stu-1',
        'student_name': 'Sample Child',
        'father_name': 'Sample Father',
        'mother_name': 'Sample Mother',
        'academic_year': '2026-27',
        'class_name': 'IG2',
        'branch_name': 'Marathahalli',
        'data': {
          'english': {
            // Term 1 = 12+8+10 = 30, Term 2 = 20+4+7 = 31, Total = 61
            'Writing': {
              'pt1': 12,
              'ca1': 8,
              'hy': 10,
              'pt2': 20,
              'ca2': 4,
              'an': 7,
            },
          },
        },
      };

      await tester.pumpWidget(_host(const MarksCardView(marksCard: payload)));
      await tester.pumpAndSettle();

      // Completely read-only.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('Save Marks'), findsNothing);

      // Exact column order.
      const order = [
        'Subject / Activity',
        'PT1',
        'CA1',
        'HY',
        'Term 1',
        'PT2',
        'CA2',
        'AN',
        'Term 2',
        'Total',
      ];
      for (final h in order) {
        expect(find.text(h), findsWidgets, reason: 'missing header "$h"');
      }
      double xOf(String t) => tester.getTopLeft(find.text(t).first).dx;
      for (var i = 1; i < order.length; i++) {
        expect(
          xOf(order[i]),
          greaterThan(xOf(order[i - 1])),
          reason: '"${order[i]}" must sit right of "${order[i - 1]}"',
        );
      }

      // Same calculated values the Admin/Teacher card shows.
      expect(find.text('30'), findsOneWidget); // Term 1
      expect(find.text('31'), findsOneWidget); // Term 2
      expect(find.text('61'), findsOneWidget); // Total
      expect(tester.takeException(), isNull);
    },
  );
}
