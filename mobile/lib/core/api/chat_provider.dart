import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'chat_api.dart';
import 'leave_api.dart';

final chatApiProvider = Provider<ChatApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  if (!auth.isAuthenticated) return null;
  return ChatApi(auth.token!);
});

final leaveApiProvider = Provider<LeaveApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  if (!auth.isAuthenticated) return null;
  return LeaveApi(auth.token!);
});
