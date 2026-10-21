import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/session_service.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class SignupData {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String? phone;
  final DateTime birthDate;
  final double heightCm;
  final double weightKg;
  final int? yearsExperience;

  const SignupData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    this.phone,
    required this.birthDate,
    required this.heightCm,
    required this.weightKg,
    this.yearsExperience,
  });
}

class ProfileUpdate {
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? birthDate;
  final double? heightCm;
  final double? weightKg;
  final String? goal;
  final int? yearsExperience;

  const ProfileUpdate({
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.goal,
    this.yearsExperience,
  });
}

class AuthRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  String _normEmail(String email) => email.trim().toLowerCase();

  Future<SessionUser> signIn({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthException('Enter your email and password.');
    }
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [_normEmail(email)],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AuthException('No account found with this email.');
    }
    final row = rows.first;
    if (row['password_hash'] != DatabaseHelper.hashPassword(password)) {
      throw const AuthException('Wrong password.');
    }
    return _toSessionUser(row);
  }

  Future<SessionUser> signUpUser(SignupData data) =>
      _create(data, role: 'user');

  Future<SessionUser> signUpCoach(
    SignupData data, {
    required String certificatePath,
  }) =>
      _create(
        data,
        role: 'coach',
        coachStatus: 'pending',
        certificatePath: certificatePath,
      );

  Future<SessionUser> loadProfile(int userId) async {
    final rows = await (await _db).query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) throw const AuthException('Profile no longer exists.');
    return _toSessionUser(rows.first);
  }

  Future<SessionUser> updateProfile(
    int userId,
    ProfileUpdate update,
  ) async {
    final db = await _db;
    try {
      await db.update(
        'users',
        {
          'first_name': update.firstName.trim(),
          'last_name': update.lastName.trim(),
          'email': _normEmail(update.email),
          'phone': update.phone?.trim(),
          'birth_date': update.birthDate,
          'height_cm': update.heightCm,
          'weight_kg': update.weightKg,
          'goal': update.goal?.trim(),
          'years_experience': update.yearsExperience,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      return await loadProfile(userId);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const AuthException('This email is already registered.');
      }
      throw const AuthException('Could not update the profile. Try again.');
    }
  }

  Future<SessionUser> _create(
    SignupData data, {
    required String role,
    String? coachStatus,
    String? certificatePath,
  }) async {
    final db = await _db;
    try {
      return await db.transaction<SessionUser>((txn) async {
        final id = await txn.insert(
          'users',
          _userValues(data, role, coachStatus),
        );
        if (certificatePath != null) {
          await txn.insert('coach_requests', {
            'coach_id': id,
            'certificate_path': certificatePath,
            'status': 'pending',
          });
        }
        final rows =
            await txn.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
        return _toSessionUser(rows.first);
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const AuthException('This email is already registered.');
      }
      throw const AuthException('Could not save the account. Try again.');
    }
  }

  Map<String, Object?> _userValues(
      SignupData d, String role, String? coachStatus) {
    return {
      'role': role,
      'first_name': d.firstName.trim(),
      'last_name': d.lastName.trim(),
      'email': _normEmail(d.email),
      'phone': d.phone?.trim(),
      'password_hash': DatabaseHelper.hashPassword(d.password),
      'birth_date': d.birthDate.toIso8601String().substring(0, 10),
      'height_cm': d.heightCm,
      'weight_kg': d.weightKg,
      'years_experience': d.yearsExperience,
      'coach_status': coachStatus,
    };
  }

  SessionUser _toSessionUser(Map<String, Object?> row) {
    return SessionUser(
      id: row['id'] as int,
      firstName: row['first_name'] as String,
      lastName: row['last_name'] as String,
      email: row['email'] as String,
      phone: row['phone'] as String?,
      birthDate: row['birth_date'] as String?,
      heightCm: (row['height_cm'] as num?)?.toDouble(),
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      goal: row['goal'] as String?,
      yearsExperience: row['years_experience'] as int?,
      role: roleFromString(row['role'] as String),
      coachStatus: row['coach_status'] as String?,
    );
  }
}