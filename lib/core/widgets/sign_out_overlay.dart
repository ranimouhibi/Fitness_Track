import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';

/// Puts a sign-out button in the top-right corner of any signed-in screen.
class SignOutOverlay extends ConsumerWidget {
  final Widget child;
  const SignOutOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Material(
                color: AppColors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout, color: AppColors.deepBlue),
                  onPressed: () {
                    ref.read(sessionProvider.notifier).signOut();
                    context.go('/login');
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}