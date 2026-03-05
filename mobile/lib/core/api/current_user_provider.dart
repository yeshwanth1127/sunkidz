import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'auth_api.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi());

final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  final api = ref.read(authApiProvider);
  return api.getMe(auth.token!);
});
