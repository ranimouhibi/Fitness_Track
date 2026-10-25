import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/sign_out_overlay.dart';

class UserShell extends StatelessWidget {
  final Widget child;
  final String location;
  const UserShell({super.key, required this.child, required this.location});

  static const _tabs = [
    ('/profile', 'Profile', Icons.person_outline),
    ('/community', 'Community', Icons.forum_outlined),
    ('/workout', 'Training', Icons.fitness_center),
    ('/nutrition', 'Nutrition', Icons.apple),
    ('/store', 'Store', Icons.shopping_bag_outlined),
    ('/coaches', 'Coaches', Icons.groups_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere((t) => location.startsWith(t.$1));
    return Scaffold(
      body: SignOutOverlay(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.$3), label: t.$2),
        ],
      ),
    );
  }
}