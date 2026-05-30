import 'package:flutter/material.dart';

import 'ui/screens/activities_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/map_screen.dart';
import 'ui/screens/persons_screen.dart';
import 'ui/screens/place_groups_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/timeline_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;

  static const _screens = [HomeScreen(), MapScreen(), TimelineScreen()];

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
      },
      home: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.list), label: 'Touren'),
            NavigationDestination(icon: Icon(Icons.map), label: 'Karte'),
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
