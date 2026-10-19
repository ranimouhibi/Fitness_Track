import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/auth_widgets.dart';

class RoleChoicePage extends StatefulWidget {
  const RoleChoicePage({super.key});

  @override
  State<RoleChoicePage> createState() => _RoleChoicePageState();
}

class _RoleChoicePageState extends State<RoleChoicePage> {
  bool _isCoach = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AuthHeader(
            title: 'Create your profile',
            subtitle: 'Step 1 of 2',
            onBack: () => context.go('/login'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Choose how you will use the app',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                ),
                _RoleCard(
                  title: 'I am a user',
                  subtitle:
                      'Follow workouts and meals, track progress, book a coach',
                  icon: Icons.person_outline,
                  selected: !_isCoach,
                  onTap: () => setState(() => _isCoach = false),
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  title: 'I am a coach',
                  subtitle:
                      'Train clients. Your account is verified by an admin first',
                  icon: Icons.groups_outlined,
                  selected: _isCoach,
                  onTap: () => setState(() => _isCoach = true),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AuthButton(
              label: 'Continue',
              onPressed: () =>
                  context.go(_isCoach ? '/signup/coach' : '/signup/user'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.softBlue : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: selected ? AppColors.white : AppColors.softBlue,
              child: Icon(icon, color: AppColors.deepBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}