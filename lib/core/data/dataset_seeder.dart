import 'package:sqflite/sqflite.dart';
import 'exercise_dataset.dart';
import 'program_dataset.dart';

/// Loads the built-in exercises and programs.
/// New items are added once. Picture paths of built-in items are refreshed on
/// every start, so a newly added picture file is found without reinstalling.
class DatasetSeeder {
  static Future<void> run(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
          'CREATE TABLE IF NOT EXISTS dataset_marks (key TEXT PRIMARY KEY)');

      // ---------- Exercises: add once ----------
      for (final e in exerciseDataset) {
        if (!await _firstTime(txn, 'ex:${e.name}|${e.group}')) continue;
        final rows = await txn.query(
          'exercises',
          columns: ['id'],
          where: 'name = ? AND muscle_group = ?',
          whereArgs: [e.name, e.group],
          limit: 1,
        );
        if (rows.isEmpty) {
          await txn.insert('exercises', {
            'name': e.name,
            'muscle_group': e.group,
            'equipment': e.equipment,
            'level': e.level,
            'description': e.description,
            'instructions': e.steps.replaceAll('|', '\n'),
            'media_path': e.mediaPath,
            'status': 'approved',
          });
        } else {
          // Starter exercise from the first version: fill in the missing details.
          await txn.rawUpdate(
            '''UPDATE exercises SET
                 equipment = COALESCE(equipment, ?),
                 level = COALESCE(level, ?),
                 description = COALESCE(description, ?),
                 instructions = COALESCE(instructions, ?)
               WHERE name = ? AND muscle_group = ? AND created_by IS NULL''',
            [
              e.equipment,
              e.level,
              e.description,
              e.steps.replaceAll('|', '\n'),
              e.name,
              e.group,
            ],
          );
        }
      }

      // ---------- Programs: add once ----------
      for (final p in programDataset) {
        if (!await _firstTime(txn, 'pg:${p.name}')) continue;
        final rows = await txn.query(
          'programs',
          columns: ['id'],
          where: "name = ? AND type = 'workout'",
          whereArgs: [p.name],
          limit: 1,
        );
        if (rows.isEmpty) await _insertProgram(txn, p);
      }

      // Remove the two starter programs from the first version.
      final names = [for (final p in programDataset) p.name];
      await txn.delete(
        'programs',
        where: "type = 'workout' AND created_by IS NULL "
            "AND name NOT IN (${List.filled(names.length, '?').join(',')})",
        whereArgs: names,
      );

      // ---------- Picture paths: refresh on every start ----------
      // Only built-in items are touched: those with no photo, or a bundled
      // asset path. Photos that users or admins added are never changed.
      for (final e in exerciseDataset) {
        await txn.rawUpdate(
          '''UPDATE exercises SET media_path = ?
             WHERE name = ? AND muscle_group = ? AND created_by IS NULL
               AND (media_path IS NULL OR media_path LIKE 'assets/%')''',
          [e.mediaPath, e.name, e.group],
        );
      }
      for (final p in programDataset) {
        await txn.rawUpdate(
          '''UPDATE programs SET media_path = ?
             WHERE name = ? AND type = 'workout' AND created_by IS NULL
               AND (media_path IS NULL OR media_path LIKE 'assets/%')''',
          [p.mediaPath, p.name],
        );
      }
    });
  }

  static Future<bool> _firstTime(Transaction txn, String key) async {
    final rows = await txn.query('dataset_marks',
        where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isNotEmpty) return false;
    await txn.insert('dataset_marks', {'key': key});
    return true;
  }

  static Future<void> _insertProgram(Transaction txn, ProgramSeed p) async {
    final programId = await txn.insert('programs', {
      'name': p.name,
      'type': 'workout',
      'goal': p.goal,
      'intensity': p.intensity,
      'weeks': p.weeks,
      'days_per_week': p.days.where((d) => !d.startsWith('Rest')).length,
      'minutes_per_session': p.minutes,
      'description': p.description,
      'media_path': p.mediaPath,
      'status': 'approved',
    });

    for (var i = 0; i < p.days.length; i++) {
      final parts = p.days[i].split('|');
      final title = parts.first;
      final isRest = title == 'Rest';
      final dayId = await txn.insert('program_days', {
        'program_id': programId,
        'day_index': i + 1,
        'title': isRest ? 'Rest' : title,
        'is_rest': isRest ? 1 : 0,
      });
      if (isRest) continue;

      for (var j = 1; j < parts.length; j++) {
        final cut = parts[j].lastIndexOf(':');
        final exerciseName = parts[j].substring(0, cut);
        final setsReps = parts[j].substring(cut + 1).split('x');
        final exercise = await txn.query(
          'exercises',
          columns: ['id'],
          where: 'name = ?',
          whereArgs: [exerciseName],
          limit: 1,
        );
        if (exercise.isEmpty) continue;
        await txn.insert('program_exercises', {
          'program_day_id': dayId,
          'exercise_id': exercise.first['id'],
          'sets': int.parse(setsReps[0]),
          'reps': int.parse(setsReps[1]),
          'position': j,
        });
      }
    }
  }
}