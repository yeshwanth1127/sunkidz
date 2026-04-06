import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/messages_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../data/messages_provider.dart';

/// Shared notifications screen for all roles (admin, coordinator, teacher, parent, etc.)
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markedAllRead = false;

  Future<void> _ensureMarkAllRead() async {
    if (_markedAllRead) return;
    final api = ref.read(messagesApiProvider);
    if (api == null) return;
    try {
      await api.markAllNotificationsRead();
      _markedAllRead = true;
      ref.invalidate(unreadCountProvider);
    } catch (_) {
      // ignore; user can still read individually / pull to refresh
    }
  }

  @override
  void initState() {
    super.initState();
    // Fire and forget; don't block build
    Future.microtask(_ensureMarkAllRead);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Messages & Notifications'),
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Error: $err', textAlign: TextAlign.center),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                final isRead = n['is_read'] as bool? ?? false;
                final senderName = n['sender_name'] as String?;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? null : AppColors.primary.withOpacity(0.05),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isRead
                          ? Colors.grey.shade300
                          : AppColors.primary.withOpacity(0.2),
                      child: Icon(
                        Icons.mail,
                        color: isRead ? Colors.grey : AppColors.primary,
                      ),
                    ),
                    title: Text(
                      n['title'] as String? ?? 'Message',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (senderName != null && senderName.isNotEmpty)
                          Text(
                            'From: $senderName',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        Text(
                          n['message'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      if (!isRead) {
                        await ref.read(messagesApiProvider)?.markNotificationRead(
                              n['id'] as String,
                            );
                        ref.invalidate(notificationsProvider);
                        ref.invalidate(unreadCountProvider);
                      }
                      final enquiryId = n['related_enquiry_id'] as String?;
                      if (enquiryId != null) {
                        context.push('/enquiries');
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
