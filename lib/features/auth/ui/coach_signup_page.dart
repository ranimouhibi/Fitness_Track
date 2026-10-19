import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

class CoachSignupPage extends ConsumerStatefulWidget {
  const CoachSignupPage({super.key});

  @override
  ConsumerState<CoachSignupPage> createState() => _CoachSignupPageState();
}

class _CoachSignupPageState extends ConsumerState<CoachSignupPage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _birth = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _years = TextEditingController();
  final _password = TextEditingController();
  final _repo = AuthRepository();
  final _picker = ImagePicker();

  DateTime? _birthDate;
  String? _certificatePath;
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
      _years,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
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

  Future<void> _pickCertificate() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _certificatePath = file.path);
  }

  Future<void> _submit() async {
    final height = double.tryParse(_height.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    final years = int.tryParse(_years.text.trim());
    if (_first.text.trim().isEmpty ||
        _last.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _birthDate == null ||
        height == null ||
        weight == null ||
        years == null) {
      setState(() => _error = 'Fill in every field.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_certificatePath == null) {
      setState(() => _error = 'Upload your certificate to continue.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _repo.signUpCoach(
        SignupData(
          firstName: _first.text,
          lastName: _last.text,
          email: _email.text,
          password: _password.text,
          phone: _phone.text,
          birthDate: _birthDate!,
          heightCm: height,
          weightKg: weight,
          yearsExperience: years,
        ),
        certificatePath: _certificatePath!,
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
    final age = _birthDate == null ? '—' : '${calcAge(_birthDate!)} years';
    final certName = _certificatePath == null
        ? 'Photo or PDF. An AI checks it, then an admin reviews'
        : _certificatePath!.split(RegExp(r'[\\/]')).last;

    return Scaffold(
      body: Column(
        children: [
          AuthHeader(
            title: 'Coach profile',
            subtitle: 'Step 2 of 2 · needs admin approval',
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
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AuthField(
                      label: 'Weight (kg)',
                      controller: _weight,
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: AuthField(
                      label: 'Years of experience',
                      controller: _years,
                      keyboard: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AuthField(
                      label: 'Password',
                      controller: _password,
                      obscure: true,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickCertificate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.softBlue,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Row(children: [
                      const Icon(Icons.upload_outlined,
                          color: AppColors.deepBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Upload your certificate',
                                style: TextStyle(
                                    color: AppColors.deepBlue,
                                    fontWeight: FontWeight.bold)),
                            Text(certName,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                ErrorText(_error),
                const SizedBox(height: 12),
                AuthButton(
                  label: 'Submit for approval',
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