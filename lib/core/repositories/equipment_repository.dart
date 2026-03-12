import 'package:equipment_tracker_app/models/equipment.dart';

abstract class EquipmentRepository {
  Future<List<Equipment>> getAll();
  Future<int> create(Equipment equipment);
  Future<void> update(Equipment equipment);
  Future<void> delete(int id);
  Future<void> replaceAll(List<Equipment> equipment);
}
