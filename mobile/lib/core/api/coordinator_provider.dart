import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'coordinator_api.dart';

final coordinatorApiProvider = Provider<CoordinatorApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  if (auth.role != UserRole.coordinator) return null;
  return CoordinatorApi(auth.token!);
});
