import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunkidz_lms/main.dart';
import 'package:sunkidz_lms/core/auth/auth_provider.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifier(prefs)),
        ],
        child: const SunkidzApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Preschool LMS'), findsOneWidget);
  });
}
