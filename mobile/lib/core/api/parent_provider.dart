import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'parent_api.dart';

final parentApiProvider = Provider<ParentApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  if (auth.role != UserRole.parent) return null;
  return ParentApi(auth.token!);
});

/// Persists which child is selected in the parent dashboard across widget rebuilds.
final selectedChildProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
