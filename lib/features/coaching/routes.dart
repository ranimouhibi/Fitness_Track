import 'package:go_router/go_router.dart';
import 'ui/coaches_page.dart';
import 'ui/book_coach_page.dart';
import 'ui/bookings_page.dart';
import 'ui/chat_page.dart';

final coachingRoutes = <RouteBase>[
  GoRoute(path: '/coaches', builder: (_, __) => const CoachesPage()),
  GoRoute(path: '/coaches/book', builder: (_, __) => const BookCoachPage()),
  GoRoute(path: '/bookings', builder: (_, __) => const BookingsPage()),
  GoRoute(path: '/chat', builder: (_, __) => const ChatPage()),
];
