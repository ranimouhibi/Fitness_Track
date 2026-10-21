import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

class AdminSignupRequest {
  final int id;
  final int userId;
  final String name;
  final String email;
  final String? phone;
  final int? yearsExperience;
  final String? certificatePath;

  const AdminSignupRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.yearsExperience,
    this.certificatePath,
  });
}

class AdminRequestRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<AdminSignupRequest>> pendingSignups() async {
    final rows = await (await _db).rawQuery('''
      SELECT cr.id, u.id AS user_id,
             u.first_name || ' ' || u.last_name AS name,
             u.email, u.phone, u.years_experience, cr.certificate_path
      FROM coach_requests cr
      INNER JOIN users u ON u.id = cr.coach_id
      WHERE cr.status = 'pending' AND u.coach_status = 'pending'
      ORDER BY cr.created_at DESC, cr.id DESC
    ''');
    return [
      for (final row in rows)
        AdminSignupRequest(
          id: row['id'] as int,
          userId: row['user_id'] as int,
          name: row['name'] as String,
          email: row['email'] as String,
          phone: row['phone'] as String?,
          yearsExperience: row['years_experience'] as int?,
          certificatePath: row['certificate_path'] as String?,
        ),
    ];
  }

  Future<void> decide({
    required AdminSignupRequest request,
    required bool accept,
    required int adminId,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'users',
        {'coach_status': accept ? 'approved' : 'rejected'},
        where: 'id = ?',
        whereArgs: [request.userId],
      );
      await txn.update(
        'coach_requests',
        {
          'status': accept ? 'approved' : 'rejected',
          'reviewed_by': adminId,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [request.id, 'pending'],
      );
    });
  }
}