import 'package:equipment_tracker_app/models/analytics_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analytics summary derived metrics are calculated correctly', () {
    const summary = AnalyticsSummary(
      totalEquipment: 4,
      totalLogs: 10,
      totalHours: 80,
      totalCost: 4000,
      totalRevenue: 6000,
      totalProfit: 2000,
      avgHoursPerDay: 8,
    );

    expect(summary.profitMargin, closeTo(33.333, 0.01));
    expect(summary.avgRevenuePerEquipment, 1500);
    expect(summary.avgProfitPerEquipment, 500);
  });
}
