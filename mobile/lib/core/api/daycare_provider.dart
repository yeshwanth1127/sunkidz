import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'daycare_api.dart';

final daycareApiProvider = Provider<DaycareApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  if (auth.role != UserRole.daycare) return null;
  return DaycareApi(auth.token!);
});
