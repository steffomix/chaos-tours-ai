import 'package:flutter/material.dart';

import '../../utils/permission_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Standortberechtigung'),
            subtitle: const Text('Standort im Vordergrund anfordern'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await PermissionHelper.instance
                  .requestLocationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted ? 'Standort gewährt' : 'Standort verweigert',
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_searching),
            title: const Text('Hintergrund-Standort'),
            subtitle: const Text('Standort im Hintergrund anfordern'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await PermissionHelper.instance
                  .requestBackgroundLocationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted
                          ? 'Hintergrund-Standort gewährt'
                          : 'Hintergrund-Standort verweigert',
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Benachrichtigungen'),
            subtitle: const Text('Benachrichtigungsberechtigung anfordern'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await PermissionHelper.instance
                  .requestNotificationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted
                          ? 'Benachrichtigungen gewährt'
                          : 'Benachrichtigungen verweigert',
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Kalender'),
            subtitle: const Text('Kalenderberechtigung anfordern'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await PermissionHelper.instance
                  .requestCalendarPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted ? 'Kalender gewährt' : 'Kalender verweigert',
                    ),
                  ),
                );
              }
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Chaos Tours'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }
}
