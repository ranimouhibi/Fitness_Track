import 'package:flutter/material.dart';

// Bottom nav for coaches. TODO(lead): define tabs.
class CoachShell extends StatelessWidget {
  final Widget child;
  final int index;
  const CoachShell({super.key, required this.child, required this.index});

  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}
