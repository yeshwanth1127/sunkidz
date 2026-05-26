import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../auth/session_guard.dart';
import 'birthdays_api.dart';

final birthdaysApiProvider = Provider<BirthdaysApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  return BirthdaysApi(auth.token!, onUnauthorized: ref.read(onUnauthorizedProvider));
});

final birthdaysTodayProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(birthdaysApiProvider);
  if (api == null) return {};
  return api.today();
});
