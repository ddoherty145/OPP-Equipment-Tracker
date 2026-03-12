import 'package:equipment_tracker_app/features/app/tracker_controller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({
    super.key,
    required this.controller,
  });

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final currency = NumberFormat.simpleCurrency();

    return RefreshIndicator(
      onRefresh: controller.refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _buildFilterRow(context),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _KpiCard(
                title: 'Revenue',
                value: currency.format(summary.totalRevenue),
              ),
              _KpiCard(
                title: 'Profit',
                value: currency.format(summary.totalProfit),
              ),
              _KpiCard(
                title: 'Hours',
                value: summary.totalHours.toStringAsFixed(1),
              ),
              _KpiCard(
                title: 'Margin',
                value: '${summary.profitMargin.toStringAsFixed(1)}%',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 240,
                child: _buildHoursChart(context),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Snapshot',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Total equipment in range: ${summary.totalEquipment}'),
                  Text('Total usage logs in range: ${summary.totalLogs}'),
                  Text(
                    'Avg hours/day: ${summary.avgHoursPerDay.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: controller.usageLogs.isEmpty
                    ? null
                    : () => _exportExcel(context),
                icon: const Icon(Icons.table_view),
                label: const Text('Export Excel'),
              ),
              FilledButton.icon(
                onPressed: controller.usageLogs.isEmpty
                    ? null
                    : () => _exportPdf(context),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    return Wrap(
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
      ],
    );
  }

  Widget _buildHoursChart(BuildContext context) {
    if (controller.hoursByDay.isEmpty) {
      return const Center(child: Text('No data for current filters.'));
    }

    final entries = controller.hoursByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 36),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: entries.length > 6 ? 2 : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat.Md().format(entries[index].key),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: (entries.length - 1).toDouble(),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            spots: spots,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await controller.exportExcel();
      await controller.shareExport(file, text: 'Equipment analytics report (Excel)');
      messenger.showSnackBar(
        const SnackBar(content: Text('Excel report generated and ready to share.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Excel export failed: $e')),
      );
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await controller.exportPdf();
      await controller.shareExport(file, text: 'Equipment analytics report (PDF)');
      messenger.showSnackBar(
        const SnackBar(content: Text('PDF report generated and ready to share.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}
