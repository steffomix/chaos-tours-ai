import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
}
