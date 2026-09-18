import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sunkidz_lms/core/api/admin_api.dart';
import 'package:sunkidz_lms/core/api/admin_provider.dart';
import 'package:sunkidz_lms/core/theme/app_theme.dart';
import 'package:sunkidz_lms/features/marks/presentation/marks_card_screen.dart';

/// Fake API — sample data only, never the client's real records.
class _FakeAdminApi extends AdminApi {
  _FakeAdminApi() : super('test-token');

  @override
  Future<List<Map<String, dynamic>>> getBranches() async => [
    {'id': 'b1', 'name': 'Marathahalli Main Branch', 'system_type': 'sunkidz'},
    {'id': 'b2', 'name': 'Whitefield', 'system_type': 'sunkidz'},
  ];

  @override
  Future<List<Map<String, dynamic>>> getClasses({String? branchId}) async => [
    {'id': 'c1', 'name': 'Playgroup', 'branch_id': branchId},
    {'id': 'c2', 'name': 'IG1', 'branch_id': branchId},
    {'id': 'c3', 'name': 'IG2', 'branch_id': branchId},
  ];

  @override
  Future<List<Map<String, dynamic>>> getAdmissions({
    String? branchId,
    String? classId,
    String? search,
  }) async => [
    {
      'id': 's1',
      'name': 'Sample Student One',
      'admission_number': 'SS-001',
      'date_of_birth': '2021-03-14',
      'father_name': 'Sample Father',
      'mother_name': 'Sample Mother',
      'class_name': 'IG1',
      'branch_name': 'Marathahalli Main Branch',
    },
  ];

  Map<String, dynamic>? saved;
  String? sentAt;
  int sendToParentCalls = 0;

  @override
  Future<Map<String, dynamic>> getMarks(
    String studentId, {
    String academicYear = '2026-27',
  }) async => {
    'student_id': studentId,
    'academic_year': academicYear,
    'data': saved,
    'sent_to_parent_at': sentAt,
  };

  @override
  Future<Map<String, dynamic>> upsertMarks(
    String studentId, {
    required String academicYear,
    required Map<String, dynamic> data,
  }) async {
    saved = Map<String, dynamic>.from(data);
    return {
      'student_id': studentId,
      'academic_year': academicYear,
      'data': data,
      'sent_to_parent_at': sentAt,
    };
  }

  @override
  Future<Map<String, dynamic>> sendMarksToParent(
    String studentId, {
    String academicYear = '2026-27',
  }) async {
    sendToParentCalls++;
    sentAt = DateTime.now().toIso8601String();
    return {
      'student_id': studentId,
      'academic_year': academicYear,
      'sent_to_parent_at': sentAt,
    };
  }
}

Widget _app([_FakeAdminApi? api]) => ProviderScope(
  overrides: [adminApiProvider.overrideWithValue(api ?? _FakeAdminApi())],
  child: MaterialApp(theme: AppTheme.lightTheme, home: const MarksCardScreen()),
);

Future<void> _selectFromDropdown(
  WidgetTester tester,
  Key key,
  String optionText,
) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}

void main() {
  // A realistic small-phone logical width.
  setUp(() {
    // set per-test in body via tester.view
  });

  testWidgets(
    'Marks Card selector renders with no overflow / ParentDataWidget errors',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Branch → Grade → Student flow opens the card, no layout errors',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _selectFromDropdown(
        tester,
        const Key('marks_branch_dropdown'),
        'Marathahalli Main Branch',
      );
      await _selectFromDropdown(
        tester,
        const Key('marks_grade_dropdown'),
        'IG1',
      );
      await _selectFromDropdown(
        tester,
        const Key('marks_student_dropdown'),
        'Sample Student One (SS-001)',
      );

      // Card is shown.
      expect(find.text('PERFORMANCE PROFILE'), findsOneWidget);
      expect(find.text('Sample Student One'), findsOneWidget);

      // The 'Send to Parent' action is now in the AppBar (compact icon button).
      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Send to Parent',
        ),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opening each dropdown menu at narrow width throws nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(300, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    for (final key in const [
      Key('marks_branch_dropdown'),
      Key('marks_grade_dropdown'),
      Key('marks_student_dropdown'),
      Key('marks_year_dropdown'),
    ]) {
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$key open');
      // dismiss any open menu
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      // advance the flow so the next field is enabled
      if (key == const Key('marks_branch_dropdown')) {
        await _selectFromDropdown(tester, key, 'Marathahalli Main Branch');
      } else if (key == const Key('marks_grade_dropdown')) {
        await _selectFromDropdown(tester, key, 'IG1');
      }
    }
  });

  testWidgets('marks fields remain editable after the flow', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _selectFromDropdown(
      tester,
      const Key('marks_branch_dropdown'),
      'Marathahalli Main Branch',
    );
    await _selectFromDropdown(tester, const Key('marks_grade_dropdown'), 'IG1');
    await _selectFromDropdown(
      tester,
      const Key('marks_student_dropdown'),
      'Sample Student One (SS-001)',
    );

    final att = find.byKey(const ValueKey('attendance'));
    expect(att, findsOneWidget);
    await tester.enterText(att, '180 / 205');
    await tester.pump();
    expect(find.text('180 / 205'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a visible "Send to Parent" button appears below the card and drives the '
    'existing send flow after Save',
    (tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeAdminApi();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await _selectFromDropdown(
        tester,
        const Key('marks_branch_dropdown'),
        'Marathahalli Main Branch',
      );
      await _selectFromDropdown(
        tester,
        const Key('marks_grade_dropdown'),
        'IG1',
      );
      await _selectFromDropdown(
        tester,
        const Key('marks_student_dropdown'),
        'Sample Student One (SS-001)',
      );

      // The button is on-screen in the body (not hidden in the AppBar) and
      // reads clearly.
      final sendBtn = find.byKey(const Key('marks_send_to_parent_button'));
      expect(sendBtn, findsOneWidget);
      expect(
        find.descendant(of: sendBtn, matching: find.text('Send to Parent')),
        findsOneWidget,
      );

      // Before any save: tapping it asks for a save first, no API call.
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();
      expect(
        find.text('Save the marks card before sending it to the parent'),
        findsOneWidget,
      );
      expect(api.sendToParentCalls, 0);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await tester.pumpAndSettle();

      // Save via the card's own button, then send.
      await tester.enterText(
        find.byKey(const ValueKey('attendance')),
        '182 / 210',
      );
      await tester.ensureVisible(find.text('Save Marks'));
      await tester.tap(find.text('Save Marks'));
      await tester.pumpAndSettle();
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await tester.pumpAndSettle();

      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(api.sendToParentCalls, 1);
      // Sent state is reflected on the same button.
      expect(
        find.descendant(of: sendBtn, matching: find.text('Sent to Parent')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
