import 'package:flutter/material.dart';

import 'ui/screens/activities_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/map_screen.dart';
import 'ui/screens/persons_screen.dart';
import 'ui/screens/place_groups_screen.dart';
import 'ui/screens/places_screen.dart';
import 'ui/screens/database_dump_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/timeline_screen.dart';
import 'ui/screens/tracking_log_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;

  final _placesRefresh = ValueNotifier<int>(0);
  final _timelineRefresh = ValueNotifier<int>(0);

  late final List<Widget> _screens = [
    const HomeScreen(),
    const MapScreen(),
    PlacesScreen(refreshNotifier: _placesRefresh),
    TimelineScreen(refreshNotifier: _timelineRefresh),
  ];

  @override
  void dispose() {
    _placesRefresh.dispose();
    _timelineRefresh.dispose();
    super.dispose();
  }

  void _onTabSelected(int i) {
    if (i == 2) _placesRefresh.value++;
    if (i == 3) _timelineRefresh.value++;
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chaos Tours',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      routes: {
        '/settings': (_) => const SettingsScreen(),
        '/place-groups': (_) => const PlaceGroupsScreen(),
        '/persons': (_) => const PersonsScreen(),
        '/activities': (_) => const ActivitiesScreen(),
        '/database-dump': (_) => const DatabaseDumpScreen(),
        '/tracking-log': (_) => const TrackingLogScreen(),
      },
      home: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Übersicht'),
            NavigationDestination(icon: Icon(Icons.map), label: 'Karte'),
            NavigationDestination(icon: Icon(Icons.place), label: 'Orte'),
            NavigationDestination(
              icon: Icon(Icons.timeline),
              label: 'Zeitachse',
            ),
          ],
        ),
      ),
    );
  }
}
