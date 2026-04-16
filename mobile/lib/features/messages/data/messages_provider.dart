import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/api/messages_provider.dart';
import '../../../core/api/parent_provider.dart';

final notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(messagesApiProvider);
  if (api == null) return [];

  final auth = ref.watch(authProvider);
  final selectedChild = ref.watch(selectedChildProvider);
  final studentId =
      auth.role == UserRole.parent ? (selectedChild?['id']?.toString()) : null;

  return api.getNotifications(studentId: studentId);
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final api = ref.watch(messagesApiProvider);
  if (api == null) return 0;

  final auth = ref.watch(authProvider);
  final selectedChild = ref.watch(selectedChildProvider);
  final studentId =
      auth.role == UserRole.parent ? (selectedChild?['id']?.toString()) : null;

  return api.getUnreadCount(studentId: studentId);
});
