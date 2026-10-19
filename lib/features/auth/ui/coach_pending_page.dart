import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/auth_widgets.dart';

class CoachPendingPage extends ConsumerWidget {
  const CoachPendingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const AuthHeader(
            title: 'Coach account',
            subtitle: 'Waiting for approval',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      color: AppColors.softBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.schedule,
                        size: 48, color: AppColors.deepBlue),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Request under review',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                const Text(
                  'An admin is checking your certificate. You will be notified when your account is approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    children: [
                      _Step(
                          title: 'Request sent',
                          subtitle: 'Today',
                          done: true),
                      Divider(height: 1),
                      _Step(
                          title: 'Certificate checked',
                          subtitle: 'Automatic check done',
                          done: true),
                      Divider(height: 1),
                      _Step(
                          title: 'Admin approval',
                          subtitle: 'In progress',
                          done: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  ref.read(sessionProvider.notifier).signOut();
                  context.go('/login');
                },
                child: const Text('Sign out',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool done;

  const _Step({
    required this.title,
    required this.subtitle,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: done ? AppColors.primary : AppColors.softBlue,
        child: Icon(
          done ? Icons.check : Icons.more_horiz,
          size: 18,
          color: done ? AppColors.white : AppColors.deepBlue,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    );
  }
}