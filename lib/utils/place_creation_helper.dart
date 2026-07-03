import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart';

import '../models/saved_place.dart';
import '../services/database_service.dart';
import '../services/nominatim_service.dart';
import '../services/settings_service.dart';
import '../ui/screens/messages_screen.dart';

/// Handles a long-press on any map. Offers the user a choice between creating a
/// new place and viewing the P2P messages of the surrounding region. When the
/// messenger is disabled it falls back to the plain create-place flow.
Future<void> handleMapLongPress(
  BuildContext context,
  TapPosition tapPosition,
  LatLng latlng, {
  required Future<void> Function() onCreated,
}) async {
  if (!SettingsService.instance.messengerEnabled) {
    return createPlaceFromLongPress(
      context,
      tapPosition,
      latlng,
      onCreated: onCreated,
    );
  }
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_location_alt),
              title: Text(l10n.createPlace),
              onTap: () => Navigator.pop(ctx, 'create'),
            ),
            ListTile(
              leading: const Icon(Icons.forum),
              title: Text(l10n.showRegionMessages),
              onTap: () => Navigator.pop(ctx, 'region'),
            ),
          ],
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;
  if (action == 'create') {
    return createPlaceFromLongPress(
      context,
      tapPosition,
      latlng,
      onCreated: onCreated,
    );
  }
  // action == 'region'
  final radius = await _askRegionRadiusKm(context);
  if (radius == null || !context.mounted) return;
  SettingsService.instance.regionMessageRadiusKm = radius;
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => MessagesScreen.region(
        lat: latlng.latitude,
        lng: latlng.longitude,
        radiusKm: radius,
      ),
    ),
  );
}

/// Prompts for a search radius in kilometres, prefilled from settings.
Future<double?> _askRegionRadiusKm(BuildContext context) async {
  final ctrl = TextEditingController(
    text: SettingsService.instance.regionMessageRadiusKm.toString().replaceAll(
      RegExp(r'\.0$'),
      '',
    ),
  );
  return showDialog<double>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return AlertDialog(
        title: Text(l10n.regionRadiusTitle),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.radiusInKm,
            suffixText: 'km',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: Text(l10n.showAction),
          ),
        ],
      );
    },
  );
}

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
