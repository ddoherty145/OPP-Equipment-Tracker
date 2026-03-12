import 'package:equipment_tracker_app/models/analytics_summary.dart';
import 'package:equipment_tracker_app/models/usage_log.dart';

abstract class UsageLogRepository {
  Future<List<UsageLog>> getAll({
    int? equipmentId,
    DateTime? start,
    DateTime? end,
  });

  Future<int> create(UsageLog log);
  Future<void> update(UsageLog log);
  Future<void> delete(int id);
  Future<AnalyticsSummary> getSummary({
    int? equipmentId,
    DateTime? start,
    DateTime? end,
  });
  Future<Map<DateTime, double>> getHoursByDay({
    int? equipmentId,
    DateTime? start,
    DateTime? end,
  });
}
