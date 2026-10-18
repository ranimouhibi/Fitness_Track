import 'package:go_router/go_router.dart';
import 'ui/requests_inbox_page.dart';
import 'ui/coach_requests_page.dart';
import 'ui/review_request_page.dart';
import 'ui/admin_training_page.dart';
import 'ui/admin_nutrition_page.dart';
import 'ui/admin_store_page.dart';

final adminRoutes = <RouteBase>[
  GoRoute(path: '/admin/requests', builder: (_, __) => const RequestsInboxPage()),
  GoRoute(path: '/admin/coach-requests', builder: (_, __) => const CoachRequestsPage()),
  GoRoute(path: '/admin/review', builder: (_, __) => const ReviewRequestPage()),
  GoRoute(path: '/admin/training', builder: (_, __) => const AdminTrainingPage()),
  GoRoute(path: '/admin/nutrition', builder: (_, __) => const AdminNutritionPage()),
  GoRoute(path: '/admin/store', builder: (_, __) => const AdminStorePage()),
];
