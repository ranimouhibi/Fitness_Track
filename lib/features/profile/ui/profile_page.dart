import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_repository.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _repo = AuthRepository();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _birthDate = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _goal = TextEditingController();
  final _experience = TextEditingController();

  SessionUser? _profile;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final controller in [
      _first,
      _last,
      _email,
      _phone,
      _birthDate,
      _height,
      _weight,
      _goal,
      _experience,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final session = ref.read(sessionProvider);
    if (session == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final profile = await _repo.loadProfile(session.id);
      _setFields(profile);
      if (mounted) setState(() => _profile = profile);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFields(SessionUser profile) {
    _first.text = profile.firstName;
    _last.text = profile.lastName;
    _email.text = profile.email;
    _phone.text = profile.phone ?? '';
    _birthDate.text = _displayDate(profile.birthDate);
    _height.text = _numberText(profile.heightCm);
    _weight.text = _numberText(profile.weightKg);
    _goal.text = profile.goal ?? '';
    _experience.text = profile.yearsExperience?.toString() ?? '';
  }

  String _numberText(num? value) {
    if (value == null) return '';
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  String _displayDate(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    if (date == null) return '';
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  String? _databaseDate() {
    final value = _birthDate.text.trim();
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    return DateTime(year, month, day).toIso8601String().substring(0, 10);
  }

  Future<void> _pickBirthDate() async {
    final current = _profile?.birthDate == null
        ? DateTime(2000)
        : DateTime.tryParse(_profile!.birthDate!) ?? DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDate.text =
            '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _save() async {
    final height = double.tryParse(_height.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    final date = _databaseDate();
    if (_first.text.trim().isEmpty ||
        _last.text.trim().isEmpty ||
        _email.text.trim().isEmpty) {
      setState(() => _error = 'First name, last name, and email are required.');
      return;
    }
    if (_birthDate.text.trim().isNotEmpty && date == null) {
      setState(() => _error = 'Use the date format MM/DD/YYYY.');
      return;
    }
    if (_height.text.trim().isNotEmpty && (height == null || height <= 0) ||
        _weight.text.trim().isNotEmpty && (weight == null || weight <= 0)) {
      setState(() => _error = 'Height and weight must be positive numbers.');
      return;
    }

    final profile = _profile;
    if (profile == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await _repo.updateProfile(
        profile.id,
        ProfileUpdate(
          firstName: _first.text,
          lastName: _last.text,
          email: _email.text,
          phone: _phone.text,
          birthDate: date,
          heightCm: height,
          weightKg: weight,
          goal: _goal.text,
          yearsExperience: int.tryParse(_experience.text.trim()),
        ),
      );
      ref.read(sessionProvider.notifier).updateProfile(updated);
      _setFields(updated);
      if (mounted) {
        setState(() {
          _profile = updated;
          _editing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile;
    if (profile == null) {
      return Scaffold(body: Center(child: Text(_error ?? 'Profile unavailable.')));
    }
    final height = double.tryParse(_height.text);
    final weight = double.tryParse(_weight.text);
    final bmi = height == null || weight == null || height <= 0
        ? null
        : weight / ((height / 100) * (height / 100));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(profile: profile),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                children: [
                  _IdentityCard(profile: profile),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                      child: _ProfileField(
                        label: 'First name',
                        controller: _first,
                        enabled: _editing,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfileField(
                        label: 'Last name',
                        controller: _last,
                        enabled: _editing,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _ProfileField(
                    label: 'Email',
                    controller: _email,
                    enabled: _editing,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _ProfileField(
                    label: 'Phone',
                    controller: _phone,
                    enabled: _editing,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _ProfileField(
                        label: 'Birth date',
                        controller: _birthDate,
                        enabled: _editing,
                        readOnly: true,
                        suffixIcon: Icons.calendar_today_outlined,
                        onTap: _editing ? _pickBirthDate : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoBox(
                        label: 'Age (auto)',
                        value: _age(profile.birthDate),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _ProfileField(
                        label: 'Height (cm)',
                        controller: _height,
                        enabled: _editing,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfileField(
                        label: 'Weight (kg)',
                        controller: _weight,
                        enabled: _editing,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _InfoBox(label: 'BMI', value: bmi == null ? '—' : bmi.toStringAsFixed(1))),
                    const SizedBox(width: 12),
                    Expanded(child: _InfoBox(label: 'Role', value: _roleLabel(profile))),
                  ]),
                  const SizedBox(height: 14),
                  _ProfileField(
                    label: 'Goal',
                    controller: _goal,
                    enabled: _editing,
                    hintText: 'e.g. lose weight',
                  ),
                  if (profile.role == UserRole.coach) ...[
                    const SizedBox(height: 14),
                    _ProfileField(
                      label: 'Years of experience',
                      controller: _experience,
                      enabled: _editing,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  if (profile.role == UserRole.coach && profile.coachStatus != null) ...[
                    const SizedBox(height: 14),
                    _InfoBox(label: 'Coach status', value: profile.coachStatus!),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : (_editing ? _save : () => setState(() => _editing = true)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const CircularProgressIndicator(color: AppColors.white)
                          : Text(_editing ? 'Save changes' : 'Edit profile', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (_editing) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saving ? null : () {
                        _setFields(profile);
                        setState(() {
                          _editing = false;
                          _error = null;
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _age(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    if (date == null) return '—';
    var age = DateTime.now().year - date.year;
    final birthdayPassed = DateTime.now().month > date.month ||
        (DateTime.now().month == date.month && DateTime.now().day >= date.day);
    if (!birthdayPassed) age--;
    return '$age years';
  }

  String _roleLabel(SessionUser profile) {
    if (profile.role == UserRole.coach && profile.coachStatus != null) {
      return 'Coach';
    }
    return profile.role.name[0].toUpperCase() + profile.role.name.substring(1);
  }
}

class _Header extends StatelessWidget {
  final SessionUser profile;
  const _Header({required this.profile});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.primary,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile', style: TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Your details and private information', style: TextStyle(color: AppColors.white, fontSize: 15)),
          ],
        ),
      );
}

class _IdentityCard extends StatelessWidget {
  final SessionUser profile;
  const _IdentityCard({required this.profile});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.softBlue,
            child: Text(
              '${profile.firstName[0]}${profile.lastName[0]}'.toUpperCase(),
              style: const TextStyle(color: AppColors.deepBlue, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(profile.email, style: const TextStyle(color: AppColors.textSecondary)),
          ])),
        ]),
      );
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool readOnly;
  final String? hintText;
  final TextInputType? keyboardType;
  final IconData? suffixIcon;
  final VoidCallback? onTap;

  const _ProfileField({
    required this.label,
    required this.controller,
    required this.enabled,
    this.readOnly = false,
    this.hintText,
    this.keyboardType,
    this.suffixIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: enabled,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hintText,
              suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, size: 19),
              filled: true,
              fillColor: enabled ? AppColors.white : AppColors.softBlue.withValues(alpha: .65),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
        ],
      );
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.softBlue, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: AppColors.deepBlue, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      );
}
