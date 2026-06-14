import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/saved_place.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/settings_service.dart';

/// Fullscreen map that lets the user reposition a single [targetPlace] via
/// long-press.  All other places are shown for spatial context.
class PlaceRepositionScreen extends StatefulWidget {
  final SavedPlace targetPlace;

  const PlaceRepositionScreen({super.key, required this.targetPlace});

  @override
  State<PlaceRepositionScreen> createState() => _PlaceRepositionScreenState();
}

class _PlaceRepositionScreenState extends State<PlaceRepositionScreen> {
  List<SavedPlace> _places = [];
  final MapController _mapController = MapController();
  LatLng? _pendingPosition;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    // Centre the map on the target place once the controller is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(
        LatLng(widget.targetPlace.lat, widget.targetPlace.lng),
        16,
      );
    });
  }

  Future<void> _loadPlaces() async {
    final places = await DatabaseService.instance.loadAllPlaces();
    if (mounted) setState(() => _places = places);
  }

  void _onLongPress(TapPosition _, LatLng latlng) {
    setState(() => _pendingPosition = latlng);
  }

  Future<void> _confirm() async {
    final pos = _pendingPosition;
    if (pos == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Position übernehmen?'),
        content: Text(
          '„${widget.targetPlace.name}" wird auf\n'
          '${pos.latitude.toStringAsFixed(6)}, '
          '${pos.longitude.toStringAsFixed(6)}\n'
          'verschoben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final updated = widget.targetPlace.copyWith(
      lat: pos.latitude,
      lng: pos.longitude,
    );
    await DatabaseService.instance.updatePlace(updated);
    if (mounted) Navigator.pop(context, updated);
  }

  void _goToCurrentLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.targetPlace;
    final pending = _pendingPosition;

    return Scaffold(
      appBar: AppBar(
        title: Text('Position: ${target.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Aktuellen Standort anzeigen',
            onPressed: _goToCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(target.lat, target.lng),
              initialZoom: 16,
              onLongPress: _onLongPress,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'de.chaostours.chaos_tours_ai',
              ),
              // All saved places for context
              CircleLayer<SavedPlace>(
                circles: _places
                    .where(
                      (p) =>
                          p.placeType != PlaceType.forbidden ||
                          SettingsService.instance.showForbiddenPlaces,
                    )
                    .map(
                      (p) => CircleMarker<SavedPlace>(
                        hitValue: p,
                        point: LatLng(p.lat, p.lng),
                        radius: p.radius,
                        useRadiusInMeter: true,
                        color: p.uuid == target.uuid
                            ? p.placeType.fillColor.withValues(alpha: 0.65)
                            : p.placeType.fillColor,
                        borderColor: p.uuid == target.uuid
                            ? Colors.orange
                            : p.placeType.dotColor,
                        borderStrokeWidth: p.uuid == target.uuid ? 3 : 1.5,
                      ),
                    )
                    .toList(),
              ),
              // New position preview marker
              if (pending != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pending,
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Instruction banner at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  pending == null
                      ? 'Langen Tap auf die neue Position setzen'
                      : 'Neue Position: '
                            '${pending.latitude.toStringAsFixed(5)}, '
                            '${pending.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: pending == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: const Text('Position übernehmen'),
            ),
    );
  }
}
