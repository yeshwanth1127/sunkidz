import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../auth/session_guard.dart';
import 'diary_api.dart';

final diaryApiProvider = Provider<DiaryApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || !auth.isAuthenticated) return null;
  return DiaryApi(auth.token!, onUnauthorized: ref.read(onUnauthorizedProvider));
});
