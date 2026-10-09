import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config.dart';
import '../models/grading.dart';
import 'providers.dart';

/// The tabs of the main screen. Farmers see all four, buyers do not get [classify].
enum HomeTab { dashboard, classify, history, profile }

/// Which tab is open. Screens set this to jump to another tab (for example "View History").
final homeTabProvider = StateProvider<HomeTab>((ref) => HomeTab.dashboard);

/// Real numbers for the dashboard, taken from the existing GET /api/history endpoint
/// (nothing is stored or invented on the phone).
class DashboardData {
  const DashboardData({required this.total, required this.byGrade, required this.recent});

  final int total;
  final Map<String, int> byGrade;
  final List<Grading> recent;
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final service = ref.watch(gradingServiceProvider);
  // One request for the total + the 5 newest, then one tiny request per class for its count.
  final pages = await Future.wait([
    service.history(limit: 5),
    for (final grade in AppConfig.grades) service.history(grade: grade, limit: 1),
  ]);
  final recent = pages.first;
  final counts = <String, int>{};
  for (var i = 0; i < AppConfig.grades.length; i++) {
    counts[AppConfig.grades[i]] = pages[i + 1].total;
  }
  return DashboardData(total: recent.total, byGrade: counts, recent: recent.items);
});
