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
