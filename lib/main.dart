import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';
import 'services/foreground_service_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ForegroundServiceManager.init();
  runApp(
    WithForegroundTask(child: const App()),
  );
}
