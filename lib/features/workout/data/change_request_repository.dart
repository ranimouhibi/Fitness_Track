import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import 'program_repository.dart';
import 'workout_repository.dart';

class ChangeRequest {
  final int id;
  final String type; // 'edit' or 'delete'
  final String targetTable; // 'exercises' or 'programs'
  final int targetId;
  final Map<String, dynamic> payload;
  final String submitterName;

  const ChangeRequest({
    required this.id,
    required this.type,
    required this.targetTable,
    required this.targetId,
    required this.payload,
    required this.submitterName,
  });
}

class ChangeRequestRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Users and coaches call this to ask for an edit or a delete.
  Future<void> submit({
    required String type,
    required String table,
    required int targetId,
    required int userId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db;
    await db.insert('content_requests', {
      'request_type': type,
      'target_table': table,
      'target_id': targetId,
      'payload': jsonEncode(payload),
      'submitted_by': userId,
      'status': 'pending',
    });
  }

  Future<List<ChangeRequest>> pending() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT cr.id, cr.request_type, cr.target_table, cr.target_id, cr.payload,
             COALESCE(u.first_name || ' ' || u.last_name, 'Unknown') AS submitter
      FROM content_requests cr
      LEFT JOIN users u ON u.id = cr.submitted_by
      WHERE cr.status = 'pending' AND cr.target_table IN ('exercises', 'programs')
      ORDER BY cr.id DESC
    ''');
    return [
      for (final r in rows)
        ChangeRequest(
          id: r['id'] as int,
          type: r['request_type'] as String,
          targetTable: r['target_table'] as String,
          targetId: r['target_id'] as int,
          payload: r['payload'] == null
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(
                  jsonDecode(r['payload'] as String) as Map),
          submitterName: r['submitter'] as String,
        ),
    ];
  }

  /// Accept applies the edit or delete. Refuse only marks the request.
  Future<void> decide(
    ChangeRequest r, {
    required bool accept,
    required int adminId,
  }) async {
    final db = await _db;
    if (accept) {
      final isExercise = r.targetTable == 'exercises';
      if (r.type == 'delete') {
        if (isExercise) {
          await WorkoutRepository().deleteExercise(r.targetId);
        } else {
          await ProgramRepository().deleteProgram(r.targetId);
        }
      } else {
        if (isExercise) {
          await WorkoutRepository().updateExercise(r.targetId, r.payload);
        } else {
          await ProgramRepository().updateProgram(r.targetId, r.payload);
        }
      }
    }
    await db.update(
      'content_requests',
      {'status': accept ? 'accepted' : 'refused', 'decided_by': adminId},
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }
}