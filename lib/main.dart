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

  // Ensure at least one Aktivitaet exists, then apply its settings.
  final s = SettingsService.instance;
  final defaultId = await DatabaseService.instance.ensureDefaultAktivitaet(
    gpsInterval: s.gpsIntervalSeconds,
    stayDetection: s.stayDetectionSeconds,
    autoPlace: s.autoPlaceSeconds,
    radius: s.defaultRadiusMeters,
    autoCreate: s.autoCreatePlaces,
    autoPlaceGroupId: s.autoPlaceGroupId,
  );
  final activeId = s.activeAktivitaetId ?? defaultId;
  final aktiv = await DatabaseService.instance.loadAktivitaet(activeId);
  if (aktiv != null) {
    s.applyAktivitaet(aktiv);
  } else {
    // Fallback: the stored id no longer exists – use/create the default.
    s.activeAktivitaetId = defaultId;
  }

  ForegroundServiceManager.init();
  runApp(WithForegroundTask(child: const App()));
}
