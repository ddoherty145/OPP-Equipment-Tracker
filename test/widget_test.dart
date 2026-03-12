import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:equipment_tracker_app/core/repositories/equipment_repository.dart';
import 'package:equipment_tracker_app/core/repositories/usage_log_repository.dart';
import 'package:equipment_tracker_app/features/analytics/services/export_service.dart';
import 'package:equipment_tracker_app/features/app/tracker_controller.dart';
import 'package:equipment_tracker_app/features/imports/services/backend_data_sync_service.dart';
import 'package:equipment_tracker_app/main.dart';
import 'package:equipment_tracker_app/models/analytics_summary.dart';
import 'package:equipment_tracker_app/models/equipment.dart';
import 'package:equipment_tracker_app/models/usage_log.dart';

void main() {
  testWidgets('Tracker app renders shell and navigation tabs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    expect(find.text('Equipment Tracker'), findsOneWidget);
    expect(find.text('Equipment'), findsWidgets);
    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('Switching tabs shows analytics export actions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    await tester.tap(find.text('Analytics').last);
    await tester.pumpAndSettle();

    expect(find.text('Export Excel'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });

  testWidgets('Switching to import tab shows import actions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    await tester.tap(find.text('Import').last);
    await tester.pumpAndSettle();

    expect(find.text('Import Data'), findsOneWidget);
    expect(find.text('Import PDF'), findsOneWidget);
    expect(find.text('Import Excel'), findsOneWidget);
  });

  testWidgets('Switching to reports tab shows report generator', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    await tester.tap(find.text('Reports').last);
    await tester.pumpAndSettle();

    expect(find.text('Preset Reports'), findsOneWidget);
    expect(find.text('Generate & Share'), findsOneWidget);
  });
}

Widget _buildTestApp() {
  final controller = TrackerController(
    equipmentRepository: _FakeEquipmentRepository(),
    usageLogRepository: _FakeUsageLogRepository(),
    exportService: ExportService(),
    backendDataSyncService: BackendDataSyncService(),
  );

  controller.equipment = [
    const Equipment(id: 1, equipmentId: 'EQ-1001', name: 'Excavator'),
  ];
  controller.usageLogs = [
    UsageLog(
      id: 1,
      equipmentId: 1,
      date: DateTime(2026, 3, 11),
      hours: 6,
      cost: 500,
      revenue: 900,
      profit: 400,
    ),
  ];
  controller.summary = const AnalyticsSummary(
    totalEquipment: 1,
    totalLogs: 1,
    totalHours: 6,
    totalCost: 500,
    totalRevenue: 900,
    totalProfit: 400,
    avgHoursPerDay: 6,
  );
  controller.hoursByDay = {DateTime(2026, 3, 11): 6};

  return ChangeNotifierProvider.value(
    value: controller,
    child: const MaterialApp(home: TrackerHomePage()),
  );
}

class _FakeEquipmentRepository implements EquipmentRepository {
  @override
  Future<int> create(Equipment equipment) async => 1;

  @override
  Future<void> delete(int id) async {}

  @override
  Future<List<Equipment>> getAll() async => const [];

  @override
  Future<void> update(Equipment equipment) async {}

  @override
  Future<void> replaceAll(List<Equipment> equipment) async {}
}

class _FakeUsageLogRepository implements UsageLogRepository {
  @override
  Future<int> create(UsageLog log) async => 1;

  @override
  Future<void> delete(int id) async {}

  @override
  Future<List<UsageLog>> getAll({
    int? equipmentId,
    DateTime? start,
    DateTime? end,
  }) async =>
      const [];

  @override
  Future<Map<DateTime, double>> getHoursByDay({
    int? equipmentId,
    DateTime? start,
    DateTime? end,
  }) async =>
      {};

  @override
  Future<AnalyticsSummary> getSummary({
    int? equipmentId,
    DateTime? start,
    DateTime? end,
  }) async =>
      const AnalyticsSummary.empty();

  @override
  Future<void> update(UsageLog log) async {}

  @override
  Future<void> replaceAll(List<UsageLog> logs) async {}
}
