import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common/sqlite_api.dart';
import '../data/dataset_seeder.dart';
import 'schema.dart';
import 'schema_v2.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'fittrack.db';

  /// 2: store upgrade and coach scheduling.
  /// 3: wishlist, reviews, contact requests.
  /// 4: training tables (private programs, body measures, progress plans)
  ///    and the target weight of a progress plan.
  static const _dbVersion = 4;

  DatabaseFactory? _webFactory;
  Future<Database>? _opening;

  /// Initialize web database factory
  Future<void> initializeWeb(DatabaseFactory factory) async {
    _webFactory = factory;
  }

  /// Use this everywhere: `final db = await DatabaseHelper.instance.database;`
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
    if (kIsWeb && _webFactory != null) {
      return _webFactory!.openDatabase(
        _dbName,
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _run(db, schemaStatements);
    await _run(db, schemaV2Statements);
    await _run(db, wishlistTableStatements);
    await _run(db, reviewTableStatements);
    await _run(db, contactRequestTableStatements);
    await _seedAccounts(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _run(db, storeUpgradeV2Statements);
      await _run(db, coachSchedulingStatements);
      await _run(db, coachSchedulingBackfillStatements);
      await _run(db, coachingTriggerStatements);
    }
    if (oldVersion < 4) {
      await _run(db, schemaV2Statements);
      await _run(db, wishlistTableStatements);
      await _run(db, reviewTableStatements);
      await _run(db, contactRequestTableStatements);
      await _run(db,
          const ['ALTER TABLE progress_plans ADD COLUMN target_weight REAL']);
    }
  }

  /// Runs statements one by one. A statement that fails because the table or
  /// column already exists is logged and skipped.
  Future<void> _run(Database db, List<String> statements) async {
    for (final statement in statements) {
      try {
        await db.execute(statement);
      } catch (e) {
        debugPrint('DB statement skipped: $e');
      }
    }
  }

  /// Test accounts, created only when the database file is first created.
  Future<void> _seedAccounts(Database db) async {
    await db.insert('users', {
      'role': 'admin',
      'first_name': 'Admin',
      'last_name': 'FitTrack',
      'email': 'admin@fittrack.com',
      'password_hash': hashPassword('Admin123!'),
    });

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