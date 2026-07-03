import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart';

import '../models/saved_place.dart';
import '../services/database_service.dart';
import '../services/nominatim_service.dart';
import '../services/settings_service.dart';

/// Shows a dialog to create a new [SavedPlace] at [latlng] via long-press.
/// Calls [onCreated] after the place has been inserted into the database.
Future<void> createPlaceFromLongPress(
  BuildContext context,
  TapPosition _,
  LatLng latlng, {
  required Future<void> Function() onCreated,
}) async {
  // Optionally pre-fill the name with the reverse-geocoded address so the user
  // can edit it before saving.
  String prefillName = '';
  if (SettingsService.instance.addressOnManualCreate) {
    final address = await NominatimService.instance.reverseGeocode(
      latlng.latitude,
      latlng.longitude,
    );
    if (address != null) prefillName = address;
  }
  if (!context.mounted) return;
  final nameController = TextEditingController(text: prefillName);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final ctxL10n = AppLocalizations.of(ctx)!;
      return AlertDialog(
        title: Text(ctxL10n.newPlaceTitle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: ctxL10n.name),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctxL10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctxL10n.save),
          ),
        ],
      );
    },
  );
  if (confirmed != true) return;
  final name = nameController.text.trim();
  if (name.isEmpty) return;

  final newPlace = SavedPlace(
    name: name,
    lat: latlng.latitude,
    lng: latlng.longitude,
    groupUuid: SettingsService.instance.defaultPlaceGroupUuid,
  );
  await DatabaseService.instance.insertPlace(newPlace);
  await onCreated();
}
