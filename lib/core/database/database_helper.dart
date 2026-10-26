import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../data/dataset_seeder.dart';
import 'schema.dart';
import 'schema_v2.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'fittrack.db';

  /// Version 2 adds private programs, body measures and progress plans.
  /// Version 3 adds the target weight of a progress plan.
  static const _dbVersion = 3;

  Future<Database>? _opening;

  /// Use this everywhere: `final db = await DatabaseHelper.instance.database;`
  /// The first call opens the database, creates or upgrades the tables and loads the data set.
  Future<Database> get database => _opening ??= _openAndSeed();

  /// Same hash is used for sign-up and sign-in. Never store the plain password.
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<Database> _openAndSeed() async {
    final db = await _open();
    await DatasetSeeder.run(db);
    return db;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // SQLite ignores foreign keys unless this is switched on.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        for (final statement in schemaStatements) {
          await db.execute(statement);
        }
        for (final statement in schemaV2Statements) {
          await db.execute(statement);
        }
        await _seedAccounts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final statement in schemaV2Statements) {
            await db.execute(statement);
          }
        }
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE progress_plans ADD COLUMN target_weight REAL');
        }
      },
    );
  }

  /// Test accounts, created only when the database file is first created.
  Future<void> _seedAccounts(Database db) async {
    // Admin
    await db.insert('users', {
      'role': 'admin',
      'first_name': 'Admin',
      'last_name': 'FitTrack',
      'email': 'admin@fittrack.com',
      'password_hash': hashPassword('Admin123!'),
    });

    // User: ghaith hajji
    await db.insert('users', {
      'role': 'user',
      'first_name': 'Ghaith',
      'last_name': 'Hajji',
      'email': 'hajjighaith7@gmail.com',
      'phone': '27654690',
      'password_hash': hashPassword('7399ghaith'),
      'birth_date': '2003-10-03',
      'height_cm': 188,
      'weight_kg': 98,
    });

    // Coach: khalil ayari (approved, certificate skipped)
    await db.insert('users', {
      'role': 'coach',
      'first_name': 'Khalil',
      'last_name': 'Ayari',
      'email': 'cbum@fittrack.com',
      'password_hash': hashPassword('coach123'),
      'birth_date': '2000-06-12',
      'height_cm': 190,
      'weight_kg': 88,
      'coach_status': 'approved',
    });
  }

  Future<void> close() async {
    final db = _opening == null ? null : await _opening;
    await db?.close();
    _opening = null;
  }
}