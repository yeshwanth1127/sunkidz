import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/auth_api.dart';
import '../api/current_user_provider.dart';
import 'auth_provider.dart';

/// Validates session when the app resumes from background.
class SessionLifecycleObserver extends ConsumerStatefulWidget {
  const SessionLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionLifecycleObserver> createState() =>
      _SessionLifecycleObserverState();
}

class _SessionLifecycleObserverState extends ConsumerState<SessionLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _validateSession();
    }
  }

  Future<void> _validateSession() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    if (auth.isTokenExpired) {
      await ref.read(authProvider.notifier).logout(sessionExpired: true);
      return;
    }

    try {
      await ref.read(authApiProvider).getMe(auth.token!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await ref.read(authProvider.notifier).logout(sessionExpired: true);
      }
    } catch (_) {
      // Network errors — keep session; user can retry when online.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
