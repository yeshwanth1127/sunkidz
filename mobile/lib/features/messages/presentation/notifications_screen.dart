import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/api/messages_provider.dart';
import '../../../core/api/parent_provider.dart';
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

    final auth = ref.read(authProvider);
    final selectedChild = ref.read(selectedChildProvider);
    final studentId =
        auth.role == UserRole.parent ? (selectedChild?['id']?.toString()) : null;

    if (auth.role == UserRole.parent && studentId == null) {
      return;
    }

    try {
      await api.markAllNotificationsRead(studentId: studentId);
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
                  color: isRead ? null : AppColors.primary.withValues(alpha: 0.05),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isRead
                          ? Colors.grey.shade300
                          : AppColors.primary.withValues(alpha: 0.2),
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
                        try {
                          await ref.read(messagesApiProvider)?.markNotificationRead(
                                n['id'] as String,
                              );
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(unreadCountProvider);
                        } catch (_) {}
                      }
                      
                      if (mounted) {
                        _showNotificationDetails(context, n);
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

  void _showNotificationDetails(BuildContext context, Map<String, dynamic> notification) {
    final title = notification['title'] as String? ?? 'Message';
    final message = notification['message'] as String? ?? '';
    final senderName = notification['sender_name'] as String?;
    final createdAtStr = notification['created_at'] as String?;
    
    DateTime? createdAt;
    if (createdAtStr != null) {
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (_) {}
    }

    final enquiryId = notification['related_enquiry_id'] as String?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (senderName != null && senderName.isNotEmpty) ...[
                Text(
                  'From: $senderName',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                message,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Received on: ${_formatDateTime(createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (enquiryId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/enquiries');
              },
              child: const Text('View Enquiry'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    // Basic formatting without adding new dependencies if possible
    // Use local time
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final mon = _monthName(local.month);
    return '$day $mon, $h:$m';
  }

  String _monthName(int m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m];
  }
}
