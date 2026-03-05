import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'admin_api.dart';

final adminApiProvider = Provider<AdminApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  if (auth.role != UserRole.admin) return null;
  return AdminApi(auth.token!);
});
