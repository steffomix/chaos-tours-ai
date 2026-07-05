import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/place_group.dart';
import '../models/saved_place.dart';
import '../utils/geo_utils.dart';
import '../utils/maidenhead.dart';
import 'database_service.dart';
import 'node_discovery_service.dart';
import 'settings_service.dart';
import 'sync_service.dart';

/// Result of a single mesh sync opportunity.
class MeshSyncLog extends ValueNotifier<String> {
  int? _lastSyncMs;
  bool _isBusy = false;
  int _nodeDiscoverTrys = 0;
  int _secondsBusy = 0;
  bool _isOnline = false;
  String _connectionType = '';
  String _responseError = '';
  bool _nodesFoundAny = false;
  int _nodesFound = 0;
  int _nodesSynced = 0;
  int _pulled = 0;
  int _pushed = 0;
  String _placeUuid = '';
  String _placeSyncUuid = '';
  String _placeName = '';
  String _placeGps = '';
  String _error = '';

  MeshSyncLog(super.value);

  set isBusy(bool value) {
    _isBusy = value;
    _setValue();
  }

  int get secondsBusy => _secondsBusy;
  set secondsBusy(int value) {
    _secondsBusy = value;
    _setValue();
  }

  set isOnline(bool value) {
    _isOnline = value;
    _setValue();
  }

  set connectionType(String value) {
    _connectionType = value;
    _setValue();
  }

  int get nodeDiscoverTrys => _nodeDiscoverTrys;
  set nodeDiscoverTrys(int value) {
    _nodeDiscoverTrys = value;
    _setValue();
  }

  set responseError(String value) {
    _responseError = value;
    _setValue();
  }

  set nodesFoundAny(bool value) {
    _nodesFoundAny = value;
    _setValue();
  }

  set nodesFound(int value) {
    _nodesFound = value;
    _setValue();
  }

  set nodesSynced(int value) {
    _nodesSynced = value;
    _setValue();
  }

  set pulled(int value) {
    _pulled = value;
    _setValue();
  }

  set pushed(int value) {
    _pushed = value;
    _setValue();
  }

  set placeUuid(String value) {
    _placeUuid = value;
    _setValue();
  }

  set placeSyncUuid(String value) {
    _placeSyncUuid = value;
    _setValue();
  }

  set placeName(String value) {
    _placeName = value;
    _setValue();
  }

  set placeGps(String value) {
    _placeGps = value;
    _setValue();
  }

  set error(String value) {
    _error = value;
    _setValue();
  }

  void _setValue() {
    value =
        '''P2P Sync Log:
Last Sync: ${_lastSyncMs != null ? DateTime.fromMillisecondsSinceEpoch(_lastSyncMs!).toIso8601String() : 'unknown'}
Busy: ${_isBusy ? 'yes, since $_secondsBusy / ${MeshSyncService.discoerTimeout} sec.' : 'no'}
Node Discovery Attempts: $_nodeDiscoverTrys
---
Online: ${_isOnline ? 'yes' : 'no'}
Connection Type: $_connectionType
Response Error: $_responseError
---
Nodes Found Any: ${_nodesFoundAny ? 'yes' : 'no'}
Nodes Found: $_nodesFound
Nodes Synced: $_nodesSynced
Pulled: $_pulled
Pushed: $_pushed
Place UUID: $_placeUuid
Place Sync UUID: $_placeSyncUuid
Place Name: $_placeName
Place GPS: $_placeGps
Error: $_error''';
  }

  void restart() {
    _lastSyncMs = DateTime.now().millisecondsSinceEpoch;
    _secondsBusy = 0;
    _isBusy = true;
    _nodeDiscoverTrys = 0;
    _isOnline = false;
    _connectionType = '';
    _nodesFoundAny = false;
    _nodesFound = 0;
    _nodesSynced = 0;
    _pulled = 0;
    _pushed = 0;
    _placeUuid = '';
    _placeSyncUuid = '';
    _placeName = '';
    _placeGps = '';
    _error = '';
    _setValue();
  }
}

/// Orchestrates the location-triggered "store-and-forward" mesh sync:
/// connectivity check → node discovery → anchor place → delta sync → watermark.
class MeshSyncService {
  MeshSyncService._();
  static final MeshSyncService instance = MeshSyncService._();
  static final MeshSyncLog log = MeshSyncLog('');
  static const String syncSourceGroupName = 'P2P Message Sync-Sources';

  bool _busy = false;
  static const discoerTimeout = 30;

  void startTimer() {
    // Start a repeating timer to count seconds while busy.
    log.secondsBusy = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      log.secondsBusy++;
      return _busy;
    });
  }

  /// Runs one opportunistic sync sweep around ([lat], [lng]). Safe to call from
  /// the tracking engine on arrival/halt. Re-entrant calls are ignored.
  Future<void> onSyncOpportunity({
    required double lat,
    required double lng,
  }) async {
    if (_busy) {
      return;
    }
    log.isBusy = _busy = true;
    try {
      log.restart();
      startTimer();
      // 1. Require a usable local network connection.
      final conn = await Connectivity().checkConnectivity();
      final online =
          conn.contains(ConnectivityResult.wifi) ||
          conn.contains(ConnectivityResult.ethernet) ||
          conn.contains(ConnectivityResult.vpn);
      log.isOnline = online;
      log.connectionType = conn.toString();
      if (!online) {
        log.error = 'No usable local network connection.';
        log.isBusy = _busy = false;
        return;
      }
      List<DiscoveredNode> nodes = [];
      int t = DateTime.now().millisecondsSinceEpoch + discoerTimeout * 1000;
      while (t > DateTime.now().millisecondsSinceEpoch) {
        nodes = await NodeDiscoveryService.instance.discover();
        log.nodesFoundAny = nodes.isNotEmpty;
        log.nodesFound = nodes.length;
        log.nodeDiscoverTrys++;
        if (nodes.isNotEmpty) {
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      if (nodes.isEmpty) {
        log.error = 'No mesh nodes found on the local network.';
        log.isBusy = _busy = false;
        return;
      }

      // 3. Delta-sync with every discovered node FIRST. This way an already
      //    shared place for this cell (deterministic UUID) is pulled in before
      //    we decide whether to create one — preventing duplicate places.
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
          log.nodesSynced = synced;
          log.pulled = pulled;
          log.pushed = pushed;
        } else {
          error ??= res.errorMessage;
          log.responseError = res.errorMessage ?? '';
        }
      }

      // 4. Ensure a place exists to anchor exchanged messages to — adopting the
      //    just-pulled / deterministic place, or creating it when permitted.
      final place = await ensureSyncSourcePlace(lat: lat, lng: lng);

      // 5. Record the message-sync watermark on the anchor place.
      if (place != null) {
        log.placeUuid = place.uuid;
        log.placeName = place.name;
        log.placeGps = '${place.lat}, ${place.lng}';
        await DatabaseService.instance.updatePlaceMessagesSyncMs(
          place.uuid,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      log.error = 'sync error: ${e.toString()}';
    } finally {
      log.isBusy = _busy = false;
    }
  }

  /// Returns a place near ([lat], [lng]) to anchor messages to. Reuses an
  /// existing nearby place when possible; otherwise adopts (or creates) a
  /// deterministic "Sync-Quelle" place whose UUID is derived from the 10-char
  /// Maidenhead cell of the location. Because every device in the same cell
  /// derives the *same* UUID and uses the cell-center coordinates, the sync
  /// merge collapses them into one shared place instead of an endless stack.
  /// Returns null when no place exists and creation is disabled.
  Future<SavedPlace?> ensureSyncSourcePlace({
    required double lat,
    required double lng,
  }) async {
    final db = DatabaseService.instance;
    final s = SettingsService.instance;
    final radius = s.defaultRadiusMeters;

    // 1. Reuse any existing place within the default radius (bounding box first).
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
    if (nearest != null) {
      return nearest;
    }

    // 2. Deterministic identity for this cell.
    final placeUuid = Maidenhead.deterministicPlaceUuid(lat, lng);
    // source for gps center calculation below
    final loc10 = Maidenhead.encodeId(lat, lng);

    log.placeSyncUuid = 'Search for sync place uuid $placeUuid ...';

    // 3. Adopt the place if it already exists locally (e.g. just pulled).
    final existing = await db.getSavedPlace(placeUuid);
    if (existing != null) {
      log.placeSyncUuid = 'Found existing sync place uuid $placeUuid';
      return existing;
    }

    // 4. No place yet — create one only if permitted.
    if (!s.autoCreatePlaces && !s.createPlaceOnSyncOpportunity) return null;

    final groupUuid = await _ensureSyncSourceGroup();
    // Use the cell CENTER so all devices agree on identical coordinates.
    final center = Maidenhead.decodeCenter(loc10);
    final place = SavedPlace(
      uuid: placeUuid,
      name: '$syncSourceGroupName ${Maidenhead.format(loc10)}',
      lat: center.lat,
      lng: center.lng,
      radius: radius,
      groupUuid: groupUuid,
      originType: PlaceOriginType.auto,
    );
    await db.insertPlace(place);
    return place;
  }

  /// Ensures the dedicated "P2P Message Sync-Sources" place group (carrying
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
      name: syncSourceGroupName,
      isAutoGroup: true,
      placeType: PlaceType.syncSource,
    );
    await db.insertPlaceGroup(group);
    s.syncSourcePlaceGroupUuid = group.uuid;
    return group.uuid;
  }
}
