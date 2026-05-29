import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import 'daily_report_service.dart';

final dailyReportServiceProvider = Provider<DailyReportService?>((ref) {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return null;
  return DailyReportService(auth.token!);
});

// Keyed by (classId, dateString) e.g. ("abc-123", "2026-05-29")
final dailyReportProvider =
    FutureProvider.family<Map<String, dynamic>?, (String, String)>(
  (ref, args) async {
    final service = ref.watch(dailyReportServiceProvider);
    if (service == null) return null;
    return service.getReport(args.$1, args.$2);
  },
);
