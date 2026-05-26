import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../auth/session_guard.dart';
import 'almanac_api.dart';

final almanacApiProvider = Provider<AlmanacApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || !auth.isAuthenticated) return null;
  return AlmanacApi(auth.token!, onUnauthorized: ref.read(onUnauthorizedProvider));
});
