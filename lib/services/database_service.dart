import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../models/todo.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  static const String tableTodos = 'todos';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('focusflow.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Use ApplicationDocumentsDirectory for reliable storage on Windows
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const boolType = 'INTEGER NOT NULL';

    if (oldVersion < 2) {
      await _createDB(db, newVersion);
    }

    // Migration for Todos (Version 3)
    if (oldVersion < 3) {
      // Check if table exists to be safe
      var tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableTodos'",
      );

      if (tableExists.isEmpty) {
        await db.execute('''
CREATE TABLE $tableTodos ( 
  id $idType, 
  title $textType,
  isCompleted $boolType,
  createdTime $textType
  )
''');
      }
    }

    // Migration for Todos Due Date (Version 4)
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE $tableTodos ADD COLUMN dueDate TEXT NULL',
        );
      } catch (e) {
        // Ignore if column exists
        debugPrint("Col dueDate likely exists or update failed: $e");
      }
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE sessions ( 
  id $idType, 
  category $textType,
  duration $integerType,
  timestamp $textType,
  apps_limited_count $integerType
  )
''');

    await db.execute('''
CREATE TABLE $tableTodos ( 
  id $idType, 
  title $textType,
  isCompleted $boolType,
  createdTime $textType,
  dueDate $textType
  )
''');
  }

  // Session CRUD

  Future<Session> create(Session session) async {
    final db = await instance.database;
    final id = await db.insert('sessions', session.toMap());
    return Session(
      id: id,
      category: session.category,
      duration: session.duration,
      timestamp: session.timestamp,
      appsLimitedCount: session.appsLimitedCount,
    );
  }

  Future<List<Session>> readAllSessions() async {
    final db = await instance.database;
    final orderBy = 'timestamp DESC';
    final result = await db.query('sessions', orderBy: orderBy);

    return result.map((json) => Session.fromMap(json)).toList();
  }

  Future<List<Session>> readSessionsForDate(DateTime date) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD

    final result = await db.query(
      'sessions',
      where: 'timestamp LIKE ?',
      whereArgs: ['$dateStr%'],
      orderBy: 'timestamp DESC',
    );

    return result.map((json) => Session.fromMap(json)).toList();
  }

  Future<List<Session>> readSessionsByCategory(String category) async {
    final db = await instance.database;
    final result = await db.query(
      'sessions',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'timestamp DESC',
    );

    return result.map((json) => Session.fromMap(json)).toList();
  }

  Future<Session?> getLastSession() async {
    final db = await instance.database;
    final result = await db.query(
      'sessions',
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return Session.fromMap(result.first);
    } else {
      return null;
    }
  }

  Future<void> clearAllSessions() async {
    final db = await instance.database;
    await db.delete('sessions');
  }

  // Todo CRUD

  Future<Todo> createTodo(Todo todo) async {
    final db = await instance.database;
    final id = await db.insert(tableTodos, todo.toMap());
    return todo.copyWith(id: id);
  }

  Future<Todo> readTodo(int id) async {
    final db = await instance.database;

    final maps = await db.query(
      tableTodos,
      columns: ['id', 'title', 'isCompleted', 'createdTime', 'dueDate'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Todo.fromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<Todo>> readAllTodos() async {
    final db = await instance.database;
    // Sort logic: Uncompleted first, then by Due Date (soonest first), then by Created Time
    // CASE WHEN isCompleted = 0 THEN 0 ELSE 1 END -> Puts uncompleted (0) before completed (1)
    // CASE WHEN dueDate IS NULL THEN 1 ELSE 0 END -> Puts tasks with due dates before those without
    // dueDate ASC -> Soonest due dates first
    // createdTime DESC -> Newest created first (fallback)
    final orderBy =
        'isCompleted ASC, CASE WHEN dueDate IS NULL THEN 1 ELSE 0 END, dueDate ASC, createdTime DESC';
    final result = await db.query(tableTodos, orderBy: orderBy);

    return result.map((json) => Todo.fromMap(json)).toList();
  }

  Future<List<Todo>> readTodosForDate(DateTime date) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().split('T')[0];

    final result = await db.query(
      tableTodos,
      where: 'dueDate LIKE ?',
      whereArgs: ['$dateStr%'],
      orderBy: 'isCompleted ASC, createdTime DESC',
    );

    return result.map((json) => Todo.fromMap(json)).toList();
  }

  Future<int> updateTodo(Todo todo) async {
    final db = await instance.database;

    return db.update(
      tableTodos,
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<int> deleteTodo(int id) async {
    final db = await instance.database;

    return await db.delete(tableTodos, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCompletedTodos() async {
    final db = await instance.database;
    return await db.delete(
      tableTodos,
      where: 'isCompleted = ?',
      whereArgs: [1],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
