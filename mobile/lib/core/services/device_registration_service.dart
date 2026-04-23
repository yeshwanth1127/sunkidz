import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../api/device_api.dart';

/// Stores the latest subscription ID when OneSignal observer fires.
class DeviceRegistrationService {
  static String? _lastSubscriptionId;

  /// Called by OneSignal observer when subscription ID is available.
  static void onSubscriptionIdReceived(String id) {
    _lastSubscriptionId = id;
  }

  /// Registers the OneSignal subscription ID with the backend after login.
  /// Call this when the user has just logged in and we have a valid token.
  static Future<void> registerDeviceForPush(String token) async {
    if (kIsWeb) return;

    try {
      String? subscriptionId = _lastSubscriptionId ?? OneSignal.User.pushSubscription.id;
      if (subscriptionId == null || subscriptionId.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        subscriptionId = _lastSubscriptionId ?? OneSignal.User.pushSubscription.id;
      }
      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        await DeviceApi(token).registerDevice(subscriptionId);
      }
    } catch (_) {
      // Silently ignore - push registration is best-effort
    }
  }
}
