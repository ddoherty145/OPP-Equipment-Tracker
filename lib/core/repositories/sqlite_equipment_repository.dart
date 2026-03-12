import 'package:equipment_tracker_app/core/database/app_database.dart';
import 'package:equipment_tracker_app/core/repositories/equipment_repository.dart';
import 'package:equipment_tracker_app/models/equipment.dart';

class SqliteEquipmentRepository implements EquipmentRepository {
  SqliteEquipmentRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<Equipment>> getAll() async {
    final db = await _database.database;
    final rows = await db.query('equipment', orderBy: 'name ASC');
    return rows.map(Equipment.fromDatabase).toList();
  }

  @override
  Future<int> create(Equipment equipment) async {
    final db = await _database.database;
    return db.insert('equipment', {
      'equipment_id': equipment.equipmentId,
      'name': equipment.name,
      'total_hours': equipment.totalHours,
      'total_revenue': equipment.totalRevenue,
      'total_profit': equipment.totalProfit,
    });
  }

  @override
  Future<void> update(Equipment equipment) async {
    if (equipment.id == null) {
      throw ArgumentError('Equipment id is required for update.');
    }

    final db = await _database.database;
    await db.update(
      'equipment',
      {
        'equipment_id': equipment.equipmentId,
        'name': equipment.name,
        'total_hours': equipment.totalHours,
        'total_revenue': equipment.totalRevenue,
        'total_profit': equipment.totalProfit,
      },
      where: 'id = ?',
      whereArgs: [equipment.id],
    );
  }

  @override
  Future<void> delete(int id) async {
    final db = await _database.database;
    await db.delete('equipment', where: 'id = ?', whereArgs: [id]);
  }
}
