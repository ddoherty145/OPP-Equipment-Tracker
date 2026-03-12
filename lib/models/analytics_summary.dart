class AnalyticsSummary {
  final int totalEquipment;
  final int totalLogs;
  final double totalHours;
  final double totalCost;
  final double totalRevenue;
  final double totalProfit;
  final double avgHoursPerDay;

  const AnalyticsSummary({
    required this.totalEquipment,
    required this.totalLogs,
    required this.totalHours,
    required this.totalCost,
    required this.totalRevenue,
    required this.totalProfit,
    required this.avgHoursPerDay,
  });

  double get profitMargin =>
      totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0;

  double get avgRevenuePerEquipment =>
      totalEquipment > 0 ? totalRevenue / totalEquipment : 0;

  double get avgProfitPerEquipment =>
      totalEquipment > 0 ? totalProfit / totalEquipment : 0;

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalEquipment: json['total_equipment'] as int? ?? 0,
      totalLogs: json['total_logs'] as int? ?? 0,
      totalHours: ((json['total_hours'] ?? 0) as num).toDouble(),
      totalCost: ((json['total_cost'] ?? 0) as num).toDouble(),
      totalRevenue: ((json['total_revenue'] ?? 0) as num).toDouble(),
      totalProfit: ((json['total_profit'] ?? 0) as num).toDouble(),
      avgHoursPerDay: ((json['avg_hours_per_day'] ?? 0) as num).toDouble(),
    );
  }

  const AnalyticsSummary.empty()
      : totalEquipment = 0,
        totalLogs = 0,
        totalHours = 0,
        totalCost = 0,
        totalRevenue = 0,
        totalProfit = 0,
        avgHoursPerDay = 0;
}
