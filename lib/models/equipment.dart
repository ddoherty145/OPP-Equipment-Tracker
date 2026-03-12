class Equipment {
  final int? id;
  final String equipmentId;
  final String name;
  final double totalHours;
  final double totalRevenue;
  final double totalProfit;

  const Equipment({
    this.id,
    required this.equipmentId,
    required this.name,
    this.totalHours = 0,
    this.totalRevenue = 0,
    this.totalProfit = 0,
  });

  double get profitMargin =>
      totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0;

  Equipment copyWith({
    int? id,
    String? equipmentId,
    String? name,
    double? totalHours,
    double? totalRevenue,
    double? totalProfit,
  }) {
    return Equipment(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      name: name ?? this.name,
      totalHours: totalHours ?? this.totalHours,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalProfit: totalProfit ?? this.totalProfit,
    );
  }

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] as int?,
      equipmentId: json['equipment_id'] as String,
      name: json['name'] as String,
      totalHours: ((json['total_hours'] ?? 0) as num).toDouble(),
      totalRevenue: ((json['total_revenue'] ?? 0) as num).toDouble(),
      totalProfit: ((json['total_profit'] ?? 0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipment_id': equipmentId,
      'name': name,
      'total_hours': totalHours,
      'total_revenue': totalRevenue,
      'total_profit': totalProfit,
    };
  }

  factory Equipment.fromDatabase(Map<String, dynamic> map) {
    return Equipment(
      id: map['id'] as int?,
      equipmentId: map['equipment_id'] as String,
      name: map['name'] as String,
      totalHours: ((map['total_hours'] ?? 0) as num).toDouble(),
      totalRevenue: ((map['total_revenue'] ?? 0) as num).toDouble(),
      totalProfit: ((map['total_profit'] ?? 0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'equipment_id': equipmentId,
      'name': name,
      'total_hours': totalHours,
      'total_revenue': totalRevenue,
      'total_profit': totalProfit,
    };
  }
}
