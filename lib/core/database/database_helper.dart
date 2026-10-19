import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'schema.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'fittrack.db';
  static const _dbVersion = 2;

  Database? _db;

  /// Use this everywhere: `final db = await DatabaseHelper.instance.database;`
  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  /// Same hash is used for sign-up and sign-in. Never store the plain password.
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
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
        for (final statement in coachSchedulingStatements) {
          await db.execute(statement);
        }
        for (final statement in coachingTriggerStatements) {
          await db.execute(statement);
        }
        await _seedAccounts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final statement in coachSchedulingStatements) {
            await db.execute(statement);
          }
          for (final statement in coachSchedulingBackfillStatements) {
            await db.execute(statement);
          }
          for (final statement in coachingTriggerStatements) {
            await db.execute(statement);
          }
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
    await _db?.close();
    _db = null;
  }
}