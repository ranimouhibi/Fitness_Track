import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

class UserSignupPage extends ConsumerStatefulWidget {
  const UserSignupPage({super.key});

  @override
  ConsumerState<UserSignupPage> createState() => _UserSignupPageState();
}

class _UserSignupPageState extends ConsumerState<UserSignupPage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _birth = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _password = TextEditingController();
  final _repo = AuthRepository();

  DateTime? _birthDate;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _first,
      _last,
      _email,
      _phone,
      _birth,
      _height,
      _weight,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birth.text = formatDate(picked);
      });
    }
  }

  Future<void> _submit() async {
    final height = double.tryParse(_height.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    if (_first.text.trim().isEmpty ||
        _last.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _birthDate == null ||
        height == null ||
        weight == null) {
      setState(() => _error = 'Fill in every field.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _repo.signUpUser(SignupData(
        firstName: _first.text,
        lastName: _last.text,
        email: _email.text,
        password: _password.text,
        phone: _phone.text,
        birthDate: _birthDate!,
        heightCm: height,
        weightKg: weight,
      ));
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
    final age = _birthDate == null ? '—' : '${calcAge(_birthDate!)} years';

    return Scaffold(
      body: Column(
        children: [
          AuthHeader(
            title: 'User profile',
            subtitle: 'Step 2 of 2',
            onBack: () => context.go('/signup'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(
                      child: AuthField(label: 'First name', controller: _first)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: AuthField(label: 'Last name', controller: _last)),
                ]),
                const SizedBox(height: 16),
                AuthField(
                  label: 'Email',
                  controller: _email,
                  hint: 'you@email.com',
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                AuthField(
                  label: 'Phone number',
                  controller: _phone,
                  hint: '+216 00 000 000',
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: AuthField(
                      label: 'Birth date',
                      controller: _birth,
                      hint: 'DD/MM/YYYY',
                      readOnly: true,
                      onTap: _pickBirth,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _AgeBox(text: age)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: AuthField(
                      label: 'Height (cm)',
                      controller: _height,
                      hint: '172',
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AuthField(
                      label: 'Weight (kg)',
                      controller: _weight,
                      hint: '68',
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                AuthField(
                  label: 'Password',
                  controller: _password,
                  hint: 'At least 6 characters',
                  obscure: true,
                ),
                const SizedBox(height: 12),
                ErrorText(_error),
                const SizedBox(height: 12),
                AuthButton(
                  label: 'Create profile',
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Already have an account? Sign in'),
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

class _AgeBox extends StatelessWidget {
  final String text;
  const _AgeBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Age (auto)',
            style: TextStyle(
                color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.softBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(text,
              style: const TextStyle(
                  color: AppColors.deepBlue, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}