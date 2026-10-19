import 'package:go_router/go_router.dart';
import '../../shell/user_shell.dart';
import '../../shell/admin_shell.dart';
import '../../features/auth/routes.dart';
import '../../features/profile/routes.dart';
import '../../features/workout/routes.dart';
import '../../features/nutrition/routes.dart';
import '../../features/store/routes.dart';
import '../../features/coaching/routes.dart';
import '../../features/progress/routes.dart';
import '../../features/admin/routes.dart';

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
        ...coachingRoutes,
      ],
    ),
    ShellRoute(
      builder: (context, state, child) =>
          AdminShell(location: state.uri.toString(), child: child),
      routes: [...adminRoutes],
    ),
    ...progressRoutes,
  ],
);