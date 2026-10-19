import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repo = AuthRepository();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _repo.signIn(
        email: _email.text,
        password: _password.text,
      );
      ref.read(sessionProvider.notifier).signIn(user);
      if (mounted) context.go(homeRouteFor(user));
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.fitness_center,
                      size: 44, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                const Text('FitTrack',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Train. Eat. Track your progress.',
                    style: TextStyle(color: AppColors.white, fontSize: 15)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Sign in',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                AuthField(
                  label: 'Email',
                  controller: _email,
                  hint: 'you@email.com',
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                AuthField(
                  label: 'Password',
                  controller: _password,
                  hint: 'Password',
                  obscure: true,
                ),
                const SizedBox(height: 12),
                ErrorText(_error),
                const SizedBox(height: 12),
                AuthButton(
                  label: 'Sign in',
                  loading: _loading,
                  onPressed: _signIn,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/signup'),
                    child: const Text('New here? Create profile'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}