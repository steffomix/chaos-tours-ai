import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/place_group.dart';
import '../models/stay.dart';
import '../models/stay_activity.dart';
import '../models/stay_person.dart';
import '../models/tour.dart';

class CalendarService {
  CalendarService._();
  static final CalendarService instance = CalendarService._();

  static const String _calendarName = 'Chaos Tours';

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  String? _calendarId;

  bool _tzInitialized = false;

  void _initTz() {
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  /// Ensure we have (or create) the app calendar.
  Future<String?> _ensureCalendar() async {
    if (_calendarId != null) return _calendarId;

    final result = await _plugin.retrieveCalendars();
    if (result.isSuccess && result.data != null) {
      final existing = result.data!.firstWhere(
        (c) => c.name == _calendarName,
        orElse: () => Calendar(),
      );
      if (existing.id != null) {
        _calendarId = existing.id;
        return _calendarId;
      }
    }

    // Create a new calendar
    final createResult = await _plugin.createCalendar(_calendarName);
    if (createResult.isSuccess && createResult.data != null) {
      _calendarId = createResult.data;
    }
    return _calendarId;
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

  /// Create a calendar event for a new tour. Returns the event ID or null.
  Future<String?> createTourEvent(Tour tour) async {
    _initTz();
    final calId = await _ensureCalendar();
    if (calId == null) return null;

    final location = tz.local;
    final start = tz.TZDateTime.from(tour.startDateTime, location);
    final end = tz.TZDateTime.from(
      tour.endDateTime ?? tour.startDateTime.add(const Duration(hours: 1)),
      location,
    );

    final event = Event(calId, title: tour.name, start: start, end: end);

    final result = await _plugin.createOrUpdateEvent(event);
    if (result != null && result.isSuccess) {
      return result.data;
    }
    return null;
  }

  /// Update an existing calendar event when the tour ends.
  Future<void> updateTourEvent(Tour tour) async {
    if (tour.calendarEventId == null) return;
    _initTz();
    final calId = await _ensureCalendar();
    if (calId == null) return;

    final location = tz.local;
    final start = tz.TZDateTime.from(tour.startDateTime, location);
    final end = tz.TZDateTime.from(
      tour.endDateTime ?? DateTime.now(),
      location,
    );

    final event = Event(
      calId,
      eventId: tour.calendarEventId,
      title: tour.name,
      start: start,
      end: end,
    );

    await _plugin.createOrUpdateEvent(event);
  }

  /// Delete a calendar event for a tour.
  Future<void> deleteTourEvent(Tour tour) async {
    if (tour.calendarEventId == null) return;
    final calId = await _ensureCalendar();
    if (calId == null) return;
    await _plugin.deleteEvent(calId, tour.calendarEventId!);
  }

  // ── Stay Events ──────────────────────────────────────────────────────────

  /// Create a calendar event for a completed stay.
  /// Returns the event ID or null.
  Future<String?> createStayEvent(
    Stay stay,
    PlaceGroup group,
    String? placeName, {
    List<StayPerson> persons = const [],
    List<StayActivity> activities = const [],
  }) async {
    final calId = group.calendarId;
    if (calId == null) return null;
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
  Future<void> updateStayEvent(
    Stay stay,
    PlaceGroup group,
    String? placeName, {
    List<StayPerson> persons = const [],
    List<StayActivity> activities = const [],
  }) async {
    if (stay.calendarEventId == null) return;
    final calId = group.calendarId;
    if (calId == null) return;
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
    );

    final event = Event(
      calId,
      eventId: stay.calendarEventId,
      title: title,
      start: start,
      end: end,
      description: description,
    );

    await _plugin.createOrUpdateEvent(event);
  }

  String _buildStayDescription({
    required Stay stay,
    required PlaceGroup group,
    required List<StayPerson> persons,
    required List<StayActivity> activities,
  }) {
    final lines = <String>[];
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
