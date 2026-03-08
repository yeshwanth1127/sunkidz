import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/auth/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  runApp(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => AuthNotifier(storage)),
      ],
      child: const SunkidzApp(),
    ),
  );
}

class SunkidzApp extends ConsumerWidget {
  const SunkidzApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Preschool LMS',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
