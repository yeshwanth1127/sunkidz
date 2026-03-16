import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/services/device_registration_service.dart';

/// Triggers device registration when user is already logged in (e.g. restored session).
/// The login screen handles registration for fresh logins.
class DeviceRegistrationListener extends ConsumerStatefulWidget {
  const DeviceRegistrationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeviceRegistrationListener> createState() =>
      _DeviceRegistrationListenerState();
}

class _DeviceRegistrationListenerState
    extends ConsumerState<DeviceRegistrationListener> {
  bool _hasRegistered = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!kIsWeb &&
        auth.isAuthenticated &&
        auth.token != null &&
        !_hasRegistered) {
      _hasRegistered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DeviceRegistrationService.registerDeviceForPush(auth.token!);
      });
    }
    return widget.child;
  }
}
