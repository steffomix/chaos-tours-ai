import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import 'ui/screens/activities_screen.dart';
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

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    const HomeScreen(),
    const MapScreen(),
    const PlacesScreen(),
    const TimelineScreen(),
    const PhotoAlbumScreen(),
  ];

  @override
  void dispose() {
    super.dispose();
  }

  void _onTabSelected(int i) {
    setState(() => _currentIndex = i);
  }

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
        '/database-dump': (_) => const DatabaseDumpScreen(),
        '/sync-sources': (_) => const SyncSourcesScreen(),
        '/telegram-connections': (_) => const TelegramConnectionsScreen(),
      },
      home: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home),
              label: AppLocalizations.of(context)!.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.map),
              label: AppLocalizations.of(context)!.navMap,
            ),
            NavigationDestination(
              icon: const Icon(Icons.place),
              label: AppLocalizations.of(context)!.navPlaces,
            ),
            NavigationDestination(
              icon: const Icon(Icons.timeline),
              label: AppLocalizations.of(context)!.navVisits,
            ),
            NavigationDestination(
              icon: const Icon(Icons.photo_library_outlined),
              label: AppLocalizations.of(context)!.navPhotos,
            ),
          ],
        ),
      ),
    );
  }
}
