import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/place_group.dart';
import '../models/stay.dart';
import '../models/stay_activity.dart';
import '../models/stay_person.dart';

class CalendarService {
  CalendarService._();
  static final CalendarService instance = CalendarService._();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  bool _tzInitialized = false;

  void _initTz() {
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  /// Request calendar permissions. Returns true if granted.
  Future<bool> requestPermissions() async {
    final result = await _plugin.requestPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  /// Returns all available calendars on the device.
  Future<List<Calendar>> loadCalendars() async {
    final result = await _plugin.retrieveCalendars();
    if (result.isSuccess && result.data != null) {
      return result.data!.where((c) => !(c.isReadOnly ?? true)).toList();
    }
    return [];
  }

  // ── Stay Events ──────────────────────────────────────────────────────────

  /// Create a preliminary calendar event when a stay **starts** (arrival).
  /// Uses a 1-hour placeholder as end time; call [updateStayEvent] later to
  /// fill in the real end time and all details.
  /// Returns the event ID or null.
  Future<String?> createArrivalEvent(
    Stay stay,
    PlaceGroup group,
    String? placeName, {
    required String calendarId,
  }) async {
    final calId = calendarId;
    _initTz();

    final location = tz.local;
    final start = tz.TZDateTime.from(stay.startDateTime, location);
    // Placeholder end: start + 1 hour (will be corrected on departure)
    final end = tz.TZDateTime.from(
      stay.startDateTime.add(const Duration(hours: 1)),
      location,
    );

    final title = placeName ?? stay.address ?? 'Aufenthalt';

    final event = Event(
      calId,
      title: title,
      start: start,
      end: end,
      description: 'Ankunft',
    );

    final result = await _plugin.createOrUpdateEvent(event);
    if (result != null && result.isSuccess) {
      return result.data;
    }
    return null;
  }

  /// Create a calendar event for a completed stay.
  /// Returns the event ID or null.
  Future<String?> createStayEvent(
    Stay stay,
    PlaceGroup group,
    String? placeName, {
    required String calendarId,
    List<StayPerson> persons = const [],
    List<StayActivity> activities = const [],
    double? lat,
    double? lng,
  }) async {
    final calId = calendarId;
    if (stay.status != StayStatus.completed) return null;
    _initTz();

    final location = tz.local;
    final start = tz.TZDateTime.from(stay.startDateTime, location);
    final end = tz.TZDateTime.from(stay.endDateTime!, location);

    final title = placeName ?? stay.address ?? 'Aufenthalt';
    final description = _buildStayDescription(
      stay: stay,
      group: group,
      persons: persons,
      activities: activities,
      lat: lat,
      lng: lng,
    );

    final event = Event(
      calId,
      title: title,
      start: start,
      end: end,
      description: description,
    );

    final result = await _plugin.createOrUpdateEvent(event);
    if (result != null && result.isSuccess) {
      return result.data;
    }
    return null;
  }

  /// Update a stay event (e.g. after notes/persons/activities change).
  /// Returns true if the update succeeded, false if the event no longer exists
  /// or the group has no calendar configured.
  Future<bool> updateStayEvent(
    Stay stay,
    PlaceGroup group,
    String? placeName, {
    required String calendarId,
    List<StayPerson> persons = const [],
    List<StayActivity> activities = const [],
    double? lat,
    double? lng,
  }) async {
    if (stay.calendarEventId == null) return false;
    final calId = calendarId;
    _initTz();

    final location = tz.local;
    final start = tz.TZDateTime.from(stay.startDateTime, location);
    final end = tz.TZDateTime.from(
      stay.endDateTime ?? DateTime.now(),
      location,
    );

    final title = placeName ?? stay.address ?? 'Aufenthalt';
    final description = _buildStayDescription(
      stay: stay,
      group: group,
      persons: persons,
      activities: activities,
      lat: lat,
      lng: lng,
    );

    final event = Event(
      calId,
      eventId: stay.calendarEventId,
      title: title,
      start: start,
      end: end,
      description: description,
    );

    final result = await _plugin.createOrUpdateEvent(event);
    return result != null && result.isSuccess;
  }

  String _buildStayDescription({
    required Stay stay,
    required PlaceGroup group,
    required List<StayPerson> persons,
    required List<StayActivity> activities,
    double? lat,
    double? lng,
  }) {
    final lines = <String>[];

    // ── Timing header ───────────────────────────────────────────────
    String fmtDt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
    lines.add('Ankunft:  ${fmtDt(stay.startDateTime)}');
    if (stay.endDateTime != null) {
      lines.add('Abfahrt:  ${fmtDt(stay.endDateTime!)}');
      final dur = stay.endDateTime!.difference(stay.startDateTime);
      final h = dur.inHours;
      final m = dur.inMinutes.remainder(60);
      lines.add('Dauer:    ${h > 0 ? '${h}h ' : ''}${m}min');
    }

    // ── Google Maps link ─────────────────────────────────────────────
    if (lat != null && lng != null) {
      lines.add(
        'maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
      );
    }

    if (lines.isNotEmpty) lines.add('');

    if (group.includeNotes && stay.notes.isNotEmpty) {
      lines.add(stay.notes);
    }
    if (group.includePersons && persons.isNotEmpty) {
      lines.add('Personen: ${persons.map((p) => p.name).join(', ')}');
    }
    if (group.includeActivities && activities.isNotEmpty) {
      lines.add(
        'Tätigkeiten: ${activities.map((a) => a.description).join(', ')}',
      );
    }
    return lines.join('\n');
  }
}
