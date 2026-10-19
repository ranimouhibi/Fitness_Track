import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

class CoachBookingRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Map<String, Object?>>> coaches() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT u.id, u.first_name, u.last_name, u.years_experience,
             COUNT(DISTINCT b.id) AS completed_bookings
      FROM users u
      LEFT JOIN bookings b ON b.coach_id = u.id AND b.status = 'ended'
      WHERE u.role = 'coach' AND u.coach_status = 'approved'
      GROUP BY u.id
      ORDER BY u.first_name, u.last_name
    ''');
  }

  Future<Map<String, Object?>?> coachDetails(int coachId) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      columns: ['id', 'first_name', 'last_name', 'years_experience'],
      where: "id = ? AND role = 'coach' AND coach_status = 'approved'",
      whereArgs: [coachId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> availability(int coachId) async {
    final db = await _db;
    return db.query(
      'coach_availability',
      where: 'coach_id = ?',
      whereArgs: [coachId],
      orderBy: 'weekday, start_time',
    );
  }

  Future<void> addWeeklyAvailability({
    required int coachId,
    required int weekday,
    required String startTime,
    required String endTime,
    required int slotMinutes,
    required String mode,
    required double priceTnd,
  }) async {
    _validateAvailability(
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
      slotMinutes: slotMinutes,
      mode: mode,
      priceTnd: priceTnd,
    );
    final db = await _db;
    await db.transaction((txn) async {
      await _validateCoachAndWindow(
        txn,
        coachId: coachId,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
      );
      final availabilityId = await txn.insert('coach_availability', {
        'coach_id': coachId,
        'weekday': weekday,
        'start_time': startTime,
        'end_time': endTime,
        'slot_minutes': slotMinutes,
        'mode': mode,
        'price_tnd': priceTnd,
      });
      await _generateSlots(
        txn,
        availabilityId: availabilityId,
        coachId: coachId,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
        slotMinutes: slotMinutes,
        mode: mode,
        priceTnd: priceTnd,
      );
    });
  }

  Future<void> editWeeklyAvailability({
    required int coachId,
    required int availabilityId,
    required int weekday,
    required String startTime,
    required String endTime,
    required int slotMinutes,
    required String mode,
    required double priceTnd,
  }) async {
    _validateAvailability(
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
      slotMinutes: slotMinutes,
      mode: mode,
      priceTnd: priceTnd,
    );
    final db = await _db;
    await db.transaction((txn) async {
      await _validateCoachAndWindow(
        txn,
        coachId: coachId,
        availabilityId: availabilityId,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
      );
      final count = await txn.update(
        'coach_availability',
        {
          'weekday': weekday,
          'start_time': startTime,
          'end_time': endTime,
          'slot_minutes': slotMinutes,
          'mode': mode,
          'price_tnd': priceTnd,
        },
        where: 'id = ? AND coach_id = ?',
        whereArgs: [availabilityId, coachId],
      );
      if (count != 1) throw StateError('Availability window no longer exists.');
      await txn.delete(
        'coach_slots',
        where: 'availability_id = ? AND status = ?',
        whereArgs: [availabilityId, 'free'],
      );
      await _generateSlots(
        txn,
        availabilityId: availabilityId,
        coachId: coachId,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
        slotMinutes: slotMinutes,
        mode: mode,
        priceTnd: priceTnd,
      );
    });
  }

  void _validateAvailability({
    required int weekday,
    required String startTime,
    required String endTime,
    required int slotMinutes,
    required String mode,
    required double priceTnd,
  }) {
    if (weekday < 1 ||
        weekday > 7 ||
        slotMinutes <= 0 ||
        startTime.compareTo(endTime) >= 0 ||
        priceTnd < 0 ||
        !{'online', 'in_person'}.contains(mode)) {
      throw ArgumentError('Enter a valid weekly availability window.');
    }
  }

  Future<void> _validateCoachAndWindow(
    Transaction txn, {
    required int coachId,
    int? availabilityId,
    required int weekday,
    required String startTime,
    required String endTime,
  }) async {
    final coaches = await txn.query(
      'users',
      columns: ['id'],
      where: "id = ? AND role = 'coach' AND coach_status = 'approved'",
      whereArgs: [coachId],
      limit: 1,
    );
    if (coaches.isEmpty) {
      throw StateError('Only approved coaches can publish availability.');
    }
    final overlapping = await txn.rawQuery(
      '''
      SELECT id FROM coach_availability
      WHERE coach_id = ? AND weekday = ?
        AND start_time < ? AND end_time > ?
        AND (? IS NULL OR id != ?)
      LIMIT 1
      ''',
      [coachId, weekday, endTime, startTime, availabilityId, availabilityId],
    );
    if (overlapping.isNotEmpty) {
      throw StateError('Availability windows on the same day cannot overlap.');
    }
  }

  Future<void> _generateSlots(
    Transaction txn, {
    required int availabilityId,
    required int coachId,
    required int weekday,
    required String startTime,
    required String endTime,
    required int slotMinutes,
    required String mode,
    required double priceTnd,
  }) async {
    final now = DateTime.now();
    for (var offset = 0; offset < 56; offset++) {
      final date = DateTime(now.year, now.month, now.day + offset);
      if (date.weekday != weekday) continue;
      var minute = _minutes(startTime);
      final end = _minutes(endTime);
      while (minute + slotMinutes <= end) {
        final slotStart = DateTime(
          date.year,
          date.month,
          date.day,
          minute ~/ 60,
          minute % 60,
        );
        if (slotStart.isAfter(now)) {
          await txn.insert(
            'coach_slots',
            {
              'coach_id': coachId,
              'availability_id': availabilityId,
              'starts_at': slotStart.toIso8601String(),
              'mode': mode,
              'price_tnd': priceTnd,
              'status': 'free',
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        minute += slotMinutes;
      }
    }
  }

  Future<void> removeAvailability(int coachId, int availabilityId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'coach_slots',
        where: 'availability_id = ? AND status = ?',
        whereArgs: [availabilityId, 'free'],
      );
      await txn.delete(
        'coach_availability',
        where: 'id = ? AND coach_id = ?',
        whereArgs: [availabilityId, coachId],
      );
    });
  }

  Future<List<Map<String, Object?>>> freeSlots(int coachId, DateTime day) async {
    final db = await _db;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return db.query(
      'coach_slots',
      where: 'coach_id = ? AND status = ? AND starts_at >= ? AND starts_at < ? '
          "AND julianday(starts_at) > julianday('now', 'localtime')",
      whereArgs: [
        coachId,
        'free',
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'starts_at',
    );
  }

  Future<void> requestBooking({
    required int userId,
    required int coachId,
    required int slotId,
    required String payment,
  }) async {
    if (!{'cash', 'online'}.contains(payment)) {
      throw ArgumentError('Choose a valid payment method.');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final accounts = await txn.rawQuery(
        '''
        SELECT
          EXISTS(SELECT 1 FROM users WHERE id = ? AND role = 'user') AS is_user,
          EXISTS(
            SELECT 1 FROM users
            WHERE id = ? AND role = 'coach' AND coach_status = 'approved'
          ) AS is_approved_coach
        ''',
        [userId, coachId],
      );
      if (accounts.first['is_user'] != 1 ||
          accounts.first['is_approved_coach'] != 1) {
        throw StateError('Only users can request sessions with approved coaches.');
      }
      final slots = await txn.query(
        'coach_slots',
        where: 'id = ? AND coach_id = ? AND status = ? AND starts_at > ?',
        whereArgs: [slotId, coachId, 'free', DateTime.now().toIso8601String()],
        limit: 1,
      );
      if (slots.isEmpty) throw StateError('That appointment is no longer free.');
      final slot = slots.first;
      await txn.insert('bookings', {
        'user_id': userId,
        'coach_id': coachId,
        'starts_at': slot['starts_at'],
        'mode': slot['mode'],
        'price_tnd': slot['price_tnd'],
        'payment': payment,
        'status': 'pending',
      });
    });
  }

  Future<List<Map<String, Object?>>> bookingsForCoach(int coachId) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT b.*, u.first_name AS client_first_name, u.last_name AS client_last_name
      FROM bookings b
      JOIN users u ON u.id = b.user_id
      WHERE b.coach_id = ?
      ORDER BY CASE b.status
        WHEN 'pending' THEN 0 WHEN 'accepted' THEN 1 ELSE 2 END, b.starts_at
    ''', [coachId]);
  }

  Future<List<Map<String, Object?>>> bookingsForClient(int userId) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT b.*, u.first_name AS coach_first_name, u.last_name AS coach_last_name
      FROM bookings b
      JOIN users u ON u.id = b.coach_id
      WHERE b.user_id = ?
      ORDER BY CASE b.status
        WHEN 'pending' THEN 0 WHEN 'accepted' THEN 1 ELSE 2 END, b.starts_at
    ''', [userId]);
  }

  Future<void> accept(int bookingId, int coachId) =>
      _setPendingStatus(bookingId, coachId, 'accepted');

  Future<void> decline(int bookingId, int coachId) =>
      _setPendingStatus(bookingId, coachId, 'declined');

  Future<void> _setPendingStatus(
    int bookingId,
    int coachId,
    String status,
  ) async {
    final db = await _db;
    final count = await db.update(
      'bookings',
      {'status': status},
      where: 'id = ? AND coach_id = ? AND status = ?',
      whereArgs: [bookingId, coachId, 'pending'],
    );
    if (count != 1) throw StateError('This booking is no longer pending.');
  }

  Future<void> reschedule({
    required int bookingId,
    required int coachId,
    required int slotId,
  }) async {
    final db = await _db;
    final count = await db.rawUpdate('''
      UPDATE bookings
      SET starts_at = (SELECT starts_at FROM coach_slots WHERE id = ?),
          mode = (SELECT mode FROM coach_slots WHERE id = ?),
          price_tnd = (SELECT price_tnd FROM coach_slots WHERE id = ?)
      WHERE id = ? AND coach_id = ? AND status = 'accepted'
        AND EXISTS (
          SELECT 1 FROM coach_slots
          WHERE id = ? AND coach_id = ? AND status = 'free'
        )
    ''', [
      slotId, slotId, slotId, bookingId, coachId, slotId, coachId,
    ]);
    if (count != 1) throw StateError('That booking or appointment changed.');
  }

  Future<void> cancel(int bookingId, int coachId) async {
    final db = await _db;
    final count = await db.update(
      'bookings',
      {'status': 'cancelled'},
      where: 'id = ? AND coach_id = ? AND status = ?',
      whereArgs: [bookingId, coachId, 'accepted'],
    );
    if (count != 1) throw StateError('Only accepted bookings can be cancelled.');
  }

  Future<bool> isChatOpen(int bookingId) async {
    final db = await _db;
    final rows = await db.query(
      'bookings',
      columns: ['id'],
      where: 'id = ? AND status = ?',
      whereArgs: [bookingId, 'accepted'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, Object?>>> messagesForBooking({
    required int bookingId,
    required int participantId,
  }) async {
    final db = await _db;
    await _requireChatAccess(db, bookingId, participantId);
    return db.rawQuery('''
      SELECT m.id, m.sender_id, m.body, m.sent_at,
             u.first_name, u.last_name
      FROM messages m
      JOIN users u ON u.id = m.sender_id
      WHERE m.booking_id = ?
      ORDER BY m.sent_at, m.id
    ''', [bookingId]);
  }

  Future<void> sendMessage({
    required int bookingId,
    required int senderId,
    required String body,
  }) async {
    final message = body.trim();
    if (message.isEmpty) throw ArgumentError('Message cannot be empty.');
    final db = await _db;
    await db.transaction((txn) async {
      await _requireChatAccess(txn, bookingId, senderId);
      await txn.insert('messages', {
        'booking_id': bookingId,
        'sender_id': senderId,
        'body': message,
      });
    });
  }

  Future<void> _requireChatAccess(
    DatabaseExecutor db,
    int bookingId,
    int participantId,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT id FROM bookings
      WHERE id = ? AND status = 'accepted'
        AND (user_id = ? OR coach_id = ?)
      LIMIT 1
      ''',
      [bookingId, participantId, participantId],
    );
    if (rows.isEmpty) {
      throw StateError('Chat is only available to booking participants while accepted.');
    }
  }

  Future<void> closePastBookings() async {
    final db = await _db;
    await db.update(
      'bookings',
      {'status': 'ended'},
      where: "status IN ('pending', 'accepted') AND julianday(starts_at) <= julianday('now', 'localtime')",
    );
  }

  int _minutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
