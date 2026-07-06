import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

import 'models/trusted_source.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'ui/screens/activities_screen.dart';
import 'ui/screens/aktivitaeten_screen.dart';
import 'ui/screens/database_explorer_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/map_screen.dart';
import 'ui/screens/persons_screen.dart';
import 'ui/screens/photo_album_screen.dart';
import 'ui/screens/place_groups_screen.dart';
import 'ui/screens/places_screen.dart';
import 'ui/screens/database_dump_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/timeline_screen.dart';
import 'ui/screens/sync_sources_screen.dart';
import 'ui/screens/telegram_connections_screen.dart';
import 'ui/screens/trusted_sources_screen.dart';
import 'ui/screens/shared_prefs_explorer_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chaos Tours',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFd6b050),
        useMaterial3: true,
      ),
      routes: {
        '/settings': (_) => const SettingsScreen(),
        '/place-groups': (_) => const PlaceGroupsScreen(),
        '/persons': (_) => const PersonsScreen(),
        '/activities': (_) => const ActivitiesScreen(),
        '/aktivitaeten': (_) => const AktivitaetenScreen(),
        '/database-dump': (_) => const DatabaseDumpScreen(),
        '/sync-sources': (_) => const SyncSourcesScreen(),
        '/telegram-connections': (_) => const TelegramConnectionsScreen(),
        '/trusted-sources': (_) => const TrustedSourcesScreen(),
        '/database-explorer': (_) => const DatabaseExplorerScreen(),
        '/shared-prefs-explorer': (_) => const SharedPrefsExplorerScreen(),
      },
      home: const _AppHome(),
    );
  }
}

class _AppHome extends StatefulWidget {
  const _AppHome();

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> {
  int _currentIndex = 0;
  TextEditingController? _deviceNameCtrl;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MapScreen(),
    const PlacesScreen(),
    const TimelineScreen(),
    const PhotoAlbumScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Show device name dialog on first startup (if no device ID has been set yet).
    if (SettingsService.instance.deviceId.isEmpty) {
      _deviceNameCtrl = TextEditingController();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showDeviceNameDialog(),
      );
    }
  }

  @override
  void dispose() {
    _deviceNameCtrl?.dispose();
    super.dispose();
  }

  Future<void> _showDeviceNameDialog() async {
    if (!mounted) return;
    final ctrl = _deviceNameCtrl!;
    final l10n = AppLocalizations.of(context)!;
    // Keep re-showing the dialog until the user provides a valid name.
    while (mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deviceNameDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.deviceNameDialogContent),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: l10n.deviceNameLabel,
                    hintText: l10n.deviceNameHint,
                    helperText: l10n.deviceNameLengthHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.save),
            ),
          ],
        ),
      );
      final name = ctrl.text.trim();
      if (name.length >= 3 && name.length <= 20) {
        const uuid = Uuid();
        final s = SettingsService.instance;
        s.deviceId = '$name@${uuid.v4()}';
        final db = DatabaseService.instance;
        final activity = (await db.loadAllAktivitaeten()).firstOrNull;
        if (activity != null) {
          await db.updateAktivitaet(activity.copyWith(deviceId: s.deviceId));
          await db.refreshTrustedSources();
          await db.upsertTrustedSource(
            TrustedSource(deviceId: s.deviceId, trusted: true),
          );
        }
        break;
      }
      // Name invalid — loop and show the dialog again.
    }
  }

  void _onTabSelected(int i) {
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map),
            label: l10n.navMap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.place),
            label: l10n.navPlaces,
          ),
          NavigationDestination(
            icon: const Icon(Icons.timeline),
            label: l10n.navVisits,
          ),
          NavigationDestination(
            icon: const Icon(Icons.photo_library_outlined),
            label: l10n.navPhotos,
          ),
        ],
      ),
    );
  }
}
