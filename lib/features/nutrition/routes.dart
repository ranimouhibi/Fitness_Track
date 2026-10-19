import 'package:go_router/go_router.dart';
import 'ui/nutrition_page.dart';
import 'ui/add_food_page.dart';
import 'ui/pending_foods_page.dart';

final nutritionRoutes = <RouteBase>[
  GoRoute(path: '/nutrition', builder: (_, __) => const NutritionPage()),
  GoRoute(
    path: '/nutrition/add-food',
    builder: (_, __) => const AddFoodPage(),
  ),
  GoRoute(
    path: '/nutrition/pending-foods',
    builder: (_, __) => const PendingFoodsPage(),
  ),
];

final adminNutritionRoutes = <RouteBase>[
  GoRoute(
    path: '/admin/nutrition',
    builder: (_, __) => const NutritionPage(isAdmin: true),
  ),
  GoRoute(
    path: '/admin/nutrition/add-food',
    builder: (_, __) => const AddFoodPage(isAdmin: true),
  ),
  GoRoute(
    path: '/admin/nutrition/pending-foods',
    builder: (_, __) => const PendingFoodsPage(),
  ),
];
