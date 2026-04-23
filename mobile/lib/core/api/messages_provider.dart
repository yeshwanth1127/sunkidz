import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'messages_api.dart';

/// Provides MessagesApi for any authenticated user (admin, coordinator, teacher, parent, etc.)
final messagesApiProvider = Provider<MessagesApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  if (!auth.isAuthenticated) return null;
  return MessagesApi(auth.token!);
});
