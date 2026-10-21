import 'package:go_router/go_router.dart';
import 'ui/coaches_page.dart';
import 'ui/book_coach_page.dart';
import 'ui/bookings_page.dart';
import 'ui/chat_page.dart';
import 'ui/coach_availability_page.dart';

final coachingRoutes = <RouteBase>[
  GoRoute(path: '/coaches', builder: (_, __) => const CoachesPage()),
  GoRoute(
    path: '/coaches/book',
    builder: (_, state) => BookCoachPage(
      coachId: int.tryParse(state.uri.queryParameters['coachId'] ?? '') ?? 0,
    ),
  ),
  GoRoute(path: '/bookings', builder: (_, __) => const BookingsPage()),
  GoRoute(
    path: '/coach/availability',
    builder: (_, __) => const CoachAvailabilityPage(),
  ),
  GoRoute(
    path: '/chat',
    builder: (_, state) => ChatPage(
      bookingId:
          int.tryParse(state.uri.queryParameters['bookingId'] ?? '') ?? 0,
    ),
  ),
];
