import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/admin_drawer.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/animated_list_item.dart';

final adminNotificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(adminApiProvider);
  if (api == null) return [];
  return api.getNotifications();
});

final adminUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
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
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AdminDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: notificationsAsync.when(
                loading: () => const _NotificationsLoadingPlaceholder(),
                error: (err, _) => _buildErrorState(err),
                data: (notifications) {
                  if (notifications.isEmpty) return _buildEmptyState();
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(adminNotificationsProvider);
                      ref.invalidate(adminUnreadCountProvider);
                    },
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      itemBuilder: (context, i) {
                        final n = notifications[i];
                        return AnimatedListItem(
                          index: i,
                          child: _NotificationCard(
                            notification: n,
                            onTap: () => _handleTap(context, ref, n),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_ios_new_rounded)),
          const SizedBox(width: 8),
          const Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const Spacer(),
          const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object err) => Center(child: Text('Error: $err'));
  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No notifications yet', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
          ],
        ),
      );

  void _handleTap(BuildContext context, WidgetRef ref, Map<String, dynamic> n) async {
    final isRead = n['is_read'] as bool? ?? false;
    if (!isRead) {
      await ref.read(adminApiProvider)?.markNotificationRead(n['id'] as String);
      ref.invalidate(adminNotificationsProvider);
      ref.invalidate(adminUnreadCountProvider);
    }
    if (n['related_enquiry_id'] != null) context.push('/enquiries');
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] as bool? ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isRead ? [AppShadows.soft] : [AppShadows.glow(AppColors.primary.withValues(alpha: 0.1))],
        border: Border.all(color: isRead ? const Color(0xFFF1F5F9) : AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isRead ? const Color(0xFFF1F5F9) : AppColors.primary.withValues(alpha: 0.1)),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_rounded, color: isRead ? const Color(0xFF94A3B8) : AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification['title'] ?? 'Alert', style: TextStyle(fontWeight: isRead ? FontWeight.w700 : FontWeight.w900, fontSize: 15, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text(notification['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4)),
                  ],
                ),
              ),
              if (!isRead) Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsLoadingPlaceholder extends StatelessWidget {
  const _NotificationsLoadingPlaceholder();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Row(
          children: [
            const ShimmerLoading.circular(width: 44, height: 44),
            SizedBox(width: 16),
            Expanded(child: ShimmerLoading.rectangular(height: 60, width: double.infinity)),
          ],
        ),
      ),
    );
  }
}
