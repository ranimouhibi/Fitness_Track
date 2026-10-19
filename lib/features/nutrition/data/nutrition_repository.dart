import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

const mealTypes = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'dinner': 'Dinner',
  'snack': 'Snack',
};

// ─── Models ──────────────────────────────────────────────────────────────────

class Food {
  final int id;
  final String name;
  final double kcalPer100g;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String status;
  final int? createdBy;

  const Food({
    required this.id,
    required this.name,
    required this.kcalPer100g,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.status,
    this.createdBy,
  });

  factory Food.fromMap(Map<String, Object?> m) => Food(
        id: m['id'] as int,
        name: m['name'] as String,
        kcalPer100g: (m['kcal_per_100g'] as num).toDouble(),
        proteinG: (m['protein_g'] as num).toDouble(),
        carbsG: (m['carbs_g'] as num).toDouble(),
        fatG: (m['fat_g'] as num).toDouble(),
        status: m['status'] as String,
        createdBy: m['created_by'] as int?,
      );

  /// Macros scaled to [grams].
  double kcalFor(double grams) => kcalPer100g * grams / 100;
  double proteinFor(double grams) => proteinG * grams / 100;
  double carbsFor(double grams) => carbsG * grams / 100;
  double fatFor(double grams) => fatG * grams / 100;
}

class MealLogEntry {
  final int id;
  final int foodId;
  final String foodName;
  final double grams;
  final String mealType;
  final String loggedOn; // 'yyyy-MM-dd'
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const MealLogEntry({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.grams,
    required this.mealType,
    required this.loggedOn,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory MealLogEntry.fromMap(Map<String, Object?> m) {
    final grams = (m['grams'] as num).toDouble();
    final kcal100 = (m['kcal_per_100g'] as num).toDouble();
    final protein100 = (m['protein_g'] as num).toDouble();
    final carbs100 = (m['carbs_g'] as num).toDouble();
    final fat100 = (m['fat_g'] as num).toDouble();
    return MealLogEntry(
      id: m['id'] as int,
      foodId: m['food_id'] as int,
      foodName: m['food_name'] as String,
      grams: grams,
      mealType: m['meal_type'] as String,
      loggedOn: m['logged_on'] as String,
      kcal: kcal100 * grams / 100,
      protein: protein100 * grams / 100,
      carbs: carbs100 * grams / 100,
      fat: fat100 * grams / 100,
    );
  }
}

class DaySummary {
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const DaySummary({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  DaySummary operator +(DaySummary other) => DaySummary(
        kcal: kcal + other.kcal,
        protein: protein + other.protein,
        carbs: carbs + other.carbs,
        fat: fat + other.fat,
      );

  static const zero = DaySummary(kcal: 0, protein: 0, carbs: 0, fat: 0);
}

class Supplement {
  final int id;
  final String name;
  final String? description;
  final String? timing;
  final List<String> alternatives; // food names

  const Supplement({
    required this.id,
    required this.name,
    this.description,
    this.timing,
    required this.alternatives,
  });
}

// ─── Payload helper ──────────────────────────────────────────────────────────

Map<String, dynamic> foodPayload({
  required String name,
  required double kcal,
  required double protein,
  required double carbs,
  required double fat,
}) =>
    {
      'name': name.trim(),
      'kcal_per_100g': kcal,
      'protein_g': protein,
      'carbs_g': carbs,
      'fat_g': fat,
    };

// ─── Repository ──────────────────────────────────────────────────────────────

class NutritionRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  // ── Seed ──────────────────────────────────────────────────────────────────

  /// Seeds starter foods and supplements the first time the table is empty.
  Future<Database> _ready() async {
    final db = await _db;
    final foodCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM foods')) ??
            0;
    if (foodCount == 0) await _seed(db);
    return db;
  }

  Future<void> _seed(Database db) async {
    await db.transaction((txn) async {
      // ── Starter foods ───────────────────────────────────────────────────
      final foods = [
        // (name, kcal, protein, carbs, fat)
        ('Chicken Breast', 165.0, 31.0, 0.0, 3.6),
        ('Oats', 389.0, 17.0, 66.0, 7.0),
        ('Egg', 155.0, 13.0, 1.1, 11.0),
        ('Brown Rice', 216.0, 5.0, 45.0, 1.8),
        ('Banana', 89.0, 1.1, 23.0, 0.3),
        ('Greek Yogurt', 100.0, 9.0, 3.6, 5.0),
        ('Almonds', 579.0, 21.0, 22.0, 50.0),
        ('Broccoli', 55.0, 3.7, 11.0, 0.6),
        ('Salmon', 208.0, 20.0, 0.0, 13.0),
        ('Sweet Potato', 86.0, 1.6, 20.0, 0.1),
        ('Whole Milk', 61.0, 3.2, 4.8, 3.3),
        ('Peanut Butter', 588.0, 25.0, 20.0, 50.0),
        ('Tuna (canned)', 109.0, 25.0, 0.0, 0.9),
        ('White Bread', 265.0, 9.0, 49.0, 3.2),
        ('Apple', 52.0, 0.3, 14.0, 0.2),
      ];
      final ids = <String, int>{};
      for (final f in foods) {
        final id = await txn.insert('foods', {
          'name': f.$1,
          'kcal_per_100g': f.$2,
          'protein_g': f.$3,
          'carbs_g': f.$4,
          'fat_g': f.$5,
          'status': 'approved',
        });
        ids[f.$1] = id;
      }

      // ── Starter supplements ─────────────────────────────────────────────
      final suppData = [
        (
          'Whey Protein',
          'Fast-digesting protein powder ideal post-workout.',
          'Post-workout',
          ['Chicken Breast', 'Egg', 'Greek Yogurt'],
        ),
        (
          'Creatine',
          'Increases strength and muscle power output.',
          'Pre or post-workout',
          ['Salmon', 'Tuna (canned)'],
        ),
        (
          'Omega-3',
          'Supports joint health and reduces inflammation.',
          'With meals',
          ['Salmon', 'Almonds'],
        ),
        (
          'Casein Protein',
          'Slow-digesting protein, great before bed.',
          'Before sleep',
          ['Greek Yogurt', 'Whole Milk'],
        ),
        (
          'Carbohydrate Powder',
          'Fast carbs for pre or intra-workout energy.',
          'Pre-workout',
          ['Oats', 'Banana', 'Sweet Potato'],
        ),
      ];
      for (final s in suppData) {
        final suppId = await txn.insert('supplements', {
          'name': s.$1,
          'description': s.$2,
          'timing': s.$3,
        });
        for (final foodName in s.$4) {
          final foodId = ids[foodName];
          if (foodId == null) continue;
          await txn.insert('supplement_alternatives', {
            'supplement_id': suppId,
            'food_id': foodId,
          });
        }
      }
    });
  }

  // ── Foods ─────────────────────────────────────────────────────────────────

  Future<List<Food>> allApprovedFoods() async {
    final db = await _ready();
    final rows = await db.query(
      'foods',
      where: "status = 'approved'",
      orderBy: 'name',
    );
    return rows.map(Food.fromMap).toList();
  }

  Future<List<Food>> foodsFor({
    required int userId,
    required bool isAdmin,
  }) async {
    final db = await _ready();
    final rows = isAdmin
        ? await db.query('foods',
            where: "status = 'approved'", orderBy: 'name')
        : await db.query(
            'foods',
            where:
                "(status = 'approved') OR (created_by = ? AND status = 'pending')",
            whereArgs: [userId],
            orderBy: 'name',
          );
    return rows.map(Food.fromMap).toList();
  }

  Future<List<Food>> myFoodRequests(int userId) async {
    final db = await _ready();
    final rows = await db.query(
      'foods',
      where: 'created_by = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return rows.map(Food.fromMap).toList();
  }

  Future<List<(Food, String)>> pendingFoods() async {
    final db = await _ready();
    final rows = await db.rawQuery('''
      SELECT f.*, COALESCE(u.first_name || ' ' || u.last_name, 'Unknown') AS submitter
      FROM foods f
      LEFT JOIN users u ON u.id = f.created_by
      WHERE f.status = 'pending'
      ORDER BY f.id DESC
    ''');
    return [
      for (final r in rows)
        (Food.fromMap(r), r['submitter'] as String),
    ];
  }

  Future<void> addFood({
    required Map<String, dynamic> payload,
    required int userId,
    required bool isAdmin,
  }) async {
    final db = await _ready();
    await db.insert('foods', {
      ...payload,
      'created_by': userId,
      'status': isAdmin ? 'approved' : 'pending',
    });
  }

  Future<void> updateFood(int id, Map<String, dynamic> p) async {
    final db = await _ready();
    await db.update(
      'foods',
      {
        'name': p['name'],
        'kcal_per_100g': p['kcal_per_100g'],
        'protein_g': p['protein_g'],
        'carbs_g': p['carbs_g'],
        'fat_g': p['fat_g'],
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setFoodStatus(int id, String status) async {
    final db = await _ready();
    await db.update(
      'foods',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteFood(int id) async {
    final db = await _ready();
    await db.delete('foods', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> cancelOwnPendingFood(int id, int userId) async {
    final db = await _ready();
    final n = await db.delete(
      'foods',
      where: "id = ? AND created_by = ? AND status = 'pending'",
      whereArgs: [id, userId],
    );
    return n > 0;
  }

  // ── Meal log ──────────────────────────────────────────────────────────────

  Future<List<MealLogEntry>> logsForDay(int userId, String date) async {
    final db = await _ready();
    final rows = await db.rawQuery('''
      SELECT ml.id, ml.food_id, f.name AS food_name, ml.grams,
             ml.meal_type, ml.logged_on,
             f.kcal_per_100g, f.protein_g, f.carbs_g, f.fat_g
      FROM meal_logs ml
      JOIN foods f ON f.id = ml.food_id
      WHERE ml.user_id = ? AND ml.logged_on = ?
      ORDER BY ml.meal_type, ml.id
    ''', [userId, date]);
    return rows.map(MealLogEntry.fromMap).toList();
  }

  Future<void> addLog({
    required int userId,
    required int foodId,
    required double grams,
    required String mealType,
    required String date,
  }) async {
    final db = await _ready();
    await db.insert('meal_logs', {
      'user_id': userId,
      'food_id': foodId,
      'grams': grams,
      'meal_type': mealType,
      'logged_on': date,
    });
  }

  Future<void> deleteLog(int id) async {
    final db = await _ready();
    await db.delete('meal_logs', where: 'id = ?', whereArgs: [id]);
  }

  // ── Supplements ───────────────────────────────────────────────────────────

  Future<List<Supplement>> supplements() async {
    final db = await _ready();
    final supps = await db.query('supplements', orderBy: 'name');
    final result = <Supplement>[];
    for (final s in supps) {
      final alts = await db.rawQuery('''
        SELECT f.name FROM supplement_alternatives sa
        JOIN foods f ON f.id = sa.food_id
        WHERE sa.supplement_id = ?
        ORDER BY f.name
      ''', [s['id']]);
      result.add(Supplement(
        id: s['id'] as int,
        name: s['name'] as String,
        description: s['description'] as String?,
        timing: s['timing'] as String?,
        alternatives: alts.map((r) => r['name'] as String).toList(),
      ));
    }
    return result;
  }
}
