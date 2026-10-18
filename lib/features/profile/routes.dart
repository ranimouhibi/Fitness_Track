import 'package:go_router/go_router.dart';
import 'ui/profile_page.dart';

final profileRoutes = <RouteBase>[
  GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
];
