import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/saved_place.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../widgets/place_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<SavedPlace> _places = [];
  final MapController _mapController = MapController();

  // Hit-notifier used by flutter_map for circle tap detection
  final LayerHitNotifier<SavedPlace> _hitNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    final places = await DatabaseService.instance.loadAllPlaces();
    if (mounted) setState(() => _places = places);
  }

  void _onCircleTap() {
    final hit = _hitNotifier.value;
    if (hit == null || hit.hitValues.isEmpty) return;
    final place = hit.hitValues.first;
    _showPlaceSheet(place);
  }

  Future<void> _onLongPress(TapPosition _, LatLng latlng) async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neuer Ort'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final newPlace = SavedPlace(
      name: name,
      lat: latlng.latitude,
      lng: latlng.longitude,
    );
    await DatabaseService.instance.insertPlace(newPlace);
    await _loadPlaces();
  }

  void _showPlaceSheet(SavedPlace place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PlaceBottomSheet(
        place: place,
        onUpdated: _loadPlaces,
        onDeleted: _loadPlaces,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chaos Tours – Karte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlaces,
            tooltip: 'Orte neu laden',
          ),
        ],
      ),
      body: GestureDetector(
        onTapUp: (_) => _onCircleTap(),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(48.1351, 11.5820), // Munich default
            initialZoom: 13,
            onLongPress: _onLongPress,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.chaostours.chaos_tours_ai',
            ),
            CircleLayer<SavedPlace>(
              hitNotifier: _hitNotifier,
              circles: _places.map((place) {
                final colorType = place.placeColorType;
                return CircleMarker<SavedPlace>(
                  hitValue: place,
                  point: LatLng(place.lat, place.lng),
                  radius: place.radius,
                  useRadiusInMeter: true,
                  color: colorType.color,
                  borderColor: colorType.borderColor,
                  borderStrokeWidth: 2,
                );
              }).toList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCurrentLocation,
        tooltip: 'Zu meiner Position',
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    }
  }
}
