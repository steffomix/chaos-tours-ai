import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';
import 'services/database_service.dart';
import 'services/foreground_service_handler.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init();
  final db = DatabaseService.instance;
  await db.cleanupOldTrackingPoints();
  await db.ensureDefaultGroups();
  await db.ensureDefaultAktivitaet();

  if (Platform.isAndroid || Platform.isIOS) {
    ForegroundServiceManager.init();
    FlutterForegroundTask.initCommunicationPort();
  }
  runApp(
    (Platform.isAndroid || Platform.isIOS)
        ? WithForegroundTask(child: const App())
        : const App(),
  );
}
