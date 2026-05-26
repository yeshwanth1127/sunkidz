import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/stories_api.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/session_guard.dart';

final storiesApiProvider = Provider<StoriesApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  return StoriesApi(auth.token!, onUnauthorized: ref.read(onUnauthorizedProvider));
});
