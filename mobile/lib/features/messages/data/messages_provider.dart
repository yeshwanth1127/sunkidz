import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/messages_provider.dart';

final notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(messagesApiProvider);
  if (api == null) return [];
  return api.getNotifications();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final api = ref.watch(messagesApiProvider);
  if (api == null) return 0;
  return api.getUnreadCount();
});
