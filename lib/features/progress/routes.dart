import 'package:go_router/go_router.dart';
import 'ui/progress_page.dart';
import 'ui/objective_page.dart';
import 'ui/weekly_checkin_page.dart';
import 'ui/weekly_analysis_page.dart';

final progressRoutes = <RouteBase>[
  GoRoute(path: '/progress', builder: (_, __) => const ProgressPage()),
  GoRoute(path: '/progress/objective', builder: (_, __) => const ObjectivePage()),
  GoRoute(path: '/progress/check-in', builder: (_, __) => const WeeklyCheckinPage()),
  GoRoute(path: '/progress/analysis', builder: (_, __) => const WeeklyAnalysisPage()),
];
