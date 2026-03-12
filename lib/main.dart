import 'package:equipment_tracker_app/core/database/app_database.dart';
import 'package:equipment_tracker_app/core/repositories/sqlite_equipment_repository.dart';
import 'package:equipment_tracker_app/core/repositories/sqlite_usage_log_repository.dart';
import 'package:equipment_tracker_app/features/analytics/analytics_screen.dart';
import 'package:equipment_tracker_app/features/analytics/services/export_service.dart';
import 'package:equipment_tracker_app/features/app/tracker_controller.dart';
import 'package:equipment_tracker_app/features/equipment/equipment_screen.dart';
import 'package:equipment_tracker_app/features/imports/import_screen.dart';
import 'package:equipment_tracker_app/features/imports/services/backend_data_sync_service.dart';
import 'package:equipment_tracker_app/features/reports/reports_screen.dart';
import 'package:equipment_tracker_app/features/usage/usage_log_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // App can run without env file during local setup.
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final database = AppDatabase();
    final equipmentRepository = SqliteEquipmentRepository(database);
    final usageRepository = SqliteUsageLogRepository(database);
    final exportService = ExportService();
    final backendDataSyncService = BackendDataSyncService();

    return ChangeNotifierProvider(
      create: (_) => TrackerController(
        equipmentRepository: equipmentRepository,
        usageLogRepository: usageRepository,
        exportService: exportService,
        backendDataSyncService: backendDataSyncService,
        initialApiBaseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000',
      )..initialize(),
      child: MaterialApp(
        title: 'Equipment Tracker',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const TrackerHomePage(),
      ),
    );
  }
}

class TrackerHomePage extends StatelessWidget {
  const TrackerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerController>(
      builder: (context, controller, _) {
        final pages = [
          EquipmentScreen(controller: controller),
          UsageLogScreen(controller: controller),
          AnalyticsScreen(controller: controller),
          const ImportScreen(),
          const ReportsScreen(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Equipment Tracker'),
            actions: [
              IconButton(
                onPressed: controller.refreshAll,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: Stack(
            children: [
              IndexedStack(
                index: controller.selectedTab,
                children: pages,
              ),
              if (controller.isLoading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: controller.selectedTab,
            onDestinationSelected: controller.setSelectedTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.construction_outlined),
                selectedIcon: Icon(Icons.construction),
                label: 'Equipment',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: 'Logs',
              ),
              NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: 'Analytics',
              ),
              NavigationDestination(
                icon: Icon(Icons.upload_file_outlined),
                selectedIcon: Icon(Icons.upload_file),
                label: 'Import',
              ),
              NavigationDestination(
                icon: Icon(Icons.assessment_outlined),
                selectedIcon: Icon(Icons.assessment),
                label: 'Reports',
              ),
            ],
          ),
        );
      },
    );
  }
}
