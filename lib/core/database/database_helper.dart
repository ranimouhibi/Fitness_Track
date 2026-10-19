import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'schema.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'fittrack.db';
  static const _dbVersion = 1;

  Database? _db;

  /// Use this everywhere: `final db = await DatabaseHelper.instance.database;`
  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
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
      },
      // onUpgrade goes here when the schema changes (see note below).
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}