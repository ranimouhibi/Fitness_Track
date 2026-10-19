import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserRole { user, coach, admin }

UserRole roleFromString(String value) => UserRole.values
    .firstWhere((r) => r.name == value, orElse: () => UserRole.user);

class SessionUser {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? birthDate;
  final double? heightCm;
  final double? weightKg;
  final String? goal;
  final int? yearsExperience;
  final UserRole role;
  final String? coachStatus;

  const SessionUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.goal,
    this.yearsExperience,
    required this.role,
    this.coachStatus,
  });

  String get fullName => '$firstName $lastName';
}

class SessionNotifier extends Notifier<SessionUser?> {
  @override
  SessionUser? build() => null;

  void signIn(SessionUser user) => state = user;

  void updateProfile(SessionUser user) => state = user;

  void signOut() => state = null;
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionUser?>(SessionNotifier.new);

/// Where a signed-in account goes after login or sign-up.
String homeRouteFor(SessionUser user) {
  switch (user.role) {
    case UserRole.admin:
      return '/admin/profile';
    case UserRole.coach:
      return user.coachStatus == 'approved' ? '/coach/jobs' : '/coach/pending';
    case UserRole.user:
      return '/profile';
  }
}