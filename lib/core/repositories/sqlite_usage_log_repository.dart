import 'package:equipment_tracker_app/core/database/app_database.dart';
import 'package:equipment_tracker_app/core/repositories/usage_log_repository.dart';
import 'package:equipment_tracker_app/models/analytics_summary.dart';
import 'package:equipment_tracker_app/models/usage_log.dart';

class SqliteUsageLogRepository implements UsageLogRepository {
  SqliteUsageLogRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<UsageLog>> getAll({
    int? equipmentId,
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await _database.database;
    final where = <String>[];
    final whereArgs = <Object>[];

    if (equipmentId != null) {
      where.add('equipment_id = ?');
      whereArgs.add(equipmentId);
    }
    if (start != null) {
      where.add('date >= ?');
      whereArgs.add(start.toIso8601String());
    }
    if (end != null) {
      final inclusiveEnd = end.add(const Duration(days: 1));
      where.add('date < ?');
      whereArgs.add(inclusiveEnd.toIso8601String());
    }

    final rows = await db.query(
      'usage_logs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );

    return rows.map(UsageLog.fromDatabase).toList();
  }

  @override
  Future<int> create(UsageLog log) async {
    final db = await _database.database;
    final id = await db.insert('usage_logs', {
      'equipment_id': log.equipmentId,
      'date': log.date.toIso8601String(),
      'hours': log.hours,
      'cost': log.cost,
      'revenue': log.revenue,
      'profit': log.profit,
    });
    await _refreshEquipmentTotals(log.equipmentId);
    return id;
  }

  @override
  Future<void> update(UsageLog log) async {
    if (log.id == null) {
      throw ArgumentError('Usage log id is required for update.');
    }

    final db = await _database.database;
    final existing = await db.query(
      'usage_logs',
      columns: ['equipment_id'],
      where: 'id = ?',
      whereArgs: [log.id],
      limit: 1,
    );

    await db.update(
      'usage_logs',
      {
        'equipment_id': log.equipmentId,
        'date': log.date.toIso8601String(),
        'hours': log.hours,
        'cost': log.cost,
        'revenue': log.revenue,
        'profit': log.profit,
      },
      where: 'id = ?',
      whereArgs: [log.id],
    );

    await _refreshEquipmentTotals(log.equipmentId);
    if (existing.isNotEmpty) {
      final oldEquipmentId = existing.first['equipment_id'] as int;
      if (oldEquipmentId != log.equipmentId) {
        await _refreshEquipmentTotals(oldEquipmentId);
      }
    }
  }

  @override
  Future<void> delete(int id) async {
    final db = await _database.database;
    final existing = await db.query(
      'usage_logs',
      columns: ['equipment_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    await db.delete('usage_logs', where: 'id = ?', whereArgs: [id]);

    if (existing.isNotEmpty) {
      await _refreshEquipmentTotals(existing.first['equipment_id'] as int);
    }
  }

  @override
  Future<void> replaceAll(List<UsageLog> logs) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('usage_logs');
      for (final log in logs) {
        await txn.insert('usage_logs', {
          'equipment_id': log.equipmentId,
          'date': log.date.toIso8601String(),
          'hours': log.hours,
          'cost': log.cost,
          'revenue': log.revenue,
          'profit': log.profit,
        });
      }
    });
    await _refreshAllEquipmentTotals();
  }

  @override
  Future<AnalyticsSummary> getSummary({
    int? equipmentId,
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await _database.database;
    final where = <String>[];
    final whereArgs = <Object>[];

    if (equipmentId != null) {
      where.add('equipment_id = ?');
      whereArgs.add(equipmentId);
    }
    if (start != null) {
      where.add('date >= ?');
      whereArgs.add(start.toIso8601String());
    }
    if (end != null) {
      final inclusiveEnd = end.add(const Duration(days: 1));
      where.add('date < ?');
      whereArgs.add(inclusiveEnd.toIso8601String());
    }

    final usageWhere = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final summaryRows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total_logs,
        COALESCE(SUM(hours), 0) AS total_hours,
        COALESCE(SUM(cost), 0) AS total_cost,
        COALESCE(SUM(revenue), 0) AS total_revenue,
        COALESCE(SUM(profit), 0) AS total_profit,
        COUNT(DISTINCT equipment_id) AS total_equipment
      FROM usage_logs
      $usageWhere
    ''', whereArgs);

    final firstDateRows = await db.rawQuery('''
      SELECT MIN(date) AS first_date, MAX(date) AS last_date
      FROM usage_logs
      $usageWhere
    ''', whereArgs);

    final summaryMap = summaryRows.first;
    final dateMap = firstDateRows.first;

    final firstDateRaw = dateMap['first_date'] as String?;
    final lastDateRaw = dateMap['last_date'] as String?;

    double avgHoursPerDay = 0;
    if (firstDateRaw != null && lastDateRaw != null) {
      final firstDate = DateTime.parse(firstDateRaw);
      final lastDate = DateTime.parse(lastDateRaw);
      final days = lastDate.difference(firstDate).inDays + 1;
      final totalHours = ((summaryMap['total_hours'] ?? 0) as num).toDouble();
      if (days > 0) {
        avgHoursPerDay = totalHours / days;
      }
    }

    return AnalyticsSummary(
      totalEquipment: (summaryMap['total_equipment'] as int?) ?? 0,
      totalLogs: (summaryMap['total_logs'] as int?) ?? 0,
      totalHours: ((summaryMap['total_hours'] ?? 0) as num).toDouble(),
      totalCost: ((summaryMap['total_cost'] ?? 0) as num).toDouble(),
      totalRevenue: ((summaryMap['total_revenue'] ?? 0) as num).toDouble(),
      totalProfit: ((summaryMap['total_profit'] ?? 0) as num).toDouble(),
      avgHoursPerDay: avgHoursPerDay,
    );
  }

  @override
  Future<Map<DateTime, double>> getHoursByDay({
    int? equipmentId,
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await _database.database;
    final where = <String>[];
    final whereArgs = <Object>[];

    if (equipmentId != null) {
      where.add('equipment_id = ?');
      whereArgs.add(equipmentId);
    }
    if (start != null) {
      where.add('date >= ?');
      whereArgs.add(start.toIso8601String());
    }
    if (end != null) {
      final inclusiveEnd = end.add(const Duration(days: 1));
      where.add('date < ?');
      whereArgs.add(inclusiveEnd.toIso8601String());
    }

    final usageWhere = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT SUBSTR(date, 1, 10) AS day_key, COALESCE(SUM(hours), 0) AS total_hours
      FROM usage_logs
      $usageWhere
      GROUP BY day_key
      ORDER BY day_key ASC
    ''', whereArgs);

    final result = <DateTime, double>{};
    for (final row in rows) {
      final day = DateTime.parse(row['day_key'] as String);
      final hours = ((row['total_hours'] ?? 0) as num).toDouble();
      result[day] = hours;
    }

    return result;
  }

  Future<void> _refreshEquipmentTotals(int equipmentId) async {
    final db = await _database.database;
    await db.rawUpdate('''
      UPDATE equipment
      SET
        total_hours = COALESCE((SELECT SUM(hours) FROM usage_logs WHERE equipment_id = ?), 0),
        total_revenue = COALESCE((SELECT SUM(revenue) FROM usage_logs WHERE equipment_id = ?), 0),
        total_profit = COALESCE((SELECT SUM(profit) FROM usage_logs WHERE equipment_id = ?), 0)
      WHERE id = ?
    ''', [equipmentId, equipmentId, equipmentId, equipmentId]);
  }

  Future<void> _refreshAllEquipmentTotals() async {
    final db = await _database.database;
    await db.execute('''
      UPDATE equipment
      SET
        total_hours = COALESCE((SELECT SUM(hours) FROM usage_logs u WHERE u.equipment_id = equipment.id), 0),
        total_revenue = COALESCE((SELECT SUM(revenue) FROM usage_logs u WHERE u.equipment_id = equipment.id), 0),
        total_profit = COALESCE((SELECT SUM(profit) FROM usage_logs u WHERE u.equipment_id = equipment.id), 0)
    ''');
  }
}
