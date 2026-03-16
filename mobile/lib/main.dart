import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/auth/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();

  // OneSignal is mobile-only (iOS/Android) - skip on web to avoid MissingPluginException
  if (!kIsWeb) {
    await OneSignal.initialize("YOUR_ONESIGNAL_APP_ID"); // Replace with your real App ID
    await OneSignal.User.pushSubscription.optIn();
    OneSignal.User.pushSubscription.addObserver((state) {
      final subscriptionId = state.current.id;
      if (subscriptionId != null) {
        // TODO: Send subscriptionId to backend via /device/register API
      }
    });
  }

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
