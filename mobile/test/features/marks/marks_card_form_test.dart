import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunkidz_lms/shared/widgets/marks_card_form.dart';

// Sample student — not the client's real data.
const _student = {
  'id': 'stu-1',
  'name': 'Sample Child',
  'father_name': 'Sample Father',
  'mother_name': 'Sample Mother',
  'date_of_birth': '2021-05-04',
  'class_name': 'IG2',
  'branch_name': 'Marathahalli',
};

Widget _wrap(
  Map<String, dynamic> initial, {
  required Future<void> Function(Map<String, dynamic>) onSave,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MarksCardForm(
          student: const {..._student},
          academicYear: '2026-27',
          initialData: initial,
          onSave: onSave,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the PERFORMANCE PROFILE structure from student data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap({}, onSave: (_) async {}));
    await tester.pumpAndSettle();

    expect(find.text('Sun Kidz'), findsOneWidget);
    expect(find.text('PERFORMANCE PROFILE'), findsOneWidget);
    expect(find.text('SCHOLASTIC AREA'), findsOneWidget);
    expect(find.text('CO-SCHOLASTIC AREA'), findsOneWidget);

    // Student identity comes from the passed record.
    expect(find.text('Sample Child'), findsOneWidget);
    expect(find.text('Sample Father'), findsOneWidget);
    expect(find.text('Sample Mother'), findsOneWidget);
    expect(find.text('2021-05-04'), findsOneWidget);

    // Report-card scaffolding.
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Class Teacher Remarks'), findsOneWidget);
    expect(find.text('Passed to'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('edits are collected and passed to onSave', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      _wrap({}, onSave: (d) async => saved = Map<String, dynamic>.from(d)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('attendance')),
      '182 / 210',
    );
    await tester.enterText(
      find.byKey(const ValueKey('remarks')),
      'Consistent effort throughout the year.',
    );
    await tester.enterText(find.byKey(const ValueKey('passed_to')), 'IG3');

    // One scholastic activity cell — stored verbatim as a String.
    await tester.enterText(
      find.byKey(const ValueKey('english.Writing.pt1')),
      '18',
    );

    await tester.ensureVisible(find.text('Save Marks'));
    await tester.tap(find.text('Save Marks'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!['attendance'], '182 / 210');
    expect(saved!['remarks'], 'Consistent effort throughout the year.');
    expect(saved!['passed_to'], 'IG3');
    expect((saved!['english'] as Map)['Writing']['pt1'], '18');
  });

  testWidgets('pre-existing marks data is shown for editing', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap({
        'attendance': '190 / 205',
        'remarks': 'Existing remark',
        'english': {
          'Writing': {
            'pt1': 15,
            'ca1': 5,
            'hy': 10,
            'pt2': 21,
            'ca2': 4,
            'an': 6,
          },
        },
      }, onSave: (_) async {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('190 / 205'), findsOneWidget);
    expect(find.text('Existing remark'), findsOneWidget);
    // Derived, read-only columns:
    expect(find.text('30'), findsOneWidget); // Term 1 = 15 + 5 + 10
    expect(find.text('31'), findsOneWidget); // Term 2 = 21 + 4 + 6
    expect(find.text('61'), findsOneWidget); // Total  = Term 1 + Term 2
  });

  testWidgets('scholastic columns are in the exact required order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap({}, onSave: (_) async {}));
    await tester.pumpAndSettle();

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
        reason: '"${order[i]}" should sit right of "${order[i - 1]}"',
      );
    }
  });

  testWidgets('Term 2 / Total update live while typing, inputs unrestricted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      _wrap({}, onSave: (d) async => saved = Map<String, dynamic>.from(d)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('english.Writing.hy')),
      '10',
    );
    await tester.enterText(
      find.byKey(const ValueKey('english.Writing.pt2')),
      '40',
    );
    await tester.enterText(
      find.byKey(const ValueKey('english.Writing.ca2')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('english.Writing.an')),
      '2',
    );
    // A non-numeric ("grade") entry must still be accepted and just not add up.
    await tester.enterText(
      find.byKey(const ValueKey('english.Writing.pt1')),
      'A+',
    );
    await tester.pump();

    expect(find.text('45'), findsOneWidget); // Term 2 = 40 + 3 + 2
    expect(find.text('55'), findsOneWidget); // Total  = 10 (Term 1) + 45

    await tester.ensureVisible(find.text('Save Marks'));
    await tester.tap(find.text('Save Marks'));
    await tester.pumpAndSettle();

    final w = (saved!['english'] as Map)['Writing'] as Map;
    expect(w['pt2'], '40');
    expect(w['an'], '2');
    expect(w['pt1'], 'A+'); // stored verbatim, unrestricted
  });
}
