import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/birthdays_provider.dart';

/// Shows a celebration card when someone in the user's scope has a birthday today.
/// Tap to see the full list.
class BirthdayBanner extends ConsumerWidget {
  const BirthdayBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(birthdaysTodayProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        final isMine = data['is_my_birthday'] == true;
        final students = List<Map<String, dynamic>>.from(data['students'] as List? ?? []);
        final staff = List<Map<String, dynamic>>.from(data['staff'] as List? ?? []);

        final celebrants = <Map<String, dynamic>>[
          if (isMine)
            {
              'name': (data['my_name'] ?? 'You').toString(),
              'kind': 'self',
              'turning_age': data['my_age'],
            },
          ...students,
          ...staff,
        ];

        if (celebrants.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8A65), Color(0xFFFFB300), Color(0xFFEC407A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('🎂', style: TextStyle(fontSize: 30)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headline(celebrants, isMine),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _message(celebrants, isMine),
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _headline(List<Map<String, dynamic>> celebrants, bool isMine) {
    if (isMine) return 'Happy Birthday! 🎉';
    if (celebrants.length == 1) {
      return 'Happy Birthday, ${celebrants.first['name']}!';
    }
    return '${celebrants.length} birthdays today!';
  }

  String _message(List<Map<String, dynamic>> celebrants, bool isMine) {
    if (isMine && celebrants.length == 1) {
      final age = celebrants.first['turning_age'];
      return age != null
          ? 'Wishing you a wonderful year ahead. May this be your best year yet! ($age today)'
          : 'Wishing you a wonderful year ahead. May this be your best year yet!';
    }
    final names = celebrants.take(4).map((c) {
      final n = c['name']?.toString() ?? '';
      final age = c['turning_age'];
      final cls = c['class_name']?.toString();
      String label = n;
      if (age != null) label += ' ($age)';
      if (cls != null && cls.isNotEmpty) label += ' · $cls';
      return label;
    }).join(', ');
    final more = celebrants.length > 4 ? ' and ${celebrants.length - 4} more' : '';
    if (isMine) {
      return 'And celebrating with $names$more today.';
    }
    return 'Send warm wishes to $names$more.';
  }
}
