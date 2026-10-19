import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

class ProgressRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Map<String, Object?>>> latestCheckins(int userId) async {
    final db = await _db;
    return db.query(
      'weekly_checkins',
      columns: [
        'week_no',
        'check_date',
        'weight_kg',
        'waist_cm',
        'chest_cm',
        'workouts_done',
        'workouts_planned',
        'energy',
        'notes',
      ],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'check_date DESC, id DESC',
      limit: 8,
    );
  }
}
