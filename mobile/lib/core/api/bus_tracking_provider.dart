import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'bus_tracking_api.dart';

final busTrackingApiProvider = Provider<BusTrackingApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.token == null) {
    return null;
  }
  return BusTrackingApi(token: auth.token!);
});
