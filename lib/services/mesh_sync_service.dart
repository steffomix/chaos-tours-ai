import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/place_group.dart';
import '../models/saved_place.dart';
import '../utils/geo_utils.dart';
import 'database_service.dart';
import 'node_discovery_service.dart';
import 'settings_service.dart';
import 'sync_service.dart';

/// Result of a single mesh sync opportunity.
class MeshSyncOutcome {
  final int nodesFound;
  final int nodesSynced;
  final int pulled;
  final int pushed;
  final String? placeUuid;
  final String? error;

  const MeshSyncOutcome({
    this.nodesFound = 0,
    this.nodesSynced = 0,
    this.pulled = 0,
    this.pushed = 0,
    this.placeUuid,
    this.error,
  });
}

/// Orchestrates the location-triggered "store-and-forward" mesh sync:
/// connectivity check → node discovery → anchor place → delta sync → watermark.
class MeshSyncService {
  MeshSyncService._();
  static final MeshSyncService instance = MeshSyncService._();

  bool _busy = false;

  /// Runs one opportunistic sync sweep around ([lat], [lng]). Safe to call from
  /// the tracking engine on arrival/halt. Re-entrant calls are ignored.
  Future<MeshSyncOutcome> onSyncOpportunity({
    required double lat,
    required double lng,
  }) async {
    if (_busy) return const MeshSyncOutcome();
    _busy = true;
    try {
      // 1. Require a usable local network connection.
      final conn = await Connectivity().checkConnectivity();
      final online =
          conn.contains(ConnectivityResult.wifi) ||
          conn.contains(ConnectivityResult.ethernet) ||
          conn.contains(ConnectivityResult.vpn);
      if (!online) return const MeshSyncOutcome();

      // 2. Discover mesh nodes on the local network.
      final nodes = await NodeDiscoveryService.instance.discover();
      if (nodes.isEmpty) return const MeshSyncOutcome();

      // 3. Ensure a place exists to anchor exchanged messages to.
      final place = await ensureSyncSourcePlace(lat: lat, lng: lng);

      // 4. Delta-sync with every discovered node.
      var synced = 0;
      var pulled = 0;
      var pushed = 0;
      String? error;
      for (final node in nodes) {
        final res = await SyncService.instance.syncWithNode(node.baseUrl);
        if (res.success) {
          synced++;
          pulled += res.pulled;
          pushed += res.pushed;
        } else {
          error ??= res.errorMessage;
        }
      }

      // 5. Record the message-sync watermark on the anchor place.
      if (place != null) {
        await DatabaseService.instance.updatePlaceMessagesSyncMs(
          place.uuid,
          DateTime.now().millisecondsSinceEpoch,
        );
      }

      return MeshSyncOutcome(
        nodesFound: nodes.length,
        nodesSynced: synced,
        pulled: pulled,
        pushed: pushed,
        placeUuid: place?.uuid,
        error: error,
      );
    } catch (e) {
      return MeshSyncOutcome(error: e.toString());
    } finally {
      _busy = false;
    }
  }

  /// Returns a place near ([lat], [lng]) to anchor messages to. Reuses an
  /// existing nearby place when possible; otherwise creates a "Sync-Quelle"
  /// place (when permitted by settings) so location-bound messages have a home.
  /// Returns null when no place exists and creation is disabled.
  Future<SavedPlace?> ensureSyncSourcePlace({
    required double lat,
    required double lng,
  }) async {
    final db = DatabaseService.instance;
    final s = SettingsService.instance;
    final radius = s.defaultRadiusMeters;

    // Look for an existing place within the default radius (bounding box first).
    final latDelta = radius / 111000;
    final lngDelta = radius / 111000;
    final candidates = await db.loadPlacesWithinBounds(
      minLat: lat - latDelta,
      maxLat: lat + latDelta,
      minLng: lng - lngDelta,
      maxLng: lng + lngDelta,
    );
    SavedPlace? nearest;
    double nearestDist = double.infinity;
    for (final p in candidates) {
      final d = GeoUtils.distanceMeters(lat, lng, p.lat, p.lng);
      if (d <= radius && d < nearestDist) {
        nearest = p;
        nearestDist = d;
      }
    }
    if (nearest != null) return nearest;

    // No nearby place — create one only if permitted.
    if (!s.autoCreatePlaces && !s.createPlaceOnSyncOpportunity) return null;

    final groupUuid = await _ensureSyncSourceGroup();
    final place = SavedPlace(
      name: 'Sync-Quelle ${_shortTime()}',
      lat: lat,
      lng: lng,
      radius: radius,
      groupUuid: groupUuid,
      originType: PlaceOriginType.auto,
    );
    await db.insertPlace(place);
    return place;
  }

  /// Ensures the dedicated "Sync-Quelle" place group (carrying
  /// [PlaceType.syncSource]) exists and returns its UUID.
  Future<String> _ensureSyncSourceGroup() async {
    final db = DatabaseService.instance;
    final s = SettingsService.instance;
    final existing = s.syncSourcePlaceGroupUuid;
    if (existing != null) {
      final group = await db.loadPlaceGroup(existing);
      if (group != null && group.deletedAt == null) return existing;
    }
    final group = PlaceGroup(
      name: 'Sync-Quellen',
      isAutoGroup: true,
      placeType: PlaceType.syncSource,
    );
    await db.insertPlaceGroup(group);
    s.syncSourcePlaceGroupUuid = group.uuid;
    return group.uuid;
  }

  String _shortTime() {
    final dt = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}. ${two(dt.hour)}:${two(dt.minute)}';
  }
}
