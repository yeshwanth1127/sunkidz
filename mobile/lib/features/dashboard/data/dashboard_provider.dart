import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/admin_provider.dart';

class DashboardData {
  final int branchesCount;
  final int studentsCount;
  final int staffCount;
  final double feesTotalDue;
  final double feesPending;
  final double feesCollected;
  final List<Map<String, dynamic>> recentEnquiries;
  final int newEnquiries;
  final int convertedEnquiries;
  final int rejectedEnquiries;
  final List<Map<String, dynamic>> admissionsThisMonth;

  const DashboardData({
    required this.branchesCount,
    required this.studentsCount,
    required this.staffCount,
    required this.feesTotalDue,
    required this.feesPending,
    required this.feesCollected,
    required this.recentEnquiries,
    required this.newEnquiries,
    required this.convertedEnquiries,
    required this.rejectedEnquiries,
    required this.admissionsThisMonth,
  });
}

final dashboardDataProvider = FutureProvider<DashboardData?>((ref) async {
  final api = ref.watch(adminApiProvider);
  if (api == null) return null;
  try {
    final branches = await api.getBranches();
    final admissions = await api.getAdmissions();
    final users = await api.getUsers();
    final enquiries = await api.getEnquiries();
    double feesTotalDue = 0.0;
    double feesPending = 0.0;
    double feesCollected = 0.0;

    // Get analytics including enquiry stats
    int newEnquiries = 0;
    int convertedEnquiries = 0;
    int rejectedEnquiries = 0;

    try {
      final analytics = await api.getAnalytics();
      final revenue = analytics['revenue'] as Map<String, dynamic>? ?? {};
      feesTotalDue = (revenue['total_due'] as num?)?.toDouble() ?? 0.0;
      feesPending = (revenue['outstanding'] as num?)?.toDouble() ?? 0.0;
      feesCollected = (revenue['total_collected'] as num?)?.toDouble() ?? 0.0;

      // Use enquiry_stats from analytics for accurate counts
      final enquiryStats =
          analytics['enquiry_stats'] as Map<String, dynamic>? ?? {};
      newEnquiries = (enquiryStats['pending'] as num?)?.toInt() ?? 0;
      convertedEnquiries = (enquiryStats['converted'] as num?)?.toInt() ?? 0;
      rejectedEnquiries = (enquiryStats['rejected'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // Fallback: count from enquiry list if analytics fails
      for (var enquiry in enquiries) {
        final status = enquiry['status']?.toString().toLowerCase() ?? 'new';
        if (status == 'new' || status == 'pending')
          newEnquiries++;
        else if (status == 'converted')
          convertedEnquiries++;
        else if (status == 'rejected')
          rejectedEnquiries++;
      }
    }

    // Get admissions from this month
    final now = DateTime.now();
    final thisMonth = admissions.where((a) {
      final createdAt = a['created_at'];
      if (createdAt == null) return false;
      try {
        final date = DateTime.parse(createdAt.toString());
        return date.year == now.year && date.month == now.month;
      } catch (_) {
        return false;
      }
    }).toList();

    return DashboardData(
      branchesCount: branches.length,
      studentsCount: admissions.length,
      staffCount: users.length,
      feesTotalDue: feesTotalDue,
      feesPending: feesPending,
      feesCollected: feesCollected,
      recentEnquiries: enquiries.take(5).toList(),
      newEnquiries: newEnquiries,
      convertedEnquiries: convertedEnquiries,
      rejectedEnquiries: rejectedEnquiries,
      admissionsThisMonth: thisMonth,
    );
  } catch (_) {
    return null;
  }
});
