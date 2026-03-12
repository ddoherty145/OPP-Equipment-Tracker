import 'package:equipment_tracker_app/features/app/tracker_controller.dart';
import 'package:equipment_tracker_app/features/app/sync_import_dialog.dart';
import 'package:equipment_tracker_app/models/equipment.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({
    super.key,
    required this.controller,
  });

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                'Equipment (${controller.equipment.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showEquipmentForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => showSyncImportedDataDialog(context, controller),
                icon: const Icon(Icons.sync),
                label: const Text('Sync Imports'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: controller.equipment.isEmpty
              ? const Center(child: Text('No equipment yet. Add your first item.'))
              : ListView.separated(
                  itemCount: controller.equipment.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = controller.equipment[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.equipmentId}  |  Hours: ${item.totalHours.toStringAsFixed(1)}  |  Profit: ${currency.format(item.totalProfit)}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _showEquipmentForm(context, existing: item);
                          }
                          if (value == 'delete' && item.id != null) {
                            await controller.deleteEquipment(item.id!);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showEquipmentForm(
    BuildContext context, {
    Equipment? existing,
  }) async {
    final codeController = TextEditingController(text: existing?.equipmentId ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final formKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Equipment' : 'Edit Equipment'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Equipment Code'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Equipment code is required';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (submitted != true) return;

    if (existing == null) {
      await controller.addEquipment(
        equipmentCode: codeController.text.trim(),
        name: nameController.text.trim(),
      );
    } else {
      await controller.updateEquipment(
        existing: existing,
        equipmentCode: codeController.text.trim(),
        name: nameController.text.trim(),
      );
    }
  }
}
