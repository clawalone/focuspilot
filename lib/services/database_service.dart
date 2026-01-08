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

  final ValueNotifier<int> changeNotifier = ValueNotifier(0);

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
      version: 7,
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

    // Migration for Todos (Version 6)
    if (oldVersion < 6) {
      try {
        // Add columns if they don't exist
        await db.execute(
          'ALTER TABLE $tableTodos ADD COLUMN progress REAL DEFAULT 0.0',
        );
        await db.execute(
          'ALTER TABLE $tableTodos ADD COLUMN priority INTEGER DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE $tableTodos ADD COLUMN orderIndex INTEGER DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE $tableTodos ADD COLUMN category TEXT DEFAULT "Tasks"',
        );
      } catch (e) {
        debugPrint("Migration to version 6 failed: $e");
      }
    }

    // Migration for Todos (Version 7)
    if (oldVersion < 7) {
      try {
        await db.execute(
          'ALTER TABLE $tableTodos ADD COLUMN reminderTime TEXT',
        );
        await db.execute(
          'ALTER TABLE $tableTodos ADD COLUMN repeatType TEXT DEFAULT "none"',
        );
        await db.execute(
          'ALTER TABLE $tableTodos ADD COLUMN isProgressTracked INTEGER DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE $tableTodos ADD COLUMN progressType TEXT DEFAULT "percentage"',
        );
        await db.execute('ALTER TABLE $tableTodos ADD COLUMN startTime TEXT');
        await db.execute(
          'ALTER TABLE $tableTodos ADD COLUMN note TEXT DEFAULT ""',
        );
        await db.execute('ALTER TABLE $tableTodos ADD COLUMN subTasks TEXT');
      } catch (e) {
        debugPrint("Migration to version 7 failed: $e");
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
  apps_limited_count $integerType,
  work_duration $integerType,
  revise_duration $integerType,
  break_duration $integerType,
  sessions_count $integerType,
  is_revise_before $boolType,
  note TEXT
  )
''');

    await db.execute('''
CREATE TABLE $tableTodos ( 
  id $idType, 
  title $textType,
  isCompleted $boolType,
  createdTime $textType,
  dueDate $textType,
  progress REAL DEFAULT 0.0,
  priority $integerType DEFAULT 0,
  orderIndex $integerType DEFAULT 0,
  category $textType DEFAULT "Tasks",
  reminderTime TEXT,
  repeatType TEXT DEFAULT "none",
  isProgressTracked $boolType DEFAULT 0,
  progressType TEXT DEFAULT "percentage",
  startTime TEXT,
  note TEXT DEFAULT "",
  subTasks TEXT
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
      workDuration: session.workDuration,
      reviseDuration: session.reviseDuration,
      breakDuration: session.breakDuration,
      sessionsCount: session.sessionsCount,
      isReviseBefore: session.isReviseBefore,
      note: session.note,
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
    changeNotifier.value++;
    return todo.copyWith(id: id);
  }

  Future<Todo> readTodo(int id) async {
    final db = await instance.database;

    final maps = await db.query(tableTodos, where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Todo.fromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<Todo>> readAllTodos() async {
    final db = await instance.database;
    // Sort logic: Uncompleted first, then by orderIndex, then by priority (high first), then by Created Time
    final orderBy =
        'isCompleted ASC, orderIndex ASC, priority DESC, createdTime DESC';
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

    final result = await db.update(
      tableTodos,
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
    changeNotifier.value++;
    return result;
  }

  Future<void> updateTodosBatch(List<Todo> todos) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var todo in todos) {
      batch.update(
        tableTodos,
        todo.toMap(),
        where: 'id = ?',
        whereArgs: [todo.id],
      );
    }
    await batch.commit(noResult: true);
    changeNotifier.value++;
  }

  Future<int> deleteTodo(int id) async {
    final db = await instance.database;

    final result = await db.delete(
      tableTodos,
      where: 'id = ?',
      whereArgs: [id],
    );
    changeNotifier.value++;
    return result;
  }

  Future<int> deleteCompletedTodos() async {
    final db = await instance.database;
    final result = await db.delete(
      tableTodos,
      where: 'isCompleted = ?',
      whereArgs: [1],
    );
    changeNotifier.value++;
    return result;
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
