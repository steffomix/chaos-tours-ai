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

  // Ensure default place groups exist on first install.
  final s = SettingsService.instance;
  final newGroups = await DatabaseService.instance.ensureDefaultGroups();
  if (newGroups != null) {
    s.autoPlaceGroupUuid ??= newGroups.autoGroupUuid;
    s.defaultPlaceGroupUuid ??= newGroups.defaultGroupUuid;
  }

  // Ensure at least one Aktivitaet exists, then apply its settings.
  final defaultUuid = await DatabaseService.instance.ensureDefaultAktivitaet(
    gpsInterval: s.gpsIntervalSeconds,
    stayDetection: s.stayDetectionSeconds,
    autoPlace: s.autoPlaceSeconds,
    radius: s.defaultRadiusMeters,
    autoCreate: s.autoCreatePlaces,
    autoPlaceGroupUuid: s.autoPlaceGroupUuid,
    defaultPlaceGroupUuid: s.defaultPlaceGroupUuid,
  );
  final activeUuid = s.activeAktivitaetUuid ?? defaultUuid;
  final aktiv = await DatabaseService.instance.loadAktivitaet(activeUuid);
  if (aktiv != null) {
    s.applyAktivitaet(aktiv);
  } else {
    // Fallback: the stored uuid no longer exists – use/create the default.
    s.activeAktivitaetUuid = defaultUuid;
  }

  ForegroundServiceManager.init();
  FlutterForegroundTask.initCommunicationPort();
  runApp(WithForegroundTask(child: const App()));
}
