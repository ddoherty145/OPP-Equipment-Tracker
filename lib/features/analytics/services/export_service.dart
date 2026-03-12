import 'dart:io';

import 'package:equipment_tracker_app/models/analytics_summary.dart';
import 'package:equipment_tracker_app/models/equipment.dart';
import 'package:equipment_tracker_app/models/usage_log.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class ExportService {
  Future<File> exportExcel({
    required AnalyticsSummary summary,
    required List<Equipment> equipment,
    required List<UsageLog> usageLogs,
  }) async {
    final excel = Excel.createExcel();
    final summarySheet = excel['Summary'];
    final logsSheet = excel['Usage Logs'];

    summarySheet.appendRow([
      TextCellValue('Metric'),
      TextCellValue('Value'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Equipment'),
      IntCellValue(summary.totalEquipment),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Logs'),
      IntCellValue(summary.totalLogs),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Hours'),
      DoubleCellValue(summary.totalHours),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Cost'),
      DoubleCellValue(summary.totalCost),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Revenue'),
      DoubleCellValue(summary.totalRevenue),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Profit'),
      DoubleCellValue(summary.totalProfit),
    ]);
    summarySheet.appendRow([
      TextCellValue('Profit Margin %'),
      DoubleCellValue(summary.profitMargin),
    ]);

    logsSheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Equipment'),
      TextCellValue('Hours'),
      TextCellValue('Cost'),
      TextCellValue('Revenue'),
      TextCellValue('Profit'),
    ]);

    final equipmentMap = {for (final e in equipment) e.id: e};
    final dateFormat = DateFormat.yMMMd();

    for (final log in usageLogs) {
      final equipmentName =
          equipmentMap[log.equipmentId]?.name ?? 'Equipment ${log.equipmentId}';
      logsSheet.appendRow([
        TextCellValue(dateFormat.format(log.date)),
        TextCellValue(equipmentName),
        DoubleCellValue(log.hours),
        DoubleCellValue(log.cost),
        DoubleCellValue(log.revenue),
        DoubleCellValue(log.profit),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Failed to encode Excel file.');
    }

    final file = await _createTempFile('.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportPdf({
    required AnalyticsSummary summary,
    required List<Equipment> equipment,
    required List<UsageLog> usageLogs,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat.yMMMd();
    final currency = NumberFormat.simpleCurrency();
    final equipmentMap = {for (final e in equipment) e.id: e};

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Equipment Tracker Report'),
          pw.Text('Total Equipment: ${summary.totalEquipment}'),
          pw.Text('Total Logs: ${summary.totalLogs}'),
          pw.Text('Total Hours: ${summary.totalHours.toStringAsFixed(2)}'),
          pw.Text('Total Cost: ${currency.format(summary.totalCost)}'),
          pw.Text('Total Revenue: ${currency.format(summary.totalRevenue)}'),
          pw.Text('Total Profit: ${currency.format(summary.totalProfit)}'),
          pw.Text('Profit Margin: ${summary.profitMargin.toStringAsFixed(2)}%'),
          pw.SizedBox(height: 12),
          pw.Text('Recent Usage Logs', style: const pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Equipment', 'Hours', 'Cost', 'Revenue', 'Profit'],
            data: usageLogs.take(25).map((log) {
              final equipmentName =
                  equipmentMap[log.equipmentId]?.name ?? 'Equipment ${log.equipmentId}';
              return [
                dateFormat.format(log.date),
                equipmentName,
                log.hours.toStringAsFixed(2),
                currency.format(log.cost),
                currency.format(log.revenue),
                currency.format(log.profit),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final file = await _createTempFile('.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Future<void> shareFile(File file, {String? text}) async {
    await Share.shareXFiles([XFile(file.path)], text: text);
  }

  Future<File> _createTempFile(String extension) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = p.join(dir.path, 'equipment_report_$timestamp$extension');
    return File(path);
  }
}
