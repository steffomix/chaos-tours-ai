import 'dart:async';

import '../models/saved_place.dart';
import '../models/stay.dart';
import '../models/tracking_point.dart';
import '../services/calendar_service.dart';
import '../services/database_service.dart';
import '../services/nominatim_service.dart';
import '../services/settings_service.dart';
import '../services/telegram_service.dart';
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
  int _statusSince = DateTime.now().millisecondsSinceEpoch;
  Stay? _currentStay;
  SavedPlace? _currentPlace;

  /// Effective privacy type at the current halt — may be higher than
  /// [_currentPlace]'s own type when a more private place overlaps.
  PlaceType? _effectivePlaceType;

  /// Load persisted state on service start.
  Future<void> initialize() async {
    final active = await DatabaseService.instance.loadActiveStay();
    if (active != null) {
      _currentStay = active;
      if (active.placeUuid != null) {
        final places = await DatabaseService.instance.loadAllPlaces();
        _currentPlace = places
            .where((p) => p.uuid == active.placeUuid)
            .firstOrNull;
        _setStatus(TrackingStatus.haltAtKnown);
      } else {
        _setStatus(
          active.status == StayStatus.detecting
              ? TrackingStatus.detectingHalt
              : TrackingStatus.haltAtUnknown,
        );
      }
    } else {
      _setStatus(TrackingStatus.idle);
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
      // Not yet confirmed as halt — but if we were halting, end the stay
      if (_status == TrackingStatus.haltAtKnown ||
          _status == TrackingStatus.haltAtUnknown) {
        await _endCurrentStay(timestamp);
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

    // 5. Check known places — only public/private places trigger stays
    final places = await DatabaseService.instance.loadAllPlaces();
    SavedPlace? nearestPlace;
    for (final place in places) {
      if (!place.placeType.tracksStay) continue; // secret/forbidden — skip
      final dist = GeoUtils.distanceMeters(c.lat, c.lng, place.lat, place.lng);
      if (dist <= place.radius) {
        nearestPlace = place;
        break;
      }
    }

    if (nearestPlace != null) {
      // Compute effective privacy level across ALL overlapping places.
      // A secret or forbidden overlay suppresses stay tracking & calendar;
      // a private overlay on a public place suppresses only calendar.
      PlaceType effectivePlaceType = nearestPlace.placeType;
      for (final place in places) {
        final dist = GeoUtils.distanceMeters(
          c.lat,
          c.lng,
          place.lat,
          place.lng,
        );
        if (dist <= place.radius &&
            place.placeType.index > effectivePlaceType.index) {
          effectivePlaceType = place.placeType;
        }
      }
      _effectivePlaceType = effectivePlaceType;

      final stayAllowed = effectivePlaceType.tracksStay;

      // End stay if: switched to different place, OR privacy now suppresses stay.
      if (_currentStay != null &&
          (_currentStay!.placeUuid != nearestPlace.uuid || !stayAllowed)) {
        await _endCurrentStay(timestamp);
      }
      if (_currentStay == null && stayAllowed) {
        // Start a new stay anchored at the earliest point in the short window.
        await _startStay(
          placeUuid: nearestPlace.uuid,
          startTime: shortWindow.first.timestamp,
          effectivePlaceType: effectivePlaceType,
        );
      }
      _setStatus(TrackingStatus.haltAtKnown);
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
        GeoUtils.isCluster(longPts, settings.defaultRadiusMeters * 2);

    if (longIsCluster && longWindowFull) {
      // Halt at unknown place — only start a stay once
      if (_currentStay == null) {
        final longC = GeoUtils.centroid(longPts);
        await _startUnknownStay(
          startTime: longWindow.first.timestamp,
          centroidLat: longC.lat,
          centroidLng: longC.lng,
        );
      }
      _setStatus(TrackingStatus.haltAtUnknown);
      _currentPlace = null;
    } else {
      // Short window clustered, no known place, long window not complete
      if (_status == TrackingStatus.haltAtKnown ||
          _status == TrackingStatus.haltAtUnknown) {
        await _endCurrentStay(timestamp);
      }
      _setStatus(TrackingStatus.detectingHalt);
      _currentPlace = null;
    }

    return _result();
  }

  Future<void> _startStay({
    required String? placeUuid,
    required int startTime,
    PlaceType effectivePlaceType = PlaceType.public,
  }) async {
    final stay = Stay(
      placeUuid: placeUuid,
      startTime: startTime,
      status: StayStatus.active,
    );
    final stayUuid = await DatabaseService.instance.insertStay(stay);
    _currentStay = stay.copyWith(uuid: stayUuid);

    // Create arrival calendar and telegramevent — only if effective privacy allows it.
    if (placeUuid != null && effectivePlaceType.syncEnabled) {
      final places = await DatabaseService.instance.loadAllPlaces();
      final place = places.where((p) => p.uuid == placeUuid).firstOrNull;
      if (place != null) {
        await _createArrivalCalendarEvent(
          _currentStay!,
          place.name,
          place.groupUuid,
        );
        await _createArrivalTelegramMessage(
          _currentStay!,
          place.name,
          place.groupUuid,
        );
      }
    }
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
        groupUuid: settings.autoPlaceGroupUuid,
      );
      final placeUuid = await DatabaseService.instance.insertPlace(place);

      final stay = Stay(
        placeUuid: placeUuid,
        startTime: startTime,
        address: address,
        status: StayStatus.active,
      );
      final stayUuid = await DatabaseService.instance.insertStay(stay);
      _currentStay = stay.copyWith(uuid: stayUuid);

      // Create arrival calendar event for auto-created place
      final autoGroupUuid = settings.autoPlaceGroupUuid;
      if (autoGroupUuid != null) {
        final autoGroup = await DatabaseService.instance.loadPlaceGroup(
          autoGroupUuid,
        );
        if (autoGroup != null && autoGroup.placeType.syncEnabled) {
          await _createArrivalCalendarEvent(
            _currentStay!,
            autoPlaceName,
            autoGroupUuid,
          );
          await _createArrivalTelegramMessage(
            _currentStay!,
            autoPlaceName,
            autoGroupUuid,
          );
        }
      }
      return;
    }

    // No auto-create — just record the stay without a place
    final stay = Stay(
      startTime: startTime,
      address: address,
      status: StayStatus.active,
    );
    final stayUuid = await DatabaseService.instance.insertStay(stay);
    _currentStay = stay.copyWith(uuid: stayUuid);
  }

  /// Creates a preliminary "arrival" calendar event for [stay] and persists
  /// the returned event ID back to the database.
  Future<void> _createArrivalCalendarEvent(
    Stay stay,
    String? placeName,
    String? groupUuid,
  ) async {
    if (!SettingsService.instance.calendarEnabled) return;
    if (groupUuid == null) return;
    final group = await DatabaseService.instance.loadPlaceGroup(groupUuid);
    if (group == null || group.calendarId == null) return;

    final eventId = await CalendarService.instance.createArrivalEvent(
      stay,
      group,
      placeName,
    );
    if (eventId != null) {
      final updated = stay.copyWith(calendarEventId: eventId);
      await DatabaseService.instance.updateStay(updated);
      _currentStay = updated;
    }
  }

  /// Sends an arrival Telegram message for [stay] and persists the message ID.
  Future<void> _createArrivalTelegramMessage(
    Stay stay,
    String? placeName,
    String? groupUuid,
  ) async {
    if (groupUuid == null) return;
    final group = await DatabaseService.instance.loadPlaceGroup(groupUuid);
    if (group == null || group.telegramConnectionUuid == null) return;
    final conn = await DatabaseService.instance.loadTelegramConnection(
      group.telegramConnectionUuid!,
    );
    if (conn == null) return;

    String esc(String s) => s.replaceAllMapped(
      RegExp(r'[_*\[\]()~`>#+\-=|{}.!\\]'),
      (m) => '\\${m[0]}',
    );

    final title = placeName ?? stay.address ?? 'Unbekannter Ort';
    final d = DateTime.fromMillisecondsSinceEpoch(stay.startTime);
    final fmtTime =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final text = '\u{1F4CD} *${esc(title)}*\nAnkunft: ${esc(fmtTime)}';

    final result = await TelegramService.instance.sendMessage(conn, text);
    if (result.success && result.messageId != null) {
      final updated = stay.copyWith(telegramMessageId: result.messageId);
      await DatabaseService.instance.updateStay(updated);
      _currentStay = updated;
    }
  }

  Future<void> _endCurrentStay(int endTime) async {
    final stay = _currentStay;
    if (stay == null) return;
    final ended = stay.copyWith(endTime: endTime, status: StayStatus.completed);
    await DatabaseService.instance.updateStay(ended);

    // Calendar sync: update the existing arrival event, or create a new one
    // if it was never created or has been deleted in the meantime.
    final place = _currentPlace;
    // Use effective privacy level for calendar decisions — a more private
    // overlapping place may have suppressed calendar sync.
    final calendarType = _effectivePlaceType ?? place?.placeType;
    if (place != null &&
        SettingsService.instance.calendarEnabled &&
        (calendarType?.syncEnabled ?? false) &&
        place.groupUuid != null) {
      final group = await DatabaseService.instance.loadPlaceGroup(
        place.groupUuid!,
      );
      if (group != null) {
        // Load persons & activities for the full description
        final persons = await DatabaseService.instance.loadPersonsForStay(
          ended.uuid,
        );
        final activities = await DatabaseService.instance.loadActivitiesForStay(
          ended.uuid,
        );

        bool updated = false;
        if (ended.calendarEventId != null) {
          // Try to update the existing arrival event
          updated = await CalendarService.instance.updateStayEvent(
            ended,
            group,
            place.name,
            persons: persons.cast(),
            activities: activities.cast(),
            lat: place.lat,
            lng: place.lng,
          );
        }
        if (!updated) {
          // Arrival event missing or deleted — create a fresh completed event
          final eventId = await CalendarService.instance.createStayEvent(
            ended,
            group,
            place.name,
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

    // Telegram sync: edit the arrival message with departure details, or send
    // a new departure message if no arrival message was recorded.
    if (place != null && place.groupUuid != null) {
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
            '[Google Maps](http://maps\.google\.com/?q=${place.lat.toStringAsFixed(6)},${place.lng.toStringAsFixed(6)})',
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

    _currentStay = null;
    _currentPlace = null;
    _effectivePlaceType = null;
  }

  /// Call when tracking is disabled to cleanly end any active stay.
  Future<void> stopTracking() async {
    if (_currentStay != null) {
      await _endCurrentStay(DateTime.now().millisecondsSinceEpoch);
    }
    _setStatus(TrackingStatus.idle);
  }

  /// Immediately ends the current stay (as if the user left) but keeps the
  /// engine running so the next GPS tick can start a new stay right away.
  /// After this call the status is reset to [TrackingStatus.moving] so that
  /// the state machine re-evaluates on the next point.
  Future<void> forceEndCurrentStay() async {
    if (_currentStay == null) return;
    await _endCurrentStay(DateTime.now().millisecondsSinceEpoch);
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
    String notifText;
    switch (_status) {
      case TrackingStatus.haltAtKnown:
        final name = trunc(_currentPlace?.name ?? 'Bekannter Ort', 22);
        final dur = _currentStay != null
            ? fmtDur(Duration(milliseconds: now - _currentStay!.startTime))
            : null;
        notifText = dur != null ? '$name · $dur' : name;
      case TrackingStatus.haltAtUnknown:
        final label = trunc(_currentStay?.address ?? 'Unbekannter Ort', 22);
        final dur = _currentStay != null
            ? fmtDur(Duration(milliseconds: now - _currentStay!.startTime))
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
      currentStay: _currentStay,
      currentPlace: _currentPlace,
      notificationText: notifText,
    );
  }
}
