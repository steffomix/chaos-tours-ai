import 'dart:async';

import '../models/saved_place.dart';
import '../models/stay.dart';
import '../models/tracking_point.dart';
import '../services/calendar_service.dart';
import '../services/database_service.dart';
import '../services/nominatim_service.dart';
import '../services/settings_service.dart';
import '../services/telegram_service.dart';
import '../services/matrix_service.dart';
import '../utils/geo_utils.dart';
import '../utils/maidenhead.dart';

enum TrackingStatus { idle, moving, detectingHalt, haltAtKnown, haltAtUnknown }

/// Result of a [TrackingEngine.onNewPoint] call, used to notify the UI/service.
class TrackingResult {
  final TrackingStatus status;
  final Stay? currentStay;
  final SavedPlace? currentPlace;
  final String? notificationText;

  /// All concurrently active stays at known places (≥1 when place radii overlap).
  final List<Stay> allActiveStays;

  /// Known places corresponding 1:1 with [allActiveStays].
  final List<SavedPlace> allActivePlaces;

  const TrackingResult({
    required this.status,
    this.currentStay,
    this.currentPlace,
    this.notificationText,
    this.allActiveStays = const [],
    this.allActivePlaces = const [],
  });
}

/// State machine that analyses GPS points and manages Stay records.
///
/// All methods are async-safe for sequential calls from the foreground service
/// isolate. Not thread-safe for concurrent calls.
class TrackingEngine {
  TrackingStatus _status = TrackingStatus.idle;
  int _statusSince = DateTime.now().millisecondsSinceEpoch;

  /// Active stays at known places, keyed by [SavedPlace.uuid].
  final Map<String, Stay> _activeStays = {};

  /// Known places currently being tracked, keyed by [SavedPlace.uuid].
  final Map<String, SavedPlace> _activePlaces = {};

  /// Active stay at an unknown location (no associated [SavedPlace]).
  Stay? _unknownStay;

  /// Load persisted state on service start.
  Future<void> initialize() async {
    final activeStays = await DatabaseService.instance.loadAllActiveStays();
    if (activeStays.isNotEmpty) {
      final places = await DatabaseService.instance.loadAllPlaces();
      final placesById = {for (final p in places) p.uuid: p};
      bool anyKnown = false;
      for (final stay in activeStays) {
        if (stay.placeUuid != null) {
          final place = placesById[stay.placeUuid];
          if (place != null) {
            _activeStays[place.uuid] = stay;
            _activePlaces[place.uuid] = place;
            anyKnown = true;
          }
        } else {
          // Keep only the most recent unknown stay.
          if (_unknownStay == null ||
              stay.startTime > _unknownStay!.startTime) {
            _unknownStay = stay;
          }
        }
      }
      if (anyKnown) {
        _setStatus(TrackingStatus.haltAtKnown);
      } else if (_unknownStay != null) {
        _setStatus(
          _unknownStay!.status == StayStatus.detecting
              ? TrackingStatus.detectingHalt
              : TrackingStatus.haltAtUnknown,
        );
      }
    } else {
      _setStatus(TrackingStatus.idle);
    }
  }

  TrackingStatus get status => _status;

  /// Primary place for display: the overlapping place with the smallest radius
  /// (most specific). Returns null when not at a known place.
  SavedPlace? get currentPlace => _primaryPlace;

  SavedPlace? get _primaryPlace => _activePlaces.values.isEmpty
      ? null
      : _activePlaces.values.reduce((a, b) => a.radius <= b.radius ? a : b);

  /// Primary active stay for display (corresponds to [currentPlace]).
  /// Falls back to [_unknownStay] when no known-place stays are active.
  Stay? get currentStay {
    final primary = _primaryPlace;
    if (primary != null) return _activeStays[primary.uuid];
    return _unknownStay;
  }

  /// Process a new GPS point. Returns a [TrackingResult] describing the new state.
  Future<TrackingResult> onNewPoint(
    double lat,
    double lng,
    int timestamp,
  ) async {
    final settings = SettingsService.instance;

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
      final recentRaw = await DatabaseService.instance.loadTrackingPointsSince(
        timestamp - lookbackMs,
      );
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
        (settings.autoPlaceSeconds + (settings.gpsIntervalSeconds * 5)) * 1000;
    await DatabaseService.instance.deleteTrackingPointsOlderThan(pruneBeforeMs);

    // 3. Load short window (stayDetectionSeconds)
    final shortWindowStart = timestamp - settings.stayDetectionSeconds * 1000;
    // Load with extra margin so the full-window check works even with gaps
    final shortWindowRaw = await DatabaseService.instance
        .loadTrackingPointsSince(
          shortWindowStart - settings.gpsIntervalSeconds * 2000,
        );

    if (shortWindowRaw.isEmpty) {
      return _result();
    }

    // Only points strictly inside (or on the boundary of) the window matter
    // for cluster / centroid, so we strip the margin points here.
    final shortWindow = shortWindowRaw
        .where((p) => p.timestamp >= shortWindowStart)
        .toList();

    // Window is "full" when at least one point older than the window start
    // exists in the raw list, meaning the window is continuously covered.
    final shortWindowFull = shortWindowRaw.first.timestamp <= shortWindowStart;

    // 4. Check if short window is a cluster
    final pts = shortWindow.map((p) => (lat: p.lat, lng: p.lng)).toList();
    final shortIsCluster =
        pts.isNotEmpty && GeoUtils.isCluster(pts, settings.defaultRadiusMeters);

    if (!shortWindowFull || !shortIsCluster) {
      // Not yet confirmed as halt — end all active stays if we were halting.
      if (_status == TrackingStatus.haltAtKnown ||
          _status == TrackingStatus.haltAtUnknown) {
        await _endAllStays(timestamp);
      }
      if (shortIsCluster && !shortWindowFull) {
        _setStatus(TrackingStatus.detectingHalt);
      } else {
        _setStatus(TrackingStatus.moving);
      }
      return _result();
    }

    // Short window is a full cluster → confirmed halt
    final c = GeoUtils.centroid(pts);

    // 5. Find ALL overlapping tracksStay places and manage per-place stays.
    //    Each place is processed independently according to its own placeType.
    //    secret/forbidden places are excluded by tracksStay == false and thus
    //    never suppress tracking at overlapping public/private places.
    final places = await DatabaseService.instance.loadAllPlaces();
    final overlapping = <SavedPlace>[];
    for (final place in places) {
      if (!place.placeType.tracksStay) continue;
      final dist = GeoUtils.distanceMeters(c.lat, c.lng, place.lat, place.lng);
      if (dist <= place.radius) {
        overlapping.add(place);
      }
    }

    if (overlapping.isNotEmpty) {
      // End the unknown stay when we've arrived at known places.
      if (_unknownStay != null) {
        await _endUnknownStay(timestamp);
      }

      final overlappingUuids = overlapping.map((p) => p.uuid).toSet();

      // End stays for places the centroid has left.
      for (final uuid in _activeStays.keys.toList()) {
        if (!overlappingUuids.contains(uuid)) {
          await _endStay(uuid, timestamp);
        }
      }

      // Start stays for newly overlapping places.
      for (final place in overlapping) {
        if (!_activeStays.containsKey(place.uuid)) {
          await _startStay(
            place: place,
            startTime: shortWindow.first.timestamp,
          );
        }
      }

      _setStatus(TrackingStatus.haltAtKnown);
      return _result();
    }

    // No known tracksStay place — check long window for unknown stay.
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
        GeoUtils.isCluster(longPts, settings.defaultRadiusMeters * 2);

    if (longIsCluster && longWindowFull) {
      // End any lingering known-place stays before switching to unknown.
      if (_activeStays.isNotEmpty) {
        await _endAllKnownStays(timestamp);
      }
      // Halt at unknown place — only start a stay once
      if (_unknownStay == null) {
        final longC = GeoUtils.centroid(longPts);
        await _startUnknownStay(
          startTime: longWindow.first.timestamp,
          centroidLat: longC.lat,
          centroidLng: longC.lng,
        );
      }
      // After _startUnknownStay with auto-create the stay ends up in
      // _activeStays, so prefer haltAtKnown in that case.
      _setStatus(
        _activeStays.isNotEmpty
            ? TrackingStatus.haltAtKnown
            : TrackingStatus.haltAtUnknown,
      );
    } else {
      // Short window clustered, no known place, long window not complete
      if (_status == TrackingStatus.haltAtKnown ||
          _status == TrackingStatus.haltAtUnknown) {
        await _endAllStays(timestamp);
      }
      _setStatus(TrackingStatus.detectingHalt);
    }

    return _result();
  }

  Future<void> _startStay({
    required SavedPlace place,
    required int startTime,
  }) async {
    final stay = Stay(
      placeUuid: place.uuid,
      startTime: startTime,
      status: StayStatus.active,
    );
    final stayUuid = await DatabaseService.instance.insertStay(stay);
    final persisted = stay.copyWith(uuid: stayUuid);
    _activeStays[place.uuid] = persisted;
    _activePlaces[place.uuid] = place;

    // Trigger arrival events only for syncEnabled places (public).
    if (place.placeType.syncEnabled) {
      await _createArrivalCalendarEvent(place.uuid);
      await _createArrivalTelegramMessage(place.uuid);
      await _createArrivalMatrixMessage(place.uuid);
    }
  }

  Future<void> _startUnknownStay({
    required int startTime,
    required double centroidLat,
    required double centroidLng,
  }) async {
    final settings = SettingsService.instance;

    // Fetch address from Nominatim (best-effort), unless disabled in settings.
    final address = settings.addressOnAutoCreate
        ? await NominatimService.instance.reverseGeocode(
            centroidLat,
            centroidLng,
          )
        : null;

    if (settings.autoCreatePlaces) {
      final now = DateTime.fromMillisecondsSinceEpoch(startTime);
      final datePart =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timePart =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final autoPlaceName = address != null
          ? '$address ($datePart $timePart)'
          : '$datePart $timePart';

      // Create the auto-place and its stay, then register as a known-place stay
      // so subsequent ticks find it via _activeStays.
      //
      // Location = identity: the place UUID is derived deterministically from
      // the 10-char Maidenhead (QTH) cell and the cell-center coordinates are
      // used, so the same spot becomes ONE shared place across all devices
      // (the UUID-merge sync collapses duplicates instead of stacking them).
      final placeUuid = Maidenhead.deterministicPlaceUuid(
        centroidLat,
        centroidLng,
      );
      final center = Maidenhead.decodeCenter(
        Maidenhead.encodeId(centroidLat, centroidLng),
      );

      SavedPlace placePersisted;
      final existing = await DatabaseService.instance.getSavedPlace(placeUuid);
      if (existing != null) {
        // Adopt the already-existing (possibly synced) place for this cell.
        placePersisted = existing;
      } else {
        final place = SavedPlace(
          uuid: placeUuid,
          name: autoPlaceName,
          lat: center.lat,
          lng: center.lng,
          radius: settings.defaultRadiusMeters,
          groupUuid: settings.autoPlaceGroupUuid,
          originType: PlaceOriginType.auto,
        );
        await DatabaseService.instance.insertPlace(place);
        placePersisted = place;
      }

      final stay = Stay(
        placeUuid: placeUuid,
        startTime: startTime,
        address: address,
        status: StayStatus.active,
      );
      final stayUuid = await DatabaseService.instance.insertStay(stay);
      final persistedStay = stay.copyWith(uuid: stayUuid);

      _activeStays[placeUuid] = persistedStay;
      _activePlaces[placeUuid] = placePersisted;

      // Arrival events for auto-created place if its group allows sync.
      final autoGroupUuid = settings.autoPlaceGroupUuid;
      if (autoGroupUuid != null) {
        final autoGroup = await DatabaseService.instance.loadPlaceGroup(
          autoGroupUuid,
        );
        if (autoGroup != null && autoGroup.placeType.syncEnabled) {
          await _createArrivalCalendarEvent(placeUuid);
          await _createArrivalTelegramMessage(placeUuid);
          await _createArrivalMatrixMessage(placeUuid);
        }
      }
      return;
    }

    // No auto-create — record the stay without a place.
    final stay = Stay(
      startTime: startTime,
      address: address,
      status: StayStatus.active,
    );
    final stayUuid = await DatabaseService.instance.insertStay(stay);
    _unknownStay = stay.copyWith(uuid: stayUuid);
  }

  /// Creates a preliminary "arrival" calendar event for the stay at [placeUuid].
  Future<void> _createArrivalCalendarEvent(String placeUuid) async {
    final stay = _activeStays[placeUuid];
    final place = _activePlaces[placeUuid];
    if (stay == null || place == null) return;
    if (!SettingsService.instance.calendarEnabled) return;
    if (place.groupUuid == null) return;
    final group = await DatabaseService.instance.loadPlaceGroup(
      place.groupUuid!,
    );
    if (group == null) return;
    final groupCalendarId = SettingsService.instance.getGroupCalendarId(
      group.uuid,
    );
    if (groupCalendarId == null) return;

    final eventId = await CalendarService.instance.createArrivalEvent(
      stay,
      group,
      place.name,
      calendarId: groupCalendarId,
    );
    if (eventId != null) {
      final updated = stay.copyWith(calendarEventId: eventId);
      await DatabaseService.instance.updateStay(updated);
      _activeStays[placeUuid] = updated;
    }
  }

  /// Sends an arrival Telegram message for the stay at [placeUuid].
  Future<void> _createArrivalTelegramMessage(String placeUuid) async {
    final stay = _activeStays[placeUuid];
    final place = _activePlaces[placeUuid];
    if (stay == null || place == null) return;
    if (place.groupUuid == null) return;
    final group = await DatabaseService.instance.loadPlaceGroup(
      place.groupUuid!,
    );
    if (group == null || group.telegramConnectionUuid == null) return;
    final conn = await DatabaseService.instance.loadTelegramConnection(
      group.telegramConnectionUuid!,
    );
    if (conn == null) return;

    String esc(String s) => s.replaceAllMapped(
      RegExp(r'[_*\[\]()~`>#+\-=|{}.!\\]'),
      (m) => '\\${m[0]}',
    );

    final d = DateTime.fromMillisecondsSinceEpoch(stay.startTime);
    final fmtTime =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final text = '\u{1F4CD} *${esc(place.name)}*\nAnkunft: ${esc(fmtTime)}';

    final result = await TelegramService.instance.sendMessage(conn, text);
    if (result.success && result.messageId != null) {
      final updated = stay.copyWith(telegramMessageId: result.messageId);
      await DatabaseService.instance.updateStay(updated);
      _activeStays[placeUuid] = updated;
    }
  }

  /// Sends an arrival Matrix message for the stay at [placeUuid].
  Future<void> _createArrivalMatrixMessage(String placeUuid) async {
    final stay = _activeStays[placeUuid];
    final place = _activePlaces[placeUuid];
    if (stay == null || place == null) return;
    if (place.groupUuid == null) return;
    final group = await DatabaseService.instance.loadPlaceGroup(
      place.groupUuid!,
    );
    if (group == null || group.matrixConnectionUuid == null) return;
    final conn = await DatabaseService.instance.loadMatrixConnection(
      group.matrixConnectionUuid!,
    );
    if (conn == null) return;

    final d = DateTime.fromMillisecondsSinceEpoch(stay.startTime);
    final fmtTime =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final text = '\u{1F4CD} ${place.name}\nAnkunft: $fmtTime';

    final result = await MatrixService.instance.sendMessage(conn, text);
    if (result.success && result.eventId != null) {
      final updated = stay.copyWith(matrixEventId: result.eventId);
      await DatabaseService.instance.updateStay(updated);
      _activeStays[placeUuid] = updated;
    }
  }

  /// Ends the active stay for a single known place and runs calendar/telegram sync.
  Future<void> _endStay(String placeUuid, int endTime) async {
    final stay = _activeStays[placeUuid];
    final place = _activePlaces[placeUuid];
    if (stay == null || place == null) return;

    final ended = stay.copyWith(endTime: endTime, status: StayStatus.completed);
    await DatabaseService.instance.updateStay(ended);

    // Calendar sync — only for syncEnabled (public) places.
    if (place.placeType.syncEnabled &&
        SettingsService.instance.calendarEnabled &&
        place.groupUuid != null) {
      final group = await DatabaseService.instance.loadPlaceGroup(
        place.groupUuid!,
      );
      if (group != null) {
        final groupCalendarId = SettingsService.instance.getGroupCalendarId(
          group.uuid,
        );
        if (groupCalendarId != null) {
          final persons = await DatabaseService.instance.loadPersonsForStay(
            ended.uuid,
          );
          final activities = await DatabaseService.instance
              .loadActivitiesForStay(ended.uuid);

          bool updated = false;
          if (ended.calendarEventId != null) {
            updated = await CalendarService.instance.updateStayEvent(
              ended,
              group,
              place.name,
              calendarId: groupCalendarId,
              persons: persons.cast(),
              activities: activities.cast(),
              lat: place.lat,
              lng: place.lng,
            );
          }
          if (!updated) {
            final eventId = await CalendarService.instance.createStayEvent(
              ended,
              group,
              place.name,
              calendarId: groupCalendarId,
              persons: persons.cast(),
              activities: activities.cast(),
              lat: place.lat,
              lng: place.lng,
            );
            if (eventId != null) {
              await DatabaseService.instance.updateStay(
                ended.copyWith(calendarEventId: eventId),
              );
            }
          }
        }
      }
    }

    // Telegram sync — fires for any place with a telegram-connected group,
    // editing the arrival message or sending a new departure message.
    if (place.groupUuid != null) {
      final group = await DatabaseService.instance.loadPlaceGroup(
        place.groupUuid!,
      );
      if (group != null && group.telegramConnectionUuid != null) {
        final conn = await DatabaseService.instance.loadTelegramConnection(
          group.telegramConnectionUuid!,
        );
        if (conn != null) {
          String esc(String s) => s.replaceAllMapped(
            RegExp(r'[_*\[\]()~`>#+\-=|{}.!\\]'),
            (m) => '\\${m[0]}',
          );

          final persons = await DatabaseService.instance.loadPersonsForStay(
            ended.uuid,
          );
          final activities = await DatabaseService.instance
              .loadActivitiesForStay(ended.uuid);

          final dStart = DateTime.fromMillisecondsSinceEpoch(ended.startTime);
          final dEnd = DateTime.fromMillisecondsSinceEpoch(endTime);
          String fmtTime(DateTime d) =>
              '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
          final duration = ended.copyWith(endTime: endTime).duration;
          String fmtDur(Duration dur) {
            final h = dur.inHours;
            final m = dur.inMinutes.remainder(60);
            return h > 0 ? '${h}h ${m}min' : '${m}min';
          }

          final buf = StringBuffer();
          buf.writeln('\u{1F4CD} *${esc(place.name)}*');
          buf.writeln(
            'Ankunft: ${esc(fmtTime(dStart))}  \u2022  Abfahrt: ${esc(fmtTime(dEnd))}',
          );
          buf.writeln('Dauer: ${esc(fmtDur(duration))}');
          buf.writeln(
            '[Google Maps](http://maps.google.com/?q=${place.lat.toStringAsFixed(6)},${place.lng.toStringAsFixed(6)})',
          );
          if (persons.isNotEmpty) {
            buf.writeln(
              'Personen: ${esc(persons.map((p) => p.name).join(', '))}',
            );
          }
          if (activities.isNotEmpty) {
            buf.writeln(
              'T\u00e4tigkeiten: ${esc(activities.map((a) => a.description).join(', '))}',
            );
          }
          if (ended.notes.isNotEmpty) {
            buf.writeln('_${esc(ended.notes)}_');
          }

          final text = buf.toString().trimRight();

          if (ended.telegramMessageId != null) {
            await TelegramService.instance.editMessage(
              conn,
              ended.telegramMessageId!,
              text,
            );
          } else {
            final result = await TelegramService.instance.sendMessage(
              conn,
              text,
            );
            if (result.success && result.messageId != null) {
              await DatabaseService.instance.updateStay(
                ended.copyWith(telegramMessageId: result.messageId),
              );
            }
          }
        }
      }
    }

    // Matrix sync — analogous to Telegram, fires for any place with a
    // matrix-connected group.
    if (place.groupUuid != null) {
      final group = await DatabaseService.instance.loadPlaceGroup(
        place.groupUuid!,
      );
      if (group != null && group.matrixConnectionUuid != null) {
        final conn = await DatabaseService.instance.loadMatrixConnection(
          group.matrixConnectionUuid!,
        );
        if (conn != null) {
          final persons = await DatabaseService.instance.loadPersonsForStay(
            ended.uuid,
          );
          final activities = await DatabaseService.instance
              .loadActivitiesForStay(ended.uuid);

          final dStart = DateTime.fromMillisecondsSinceEpoch(ended.startTime);
          final dEnd = DateTime.fromMillisecondsSinceEpoch(endTime);
          String fmtTime(DateTime d) =>
              '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
          final duration = ended.copyWith(endTime: endTime).duration;
          String fmtDur(Duration dur) {
            final h = dur.inHours;
            final m = dur.inMinutes.remainder(60);
            return h > 0 ? '${h}h ${m}min' : '${m}min';
          }

          final buf = StringBuffer();
          buf.writeln('\u{1F4CD} ${place.name}');
          buf.writeln(
            'Ankunft: ${fmtTime(dStart)}  \u2022  Abfahrt: ${fmtTime(dEnd)}',
          );
          buf.writeln('Dauer: ${fmtDur(duration)}');
          buf.writeln(
            'Google Maps: http://maps.google.com/?q=${place.lat.toStringAsFixed(6)},${place.lng.toStringAsFixed(6)}',
          );
          if (persons.isNotEmpty) {
            buf.writeln('Personen: ${persons.map((p) => p.name).join(', ')}');
          }
          if (activities.isNotEmpty) {
            buf.writeln(
              'T\u00e4tigkeiten: ${activities.map((a) => a.description).join(', ')}',
            );
          }
          if (ended.notes.isNotEmpty) {
            buf.writeln(ended.notes);
          }

          final text = buf.toString().trimRight();

          if (ended.matrixEventId != null) {
            await MatrixService.instance.editMessage(
              conn,
              ended.matrixEventId!,
              text,
            );
          } else {
            final result = await MatrixService.instance.sendMessage(conn, text);
            if (result.success && result.eventId != null) {
              await DatabaseService.instance.updateStay(
                ended.copyWith(matrixEventId: result.eventId),
              );
            }
          }
        }
      }
    }

    _activeStays.remove(placeUuid);
    _activePlaces.remove(placeUuid);
  }

  /// Ends the active stay at an unknown location (no calendar/telegram).
  Future<void> _endUnknownStay(int endTime) async {
    final stay = _unknownStay;
    if (stay == null) return;
    final ended = stay.copyWith(endTime: endTime, status: StayStatus.completed);
    await DatabaseService.instance.updateStay(ended);
    _unknownStay = null;
  }

  /// Ends all active known-place stays.
  Future<void> _endAllKnownStays(int endTime) async {
    for (final uuid in _activeStays.keys.toList()) {
      await _endStay(uuid, endTime);
    }
  }

  /// Ends all active stays (known places + unknown stay).
  Future<void> _endAllStays(int endTime) async {
    await _endAllKnownStays(endTime);
    await _endUnknownStay(endTime);
  }

  /// Call when tracking is disabled to cleanly end any active stay.
  Future<void> stopTracking() async {
    await _endAllStays(DateTime.now().millisecondsSinceEpoch);
    _setStatus(TrackingStatus.idle);
  }

  /// Immediately ends all current stays (as if the user left) but keeps the
  /// engine running so the next GPS tick can start new stays right away.
  /// After this call the status is reset to [TrackingStatus.moving].
  Future<void> forceEndCurrentStay() async {
    if (_activeStays.isEmpty && _unknownStay == null) return;
    await _endAllStays(DateTime.now().millisecondsSinceEpoch);
    _setStatus(TrackingStatus.moving);
  }

  void _setStatus(TrackingStatus newStatus) {
    if (newStatus != _status) {
      _statusSince = DateTime.now().millisecondsSinceEpoch;
    }
    _status = newStatus;
  }

  TrackingResult _result() {
    String fmtDur(Duration dur) {
      final h = dur.inHours;
      final m = dur.inMinutes.remainder(60);
      return h > 0 ? '${h}h\u00a0${m}min' : '${m}min';
    }

    String trunc(String s, int max) =>
        s.length <= max ? s : '${s.substring(0, max - 1)}\u2026';

    final now = DateTime.now().millisecondsSinceEpoch;
    final primary = currentPlace;
    final primaryStay = currentStay;
    String notifText;
    switch (_status) {
      case TrackingStatus.haltAtKnown:
        final name = trunc(primary?.name ?? 'Bekannter Ort', 22);
        final dur = primaryStay != null
            ? fmtDur(Duration(milliseconds: now - primaryStay.startTime))
            : null;
        final extra = _activeStays.length > 1
            ? ' (+${_activeStays.length - 1})'
            : '';
        notifText = dur != null ? '$name$extra · $dur' : '$name$extra';
      case TrackingStatus.haltAtUnknown:
        final label = trunc(_unknownStay?.address ?? 'Unbekannter Ort', 22);
        final dur = _unknownStay != null
            ? fmtDur(Duration(milliseconds: now - _unknownStay!.startTime))
            : null;
        notifText = dur != null ? 'Halten: $label · $dur' : 'Halten: $label';
      case TrackingStatus.detectingHalt:
        final dur = fmtDur(Duration(milliseconds: now - _statusSince));
        notifText = 'Aufenthalt wird erkannt seit $dur';
      case TrackingStatus.moving:
        final dur = fmtDur(Duration(milliseconds: now - _statusSince));
        notifText = 'Unterwegs seit $dur';
      case TrackingStatus.idle:
        final dur = fmtDur(Duration(milliseconds: now - _statusSince));
        notifText = 'Tracking aktiv seit $dur';
    }
    return TrackingResult(
      status: _status,
      currentStay: primaryStay,
      currentPlace: primary,
      notificationText: notifText,
      allActiveStays: _activeStays.values.toList(),
      allActivePlaces: _activePlaces.values.toList(),
    );
  }
}
