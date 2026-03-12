import 'dart:io';

import 'package:equipment_tracker_app/core/repositories/equipment_repository.dart';
import 'package:equipment_tracker_app/core/repositories/usage_log_repository.dart';
import 'package:equipment_tracker_app/features/analytics/services/export_service.dart';
import 'package:equipment_tracker_app/features/imports/services/backend_data_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:equipment_tracker_app/models/analytics_summary.dart';
import 'package:equipment_tracker_app/models/equipment.dart';
import 'package:equipment_tracker_app/models/usage_log.dart';
import 'package:flutter/material.dart';

class TrackerController extends ChangeNotifier {
  TrackerController({
    required EquipmentRepository equipmentRepository,
    required UsageLogRepository usageLogRepository,
    required ExportService exportService,
    required BackendDataSyncService backendDataSyncService,
    String initialApiBaseUrl = 'http://localhost:8000',
  })  : _equipmentRepository = equipmentRepository,
        _usageLogRepository = usageLogRepository,
        _exportService = exportService,
        _backendDataSyncService = backendDataSyncService,
        apiBaseUrl = initialApiBaseUrl;

  final EquipmentRepository _equipmentRepository;
  final UsageLogRepository _usageLogRepository;
  final ExportService _exportService;
  final BackendDataSyncService _backendDataSyncService;

  bool isLoading = false;
  String? error;
  int selectedTab = 0;
  String apiBaseUrl;
  DateTime? lastImportedSyncAt;
  int lastImportedEquipmentCount = 0;
  int lastImportedLogCount = 0;

  List<Equipment> equipment = [];
  List<UsageLog> usageLogs = [];
  AnalyticsSummary summary = const AnalyticsSummary.empty();
  Map<DateTime, double> hoursByDay = {};

  int? selectedEquipmentId;
  DateTimeRange? selectedDateRange;
  bool _useRemoteCache = false;
  List<Equipment> _remoteEquipmentCache = [];
  List<UsageLog> _remoteUsageLogCache = [];

  Future<void> initialize() async {
    await refreshAll();
  }

  void setApiBaseUrl(String url) {
    final next = url.trim();
    if (next.isEmpty) return;
    apiBaseUrl = next;
    notifyListeners();
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

  Future<void> syncImportedDataFromApi({String? baseUrlOverride}) async {
    await _runWithLoading(() async {
      final targetUrl = (baseUrlOverride ?? apiBaseUrl).trim();
      if (targetUrl.isEmpty) {
        throw ArgumentError('API URL is required for sync.');
      }
      apiBaseUrl = targetUrl;

      if (kIsWeb) {
        await _syncFromBackendToRemoteCache(targetUrl);
        return;
      }

      final snapshot = await _backendDataSyncService.fetchSnapshot(targetUrl);
      await _equipmentRepository.replaceAll(
        snapshot.equipment
            .map(
              (item) => Equipment(
                equipmentId: item.equipmentCode,
                name: item.name,
              ),
            )
            .toList(),
      );

      final localEquipment = await _equipmentRepository.getAll();
      final codeToLocalId = <String, int>{
        for (final item in localEquipment)
          if (item.id != null) item.equipmentId: item.id!,
      };

      final localLogs = snapshot.usageLogs
          .where((log) => codeToLocalId.containsKey(log.equipmentCode))
          .map(
            (log) => UsageLog(
              equipmentId: codeToLocalId[log.equipmentCode]!,
              date: log.date,
              hours: log.hours,
              cost: log.cost,
              revenue: log.revenue,
              profit: log.profit,
            ),
          )
          .toList();

      await _usageLogRepository.replaceAll(localLogs);

      lastImportedSyncAt = DateTime.now();
      lastImportedEquipmentCount = snapshot.equipment.length;
      lastImportedLogCount = localLogs.length;

      _useRemoteCache = false;
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
    if (_useRemoteCache) {
      equipment = _remoteEquipmentCache;
      usageLogs = _applyUsageFilters(_remoteUsageLogCache);
      summary = _computeSummary(usageLogs);
      hoursByDay = _computeHoursByDay(usageLogs);
      return;
    }

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

  List<UsageLog> _applyUsageFilters(List<UsageLog> source) {
    return source.where((log) {
      if (selectedEquipmentId != null && log.equipmentId != selectedEquipmentId) {
        return false;
      }
      if (selectedDateRange != null) {
        final start = DateTime(
          selectedDateRange!.start.year,
          selectedDateRange!.start.month,
          selectedDateRange!.start.day,
        );
        final end = DateTime(
          selectedDateRange!.end.year,
          selectedDateRange!.end.month,
          selectedDateRange!.end.day,
          23,
          59,
          59,
          999,
        );
        if (log.date.isBefore(start) || log.date.isAfter(end)) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  AnalyticsSummary _computeSummary(List<UsageLog> logs) {
    final totalHours = logs.fold<double>(0, (sum, log) => sum + log.hours);
    final totalCost = logs.fold<double>(0, (sum, log) => sum + log.cost);
    final totalRevenue = logs.fold<double>(0, (sum, log) => sum + log.revenue);
    final totalProfit = logs.fold<double>(0, (sum, log) => sum + log.profit);
    final equipmentCount = logs.map((log) => log.equipmentId).toSet().length;

    double avgHoursPerDay = 0;
    if (logs.isNotEmpty) {
      final sortedDates = logs.map((log) => DateTime(log.date.year, log.date.month, log.date.day)).toList()
        ..sort();
      final days = sortedDates.last.difference(sortedDates.first).inDays + 1;
      if (days > 0) {
        avgHoursPerDay = totalHours / days;
      }
    }

    return AnalyticsSummary(
      totalEquipment: equipmentCount,
      totalLogs: logs.length,
      totalHours: totalHours,
      totalCost: totalCost,
      totalRevenue: totalRevenue,
      totalProfit: totalProfit,
      avgHoursPerDay: avgHoursPerDay,
    );
  }

  Map<DateTime, double> _computeHoursByDay(List<UsageLog> logs) {
    final result = <DateTime, double>{};
    for (final log in logs) {
      final key = DateTime(log.date.year, log.date.month, log.date.day);
      result[key] = (result[key] ?? 0) + log.hours;
    }
    return result;
  }

  Future<void> _syncFromBackendToRemoteCache(String targetUrl) async {
    final snapshot = await _backendDataSyncService.fetchSnapshot(targetUrl);

    final codeToId = <String, int>{};
    final equipmentWithTotals = <Equipment>[];
    for (var index = 0; index < snapshot.equipment.length; index++) {
      final item = snapshot.equipment[index];
      final syntheticId = index + 1;
      codeToId[item.equipmentCode] = syntheticId;

      final relatedLogs = snapshot.usageLogs.where((log) => log.equipmentCode == item.equipmentCode);
      final totalHours = relatedLogs.fold<double>(0, (sum, log) => sum + log.hours);
      final totalRevenue = relatedLogs.fold<double>(0, (sum, log) => sum + log.revenue);
      final totalProfit = relatedLogs.fold<double>(0, (sum, log) => sum + log.profit);

      equipmentWithTotals.add(
        Equipment(
          id: syntheticId,
          equipmentId: item.equipmentCode,
          name: item.name,
          totalHours: totalHours,
          totalRevenue: totalRevenue,
          totalProfit: totalProfit,
        ),
      );
    }

    final mappedLogs = snapshot.usageLogs
        .where((log) => codeToId.containsKey(log.equipmentCode))
        .map(
          (log) => UsageLog(
            equipmentId: codeToId[log.equipmentCode]!,
            date: log.date,
            hours: log.hours,
            cost: log.cost,
            revenue: log.revenue,
            profit: log.profit,
          ),
        )
        .toList();

    _remoteEquipmentCache = equipmentWithTotals;
    _remoteUsageLogCache = mappedLogs;
    _useRemoteCache = true;

    lastImportedSyncAt = DateTime.now();
    lastImportedEquipmentCount = equipmentWithTotals.length;
    lastImportedLogCount = mappedLogs.length;

    await _loadData();
  }
}
