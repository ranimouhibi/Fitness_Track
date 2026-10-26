import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

/// Body parts measured in centimetres.
const bodyParts = [
  'Neck', 'Shoulders', 'Chest', 'Upper arm', 'Forearm',
  'Waist', 'Hips', 'Thigh', 'Calf',
];

const objectives = ['Lose weight', 'Gain muscle', 'Build strength', 'Stay fit'];

String todayIso() => DateTime.now().toIso8601String().substring(0, 10);

int? _ageOf(String? birth) {
  final d = birth == null ? null : DateTime.tryParse(birth);
  if (d == null) return null;
  final now = DateTime.now();
  var age = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
  return age;
}

class ProfileData {
  final int id;
  final String fullName;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final Map<String, double> measures;

  const ProfileData({
    required this.id,
    required this.fullName,
    this.age,
    this.heightCm,
    this.weightKg,
    required this.measures,
  });
}

class PlanSummary {
  final int id;
  final String objective;
  final int durationWeeks;
  final String startDate;
  final int? programId;
  final String? programName;
  final String status;
  final double? targetWeight;

  const PlanSummary({
    required this.id,
    required this.objective,
    required this.durationWeeks,
    required this.startDate,
    this.programId,
    this.programName,
    required this.status,
    this.targetWeight,
  });

  DateTime get startDay => DateTime.parse(startDate);
  DateTime get endDay => startDay.add(Duration(days: durationWeeks * 7));
  bool get isActive => status == 'active';

  /// Whole days left until the end date (never negative).
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final left = endDay.difference(today).inDays;
    return left < 0 ? 0 : left;
  }
}

class WeekEntry {
  final int id;
  final int weekNo;
  final String date;
  final double? weightKg;
  final Map<String, double> measures;

  const WeekEntry({
    required this.id,
    required this.weekNo,
    required this.date,
    this.weightKg,
    required this.measures,
  });
}

PlanSummary _planFromRow(Map<String, Object?> r) => PlanSummary(
      id: r['id'] as int,
      objective: r['objective'] as String,
      durationWeeks: r['duration_weeks'] as int,
      startDate: r['start_date'] as String,
      programId: r['program_id'] as int?,
      programName: r['program_name'] as String?,
      status: r['status'] as String,
      targetWeight: (r['target_weight'] as num?)?.toDouble(),
    );

class ProgressRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<ProfileData> profile(int userId) async {
    final db = await _db;
    final u = (await db.query('users',
            where: 'id = ?', whereArgs: [userId], limit: 1))
        .first;
    final m = await db.query('body_measures',
        where: 'user_id = ?', whereArgs: [userId]);
    return ProfileData(
      id: userId,
      fullName: '${u['first_name']} ${u['last_name']}',
      age: _ageOf(u['birth_date'] as String?),
      heightCm: (u['height_cm'] as num?)?.toDouble(),
      weightKg: (u['weight_kg'] as num?)?.toDouble(),
      measures: {
        for (final r in m) r['part'] as String: (r['value_cm'] as num).toDouble(),
      },
    );
  }

  /// Saves weight, height and body measures. A null measure is removed.
  Future<void> updateProfile({
    required int userId,
    double? weight,
    double? height,
    required Map<String, double?> measures,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final values = <String, Object?>{};
      if (weight != null) values['weight_kg'] = weight;
      if (height != null) values['height_cm'] = height;
      if (values.isNotEmpty) {
        await txn.update('users', values, where: 'id = ?', whereArgs: [userId]);
      }
      for (final e in measures.entries) {
        if (e.value == null) {
          await txn.delete('body_measures',
              where: 'user_id = ? AND part = ?', whereArgs: [userId, e.key]);
        } else {
          await txn.insert(
            'body_measures',
            {'user_id': userId, 'part': e.key, 'value_cm': e.value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<List<PlanSummary>> plans(int userId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT pl.id, pl.objective, pl.duration_weeks, pl.start_date, pl.program_id,
             pl.status, pl.target_weight, pr.name AS program_name
      FROM progress_plans pl
      LEFT JOIN programs pr ON pr.id = pl.program_id
      WHERE pl.user_id = ?
      ORDER BY pl.id DESC
    ''', [userId]);
    return [for (final r in rows) _planFromRow(r)];
  }

  /// Creates the plan and its week 0 snapshot (weight and measures at the start).
  Future<int> startPlan({
    required int userId,
    required String objective,
    required int weeks,
    required int? programId,
    required double? startWeight,
    double? targetWeight,
    required Map<String, double> baseline,
  }) async {
    final db = await _db;
    return db.transaction<int>((txn) async {
      final today = todayIso();
      final planId = await txn.insert('progress_plans', {
        'user_id': userId,
        'objective': objective,
        'duration_weeks': weeks,
        'start_date': today,
        'program_id': programId,
        'status': 'active',
        'target_weight': targetWeight,
      });
      final entryId = await txn.insert('progress_entries', {
        'plan_id': planId,
        'week_no': 0,
        'entry_date': today,
        'weight_kg': startWeight,
      });
      for (final e in baseline.entries) {
        await txn.insert('progress_entry_measures', {
          'entry_id': entryId,
          'part': e.key,
          'value_cm': e.value,
        });
      }
      return planId;
    });
  }

  Future<void> setPlanStatus(int planId, String status) async {
    final db = await _db;
    await db.update('progress_plans', {'status': status},
        where: 'id = ?', whereArgs: [planId]);
  }

  /// All weeks of a plan, oldest first.
  Future<List<WeekEntry>> entries(int planId) async {
    final db = await _db;
    final rows = await db.query('progress_entries',
        where: 'plan_id = ?', whereArgs: [planId], orderBy: 'week_no ASC');
    final out = <WeekEntry>[];
    for (final r in rows) {
      final id = r['id'] as int;
      final m = await db.query('progress_entry_measures',
          where: 'entry_id = ?', whereArgs: [id]);
      out.add(WeekEntry(
        id: id,
        weekNo: r['week_no'] as int,
        date: r['entry_date'] as String,
        weightKg: (r['weight_kg'] as num?)?.toDouble(),
        measures: {
          for (final x in m) x['part'] as String: (x['value_cm'] as num).toDouble(),
        },
      ));
    }
    return out;
  }

  /// The next week number to fill in (1 after the start snapshot).
  Future<int> nextWeekNo(int planId) async {
    final db = await _db;
    final max = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT MAX(week_no) FROM progress_entries WHERE plan_id = ?',
            [planId])) ??
        0;
    return max + 1;
  }

  /// Creates or updates one week. Measures not sent are cleared for that week.
  Future<void> saveEntry({
    required int planId,
    required int weekNo,
    required double? weight,
    required Map<String, double> measures,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query('progress_entries',
          columns: ['id'],
          where: 'plan_id = ? AND week_no = ?',
          whereArgs: [planId, weekNo],
          limit: 1);
      final int entryId;
      if (existing.isEmpty) {
        entryId = await txn.insert('progress_entries', {
          'plan_id': planId,
          'week_no': weekNo,
          'entry_date': todayIso(),
          'weight_kg': weight,
        });
      } else {
        entryId = existing.first['id'] as int;
        await txn.update(
          'progress_entries',
          {'weight_kg': weight, 'entry_date': todayIso()},
          where: 'id = ?',
          whereArgs: [entryId],
        );
        await txn.delete('progress_entry_measures',
            where: 'entry_id = ?', whereArgs: [entryId]);
      }
      for (final e in measures.entries) {
        await txn.insert('progress_entry_measures', {
          'entry_id': entryId,
          'part': e.key,
          'value_cm': e.value,
        });
      }
    });
  }
}