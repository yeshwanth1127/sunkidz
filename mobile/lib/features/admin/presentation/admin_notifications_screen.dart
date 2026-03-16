import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/admin_drawer.dart';

final adminNotificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(adminApiProvider);
  if (api == null) return [];
  return api.getNotifications();
});

final adminUnreadCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final api = ref.watch(adminApiProvider);
  if (api == null) return 0;
  return api.getUnreadNotificationCount();
});

class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(adminNotificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Notifications'),
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
                    'No notifications yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminNotificationsProvider);
              ref.invalidate(adminUnreadCountProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                final isRead = n['is_read'] as bool? ?? false;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? null : AppColors.primary.withValues(alpha: 0.05),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isRead
                          ? Colors.grey.shade300
                          : AppColors.primary.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.notifications,
                        color: isRead ? Colors.grey : AppColors.primary,
                      ),
                    ),
                    title: Text(
                      n['title'] as String? ?? 'Notification',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      n['message'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      if (!isRead) {
                        await ref.read(adminApiProvider)?.markNotificationRead(
                              n['id'] as String,
                            );
                        ref.invalidate(adminNotificationsProvider);
                        ref.invalidate(adminUnreadCountProvider);
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
