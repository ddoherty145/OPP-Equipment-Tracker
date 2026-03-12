import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String _dbName = 'equipment_tracker.db';
  static const int _dbVersion = 1;

  AppDatabase({
    String? databasePath,
    DatabaseFactory? databaseFactory,
  })  : _databasePath = databasePath,
        _databaseFactory = databaseFactory;

  final String? _databasePath;
  final DatabaseFactory? _databaseFactory;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final path = await _resolveDatabasePath();
    final factory = _databaseFactory ?? databaseFactory;

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE equipment (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            equipment_id TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            total_hours REAL NOT NULL DEFAULT 0,
            total_revenue REAL NOT NULL DEFAULT 0,
            total_profit REAL NOT NULL DEFAULT 0
          )
        ''');

          await db.execute('''
          CREATE TABLE usage_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            equipment_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            hours REAL NOT NULL DEFAULT 0,
            cost REAL NOT NULL DEFAULT 0,
            revenue REAL NOT NULL DEFAULT 0,
            profit REAL NOT NULL DEFAULT 0,
            FOREIGN KEY (equipment_id) REFERENCES equipment (id) ON DELETE CASCADE
          )
        ''');

          await db.execute(
            'CREATE INDEX idx_usage_logs_date ON usage_logs(date)',
          );
          await db.execute(
            'CREATE INDEX idx_usage_logs_equipment ON usage_logs(equipment_id)',
          );

          await _seedDemoData(db);
        },
      ),
    );
  }

  Future<String> _resolveDatabasePath() async {
    if (_databasePath != null) {
      return _databasePath!;
    }

    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, _dbName);
  }

  Future<void> _seedDemoData(Database db) async {
    final excavatorId = await db.insert('equipment', {
      'equipment_id': 'EQ-1001',
      'name': 'Excavator',
    });
    final loaderId = await db.insert('equipment', {
      'equipment_id': 'EQ-1002',
      'name': 'Wheel Loader',
    });

    final now = DateTime.now();
    final demoLogs = [
      {
        'equipment_id': excavatorId,
        'date': now.subtract(const Duration(days: 2)).toIso8601String(),
        'hours': 7.5,
        'cost': 980.0,
        'revenue': 1560.0,
        'profit': 580.0,
      },
      {
        'equipment_id': loaderId,
        'date': now.subtract(const Duration(days: 1)).toIso8601String(),
        'hours': 6.0,
        'cost': 700.0,
        'revenue': 1200.0,
        'profit': 500.0,
      },
      {
        'equipment_id': excavatorId,
        'date': now.toIso8601String(),
        'hours': 8.0,
        'cost': 1020.0,
        'revenue': 1700.0,
        'profit': 680.0,
      },
    ];

    for (final log in demoLogs) {
      await db.insert('usage_logs', log);
    }

    await db.execute('''
      UPDATE equipment
      SET
        total_hours = COALESCE((SELECT SUM(hours) FROM usage_logs u WHERE u.equipment_id = equipment.id), 0),
        total_revenue = COALESCE((SELECT SUM(revenue) FROM usage_logs u WHERE u.equipment_id = equipment.id), 0),
        total_profit = COALESCE((SELECT SUM(profit) FROM usage_logs u WHERE u.equipment_id = equipment.id), 0)
    ''');
  }
}
