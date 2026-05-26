import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

/// Riverpod callback used by authenticated API clients on HTTP 401.
final onUnauthorizedProvider = Provider<void Function()>((ref) {
  return () {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;
    ref.read(authProvider.notifier).logout(sessionExpired: true);
  };
});
