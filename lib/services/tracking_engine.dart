import 'dart:async';

import '../models/saved_place.dart';
import '../models/stay.dart';
import '../models/tracking_log_entry.dart';
import '../models/tracking_point.dart';
import '../services/calendar_service.dart';
import '../services/database_service.dart';
import '../services/nominatim_service.dart';
import '../services/settings_service.dart';
import '../utils/geo_utils.dart';

enum TrackingStatus { idle, moving, detectingHalt, haltAtKnown, haltAtUnknown }

/// Result of a [TrackingEngine.onNewPoint] call, used to notify the UI/service.
class TrackingResult {
  final TrackingStatus status;
  final Stay? currentStay;
  final SavedPlace? currentPlace;
  final String? notificationText;

  const TrackingResult({
    required this.status,
    this.currentStay,
    this.currentPlace,
    this.notificationText,
  });
}

/// State machine that analyses GPS points and manages Stay records.
///
/// All methods are async-safe for sequential calls from the foreground service
/// isolate. Not thread-safe for concurrent calls.
class TrackingEngine {
  TrackingStatus _status = TrackingStatus.idle;
  Stay? _currentStay;
  SavedPlace? _currentPlace;

  /// Load persisted state on service start.
  Future<void> initialize() async {
    final active = await DatabaseService.instance.loadActiveStay();
    if (active != null) {
      _currentStay = active;
      if (active.placeId != null) {
        final places = await DatabaseService.instance.loadAllPlaces();
        _currentPlace = places.where((p) => p.id == active.placeId).firstOrNull;
        _status = TrackingStatus.haltAtKnown;
      } else {
        _status = active.status == StayStatus.detecting
            ? TrackingStatus.detectingHalt
            : TrackingStatus.haltAtUnknown;
      }
    } else {
      _status = TrackingStatus.idle;
    }
  }

  TrackingStatus get status => _status;
  Stay? get currentStay => _currentStay;
  SavedPlace? get currentPlace => _currentPlace;

  /// Process a new GPS point. Returns a [TrackingResult] describing the new state.
  Future<TrackingResult> onNewPoint(
    double lat,
    double lng,
    int timestamp,
  ) async {
    final settings = SettingsService.instance;
    final prevStatus = _status;

    // Log variables — updated as we move through the state machine.
    int logShortPts = 0;
    bool logShortFull = false;
    bool logShortCluster = false;
    int logLongPts = 0;
    bool logLongFull = false;
    bool logLongCluster = false;
    int? logPlaceId;
    String logAction = 'tick';

    try {
      // 1. Compute smoothed position and persist it.
      //    Load the last (gpsSmoothingPoints - 1) already-stored points and
      //    average them with the current raw reading. Only the smoothed
      //    coordinate is stored, so all downstream window logic (short/long
      //    cluster checks) automatically operates on cleaner data.
      final smoothingCount = settings.gpsSmoothingPoints;
      double smoothLat = lat;
      double smoothLng = lng;
      if (smoothingCount > 1) {
        final lookbackMs =
            smoothingCount * settings.gpsIntervalSeconds * 1000 * 2;
        final recentRaw = await DatabaseService.instance
            .loadTrackingPointsSince(timestamp - lookbackMs);
        final prev = recentRaw.where((p) => p.timestamp < timestamp).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final windowPts = [
          (lat: lat, lng: lng),
          ...prev.take(smoothingCount - 1).map((p) => (lat: p.lat, lng: p.lng)),
        ];
        final smoothed = GeoUtils.smoothedPosition(windowPts);
        smoothLat = smoothed.lat;
        smoothLng = smoothed.lng;
      }

      await DatabaseService.instance.insertTrackingPoint(
        TrackingPoint(lat: smoothLat, lng: smoothLng, timestamp: timestamp),
      );

      // 2. Prune old points (keep autoPlaceSeconds + 5 interval points)
      final pruneBeforeMs =
          timestamp -
          (settings.autoPlaceSeconds + (settings.gpsIntervalSeconds * 5)) *
              1000;
      await DatabaseService.instance.deleteTrackingPointsOlderThan(
        pruneBeforeMs,
      );

      // 3. Load short window (stayDetectionSeconds)
      final shortWindowStart = timestamp - settings.stayDetectionSeconds * 1000;
      // Load with extra margin so the full-window check works even with gaps
      final shortWindowRaw = await DatabaseService.instance
          .loadTrackingPointsSince(
            shortWindowStart - settings.gpsIntervalSeconds * 2000,
          );

      if (shortWindowRaw.isEmpty) {
        logAction = 'no_data';
        return _result();
      }

      // Only points strictly inside (or on the boundary of) the window matter
      // for cluster / centroid, so we strip the margin points here.
      final shortWindow = shortWindowRaw
          .where((p) => p.timestamp >= shortWindowStart)
          .toList();

      // Window is "full" when at least one point older than the window start
      // exists in the raw list, meaning the window is continuously covered.
      final shortWindowFull =
          shortWindowRaw.first.timestamp <= shortWindowStart;

      // 4. Check if short window is a cluster
      final pts = shortWindow.map((p) => (lat: p.lat, lng: p.lng)).toList();
      final shortIsCluster =
          pts.isNotEmpty &&
          GeoUtils.isCluster(pts, settings.defaultRadiusMeters);

      logShortPts = pts.length;
      logShortFull = shortWindowFull;
      logShortCluster = shortIsCluster;

      if (!shortWindowFull || !shortIsCluster) {
        // Not yet confirmed as halt — but if we were halting, end the stay
        if (_status == TrackingStatus.haltAtKnown ||
            _status == TrackingStatus.haltAtUnknown) {
          await _endCurrentStay(timestamp);
          logAction = 'stay_ended';
        }
        if (shortIsCluster && !shortWindowFull) {
          // Points are clustered but window not complete yet
          _status = TrackingStatus.detectingHalt;
          if (logAction == 'tick') logAction = 'detecting';
        } else {
          _status = TrackingStatus.moving;
          if (logAction == 'tick') logAction = 'moving';
        }
        return _result();
      }

      // Short window is a full cluster → confirmed halt
      final c = GeoUtils.centroid(pts);

      // 5. Check known places — only public/private places trigger stays
      final places = await DatabaseService.instance.loadAllPlaces();
      SavedPlace? nearestPlace;
      for (final place in places) {
        if (!place.placeType.tracksStay) continue; // secret/forbidden — skip
        final dist = GeoUtils.distanceMeters(
          c.lat,
          c.lng,
          place.lat,
          place.lng,
        );
        if (dist <= place.radius) {
          nearestPlace = place;
          break;
        }
      }

      if (nearestPlace != null) {
        logPlaceId = nearestPlace.id;
        // Halt at known place
        if (_currentStay != null && _currentStay!.placeId != nearestPlace.id) {
          // Switched to a different known place — close the previous stay.
          await _endCurrentStay(timestamp);
          logAction = 'stay_switched';
        }
        if (_currentStay == null) {
          // Start a new stay anchored at the earliest point in the short window.
          await _startStay(
            placeId: nearestPlace.id,
            startTime: shortWindow.first.timestamp,
          );
          if (logAction == 'tick') logAction = 'stay_started';
        } else {
          if (logAction == 'tick') logAction = 'halt_known';
        }
        _status = TrackingStatus.haltAtKnown;
        _currentPlace = nearestPlace;
        return _result();
      }

      // No known place — check long window
      final longWindowStart = timestamp - settings.autoPlaceSeconds * 1000;
      // Load with margin so full-window check is accurate
      final longWindowRaw = await DatabaseService.instance
          .loadTrackingPointsSince(
            longWindowStart - settings.gpsIntervalSeconds * 2000,
          );

      // Strip margin points for actual cluster / centroid work
      final longWindow = longWindowRaw
          .where((p) => p.timestamp >= longWindowStart)
          .toList();

      final longWindowFull =
          longWindowRaw.isNotEmpty &&
          longWindowRaw.first.timestamp <= longWindowStart;
      final longPts = longWindow.map((p) => (lat: p.lat, lng: p.lng)).toList();
      final longIsCluster =
          longPts.isNotEmpty &&
          GeoUtils.isCluster(longPts, settings.defaultRadiusMeters);

      logLongPts = longPts.length;
      logLongFull = longWindowFull;
      logLongCluster = longIsCluster;

      if (longIsCluster && longWindowFull) {
        // Halt at unknown place — only start a stay once
        if (_currentStay == null) {
          final longC = GeoUtils.centroid(longPts);
          await _startUnknownStay(
            startTime: longWindow.first.timestamp,
            centroidLat: longC.lat,
            centroidLng: longC.lng,
          );
          logAction = 'unknown_stay_started';
        } else {
          logAction = 'halt_unknown';
        }
        _status = TrackingStatus.haltAtUnknown;
        _currentPlace = null;
      } else {
        // Short window clustered, no known place, long window not complete
        if (_status == TrackingStatus.haltAtKnown ||
            _status == TrackingStatus.haltAtUnknown) {
          await _endCurrentStay(timestamp);
          logAction = 'stay_ended';
        }
        _status = TrackingStatus.detectingHalt;
        if (logAction == 'tick') logAction = 'detecting';
        _currentPlace = null;
      }

      return _result();
    } finally {
      unawaited(
        DatabaseService.instance.insertTrackingLog(
          TrackingLogEntry(
            ts: timestamp,
            prevStatus: prevStatus.name,
            newStatus: _status.name,
            shortPts: logShortPts,
            shortFull: logShortFull,
            shortCluster: logShortCluster,
            longPts: logLongPts,
            longFull: logLongFull,
            longCluster: logLongCluster,
            placeId: logPlaceId,
            action: logAction,
          ),
        ),
      );
    }
  }

  Future<void> _startStay({
    required int? placeId,
    required int startTime,
  }) async {
    final stay = Stay(
      placeId: placeId,
      startTime: startTime,
      status: StayStatus.active,
    );
    final id = await DatabaseService.instance.insertStay(stay);
    _currentStay = stay.copyWith(id: id);
  }

  Future<void> _startUnknownStay({
    required int startTime,
    required double centroidLat,
    required double centroidLng,
  }) async {
    final settings = SettingsService.instance;

    // Fetch address from Nominatim (best-effort)
    final address = await NominatimService.instance.reverseGeocode(
      centroidLat,
      centroidLng,
    );

    String? autoPlaceName;
    if (settings.autoCreatePlaces) {
      final now = DateTime.fromMillisecondsSinceEpoch(startTime);
      final datePart =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timePart =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      autoPlaceName = address != null
          ? '$address ($datePart $timePart)'
          : '$datePart $timePart';

      // Create the auto-place
      final place = SavedPlace(
        name: autoPlaceName,
        lat: centroidLat,
        lng: centroidLng,
        radius: settings.defaultRadiusMeters,
        placeType: PlaceType.values[settings.autoPlacePlaceTypeIndex],
        groupId: settings.autoPlaceGroupId,
      );
      final placeId = await DatabaseService.instance.insertPlace(place);

      final stay = Stay(
        placeId: placeId,
        startTime: startTime,
        address: address,
        status: StayStatus.active,
      );
      final id = await DatabaseService.instance.insertStay(stay);
      _currentStay = stay.copyWith(id: id);
      return;
    }

    // No auto-create — just record the stay without a place
    final stay = Stay(
      startTime: startTime,
      address: address,
      status: StayStatus.active,
    );
    final id = await DatabaseService.instance.insertStay(stay);
    _currentStay = stay.copyWith(id: id);
  }

  Future<void> _endCurrentStay(int endTime) async {
    final stay = _currentStay;
    if (stay == null) return;
    final ended = stay.copyWith(endTime: endTime, status: StayStatus.completed);
    await DatabaseService.instance.updateStay(ended);

    // Calendar sync for public places
    final place = _currentPlace;
    if (place != null &&
        SettingsService.instance.calendarEnabled &&
        place.placeType.syncsCalendar &&
        place.groupId != null) {
      final group = await DatabaseService.instance.loadPlaceGroup(
        place.groupId!,
      );
      if (group != null) {
        final eventId = await CalendarService.instance.createStayEvent(
          ended,
          group,
          place.name,
        );
        if (eventId != null) {
          await DatabaseService.instance.updateStay(
            ended.copyWith(calendarEventId: eventId),
          );
        }
      }
    }

    _currentStay = null;
    _currentPlace = null;
  }

  /// Call when tracking is disabled to cleanly end any active stay.
  Future<void> stopTracking() async {
    if (_currentStay != null) {
      await _endCurrentStay(DateTime.now().millisecondsSinceEpoch);
    }
    _status = TrackingStatus.idle;
  }

  TrackingResult _result() {
    String notifText;
    switch (_status) {
      case TrackingStatus.haltAtKnown:
        notifText = 'Halten bei ${_currentPlace?.name ?? 'bekanntem Ort'}';
      case TrackingStatus.haltAtUnknown:
        notifText = _currentStay?.address != null
            ? 'Halten: ${_currentStay!.address}'
            : 'Halten an unbekanntem Ort';
      case TrackingStatus.detectingHalt:
        notifText = 'Aufenthalt wird erkannt…';
      case TrackingStatus.moving:
        notifText = 'Unterwegs';
      case TrackingStatus.idle:
        notifText = 'Tracking aktiv';
    }
    return TrackingResult(
      status: _status,
      currentStay: _currentStay,
      currentPlace: _currentPlace,
      notificationText: notifText,
    );
  }
}
