import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sunkidz_lms/main.dart';
import 'package:sunkidz_lms/core/auth/auth_provider.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifier(storage)),
        ],
        child: const SunkidzApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Preschool LMS'), findsOneWidget);
  });
}
