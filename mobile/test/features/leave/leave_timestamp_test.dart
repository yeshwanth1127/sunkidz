import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sunkidz_lms/core/api/leave_api.dart';
import 'package:sunkidz_lms/core/api/chat_provider.dart';
import 'package:sunkidz_lms/core/api/parent_provider.dart';
import 'package:sunkidz_lms/features/leave/presentation/staff_leave_screen.dart';
import 'package:sunkidz_lms/features/leave/presentation/parent_leave_screen.dart';

/// Fake that returns whatever leave rows the test supplies — no network.
class _FakeLeaveApi extends LeaveApi {
  _FakeLeaveApi(this._rows) : super('test-token');
  final List<Map<String, dynamic>> _rows;

  @override
  Future<List<Map<String, dynamic>>> listLeaves({String? status}) async =>
      _rows.map((e) => Map<String, dynamic>.from(e)).toList();
}

Map<String, dynamic> _row({String? createdAt}) => {
  'id': 'l1',
  'student_name': 'Sample Child',
  'student_admission_number': 'SS-001',
  'parent_name': 'Sample Parent',
  'status': 'pending',
  'start_date': '2026-09-01',
  'end_date': '2026-09-03',
  'reason': 'Family function',
  if (createdAt != null) 'created_at': createdAt,
};

Widget _host(Widget screen, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(home: screen),
);

void main() {
  testWidgets(
    'staff leave card shows the real submitted date + time and keeps the date range',
    (tester) async {
      await tester.pumpWidget(
        _host(const StaffLeaveScreen(), [
          leaveApiProvider.overrideWithValue(
            // No timezone suffix -> parsed as local, deterministic in the test.
            _FakeLeaveApi([_row(createdAt: '2026-09-02T15:45:00')]),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // Existing date range is untouched.
      expect(find.text('2026-09-01 → 2026-09-03'), findsOneWidget);
      // Submitted timestamp is shown (right side of the same row).
      expect(find.text('02/09/2026  3:45 PM'), findsOneWidget);
    },
  );

  testWidgets(
    'staff leave card shows no timestamp when created_at is absent (legacy request)',
    (tester) async {
      await tester.pumpWidget(
        _host(const StaffLeaveScreen(), [
          leaveApiProvider.overrideWithValue(_FakeLeaveApi([_row()])),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026-09-01 → 2026-09-03'), findsOneWidget);
      expect(find.textContaining('/2026'), findsNothing);
    },
  );

  testWidgets('parent leave card shows the real submitted date + time', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ParentLeaveScreen(), [
        leaveApiProvider.overrideWithValue(
          _FakeLeaveApi([_row(createdAt: '2026-09-02T09:05:00')]),
        ),
        parentApiProvider.overrideWithValue(null),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026-09-01 → 2026-09-03'), findsOneWidget);
    expect(find.text('02/09/2026  9:05 AM'), findsOneWidget);
  });
}
