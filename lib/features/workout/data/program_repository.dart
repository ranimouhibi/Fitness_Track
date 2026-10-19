import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import 'workout_repository.dart';

const goals = {'gain': 'Gain weight', 'lose': 'Lose weight'};
const intensities = {'low': 'Low', 'medium': 'Medium', 'high': 'High'};
const weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

class _StarterDay {
  final String? muscle;
  final List<(String, int, int)> exercises;
  const _StarterDay.rest()
      : muscle = null,
        exercises = const [];
  const _StarterDay.train(this.muscle, this.exercises);
}

class _StarterProgram {
  final String name;
  final String goal;
  final String intensity;
  final int weeks;
  final int minutes;
  final String description;
  final List<_StarterDay> days;
  const _StarterProgram({
    required this.name,
    required this.goal,
    required this.intensity,
    required this.weeks,
    required this.minutes,
    required this.description,
    required this.days,
  });
}

const _starterPrograms = [
  _StarterProgram(
    name: 'Mass Builder',
    goal: 'gain',
    intensity: 'medium',
    weeks: 8,
    minutes: 60,
    description: 'Build muscle with heavy chest, back and leg days.',
    days: [
      _StarterDay.train('Chest', [
        ('Bench Press', 4, 8),
        ('Incline Dumbbell Press', 3, 10),
        ('Cable Fly', 3, 12),
      ]),
      _StarterDay.train('Back', [('Dumbbell Pullover', 3, 12)]),
      _StarterDay.rest(),
      _StarterDay.train('Legs', [('Wall Sit', 3, 12)]),
      _StarterDay.rest(),
      _StarterDay.train('Chest', [
        ('Push-up', 3, 15),
        ('Pec Deck', 3, 12),
      ]),
      _StarterDay.rest(),
    ],
  ),
  _StarterProgram(
    name: 'Fat Burn Start',
    goal: 'lose',
    intensity: 'low',
    weeks: 6,
    minutes: 40,
    description: 'A gentle full-body start to build the habit.',
    days: [
      _StarterDay.train('Legs', [('Wall Sit', 3, 15)]),
      _StarterDay.rest(),
      _StarterDay.train('Chest', [('Push-up', 3, 15)]),
      _StarterDay.rest(),
      _StarterDay.train('Back', [('Dumbbell Pullover', 3, 12)]),
      _StarterDay.rest(),
      _StarterDay.rest(),
    ],
  ),
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
  required List<DayPlan> days,
}) {
  return {
    'name': name.trim(),
    'goal': goal,
    'intensity': intensity,
    'weeks': weeks,
    'minutes': minutes,
    'description': description?.trim(),
    'days_per_week': days.where((d) => !d.isRest).length,
    'days': [for (final d in days) d.toJson()],
  };
}

class ProgramRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<Database> _ready() async {
    final db = await _db;
    final count = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM programs WHERE type = 'workout'")) ??
        0;
    if (count == 0) await _seedStarters(db);
    return db;
  }

  Future<void> _seedStarters(Database db) async {
    await WorkoutRepository().allExercises();

    final ids = <String, int>{};
    final rows = await db.query('exercises', columns: ['id', 'name']);
    for (final r in rows) {
      ids[r['name'] as String] = r['id'] as int;
    }

    await db.transaction((txn) async {
      for (final s in _starterPrograms) {
        final programId = await txn.insert('programs', {
          'name': s.name,
          'type': 'workout',
          'goal': s.goal,
          'intensity': s.intensity,
          'weeks': s.weeks,
          'days_per_week': s.days.where((d) => d.muscle != null).length,
          'minutes_per_session': s.minutes,
          'description': s.description,
          'status': 'approved',
        });
        for (var i = 0; i < s.days.length; i++) {
          final d = s.days[i];
          final dayId = await txn.insert('program_days', {
            'program_id': programId,
            'day_index': i + 1,
            'title': d.muscle ?? 'Rest',
            'is_rest': d.muscle == null ? 1 : 0,
          });
          for (var p = 0; p < d.exercises.length; p++) {
            final e = d.exercises[p];
            final exerciseId = ids[e.$1];
            if (exerciseId == null) continue;
            await txn.insert('program_exercises', {
              'program_day_id': dayId,
              'exercise_id': exerciseId,
              'sets': e.$2,
              'reps': e.$3,
              'position': p + 1,
            });
          }
        }
      }
    });
  }

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
            where: "type = 'workout' AND goal = ? AND intensity = ? AND status = 'approved'",
            whereArgs: [goal, intensity],
            orderBy: 'name',
          )
        : await db.query(
            'programs',
            where: "type = 'workout' AND goal = ? AND intensity = ? "
                "AND (status = 'approved' OR (created_by = ? AND status = 'pending'))",
            whereArgs: [goal, intensity, userId],
            orderBy: 'name',
          );
    return [for (final r in rows) await _toProgram(db, r)];
  }

  /// Everything this user added, with its status.
  Future<List<Program>> myRequests(int userId) async {
    final db = await _ready();
    final rows = await db.query(
      'programs',
      where: "type = 'workout' AND created_by = ?",
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return [for (final r in rows) await _toProgram(db, r)];
  }

  /// New programs waiting for review, with the submitter's name.
  Future<List<(Program, String)>> pendingPrograms() async {
    final db = await _ready();
    final rows = await db.query(
      'programs',
      where: "type = 'workout' AND status = 'pending'",
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
  Future<void> addProgram({
    required Map<String, dynamic> payload,
    required int userId,
    required bool isAdmin,
  }) async {
    final db = await _ready();
    await db.transaction((txn) async {
      final programId = await txn.insert('programs', {
        'name': payload['name'],
        'type': 'workout',
        'goal': payload['goal'],
        'intensity': payload['intensity'],
        'weeks': payload['weeks'],
        'days_per_week': payload['days_per_week'],
        'minutes_per_session': payload['minutes'],
        'description': payload['description'],
        'created_by': userId,
        'status': isAdmin ? 'approved' : 'pending',
      });
      await _insertDays(txn, programId, payload['days'] as List);
    });
  }

  /// Replaces the program's details and its weekly plan.
  Future<void> updateProgram(int id, Map<String, dynamic> p) async {
    final db = await _ready();
    await db.transaction((txn) async {
      await txn.update(
        'programs',
        {
          'name': p['name'],
          'goal': p['goal'],
          'intensity': p['intensity'],
          'weeks': p['weeks'],
          'days_per_week': p['days_per_week'],
          'minutes_per_session': p['minutes'],
          'description': p['description'],
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete('program_days', where: 'program_id = ?', whereArgs: [id]);
      await _insertDays(txn, id, p['days'] as List);
    });
  }

  Future<void> setProgramStatus(int id, String status) async {
    final db = await _ready();
    await db.update('programs', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProgram(int id) async {
    final db = await _ready();
    await db.delete('programs', where: 'id = ?', whereArgs: [id]);
  }

  /// The submitter can cancel a request only while it is still pending.
  /// The program's days and exercises are removed with it.
  Future<bool> cancelOwnPending(int id, int userId) async {
    final db = await _ready();
    final n = await db.delete(
      'programs',
      where: "id = ? AND created_by = ? AND status = 'pending'",
      whereArgs: [id, userId],
    );
    return n > 0;
  }
}