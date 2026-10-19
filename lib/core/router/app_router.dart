import 'package:go_router/go_router.dart';
import '../../shell/user_shell.dart';
import '../../shell/coach_shell.dart';
import '../../shell/admin_shell.dart';
import '../../features/auth/routes.dart';
import '../../features/profile/routes.dart';
import '../../features/profile/ui/profile_page.dart';
import '../../features/workout/routes.dart';
import '../../features/workout/ui/workout_page.dart';
import '../../features/nutrition/routes.dart';
import '../../features/nutrition/ui/nutrition_page.dart';
import '../../features/store/routes.dart';
import '../../features/store/ui/store_page.dart';
import '../../features/coaching/routes.dart';
import '../../features/coaching/ui/bookings_page.dart';
import '../../features/progress/routes.dart';
import '../../features/admin/ui/coach_requests_page.dart';
import '../../features/admin/ui/requests_inbox_page.dart';

// Client-side coaching pages (users browse and book coaches).
final _userCoachingRoutes = coachingRoutes
    .whereType<GoRoute>()
    .where((r) => r.path.startsWith('/coaches'))
    .toList();

// Coach-side pages: the same bar as the user, with Jobs last.
final _coachRoutes = <RouteBase>[
  GoRoute(path: '/coach/profile', builder: (_, __) => const ProfilePage()),
  GoRoute(path: '/coach/training', builder: (_, __) => const WorkoutPage()),
  GoRoute(path: '/coach/nutrition', builder: (_, __) => const NutritionPage()),
  GoRoute(path: '/coach/store', builder: (_, __) => const StorePage()),
  GoRoute(path: '/coach/jobs', builder: (_, __) => const BookingsPage()),
  ...coachingRoutes
      .whereType<GoRoute>()
      .where((r) => !r.path.startsWith('/coaches')),
];

// Admin pages: the same bar as the user. Training is the admin version of WorkoutPage.
final _adminRoutes = <RouteBase>[
  GoRoute(path: '/admin/profile', builder: (_, __) => const ProfilePage()),
  GoRoute(path: '/admin/requests', builder: (_, __) => const RequestsInboxPage()),
  GoRoute(
    path: '/admin/training',
    builder: (_, __) => const WorkoutPage(isAdmin: true),
  ),
  GoRoute(path: '/admin/nutrition', builder: (_, __) => const NutritionPage()),
  GoRoute(path: '/admin/store', builder: (_, __) => const StorePage()),
  GoRoute(
    path: '/admin/coaches',
    builder: (_, __) => const CoachRequestsPage(),
  ),
];

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    ...authRoutes,
    ShellRoute(
      builder: (context, state, child) =>
          UserShell(location: state.uri.toString(), child: child),
      routes: [
        ...profileRoutes,
        ...workoutRoutes,
        ...nutritionRoutes,
        ...storeRoutes,
        ..._userCoachingRoutes,
      ],
    ),
    ShellRoute(
      builder: (context, state, child) =>
          CoachShell(location: state.uri.toString(), child: child),
      routes: [..._coachRoutes],
    ),
    ShellRoute(
      builder: (context, state, child) =>
          AdminShell(location: state.uri.toString(), child: child),
      routes: [..._adminRoutes],
    ),
    ...progressRoutes,
  ],
);