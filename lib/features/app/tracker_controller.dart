import 'dart:io';

import 'package:equipment_tracker_app/core/repositories/equipment_repository.dart';
import 'package:equipment_tracker_app/core/repositories/usage_log_repository.dart';
import 'package:equipment_tracker_app/features/analytics/services/export_service.dart';
import 'package:equipment_tracker_app/models/analytics_summary.dart';
import 'package:equipment_tracker_app/models/equipment.dart';
import 'package:equipment_tracker_app/models/usage_log.dart';
import 'package:flutter/material.dart';

class TrackerController extends ChangeNotifier {
  TrackerController({
    required EquipmentRepository equipmentRepository,
    required UsageLogRepository usageLogRepository,
    required ExportService exportService,
  })  : _equipmentRepository = equipmentRepository,
        _usageLogRepository = usageLogRepository,
        _exportService = exportService;

  final EquipmentRepository _equipmentRepository;
  final UsageLogRepository _usageLogRepository;
  final ExportService _exportService;

  bool isLoading = false;
  String? error;
  int selectedTab = 0;

  List<Equipment> equipment = [];
  List<UsageLog> usageLogs = [];
  AnalyticsSummary summary = const AnalyticsSummary.empty();
  Map<DateTime, double> hoursByDay = {};

  int? selectedEquipmentId;
  DateTimeRange? selectedDateRange;

  Future<void> initialize() async {
    await refreshAll();
  }

  void setSelectedTab(int index) {
    selectedTab = index;
    notifyListeners();
  }

  Future<void> updateFilters({
    int? equipmentId,
    DateTimeRange? dateRange,
    bool clearEquipment = false,
    bool clearDateRange = false,
  }) async {
    if (clearEquipment) {
      selectedEquipmentId = null;
    } else if (equipmentId != null) {
      selectedEquipmentId = equipmentId;
    }

    if (clearDateRange) {
      selectedDateRange = null;
    } else if (dateRange != null) {
      selectedDateRange = dateRange;
    }

    await refreshAll();
  }

  Future<void> refreshAll() async {
    await _runWithLoading(() async {
      await _loadData();
    });
  }

  Future<void> addEquipment({
    required String equipmentCode,
    required String name,
  }) async {
    await _runWithLoading(() async {
      await _equipmentRepository.create(
        Equipment(equipmentId: equipmentCode, name: name),
      );
      await _loadData();
    });
  }

  Future<void> updateEquipment({
    required Equipment existing,
    required String equipmentCode,
    required String name,
  }) async {
    await _runWithLoading(() async {
      await _equipmentRepository.update(
        existing.copyWith(equipmentId: equipmentCode, name: name),
      );
      await _loadData();
    });
  }

  Future<void> deleteEquipment(int id) async {
    await _runWithLoading(() async {
      await _equipmentRepository.delete(id);
      await _loadData();
    });
  }

  Future<void> addUsageLog({
    required int equipmentId,
    required DateTime date,
    required double hours,
    required double cost,
    required double revenue,
  }) async {
    await _runWithLoading(() async {
      final profit = revenue - cost;
      await _usageLogRepository.create(
        UsageLog(
          equipmentId: equipmentId,
          date: date,
          hours: hours,
          cost: cost,
          revenue: revenue,
          profit: profit,
        ),
      );
      await _loadData();
    });
  }

  Future<void> updateUsageLog({
    required UsageLog existing,
    required int equipmentId,
    required DateTime date,
    required double hours,
    required double cost,
    required double revenue,
  }) async {
    await _runWithLoading(() async {
      final profit = revenue - cost;
      await _usageLogRepository.update(
        existing.copyWith(
          equipmentId: equipmentId,
          date: date,
          hours: hours,
          cost: cost,
          revenue: revenue,
          profit: profit,
        ),
      );
      await _loadData();
    });
  }

  Future<void> deleteUsageLog(int id) async {
    await _runWithLoading(() async {
      await _usageLogRepository.delete(id);
      await _loadData();
    });
  }

  Future<File> exportExcel() {
    return _exportService.exportExcel(
      summary: summary,
      equipment: equipment,
      usageLogs: usageLogs,
    );
  }

  Future<File> exportPdf() {
    return _exportService.exportPdf(
      summary: summary,
      equipment: equipment,
      usageLogs: usageLogs,
    );
  }

  Future<void> shareExport(File file, {String? text}) {
    return _exportService.shareFile(file, text: text);
  }

  Future<void> _runWithLoading(Future<void> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadData() async {
    equipment = await _equipmentRepository.getAll();
    usageLogs = await _usageLogRepository.getAll(
      equipmentId: selectedEquipmentId,
      start: selectedDateRange?.start,
      end: selectedDateRange?.end,
    );
    summary = await _usageLogRepository.getSummary(
      equipmentId: selectedEquipmentId,
      start: selectedDateRange?.start,
      end: selectedDateRange?.end,
    );
    hoursByDay = await _usageLogRepository.getHoursByDay(
      equipmentId: selectedEquipmentId,
      start: selectedDateRange?.start,
      end: selectedDateRange?.end,
    );
  }
}
