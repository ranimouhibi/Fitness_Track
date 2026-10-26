import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/media/media_store.dart';

const muscleGroups = [
  'Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Glutes', 'Cardio',
];

const materialOptions = [
  'Machine', 'Dumbbell', 'Barbell', 'Cable', 'Bodyweight',
  'Kettlebell', 'Resistance band', 'Other',
];

class Exercise {
  final int id;
  final String name;
  final String muscleGroup;
  final String? equipment;
  final String? level;
  final String? description;
  final String? instructions;
  final String? mediaPath;
  final String status;
  final int? createdBy;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.equipment,
    this.level,
    this.description,
    this.instructions,
    this.mediaPath,
    required this.status,
    this.createdBy,
  });

  /// Instructions split into one step per line.
  List<String> get steps => (instructions ?? '')
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  factory Exercise.fromMap(Map<String, Object?> m) => Exercise(
        id: m['id'] as int,
        name: m['name'] as String,
        muscleGroup: m['muscle_group'] as String,
        equipment: m['equipment'] as String?,
        level: m['level'] as String?,
        description: m['description'] as String?,
        instructions: m['instructions'] as String?,
        mediaPath: m['media_path'] as String?,
        status: m['status'] as String,
        createdBy: m['created_by'] as int?,
      );
}

/// Column values for an exercise. Used for adds, edits and edit requests.
Map<String, dynamic> exercisePayload({
  required String name,
  required String muscleGroup,
  String? equipment,
  String? level,
  String? description,
  String? instructions,
  String? mediaPath,
}) {
  return {
    'name': name.trim(),
    'muscle_group': muscleGroup,
    'equipment': equipment,
    'level': level,
    'description': description?.trim(),
    'instructions': instructions?.trim(),
    'media_path': mediaPath,
  };
}

class WorkoutRepository {
  Future<Database> _ready() => DatabaseHelper.instance.database;

  /// Admin sees approved exercises. Users and coaches also see their own pending ones.
  Future<List<Exercise>> exercisesForGroup({
    required String muscleGroup,
    required int userId,
    required bool isAdmin,
  }) async {
    final db = await _ready();
    final rows = isAdmin
        ? await db.query(
            'exercises',
            where: 'muscle_group = ? AND status = ?',
            whereArgs: [muscleGroup, 'approved'],
            orderBy: 'name',
          )
        : await db.query(
            'exercises',
            where:
                'muscle_group = ? AND (status = ? OR (created_by = ? AND status = ?))',
            whereArgs: [muscleGroup, 'approved', userId, 'pending'],
            orderBy: 'name',
          );
    return rows.map(Exercise.fromMap).toList();
  }

  /// Everything this user submitted, with its status.
  Future<List<Exercise>> myRequests(int userId) async {
    final db = await _ready();
    final rows = await db.query(
      'exercises',
      where: 'created_by = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return rows.map(Exercise.fromMap).toList();
  }

  Future<List<Exercise>> allExercises() async {
    final db = await _ready();
    final rows = await db.query('exercises', orderBy: 'muscle_group, name');
    return rows.map(Exercise.fromMap).toList();
  }

  /// New exercises waiting for review, with the submitter's name.
  Future<List<(Exercise, String)>> pendingExercises() async {
    final db = await _ready();
    final rows = await db.rawQuery('''
      SELECT e.*, COALESCE(u.first_name || ' ' || u.last_name, 'Unknown') AS submitter
      FROM exercises e
      LEFT JOIN users u ON u.id = e.created_by
      WHERE e.status = 'pending'
      ORDER BY e.id DESC
    ''');
    return [
      for (final r in rows) (Exercise.fromMap(r), r['submitter'] as String),
    ];
  }

  /// Admin adds are approved right away. Others wait as pending.
  Future<void> addExercise({
    required Map<String, dynamic> payload,
    required int userId,
    required bool isAdmin,
  }) async {
    final db = await _ready();
    await db.insert('exercises', {
      ...payload,
      'created_by': userId,
      'status': isAdmin ? 'approved' : 'pending',
    });
  }

  /// Saves the new details. If the photo was replaced, the old file is deleted.
  Future<void> updateExercise(int id, Map<String, dynamic> p) async {
    final db = await _ready();
    final old = await db.query('exercises',
        columns: ['media_path'], where: 'id = ?', whereArgs: [id], limit: 1);
    final oldMedia = old.isEmpty ? null : old.first['media_path'] as String?;

    await db.update(
      'exercises',
      {
        'name': p['name'],
        'muscle_group': p['muscle_group'],
        'equipment': p['equipment'],
        'level': p['level'],
        'description': p['description'],
        'instructions': p['instructions'],
        'media_path': p['media_path'],
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (oldMedia != p['media_path']) await deleteUserMedia(oldMedia);
  }

  Future<void> setExerciseStatus(int id, String status) async {
    final db = await _ready();
    await db.update(
      'exercises',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes the exercise and its photo file.
  /// Fails if the exercise is used in a program (the database blocks it).
  Future<void> deleteExercise(int id) async {
    final db = await _ready();
    final rows = await db.query('exercises',
        columns: ['media_path'], where: 'id = ?', whereArgs: [id], limit: 1);
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      await deleteUserMedia(rows.first['media_path'] as String?);
    }
  }

  /// The submitter can cancel a request only while it is still pending.
  /// Cancelling also deletes the photo file.
  Future<bool> cancelOwnPending(int id, int userId) async {
    final db = await _ready();
    final rows = await db.query('exercises',
        columns: ['media_path'],
        where: "id = ? AND created_by = ? AND status = 'pending'",
        whereArgs: [id, userId],
        limit: 1);
    if (rows.isEmpty) return false;
    final n = await db.delete(
      'exercises',
      where: "id = ? AND created_by = ? AND status = 'pending'",
      whereArgs: [id, userId],
    );
    if (n > 0) await deleteUserMedia(rows.first['media_path'] as String?);
    return n > 0;
  }
}