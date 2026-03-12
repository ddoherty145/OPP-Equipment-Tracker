import 'dart:io';

import 'package:equipment_tracker_app/core/database/app_database.dart';
import 'package:equipment_tracker_app/core/repositories/sqlite_equipment_repository.dart';
import 'package:equipment_tracker_app/core/repositories/sqlite_usage_log_repository.dart';
import 'package:equipment_tracker_app/models/equipment.dart';
import 'package:equipment_tracker_app/models/usage_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDatabase;
  late SqliteEquipmentRepository equipmentRepository;
  late SqliteUsageLogRepository usageLogRepository;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    dbPath = '${Directory.systemTemp.path}/equipment_tracker_test_${DateTime.now().microsecondsSinceEpoch}.db';
    appDatabase = AppDatabase(
      databasePath: dbPath,
      databaseFactory: databaseFactoryFfi,
    );
    equipmentRepository = SqliteEquipmentRepository(appDatabase);
    usageLogRepository = SqliteUsageLogRepository(appDatabase);
  });

  tearDown(() async {
    await databaseFactoryFfi.deleteDatabase(dbPath);
  });

  test('equipment repository supports create update delete', () async {
    final createdId = await equipmentRepository.create(
      const Equipment(equipmentId: 'EQ-9001', name: 'Test Crane'),
    );
    expect(createdId, greaterThan(0));

    final all = await equipmentRepository.getAll();
    final created = all.firstWhere((item) => item.id == createdId);
    expect(created.name, 'Test Crane');

    await equipmentRepository.update(
      created.copyWith(name: 'Updated Crane'),
    );
    final afterUpdate = await equipmentRepository.getAll();
    expect(
      afterUpdate.firstWhere((item) => item.id == createdId).name,
      'Updated Crane',
    );

    await equipmentRepository.delete(createdId);
    final afterDelete = await equipmentRepository.getAll();
    expect(afterDelete.where((item) => item.id == createdId), isEmpty);
  });

  test('usage repository returns summary and daily hours aggregates', () async {
    final equipmentId = await equipmentRepository.create(
      const Equipment(equipmentId: 'EQ-9100', name: 'Aggregate Unit'),
    );

    await usageLogRepository.create(
      UsageLog(
        equipmentId: equipmentId,
        date: DateTime(2026, 3, 1),
        hours: 5,
        cost: 300,
        revenue: 600,
        profit: 300,
      ),
    );
    await usageLogRepository.create(
      UsageLog(
        equipmentId: equipmentId,
        date: DateTime(2026, 3, 2),
        hours: 7,
        cost: 350,
        revenue: 800,
        profit: 450,
      ),
    );

    final summary = await usageLogRepository.getSummary(equipmentId: equipmentId);
    expect(summary.totalLogs, 2);
    expect(summary.totalHours, 12);
    expect(summary.totalCost, 650);
    expect(summary.totalRevenue, 1400);
    expect(summary.totalProfit, 750);

    final byDay = await usageLogRepository.getHoursByDay(equipmentId: equipmentId);
    expect(byDay.length, 2);
    expect(byDay[DateTime(2026, 3, 1)], 5);
    expect(byDay[DateTime(2026, 3, 2)], 7);
  });
}
