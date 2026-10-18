import 'package:go_router/go_router.dart';
import 'ui/nutrition_page.dart';
import 'ui/add_food_page.dart';
import 'ui/nutrition_programs_page.dart';
import 'ui/supplements_page.dart';

final nutritionRoutes = <RouteBase>[
  GoRoute(path: '/nutrition', builder: (_, __) => const NutritionPage()),
  GoRoute(path: '/nutrition/add-food', builder: (_, __) => const AddFoodPage()),
  GoRoute(path: '/nutrition/programs', builder: (_, __) => const NutritionProgramsPage()),
  GoRoute(path: '/nutrition/supplements', builder: (_, __) => const SupplementsPage()),
];
