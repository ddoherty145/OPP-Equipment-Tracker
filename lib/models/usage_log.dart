class UsageLog {
  final int? id;
  final int equipmentId;
  final DateTime date;
  final double hours;
  final double cost;
  final double revenue;
  final double profit;

  const UsageLog({
    this.id,
    required this.equipmentId,
    required this.date,
    required this.hours,
    required this.cost,
    required this.revenue,
    required this.profit,
  });

  double get costPerHour => hours > 0 ? cost / hours : 0;

  double get revenuePerHour => hours > 0 ? revenue / hours : 0;

  UsageLog copyWith({
    int? id,
    int? equipmentId,
    DateTime? date,
    double? hours,
    double? cost,
    double? revenue,
    double? profit,
  }) {
    return UsageLog(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      date: date ?? this.date,
      hours: hours ?? this.hours,
      cost: cost ?? this.cost,
      revenue: revenue ?? this.revenue,
      profit: profit ?? this.profit,
    );
  }

  factory UsageLog.fromJson(Map<String, dynamic> json) {
    return UsageLog(
      id: json['id'] as int?,
      equipmentId: json['equipment_id'] as int,
      date: DateTime.parse(json['date'] as String),
      hours: ((json['hours'] ?? 0) as num).toDouble(),
      cost: ((json['cost'] ?? 0) as num).toDouble(),
      revenue: ((json['revenue'] ?? 0) as num).toDouble(),
      profit: ((json['profit'] ?? 0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipment_id': equipmentId,
      'date': date.toIso8601String(),
      'hours': hours,
      'cost': cost,
      'revenue': revenue,
      'profit': profit,
    };
  }

  factory UsageLog.fromDatabase(Map<String, dynamic> map) {
    return UsageLog(
      id: map['id'] as int?,
      equipmentId: map['equipment_id'] as int,
      date: DateTime.parse(map['date'] as String),
      hours: ((map['hours'] ?? 0) as num).toDouble(),
      cost: ((map['cost'] ?? 0) as num).toDouble(),
      revenue: ((map['revenue'] ?? 0) as num).toDouble(),
      profit: ((map['profit'] ?? 0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'equipment_id': equipmentId,
      'date': date.toIso8601String(),
      'hours': hours,
      'cost': cost,
      'revenue': revenue,
      'profit': profit,
    };
  }
}
