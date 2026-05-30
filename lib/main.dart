import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';
import 'services/database_service.dart';
import 'services/foreground_service_handler.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init();
  await DatabaseService.instance.cleanupOldTrackingPoints();
  ForegroundServiceManager.init();
  runApp(WithForegroundTask(child: const App()));
}
