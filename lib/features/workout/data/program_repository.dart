import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/media/media_store.dart';
import 'workout_repository.dart';

const goals = {'gain': 'Gain weight', 'lose': 'Lose weight'};
const intensities = {'low': 'Low', 'medium': 'Medium', 'high': 'High'};
const weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

class ProgramExerciseLine {
  final String name;
  final int sets;
  final int reps;
  const ProgramExerciseLine({
    required this.name,
    required this.sets,
    required this.reps,
  });
}

/// One day of the weekly plan as stored.
class ProgramDay {
  final String weekday;
  final bool isRest;
  final String? muscle;
  final List<ProgramExerciseLine> exercises;

  const ProgramDay({
    required this.weekday,
    required this.isRest,
    this.muscle,
    required this.exercises,
  });
}

class Program {
  final int id;
  final String name;
  final String goal;
  final String intensity;
  final int weeks;
  final int daysPerWeek;
  final int minutes;
  final String? description;
  final String? mediaPath;
  final String status;
  final int? createdBy;
  final List<ProgramDay> days;

  const Program({
    required this.id,
    required this.name,
    required this.goal,
    required this.intensity,
    required this.weeks,
    required this.daysPerWeek,
    required this.minutes,
    this.description,
    this.mediaPath,
    required this.status,
    this.createdBy,
    required this.days,
  });

  int get trainingDays => days.where((d) => !d.isRest).length;
}

/// One day as the add or edit form builds it.
class DayPlan {
  final bool isRest;
  final String? muscle;
  final List<({int exerciseId, int sets, int reps})> exercises;

  DayPlan.rest()
      : isRest = true,
        muscle = null,
        exercises = const [];

  DayPlan.train(this.muscle, this.exercises) : isRest = false;

  Map<String, dynamic> toJson() => {
        'isRest': isRest,
        'title': isRest ? 'Rest' : muscle,
        'exercises': [
          for (final e in exercises)
            {'exerciseId': e.exerciseId, 'sets': e.sets, 'reps': e.reps},
        ],
      };
}

/// Column values for a program. Used for adds, edits and edit requests.
Map<String, dynamic> programPayload({
  required String name,
  required String goal,
  required String intensity,
  required int weeks,
  required int minutes,
  String? description,
  String? mediaPath,
  required List<DayPlan> days,
}) {
  return {
    'name': name.trim(),
    'goal': goal,
    'intensity': intensity,
    'weeks': weeks,
    'minutes': minutes,
    'description': description?.trim(),
    'media_path': mediaPath,
    'days_per_week': days.where((d) => !d.isRest).length,
    'days': [for (final d in days) d.toJson()],
  };
}

class ProgramRepository {
  Future<Database> _ready() => DatabaseHelper.instance.database;

  Future<List<ProgramExerciseLine>> _exercisesOf(Database db, int dayId) async {
    final rows = await db.rawQuery('''
      SELECT e.name AS name, pe.sets AS sets, pe.reps AS reps
      FROM program_exercises pe
      JOIN exercises e ON e.id = pe.exercise_id
      WHERE pe.program_day_id = ?
      ORDER BY pe.position
    ''', [dayId]);
    return [
      for (final r in rows)
        ProgramExerciseLine(
          name: r['name'] as String,
          sets: r['sets'] as int,
          reps: r['reps'] as int,
        ),
    ];
  }

  Future<List<ProgramDay>> _daysOf(Database db, int programId) async {
    final rows = await db.query(
      'program_days',
      where: 'program_id = ?',
      whereArgs: [programId],
      orderBy: 'day_index',
    );
    final days = <ProgramDay>[];
    for (final r in rows) {
      final isRest = (r['is_rest'] as int) == 1;
      final index = r['day_index'] as int;
      days.add(ProgramDay(
        weekday: weekdayNames[(index - 1) % 7],
        isRest: isRest,
        muscle: isRest ? null : r['title'] as String,
        exercises: isRest ? const [] : await _exercisesOf(db, r['id'] as int),
      ));
    }
    return days;
  }

  Future<Program> _toProgram(Database db, Map<String, Object?> r) async {
    final id = r['id'] as int;
    return Program(
      id: id,
      name: r['name'] as String,
      goal: (r['goal'] as String?) ?? 'gain',
      intensity: (r['intensity'] as String?) ?? 'low',
      weeks: (r['weeks'] as int?) ?? 0,
      daysPerWeek: (r['days_per_week'] as int?) ?? 0,
      minutes: (r['minutes_per_session'] as int?) ?? 0,
      description: r['description'] as String?,
      mediaPath: r['media_path'] as String?,
      status: r['status'] as String,
      createdBy: r['created_by'] as int?,
      days: await _daysOf(db, id),
    );
  }

  Future<String> _nameOf(Database db, int? userId) async {
    if (userId == null) return 'Unknown';
    final rows = await db.query(
      'users',
      columns: ['first_name', 'last_name'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return 'Unknown';
    return '${rows.first['first_name']} ${rows.first['last_name']}';
  }

  Future<void> _insertDays(DatabaseExecutor txn, int programId, List days) async {
    for (var i = 0; i < days.length; i++) {
      final d = days[i] as Map;
      final isRest = d['isRest'] == true;
      final dayId = await txn.insert('program_days', {
        'program_id': programId,
        'day_index': i + 1,
        'title': isRest ? 'Rest' : d['title'],
        'is_rest': isRest ? 1 : 0,
      });
      final exercises = d['exercises'] as List;
      for (var p = 0; p < exercises.length; p++) {
        final e = exercises[p] as Map;
        await txn.insert('program_exercises', {
          'program_day_id': dayId,
          'exercise_id': e['exerciseId'],
          'sets': e['sets'],
          'reps': e['reps'],
          'position': p + 1,
        });
      }
    }
  }

  /// Admin sees approved programs. Users and coaches also see their own pending ones.
  /// Private programs are never listed here.
  Future<List<Program>> programsFor({
    required String goal,
    required String intensity,
    required int userId,
    required bool isAdmin,
  }) async {
    final db = await _ready();
    final rows = isAdmin
        ? await db.query(
            'programs',
            where: "type = 'workout' AND is_private = 0 AND goal = ? "
                "AND intensity = ? AND status = 'approved'",
            whereArgs: [goal, intensity],
            orderBy: 'name',
          )
        : await db.query(
            'programs',
            where: "type = 'workout' AND is_private = 0 AND goal = ? AND intensity = ? "
                "AND (status = 'approved' OR (created_by = ? AND status = 'pending'))",
            whereArgs: [goal, intensity, userId],
            orderBy: 'name',
          );
    return [for (final r in rows) await _toProgram(db, r)];
  }

  /// Everything this user added to the Programs section, with its status.
  Future<List<Program>> myRequests(int userId) async {
    final db = await _ready();
    final rows = await db.query(
      'programs',
      where: "type = 'workout' AND is_private = 0 AND created_by = ?",
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return [for (final r in rows) await _toProgram(db, r)];
  }

  /// Approved public programs, used by the progress form.
  Future<List<Program>> approvedPrograms() async {
    final db = await _ready();
    final rows = await db.query(
      'programs',
      where: "type = 'workout' AND is_private = 0 AND status = 'approved'",
      orderBy: 'goal, intensity, name',
    );
    return [for (final r in rows) await _toProgram(db, r)];
  }

  /// The newest private program a user created in their progress section.
  Future<Program?> latestPrivateProgram(int userId) async {
    final db = await _ready();
    final rows = await db.query(
      'programs',
      where: "type = 'workout' AND is_private = 1 AND created_by = ?",
      whereArgs: [userId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _toProgram(db, rows.first);
  }

  /// New public programs waiting for review, with the submitter's name.
  Future<List<(Program, String)>> pendingPrograms() async {
    final db = await _ready();
    final rows = await db.query(
      'programs',
      where: "type = 'workout' AND is_private = 0 AND status = 'pending'",
      orderBy: 'id DESC',
    );
    return [
      for (final r in rows)
        (await _toProgram(db, r), await _nameOf(db, r['created_by'] as int?)),
    ];
  }

  Future<List<Exercise>> approvedExercises() async {
    final all = await WorkoutRepository().allExercises();
    return all.where((e) => e.status == 'approved').toList();
  }

  /// Admin adds are approved right away. Others wait as pending.
  /// Private programs are approved but hidden from everyone except their owner.
  Future<int> addProgram({
    required Map<String, dynamic> payload,
    required int userId,
    required bool isAdmin,
    bool isPrivate = false,
  }) async {
    final db = await _ready();
    return db.transaction<int>((txn) async {
      final programId = await txn.insert('programs', {
        'name': payload['name'],
        'type': 'workout',
        'goal': payload['goal'],
        'intensity': payload['intensity'],
        'weeks': payload['weeks'],
        'days_per_week': payload['days_per_week'],
        'minutes_per_session': payload['minutes'],
        'description': payload['description'],
        'media_path': payload['media_path'],
        'created_by': userId,
        'is_private': isPrivate ? 1 : 0,
        'status': (isPrivate || isAdmin) ? 'approved' : 'pending',
      });
      await _insertDays(txn, programId, payload['days'] as List);
      return programId;
    });
  }

  /// Replaces the program's details and its weekly plan.
  /// If the photo changed, the old user-added photo file is deleted.
  Future<void> updateProgram(int id, Map<String, dynamic> p) async {
    final db = await _ready();
    final old = await db.query('programs',
        columns: ['media_path'], where: 'id = ?', whereArgs: [id], limit: 1);
    final oldMedia = old.isEmpty ? null : old.first['media_path'] as String?;

    final values = <String, Object?>{
      'name': p['name'],
      'goal': p['goal'],
      'intensity': p['intensity'],
      'weeks': p['weeks'],
      'days_per_week': p['days_per_week'],
      'minutes_per_session': p['minutes'],
      'description': p['description'],
    };
    final hasMedia = p.containsKey('media_path');
    if (hasMedia) values['media_path'] = p['media_path'];

    await db.transaction((txn) async {
      await txn.update('programs', values, where: 'id = ?', whereArgs: [id]);
      await txn.delete('program_days', where: 'program_id = ?', whereArgs: [id]);
      await _insertDays(txn, id, p['days'] as List);
    });

    if (hasMedia && oldMedia != p['media_path']) {
      await deleteUserMedia(oldMedia);
    }
  }

  Future<void> setProgramStatus(int id, String status) async {
    final db = await _ready();
    await db.update('programs', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes the program, its days and its photo file (if the user added it).
  Future<void> deleteProgram(int id) async {
    final db = await _ready();
    final rows = await db.query('programs',
        columns: ['media_path'], where: 'id = ?', whereArgs: [id], limit: 1);
    await db.delete('programs', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      await deleteUserMedia(rows.first['media_path'] as String?);
    }
  }

  /// The submitter can cancel a request only while it is still pending.
  /// Cancelling also deletes the photo file.
  Future<bool> cancelOwnPending(int id, int userId) async {
    final db = await _ready();
    final rows = await db.query('programs',
        columns: ['media_path'],
        where: "id = ? AND created_by = ? AND status = 'pending'",
        whereArgs: [id, userId],
        limit: 1);
    if (rows.isEmpty) return false;
    final n = await db.delete(
      'programs',
      where: "id = ? AND created_by = ? AND status = 'pending'",
      whereArgs: [id, userId],
    );
    if (n > 0) await deleteUserMedia(rows.first['media_path'] as String?);
    return n > 0;
  }
}