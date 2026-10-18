import 'package:go_router/go_router.dart';
import 'ui/login_page.dart';
import 'ui/role_choice_page.dart';
import 'ui/user_signup_page.dart';
import 'ui/coach_signup_page.dart';
import 'ui/coach_pending_page.dart';

final authRoutes = <RouteBase>[
  GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
  GoRoute(path: '/signup', builder: (_, __) => const RoleChoicePage()),
  GoRoute(path: '/signup/user', builder: (_, __) => const UserSignupPage()),
  GoRoute(path: '/signup/coach', builder: (_, __) => const CoachSignupPage()),
  GoRoute(path: '/coach/pending', builder: (_, __) => const CoachPendingPage()),
];
