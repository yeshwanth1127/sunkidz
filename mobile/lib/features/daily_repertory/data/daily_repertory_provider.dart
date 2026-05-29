import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import 'daily_repertory_service.dart';

final dailyRepertoryServiceProvider = Provider<DailyRepertoryService?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  return DailyRepertoryService(auth.token!);
});

// Keyed by (classId, dateString) e.g. ("abc-123", "2025-06-10")
final repertoryProvider = FutureProvider.family<Map<String, dynamic>?, (String, String)>(
  (ref, args) async {
    final service = ref.watch(dailyRepertoryServiceProvider);
    if (service == null) return null;
    return service.getReport(args.$1, args.$2);
  },
);
