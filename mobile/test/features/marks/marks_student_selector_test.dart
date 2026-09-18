import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunkidz_lms/features/marks/presentation/marks_student_selector.dart';

/// Sample data — deliberately NOT the client's real branches/grades/students.
const _branches = [
  {'id': 'b1', 'name': 'Marathahalli'},
  {'id': 'b2', 'name': 'Whitefield'},
];
const _classesByBranch = {
  'b1': [
    {'id': 'c1', 'name': 'Playgroup', 'branch_id': 'b1'},
    {'id': 'c2', 'name': 'IG1', 'branch_id': 'b1'},
    {'id': 'c3', 'name': 'IG2', 'branch_id': 'b1'},
  ],
  'b2': <Map<String, dynamic>>[],
};
const _studentsByClass = {
  'c2': [
    {'id': 's1', 'name': 'Test Student One', 'admission_number': 'TS-001'},
    {'id': 's2', 'name': 'Test Student Two', 'admission_number': 'TS-002'},
  ],
};

class _Harness extends StatefulWidget {
  const _Harness({this.onStudent});
  final ValueChanged<Map<String, dynamic>?>? onStudent;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String? branchId;
  String? classId;
  Map<String, dynamic>? student;
  String year = '2026-27';

  List<Map<String, dynamic>> get classes =>
      branchId == null ? [] : List.of(_classesByBranch[branchId] ?? []);

  List<Map<String, dynamic>> get students =>
      classId == null ? [] : List.of(_studentsByClass[classId] ?? []);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarksStudentSelector(
            branches: const [..._branches],
            classes: classes,
            students: students,
            selectedBranchId: branchId,
            selectedClassId: classId,
            selectedStudent: student,
            academicYear: year,
            academicYearOptions: const ['2026-27'],
            onBranchChanged:
                (v) => setState(() {
                  branchId = v;
                  classId = null;
                  student = null;
                }),
            onClassChanged:
                (v) => setState(() {
                  classId = v;
                  student = null;
                }),
            onStudentChanged: (v) {
              setState(() => student = v);
              widget.onStudent?.call(v);
            },
            onAcademicYearChanged: (v) => setState(() => year = v),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Grade dropdown is disabled until a branch is selected', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    expect(find.text('Select a branch first'), findsWidgets);

    // Tapping the disabled Grade field opens nothing.
    await tester.tap(find.byKey(const Key('marks_grade_dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('IG1'), findsNothing);
  });

  testWidgets('selecting a branch enables the Grade dropdown and it opens', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('marks_branch_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marathahalli').last);
    await tester.pumpAndSettle();

    // Grade now opens and shows the branch's grades.
    await tester.tap(find.byKey(const Key('marks_grade_dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('Playgroup'), findsWidgets);
    expect(find.text('IG1'), findsWidgets);
    expect(find.text('IG2'), findsWidgets);
  });

  testWidgets('a branch with no grades shows an explanatory hint', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('marks_branch_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Whitefield').last);
    await tester.pumpAndSettle();

    expect(find.text('No grades in this branch'), findsOneWidget);
  });

  testWidgets('full Branch → Grade → Student flow reports the chosen student', (
    tester,
  ) async {
    Map<String, dynamic>? picked;
    await tester.pumpWidget(_Harness(onStudent: (s) => picked = s));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('marks_branch_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marathahalli').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('marks_grade_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IG1').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('marks_student_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Student One (TS-001)').last);
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!['id'], 's1');
  });

  testWidgets('no layout overflow on a narrow phone viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('marks_branch_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marathahalli').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
