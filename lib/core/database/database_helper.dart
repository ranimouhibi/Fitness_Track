import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'schema.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'fittrack.db';
  static const _dbVersion = 1;

  // Default admin account created with the database. Change the password after your first sign-in.
  static const adminEmail = 'admin@fittrack.com';
  static const _adminPassword = 'Admin123!';

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
        await _seedAdmin(db);
      },
    );
  }

  Future<void> _seedAdmin(Database db) async {
    await db.insert('users', {
      'role': 'admin',
      'first_name': 'Admin',
      'last_name': 'FitTrack',
      'email': adminEmail,
      'password_hash': hashPassword(_adminPassword),
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}