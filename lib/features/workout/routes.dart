import 'package:go_router/go_router.dart';
import 'ui/workout_page.dart';
import 'ui/add_exercise_page.dart';
import 'ui/create_program_page.dart';
import 'ui/my_requests_page.dart';

final workoutRoutes = <RouteBase>[
  GoRoute(path: '/workout', builder: (_, __) => const WorkoutPage()),
  GoRoute(path: '/workout/add-exercise', builder: (_, __) => const AddExercisePage()),
  GoRoute(path: '/workout/create-program', builder: (_, __) => const CreateProgramPage()),
  GoRoute(path: '/workout/requests', builder: (_, __) => const WorkoutRequestsPage()),
];
