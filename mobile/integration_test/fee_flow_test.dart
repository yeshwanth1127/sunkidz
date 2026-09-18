// Real end-to-end UI flow test for Fee Management.
//
// Runs the ACTUAL AdminFeeManagementScreen widget on a real device (`-d windows`)
// against a REAL backend on http://localhost:9889 that the runner script starts
// with a throwaway database. Every fee amount is typed into the real widgets and
// read back from the real server — no mocked or hardcoded fee values.
//
//   scratchpad/run_ui_flow.sh

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sunkidz_lms/core/auth/auth_provider.dart';
import 'package:sunkidz_lms/features/admin/presentation/admin_fee_management_screen.dart';

late Map<String, dynamic> fx;
late String baseUrl;
late String studentId;
late String branchId;
late Dio raw;
late String adminToken;
late String parentToken;

/// Subclass so we can seed auth state synchronously (the `state` setter is
/// protected — legitimate from a subclass, no lint).
class _TestAuth extends AuthNotifier {
  _TestAuth() : super(const FlutterSecureStorage());
  void seed(String token) {
    state = AuthState(
      token: token,
      userId: fx['admin_id'] as String,
      role: UserRole.admin,
      branchId: branchId,
      tokenExpiry: DateTime.now().add(const Duration(days: 1)),
    );
  }
}

Future<void> bootstrap() async {
  FlutterSecureStorage.setMockInitialValues({});
  raw = Dio(BaseOptions(baseUrl: baseUrl, validateStatus: (_) => true));
  final a = await raw.post('/auth/login',
      data: {'email': fx['admin_email'], 'password': fx['admin_password']});
  adminToken = a.data['access_token'] as String;
  final p = await raw.post('/auth/login',
      data: {'admission_number': fx['admission_number'], 'date_of_birth': fx['dob']});
  parentToken = p.data['access_token'] as String;
}

Options get _ah => Options(headers: {'Authorization': 'Bearer $adminToken'});

Future<Map<String, dynamic>> serverFees() async {
  final r = await raw.get('/admin/students/$studentId/fees', options: _ah);
  return Map<String, dynamic>.from(r.data as Map);
}

Future<void> putStructure(Map<String, dynamic> body) =>
    raw.put('/admin/students/$studentId/fees', data: body, options: _ah);

Future<void> settle(WidgetTester tester, Finder until,
    {Duration timeout = const Duration(seconds: 40)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (until.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for: $until');
}

Widget _app() => ProviderScope(
      overrides: [authProvider.overrideWith((ref) => _TestAuth()..seed(adminToken))],
      child: MaterialApp(
        home: AdminFeeManagementScreen(branchId: branchId, studentId: studentId),
      ),
    );

Future<void> openDashboard(WidgetTester tester) async {
  // Predictable tall/narrow viewport so lists and right-aligned buttons stay on screen.
  await tester.binding.setSurfaceSize(const Size(900, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app());
  await settle(tester, find.text('Structure'));
}

// Structure tab is a lazy ListView — scroll a value into view before asserting.
Future<void> seeInStructure(WidgetTester tester, String text) async {
  final f = find.textContaining(text);
  if (f.evaluate().isEmpty) {
    await tester.dragUntilVisible(f, find.byType(ListView).first, const Offset(0, -80));
    await tester.pumpAndSettle();
  }
  expect(f, findsWidgets, reason: 'Structure tab missing "$text"');
}

Future<void> openEditSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.edit_rounded));
  await tester.pumpAndSettle();
  expect(find.text('Edit Fee Structure'), findsOneWidget);
}

Future<void> setField(WidgetTester tester, String label, String value) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), value);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  fx = jsonDecode(File('.fee_fixture.json').readAsStringSync()) as Map<String, dynamic>;
  baseUrl = fx['base_url'] as String;
  studentId = fx['student_id'] as String;
  branchId = fx['branch_id'] as String;

  setUpAll(bootstrap);

  testWidgets('1. arbitrary values typed in Edit sheet save exactly and show in Structure + Summary',
      (tester) async {
    await openDashboard(tester);
    await openEditSheet(tester);
    await setField(tester, 'Advance Deposit (₹)', '13500');
    await setField(tester, 'Term I Fee (₹)', '27000');
    await setField(tester, 'Term II Fee (₹)', '8250');
    await setField(tester, 'Term III Fee (₹)', '1975');
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();
    await setField(tester, 'Name', 'Excursion');
    await setField(tester, '₹', '6300');
    await tester.tap(find.text('Save Changes'));
    await settle(tester, find.textContaining('13,500'));

    for (final s in ['13,500', '27,000', '8,250', '1,975', '6,300', 'Excursion']) {
      await seeInStructure(tester, s);
    }
    await tester.tap(find.text('Summary'));
    await tester.pumpAndSettle();
    expect(find.textContaining('57,025'), findsWidgets,
        reason: '13500+27000+8250+1975+6300 = 57025');

    final srv = await serverFees();
    expect(srv['advance_fees'], 13500.0);
    expect(srv['term_fee_1'], 27000.0);
    expect(srv['term_fee_2'], 8250.0);
    expect(srv['term_fee_3'], 1975.0);
    expect(srv['total_due'], 57025.0);
    expect((srv['custom_fields'] as List).single['amount'], 6300.0);
    expect((srv['custom_fields'] as List).single['label'], 'Excursion');
  });

  testWidgets('2. re-edit with different values, then reopen the screen -> same saved values',
      (tester) async {
    await openDashboard(tester);
    await openEditSheet(tester);
    await setField(tester, 'Advance Deposit (₹)', '44444');
    await setField(tester, 'Term I Fee (₹)', '33333');
    await setField(tester, 'Term II Fee (₹)', '22222');
    await setField(tester, 'Term III Fee (₹)', '11111');
    await tester.tap(find.text('Save Changes'));
    await settle(tester, find.textContaining('44,444'));

    // dispose + rebuild == closing and reopening the student fee screen
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await openDashboard(tester);
    for (final s in ['44,444', '33,333', '22,222', '11,111', '6,300']) {
      await seeInStructure(tester, s);
    }
    final srv = await serverFees();
    expect(srv['advance_fees'], 44444.0);
    expect(srv['total_due'], 44444.0 + 33333.0 + 22222.0 + 11111.0 + 6300.0);
  });

  testWidgets('3. invalid amount is rejected, error shows INSIDE the sheet, nothing saved',
      (tester) async {
    await putStructure({
      'advance_fees': 5000, 'term_fee_1': 6000, 'term_fee_2': 7000, 'term_fee_3': 8000,
      'custom_fields': [],
    });
    await openDashboard(tester);
    await openEditSheet(tester);
    await setField(tester, 'Term I Fee (₹)', 'abc');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Fee Structure'), findsOneWidget, reason: 'sheet stays open');
    expect(find.textContaining('valid non-negative amount'), findsOneWidget,
        reason: 'error visible in the sheet, not hidden behind it');

    final srv = await serverFees();
    expect(srv['term_fee_1'], 6000.0, reason: 'invalid input must not be saved');
    expect(srv['advance_fees'], 5000.0);
  });

  testWidgets('4. Record Payment submits and appears immediately in the Payments tab',
      (tester) async {
    await putStructure({
      'advance_fees': 20000, 'term_fee_1': 0, 'term_fee_2': 0, 'term_fee_3': 0,
      'custom_fields': [],
    });
    await openDashboard(tester);
    await tester.tap(find.byIcon(Icons.payment_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Fee Category *'), findsOneWidget, reason: 'payment sheet open');
    await setField(tester, 'Amount (₹) *', '5000');
    await tester.tap(find.widgetWithText(FilledButton, 'Record Payment'));
    await settle(tester, find.text('Payment recorded'));
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Payments'));
    await settle(tester, find.textContaining('5,000'));
    expect(find.textContaining('5,000'), findsWidgets);

    final srv = await serverFees();
    expect(srv['total_paid'], 5000.0);
    expect((srv['payments'] as List).any((p) => p['amount_paid'] == 5000.0), isTrue);
  });

  testWidgets('5. invalid payment amount -> clear error INSIDE the payment sheet', (tester) async {
    await openDashboard(tester);
    await tester.tap(find.byIcon(Icons.payment_rounded));
    await tester.pumpAndSettle();
    await setField(tester, 'Amount (₹) *', 'xyz');
    await tester.tap(find.widgetWithText(FilledButton, 'Record Payment'));
    await tester.pumpAndSettle();
    expect(find.text('Fee Category *'), findsOneWidget, reason: 'sheet stays open on error');
    expect(find.textContaining('valid amount'), findsOneWidget);
  });

  testWidgets('6. Send Receipt makes the receipt appear in the parent portal; parent cannot manage',
      (tester) async {
    await openDashboard(tester);
    await tester.tap(find.text('Payments'));
    await settle(tester, find.widgetWithText(TextButton, 'Send Receipt'));
    final sendBtn = find.widgetWithText(TextButton, 'Send Receipt').first;
    await tester.ensureVisible(sendBtn);
    await tester.pumpAndSettle();
    await tester.tap(sendBtn);
    await settle(tester, find.textContaining('Receipt'));

    final pr = await raw.get('/parent/receipts',
        options: Options(headers: {'Authorization': 'Bearer $parentToken'}));
    final receipts = pr.data['receipts'] as List;
    expect(receipts.length, greaterThanOrEqualTo(1));
    expect(receipts.first['amount_paid'], 5000.0);

    // parent is read-only
    final put = await raw.put('/admin/students/$studentId/fees',
        data: {'advance_fees': 1},
        options: Options(headers: {'Authorization': 'Bearer $parentToken'}));
    expect(put.statusCode, 403);
    final post = await raw.post('/admin/students/$studentId/fees/payments',
        data: {'component': 'advance_fees', 'amount_paid': 1, 'payment_mode': 'cash'},
        options: Options(headers: {'Authorization': 'Bearer $parentToken'}));
    expect(post.statusCode, 403);
  });
}
