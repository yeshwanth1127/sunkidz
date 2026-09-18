import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunkidz_lms/core/theme/app_theme.dart';
import 'package:sunkidz_lms/shared/widgets/marks_card_form.dart';

const _student = {
  'id': 'stu-1',
  'name': 'Sample Child',
  'father_name': 'Sample Father',
  'mother_name': 'Sample Mother',
  'date_of_birth': '2021-05-04',
  'class_name': 'IG2',
  'branch_name': 'Marathahalli',
};

Widget _host(
  Map<String, dynamic> initial,
  Future<void> Function(Map<String, dynamic>) onSave,
) => MaterialApp(
  theme: AppTheme.lightTheme,
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

void main() {
  testWidgets('tapping a scholastic mark field focuses it and typing is kept', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? saved;
    await tester.pumpWidget(_host({}, (d) async => saved = Map.of(d)));
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('english.Writing.pt1'));
    expect(field, findsOneWidget);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();

    // A real hit-test tap (not showKeyboard()); fail if the tap misses the
    // widget (e.g. it is clipped out of its parent by an overflow).
    await tester.tap(field);
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus,
      isNotNull,
      reason: 'a field should hold focus after being tapped',
    );
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(
      editable.focusNode.hasFocus,
      isTrue,
      reason: 'tapped scholastic field should receive focus',
    );

    // Type character-by-character. Each keystroke updates only the row's
    // derived "Term 1" cell (via its ValueNotifier) — the field itself is not
    // rebuilt. Focus + accumulated text must survive — this is the "can't type
    // in the field" regression.
    await tester.enterText(field, '1');
    await tester.pump();
    expect(
      editable.focusNode.hasFocus,
      isTrue,
      reason: 'focus kept after 1st keystroke rebuild',
    );
    await tester.enterText(field, '18');
    await tester.pump();
    expect(
      editable.focusNode.hasFocus,
      isTrue,
      reason: 'focus kept after 2nd keystroke rebuild',
    );
    expect(tester.widget<TextField>(field).controller?.text, '18');

    // A second field edits independently and does not disturb the first.
    final field2 = find.byKey(const ValueKey('kannada.Reading.ca1'));
    await tester.ensureVisible(field2);
    await tester.tap(field2);
    await tester.pumpAndSettle();
    await tester.enterText(field2, '9');
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller?.text,
      '18',
      reason: 'first field unchanged while editing another',
    );
    expect(tester.widget<TextField>(field2).controller?.text, '9');

    // A co-scholastic grade field is a plain unrestricted text field.
    final gradeField = find.byKey(const ValueKey('co_drawing_and_coloring_t1'));
    expect(gradeField, findsOneWidget);
    await tester.ensureVisible(gradeField);
    await tester.tap(gradeField);
    await tester.pumpAndSettle();
    await tester.enterText(gradeField, 'A+');
    await tester.pump();

    // Attendance (outside the tables) too.
    final att = find.byKey(const ValueKey('attendance'));
    await tester.ensureVisible(att);
    await tester.tap(att);
    await tester.enterText(att, '175 / 200');
    await tester.pump();

    await tester.ensureVisible(find.text('Save Marks'));
    await tester.tap(find.text('Save Marks'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect((saved!['english'] as Map)['Writing']['pt1'], '18');
    expect((saved!['kannada'] as Map)['Reading']['ca1'], '9');
    expect(saved!['attendance'], '175 / 200');
    // The co-scholastic grade string was stored verbatim.
    expect(
      saved!['co_drawing_and_coloring_t1'],
      'A+',
      reason: 'typed co-scholastic grade should be saved exactly as entered',
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'typing a mark never re-inflates the field and never rebuilds the form-wide tree',
    (tester) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host({}, (_) async {}));
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey('english.Writing.pt1'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();

      // The exact Element backing the EditableText must survive every keystroke:
      // if the whole form rebuilds on each character the field is torn down and
      // the running app silently stops accepting input.
      final editableElement = tester.element(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );

      for (final text in ['1', '18', '187', '1874']) {
        await tester.enterText(field, text);
        await tester.pump();
        expect(
          tester.element(
            find.descendant(of: field, matching: find.byType(EditableText)),
          ),
          same(editableElement),
          reason: 'field Element reused after "$text" (no form-wide rebuild)',
        );
        expect(tester.widget<TextField>(field).controller?.text, text);
      }

      // The derived "Term 1" cell still tracks the row as marks change.
      await tester.enterText(
        find.byKey(const ValueKey('english.Writing.ca1')),
        '5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('english.Writing.hy')),
        '10',
      );
      await tester.pump();
      // 1874 + 5 + 10 — the digitsOnly field keeps whatever was typed; the point
      // is the derived cell recomputes without a global setState.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'co-scholastic grade field is not trapped in a horizontal scroll',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? saved;
      await tester.pumpWidget(_host({}, (d) async => saved = Map.of(d)));
      await tester.pumpAndSettle();

      final gradeField = find.byKey(const ValueKey('co_confidence_t2'));
      await tester.ensureVisible(gradeField);

      // No horizontal Scrollable competes with the field's tap gesture.
      expect(
        find.ancestor(
          of: gradeField,
          matching: find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          ),
        ),
        findsNothing,
      );

      // No input restriction of any kind on the field.
      final tf = tester.widget<TextField>(gradeField);
      expect(tf.inputFormatters, anyOf(isNull, isEmpty));
      expect(tf.maxLength, isNull);

      await tester.tap(gradeField);
      await tester.pumpAndSettle();
      await tester.enterText(gradeField, 'B- / needs work');
      await tester.pump();

      await tester.ensureVisible(find.text('Save Marks'));
      await tester.tap(find.text('Save Marks'));
      await tester.pumpAndSettle();

      expect(saved!['co_confidence_t2'], 'B- / needs work');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('grade fields accept arbitrary mixed strings, stored verbatim', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? saved;
    await tester.pumpWidget(_host({}, (d) async => saved = Map.of(d)));
    await tester.pumpAndSettle();

    // Letters, letter+symbol, pure digits, alphanumeric+symbol, and a word
    // ending in punctuation — every one must round-trip unchanged.
    const cases = <String, String>{
      'co_drawing_and_coloring_t1': 'A+',
      'co_emotional_stability_t1': 'B-',
      'co_adaptability_t1': '123',
      'co_confidence_t1': 'AB12+',
      'co_discipline_t1': 'Excellent!',
    };

    for (final entry in cases.entries) {
      final f = find.byKey(ValueKey(entry.key));
      expect(f, findsOneWidget, reason: 'missing field ${entry.key}');
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
      await tester.enterText(f, entry.value);
      await tester.pump();
      // Controller holds exactly what was typed — no formatter stripped it.
      expect(
        tester.widget<TextField>(f).controller?.text,
        entry.value,
        reason: 'field ${entry.key} should keep "${entry.value}" verbatim',
      );
    }

    await tester.ensureVisible(find.text('Save Marks'));
    await tester.tap(find.text('Save Marks'));
    await tester.pumpAndSettle();

    for (final entry in cases.entries) {
      expect(
        saved![entry.key],
        entry.value,
        reason: 'saved[${entry.key}] must equal "${entry.value}" exactly',
      );
      expect(saved![entry.key], isA<String>());
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('loaded values remain editable (can be replaced)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      _host({
        'english': {
          'Writing': {'pt1': 12},
        },
      }, (d) async => saved = Map.of(d)),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('english.Writing.pt1'));
    expect(tester.widget<TextField>(field).controller?.text, '12');

    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, '20');
    await tester.pump();

    await tester.ensureVisible(find.text('Save Marks'));
    await tester.tap(find.text('Save Marks'));
    await tester.pumpAndSettle();

    expect((saved!['english'] as Map)['Writing']['pt1'], '20');
  });

  testWidgets(
    'scholastic grade cell accepts A+ and Excellent! and shows them verbatim',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? saved;
      await tester.pumpWidget(_host({}, (d) async => saved = Map.of(d)));
      await tester.pumpAndSettle();

      // The exact rendered scholastic cell the user types a grade into.
      final cell = find.byKey(const ValueKey('english.Writing.pt1'));
      expect(cell, findsOneWidget);

      // No restriction of any kind on the widget itself.
      final tf = tester.widget<TextField>(cell);
      expect(tf.keyboardType, anyOf(isNull, TextInputType.text));
      expect(tf.inputFormatters, anyOf(isNull, isEmpty));
      expect(tf.maxLength, isNull);
      expect(tf.maxLines, 1);

      for (final value in const ['A+', 'Excellent!']) {
        await tester.ensureVisible(cell);
        await tester.tap(cell);
        await tester.pumpAndSettle();
        await tester.enterText(cell, value);
        await tester.pump();

        // Visible field shows exactly the typed string.
        expect(
          tester.widget<TextField>(cell).controller?.text,
          value,
          reason: 'field text should be "$value"',
        );
        expect(
          find.descendant(of: cell, matching: find.text(value)),
          findsOneWidget,
          reason: 'the rendered EditableText should display "$value"',
        );
      }

      await tester.ensureVisible(find.text('Save Marks'));
      await tester.tap(find.text('Save Marks'));
      await tester.pumpAndSettle();

      // Last value entered is stored verbatim, as a String.
      expect((saved!['english'] as Map)['Writing']['pt1'], 'Excellent!');
      expect((saved!['english'] as Map)['Writing']['pt1'], isA<String>());
      expect(tester.takeException(), isNull);
    },
  );
}
