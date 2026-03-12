import 'package:equipment_tracker_app/features/app/tracker_controller.dart';
import 'package:equipment_tracker_app/features/app/sync_import_dialog.dart';
import 'package:equipment_tracker_app/models/usage_log.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UsageLogScreen extends StatelessWidget {
  const UsageLogScreen({
    super.key,
    required this.controller,
  });

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency();
    final dateFormat = DateFormat.yMMMd();
    final equipmentMap = {for (final e in controller.equipment) e.id: e};

    return Column(
      children: [
        _buildToolbar(context),
        const Divider(height: 1),
        Expanded(
          child: controller.usageLogs.isEmpty
              ? const Center(child: Text('No usage logs for the selected filters.'))
              : ListView.separated(
                  itemCount: controller.usageLogs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = controller.usageLogs[index];
                    final equipmentName =
                        equipmentMap[log.equipmentId]?.name ?? 'Equipment ${log.equipmentId}';
                    return ListTile(
                      title: Text(
                        '$equipmentName - ${dateFormat.format(log.date)}',
                      ),
                      subtitle: Text(
                        'Hours: ${log.hours.toStringAsFixed(1)} | Cost: ${currency.format(log.cost)} | Revenue: ${currency.format(log.revenue)} | Profit: ${currency.format(log.profit)}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _showUsageLogForm(context, existing: log);
                          }
                          if (value == 'delete' && log.id != null) {
                            await controller.deleteUsageLog(log.id!);
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

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int?>(
              initialValue: controller.selectedEquipmentId,
              decoration: const InputDecoration(
                labelText: 'Equipment Filter',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All')),
                ...controller.equipment
                    .where((item) => item.id != null)
                    .map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
              ],
              onChanged: (value) {
                controller.updateFilters(
                  equipmentId: value,
                  clearEquipment: value == null,
                );
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 1),
                initialDateRange: controller.selectedDateRange,
              );
              if (range != null) {
                await controller.updateFilters(dateRange: range);
              }
            },
            icon: const Icon(Icons.date_range),
            label: Text(
              controller.selectedDateRange == null
                  ? 'Date Range'
                  : '${DateFormat.MMMd().format(controller.selectedDateRange!.start)} - ${DateFormat.MMMd().format(controller.selectedDateRange!.end)}',
            ),
          ),
          TextButton(
            onPressed: () {
              controller.updateFilters(clearDateRange: true, clearEquipment: true);
            },
            child: const Text('Clear Filters'),
          ),
          FilledButton.icon(
            onPressed: controller.equipment.isEmpty
                ? null
                : () => _showUsageLogForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Log'),
          ),
          OutlinedButton.icon(
            onPressed: () => showSyncImportedDataDialog(context, controller),
            icon: const Icon(Icons.sync),
            label: const Text('Sync Imports'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUsageLogForm(
    BuildContext context, {
    UsageLog? existing,
  }) async {
    if (controller.equipment.isEmpty) return;

    int? selectedEquipment =
        existing?.equipmentId ?? controller.equipment.firstWhere((e) => e.id != null).id;
    DateTime selectedDate = existing?.date ?? DateTime.now();
    final hoursController = TextEditingController(
      text: existing?.hours.toStringAsFixed(1) ?? '',
    );
    final costController = TextEditingController(
      text: existing?.cost.toStringAsFixed(2) ?? '',
    );
    final revenueController = TextEditingController(
      text: existing?.revenue.toStringAsFixed(2) ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Usage Log' : 'Edit Usage Log'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selectedEquipment,
                        decoration:
                            const InputDecoration(labelText: 'Equipment'),
                        items: controller.equipment
                            .where((item) => item.id != null)
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedEquipment = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Equipment is required' : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Date: ${DateFormat.yMMMd().format(selectedDate)}'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 365 * 3),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                initialDate: selectedDate,
                              );
                              if (picked != null) {
                                setModalState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: hoursController,
                        decoration: const InputDecoration(labelText: 'Hours'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _validatePositiveNumber,
                      ),
                      TextFormField(
                        controller: costController,
                        decoration: const InputDecoration(labelText: 'Cost'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _validatePositiveNumber,
                      ),
                      TextFormField(
                        controller: revenueController,
                        decoration: const InputDecoration(labelText: 'Revenue'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _validatePositiveNumber,
                      ),
                    ],
                  ),
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
      },
    );

    if (submitted != true || selectedEquipment == null) return;
    final selectedEquipmentId = selectedEquipment!;

    final hours = double.parse(hoursController.text.trim());
    final cost = double.parse(costController.text.trim());
    final revenue = double.parse(revenueController.text.trim());

    if (existing == null) {
      await controller.addUsageLog(
        equipmentId: selectedEquipmentId,
        date: selectedDate,
        hours: hours,
        cost: cost,
        revenue: revenue,
      );
    } else {
      await controller.updateUsageLog(
        existing: existing,
        equipmentId: selectedEquipmentId,
        date: selectedDate,
        hours: hours,
        cost: cost,
        revenue: revenue,
      );
    }
  }

  String? _validatePositiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number';
    }
    if (parsed < 0) {
      return 'Must be non-negative';
    }
    return null;
  }
}
