import 'package:flutter/material.dart';

// Bottom nav for admin: Training, Nutrition, Store, Coaches, Requests. TODO(lead): define tabs.
class AdminShell extends StatelessWidget {
  final Widget child;
  final int index;
  const AdminShell({super.key, required this.child, required this.index});

  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}
