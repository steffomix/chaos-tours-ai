import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/aktivitaet.dart';

/// When the app scans the local network for P2P mesh nodes.
enum NodeScanMode {
  /// Scan periodically, every N GPS sampling intervals.
  perGpsInterval,

  /// Scan only when the tracking engine registers a halt at a place.
  onHalt,
}

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _keyGpsInterval = 'gps_interval_seconds';
  static const String _keyStayDetection = 'stay_detection_seconds';
  static const String _keyAutoPlace = 'auto_place_seconds';
  static const String _keyDefaultRadius = 'default_radius_meters';
  static const String _keyAutoCreate = 'auto_create_places';
  static const String _keyAutoPlaceGroup = 'auto_place_group_uuid';
  static const String _keyDefaultPlaceGroup = 'default_place_group_uuid';
  static const String _keyTrackingEnabled = 'tracking_enabled';
  static const String _keyActiveAktivitaetId = 'active_aktivitaet_uuid';
  static const String _keyShowForbiddenPlaces = 'show_forbidden_places';
  static const String _keyShowTrackingPoints = 'show_tracking_points';
  static const String _keyTrackingPointRadius = 'tracking_point_radius';
  static const String _keyGpsSmoothingPoints = 'gps_smoothing_points';
  static const String _keyCalendarEnabled = 'calendar_enabled';
  static const String _keyTimelineHistoryDays = 'timeline_history_days';
  static const String _keyForceEndStayPending = 'force_end_stay_pending';
  static const String _keyAddressOnAutoCreate = 'address_on_auto_create';
  static const String _keyAddressOnManualCreate = 'address_on_manual_create';
  static const String _keyAddressOnInterval = 'address_on_interval';
  static const String _keyNominatimUserAgent = 'nominatim_user_agent';
  static const String _keySearchCountry = 'search_country';
  static const String _keySchedulerColorRange = 'scheduler_color_range';
  static const String _keySchedulerGroupIds = 'scheduler_group_ids';
  static const String _keyFilterRequireExperiences =
      'filter_require_experiences';
  static const String _keyFilterMinAvgRating = 'filter_min_avg_rating';
  static const String _keyFilterDistanceEnabled = 'filter_distance_enabled';
  static const String _keyFilterMaxDistanceKm = 'filter_max_distance_km';
  static const String _keyFilterUseMedian = 'filter_use_median';
  static const String _keyFilterUseSpecificRating =
      'filter_use_specific_rating';
  static const String _keyFilterSpecificRatingField =
      'filter_specific_rating_field';
  static const String _keyLastSyncMs = 'sync_last_ms';
  static const String _keyDeviceId = 'device_id';
  static const String _keyPhotoMaxWidth = 'photo_max_width';
  static const String _keyPhotoMaxHeight = 'photo_max_height';
  static const String _keyPhotoImageQuality = 'photo_image_quality';
  static const String _keyGroupCalendarIds = 'group_calendar_ids';
  static const String _keyTelegramBotTokens = 'telegram_bot_tokens';
  static const String _keyDevToolsUnlockedUntilMs =
      'dev_tools_unlocked_until_ms';

  // ── P2P Messenger / mesh sync ─────────────────────────────────────────────
  static const String _keyMessengerEnabled = 'messenger_enabled';
  static const String _keyCreatePlaceOnSyncOpportunity =
      'create_place_on_sync_opportunity';
  static const String _keySyncSourcePlaceGroup = 'sync_source_place_group_uuid';
  static const String _keySyncPhotosEnabled = 'sync_photos_enabled';
  static const String _keyPhotoSyncMaxBytes = 'photo_sync_max_bytes';
  static const String _keyNodeScanMode = 'node_scan_mode';
  static const String _keyNodeScanIntervalPerGps = 'node_scan_interval_per_gps';
  static const String _keyRegionMessageRadiusKm = 'region_message_radius_km';

  SharedPreferences? _prefs;

  /// Broadcasts the GPS interval whenever it is changed via the setter.
  final ValueNotifier<int> gpsIntervalNotifier = ValueNotifier<int>(60);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    gpsIntervalNotifier.value = gpsIntervalSeconds;
  }

  /// Reload values from disk — call this in the service isolate before reading
  /// values that may have been written by the main isolate.
  Future<void> reload() async {
    await _prefs?.reload();
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'SettingsService.init() must be called before use');
    return _prefs!;
  }

  /// Full device ID used in all database records: "name@uuid".
  /// Set once at Aktivität creation and never changed individually.
  String get deviceId => _p.getString(_keyDeviceId) ?? '';
  set deviceId(String v) => _p.setString(_keyDeviceId, v);

  /// Timestamp of the last successful sync in milliseconds since epoch (0 = never).
  int get lastSyncMs => _p.getInt(_keyLastSyncMs) ?? 0;
  set lastSyncMs(int v) => _p.setInt(_keyLastSyncMs, v);

  /// Timestamp (ms since epoch) until which the potentially destructive
  /// developer tools remain unlocked (0 = locked).
  int get devToolsUnlockedUntilMs =>
      _p.getInt(_keyDevToolsUnlockedUntilMs) ?? 0;
  set devToolsUnlockedUntilMs(int v) =>
      _p.setInt(_keyDevToolsUnlockedUntilMs, v);

  /// Whether the developer tools are currently unlocked (within the hour).
  bool get devToolsUnlocked =>
      DateTime.now().millisecondsSinceEpoch < devToolsUnlockedUntilMs;

  /// Maximum width in pixels when capturing/picking photos (0 = unlimited, default: 1920).
  int get photoMaxWidth => _p.getInt(_keyPhotoMaxWidth) ?? 1920;
  set photoMaxWidth(int v) => _p.setInt(_keyPhotoMaxWidth, v.clamp(0, 8192));

  /// Maximum height in pixels when capturing/picking photos (0 = unlimited, default: 1080).
  int get photoMaxHeight => _p.getInt(_keyPhotoMaxHeight) ?? 1080;
  set photoMaxHeight(int v) => _p.setInt(_keyPhotoMaxHeight, v.clamp(0, 8192));

  /// JPEG quality (1–100) when capturing/picking photos (default: 75).
  int get photoImageQuality => _p.getInt(_keyPhotoImageQuality) ?? 75;
  set photoImageQuality(int v) =>
      _p.setInt(_keyPhotoImageQuality, v.clamp(1, 100));

  /// GPS sampling interval in seconds (default: 60).
  int get gpsIntervalSeconds => _p.getInt(_keyGpsInterval) ?? 60;
  set gpsIntervalSeconds(int v) {
    final clamped = v.clamp(10, 180);
    _p.setInt(_keyGpsInterval, clamped);
    gpsIntervalNotifier.value = clamped;
  }

  /// Duration in seconds for stay detection at known places (default: 300 = 5 min).
  int get stayDetectionSeconds => _p.getInt(_keyStayDetection) ?? 300;
  set stayDetectionSeconds(int v) =>
      _p.setInt(_keyStayDetection, v.clamp(180, 600));

  /// Duration in seconds before auto-creating a place (default: 900 = 15 min).
  int get autoPlaceSeconds => _p.getInt(_keyAutoPlace) ?? 900;
  set autoPlaceSeconds(int v) => _p.setInt(_keyAutoPlace, v.clamp(300, 3600));

  /// Default radius in meters for stay detection (default: 50).
  double get defaultRadiusMeters => _p.getDouble(_keyDefaultRadius) ?? 50.0;
  set defaultRadiusMeters(double v) =>
      _p.setDouble(_keyDefaultRadius, v.clamp(10.0, 500.0));

  /// Whether to automatically create places for unknown stays (default: true).
  bool get autoCreatePlaces => _p.getBool(_keyAutoCreate) ?? true;
  set autoCreatePlaces(bool v) => _p.setBool(_keyAutoCreate, v);

  // ── P2P Messenger / mesh sync ─────────────────────────────────────────────

  /// Whether the P2P messenger feature is enabled (default: true).
  bool get messengerEnabled => _p.getBool(_keyMessengerEnabled) ?? true;
  set messengerEnabled(bool v) => _p.setBool(_keyMessengerEnabled, v);

  /// When a sync opportunity is detected and no place is nearby, create a
  /// "Sync-Quelle" place automatically — even if [autoCreatePlaces] is off.
  /// Location-bound messages require a place to anchor to (default: true).
  bool get createPlaceOnSyncOpportunity =>
      _p.getBool(_keyCreatePlaceOnSyncOpportunity) ?? true;
  set createPlaceOnSyncOpportunity(bool v) =>
      _p.setBool(_keyCreatePlaceOnSyncOpportunity, v);

  /// UUID of the group assigned to auto-created "Sync-Quelle" places. The group
  /// carries [PlaceType.syncSource]. Nullable until first created.
  String? get syncSourcePlaceGroupUuid =>
      _p.getString(_keySyncSourcePlaceGroup);
  set syncSourcePlaceGroupUuid(String? v) {
    if (v == null || v.isEmpty) {
      _p.remove(_keySyncSourcePlaceGroup);
    } else {
      _p.setString(_keySyncSourcePlaceGroup, v);
    }
  }

  /// Whether photos are included in mesh sync transport (default: true).
  bool get syncPhotosEnabled => _p.getBool(_keySyncPhotosEnabled) ?? true;
  set syncPhotosEnabled(bool v) => _p.setBool(_keySyncPhotosEnabled, v);

  /// Maximum photo size in bytes eligible for sync (0 = no limit).
  /// Photos larger than this are skipped during sync (default: 512 KiB).
  int get photoSyncMaxBytes => _p.getInt(_keyPhotoSyncMaxBytes) ?? 524288;
  set photoSyncMaxBytes(int v) =>
      _p.setInt(_keyPhotoSyncMaxBytes, v < 0 ? 0 : v);

  /// When the app scans for local mesh nodes (default: onHalt).
  NodeScanMode get nodeScanMode {
    final raw = _p.getInt(_keyNodeScanMode) ?? NodeScanMode.onHalt.index;
    return NodeScanMode.values[raw.clamp(0, NodeScanMode.values.length - 1)];
  }

  set nodeScanMode(NodeScanMode v) => _p.setInt(_keyNodeScanMode, v.index);

  /// In [NodeScanMode.perGpsInterval], scan every N GPS intervals (default: 4).
  int get nodeScanIntervalPerGps => _p.getInt(_keyNodeScanIntervalPerGps) ?? 4;
  set nodeScanIntervalPerGps(int v) =>
      _p.setInt(_keyNodeScanIntervalPerGps, v.clamp(1, 100));

  /// Radius in km for the "messages of the region" map view (default: 5.0).
  double get regionMessageRadiusKm =>
      _p.getDouble(_keyRegionMessageRadiusKm) ?? 5.0;
  set regionMessageRadiusKm(double v) =>
      _p.setDouble(_keyRegionMessageRadiusKm, v.clamp(0.1, 500.0));

  /// UUID of group for automatically created places (nullable).
  String? get autoPlaceGroupUuid => _p.getString(_keyAutoPlaceGroup);
  set autoPlaceGroupUuid(String? v) {
    if (v == null || v.isEmpty) {
      _p.remove(_keyAutoPlaceGroup);
    } else {
      _p.setString(_keyAutoPlaceGroup, v);
    }
  }

  /// UUID of group pre-selected when the user creates a place manually (nullable).
  String? get defaultPlaceGroupUuid => _p.getString(_keyDefaultPlaceGroup);
  set defaultPlaceGroupUuid(String? v) {
    if (v == null || v.isEmpty) {
      _p.remove(_keyDefaultPlaceGroup);
    } else {
      _p.setString(_keyDefaultPlaceGroup, v);
    }
  }

  /// Whether the background tracking service is enabled (default: false).
  bool get trackingEnabled => _p.getBool(_keyTrackingEnabled) ?? false;
  set trackingEnabled(bool v) => _p.setBool(_keyTrackingEnabled, v);

  /// Whether forbidden places are shown in the places list (default: false).
  bool get showForbiddenPlaces => _p.getBool(_keyShowForbiddenPlaces) ?? false;
  set showForbiddenPlaces(bool v) => _p.setBool(_keyShowForbiddenPlaces, v);

  /// Whether tracking points are shown on the map (default: true).
  bool get showTrackingPoints => _p.getBool(_keyShowTrackingPoints) ?? true;
  set showTrackingPoints(bool v) => _p.setBool(_keyShowTrackingPoints, v);

  /// Radius in meters for tracking point circles on the map (default: 2.0).
  double get trackingPointRadius =>
      _p.getDouble(_keyTrackingPointRadius) ?? 2.0;
  set trackingPointRadius(double v) =>
      _p.setDouble(_keyTrackingPointRadius, v.clamp(1.0, 20.0));

  /// Number of GPS points to average for smoothing (1 = disabled, default: 3).
  int get gpsSmoothingPoints => _p.getInt(_keyGpsSmoothingPoints) ?? 3;
  set gpsSmoothingPoints(int v) =>
      _p.setInt(_keyGpsSmoothingPoints, v.clamp(1, 10));

  /// Whether calendar sync is globally enabled (default: true).
  bool get calendarEnabled => _p.getBool(_keyCalendarEnabled) ?? true;
  set calendarEnabled(bool v) => _p.setBool(_keyCalendarEnabled, v);

  /// How many days of stay history are shown on the timeline map (7-90, default: 30).
  int get timelineHistoryDays => _p.getInt(_keyTimelineHistoryDays) ?? 30;
  set timelineHistoryDays(int v) =>
      _p.setInt(_keyTimelineHistoryDays, v.clamp(7, 90));

  /// Set by the UI to request a force-end of the current stay.
  /// The task isolate reads and clears this flag at the start of each tick.
  bool get forceEndStayPending => _p.getBool(_keyForceEndStayPending) ?? false;
  set forceEndStayPending(bool v) => _p.setBool(_keyForceEndStayPending, v);

  /// Whether to query the address (Nominatim) when a place is auto-created
  /// during tracking (default: true).
  bool get addressOnAutoCreate => _p.getBool(_keyAddressOnAutoCreate) ?? true;
  set addressOnAutoCreate(bool v) => _p.setBool(_keyAddressOnAutoCreate, v);

  /// Whether to pre-fill the address as the name when the user creates a place
  /// manually via long-press on the map (default: true).
  bool get addressOnManualCreate =>
      _p.getBool(_keyAddressOnManualCreate) ?? true;
  set addressOnManualCreate(bool v) => _p.setBool(_keyAddressOnManualCreate, v);

  /// Whether to query the address on every GPS tracking interval and show it
  /// on the home screen (default: false).
  bool get addressOnInterval => _p.getBool(_keyAddressOnInterval) ?? false;
  set addressOnInterval(bool v) => _p.setBool(_keyAddressOnInterval, v);

  /// Custom HTTP User-Agent for Nominatim requests. Device-local (never synced).
  /// Empty string means the built-in default is used.
  String get nominatimUserAgent => _p.getString(_keyNominatimUserAgent) ?? '';
  set nominatimUserAgent(String v) =>
      _p.setString(_keyNominatimUserAgent, v.trim());

  /// Default country pre-filled in the map address search (e.g. 'Deutschland').
  String get searchCountry => _p.getString(_keySearchCountry) ?? '';
  set searchCountry(String v) => _p.setString(_keySearchCountry, v);

  /// Color range in days for the scheduler urgency indicator (default: 14).
  int get schedulerColorRange => _p.getInt(_keySchedulerColorRange) ?? 14;
  set schedulerColorRange(int v) =>
      _p.setInt(_keySchedulerColorRange, v.clamp(1, 365));

  // ── Group calendar mapping (device-local, never synced) ────────────────

  /// Returns the device calendar ID linked to [groupUuid], or null.
  String? getGroupCalendarId(String groupUuid) {
    final raw = _p.getString(_keyGroupCalendarIds);
    if (raw == null || raw.isEmpty) return null;
    final map = Map<String, String>.from(
      (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
    return map[groupUuid];
  }

  /// Sets or clears the device calendar ID for [groupUuid].
  Future<void> setGroupCalendarId(String groupUuid, String? calendarId) async {
    final raw = _p.getString(_keyGroupCalendarIds);
    final map = <String, String>{};
    if (raw != null && raw.isNotEmpty) {
      map.addAll(
        Map<String, String>.from(
          (jsonDecode(raw) as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, v as String),
          ),
        ),
      );
    }
    if (calendarId == null) {
      map.remove(groupUuid);
    } else {
      map[groupUuid] = calendarId;
    }
    await _p.setString(_keyGroupCalendarIds, jsonEncode(map));
  }

  /// Removes all calendar mappings for the given group UUIDs (e.g. after group deletion).
  Future<void> removeGroupCalendarIds(List<String> groupUuids) async {
    if (groupUuids.isEmpty) return;
    final raw = _p.getString(_keyGroupCalendarIds);
    if (raw == null || raw.isEmpty) return;
    final map = Map<String, String>.from(
      (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
    for (final uuid in groupUuids) {
      map.remove(uuid);
    }
    await _p.setString(_keyGroupCalendarIds, jsonEncode(map));
  }

  // ── Telegram bot-token mapping (device-local, never synced) ────────────

  /// Returns the bot token linked to [connectionUuid], or null.
  String? getTelegramBotToken(String connectionUuid) {
    final raw = _p.getString(_keyTelegramBotTokens);
    if (raw == null || raw.isEmpty) return null;
    final map = Map<String, String>.from(
      (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
    return map[connectionUuid];
  }

  /// Sets or clears the bot token for [connectionUuid].
  Future<void> setTelegramBotToken(String connectionUuid, String? token) async {
    final raw = _p.getString(_keyTelegramBotTokens);
    final map = <String, String>{};
    if (raw != null && raw.isNotEmpty) {
      map.addAll(
        Map<String, String>.from(
          (jsonDecode(raw) as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, v as String),
          ),
        ),
      );
    }
    if (token == null || token.isEmpty) {
      map.remove(connectionUuid);
    } else {
      map[connectionUuid] = token;
    }
    await _p.setString(_keyTelegramBotTokens, jsonEncode(map));
  }

  /// Removes bot tokens for the given connection UUIDs (e.g. after deletion).
  Future<void> removeTelegramBotTokens(List<String> connectionUuids) async {
    if (connectionUuids.isEmpty) return;
    final raw = _p.getString(_keyTelegramBotTokens);
    if (raw == null || raw.isEmpty) return;
    final map = Map<String, String>.from(
      (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
    for (final uuid in connectionUuids) {
      map.remove(uuid);
    }
    await _p.setString(_keyTelegramBotTokens, jsonEncode(map));
  }

  /// Comma-separated group UUIDs to display in map and scheduler (empty = all).
  String get schedulerGroupIds => _p.getString(_keySchedulerGroupIds) ?? '';
  set schedulerGroupIds(String v) => _p.setString(_keySchedulerGroupIds, v);

  /// Parses [schedulerGroupIds] into a list of UUID strings (empty = all groups).
  List<String> get schedulerGroupUuidList {
    final raw = schedulerGroupIds;
    if (raw.isEmpty) return [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ── Experience / distance filter ────────────────────────────────────────

  bool get filterRequireExperiences =>
      _p.getBool(_keyFilterRequireExperiences) ?? false;
  set filterRequireExperiences(bool v) =>
      _p.setBool(_keyFilterRequireExperiences, v);

  double get filterMinAvgRating => _p.getDouble(_keyFilterMinAvgRating) ?? 0.0;
  set filterMinAvgRating(double v) => _p.setDouble(_keyFilterMinAvgRating, v);

  bool get filterDistanceEnabled =>
      _p.getBool(_keyFilterDistanceEnabled) ?? false;
  set filterDistanceEnabled(bool v) => _p.setBool(_keyFilterDistanceEnabled, v);

  double get filterMaxDistanceKm =>
      _p.getDouble(_keyFilterMaxDistanceKm) ?? 100.0;
  set filterMaxDistanceKm(double v) => _p.setDouble(_keyFilterMaxDistanceKm, v);

  bool get filterUseMedian => _p.getBool(_keyFilterUseMedian) ?? false;
  set filterUseMedian(bool v) => _p.setBool(_keyFilterUseMedian, v);

  bool get filterUseSpecificRating =>
      _p.getBool(_keyFilterUseSpecificRating) ?? false;
  set filterUseSpecificRating(bool v) =>
      _p.setBool(_keyFilterUseSpecificRating, v);

  String get filterSpecificRatingField =>
      _p.getString(_keyFilterSpecificRatingField) ?? '';
  set filterSpecificRatingField(String v) =>
      _p.setString(_keyFilterSpecificRatingField, v);

  // ── Aktivitaet binding ───────────────────────────────────────────────────

  /// The UUID of the currently selected [Aktivitaet].
  String? get activeAktivitaetUuid => _p.getString(_keyActiveAktivitaetId);
  set activeAktivitaetUuid(String? v) {
    if (v == null || v.isEmpty) {
      _p.remove(_keyActiveAktivitaetId);
    } else {
      _p.setString(_keyActiveAktivitaetId, v);
    }
  }

  /// Copies all settings from [a] into SharedPreferences so that the rest of
  /// the app picks them up synchronously, and remembers [a.id] as the active
  /// Aktivitaet.
  void applyAktivitaet(Aktivitaet a) {
    gpsIntervalSeconds = a.gpsIntervalSeconds;
    stayDetectionSeconds = a.stayDetectionSeconds;
    autoPlaceSeconds = a.autoPlaceSeconds;
    defaultRadiusMeters = a.defaultRadiusMeters;
    autoCreatePlaces = a.autoCreatePlaces;
    autoPlaceGroupUuid = a.autoPlaceGroupUuid;
    defaultPlaceGroupUuid = a.defaultPlaceGroupUuid;
    timelineHistoryDays = a.timelineHistoryDays;
    searchCountry = a.searchCountry;
    addressOnAutoCreate = a.addressOnAutoCreate;
    addressOnManualCreate = a.addressOnManualCreate;
    addressOnInterval = a.addressOnInterval;
    schedulerColorRange = a.schedulerColorRange;
    schedulerGroupIds = a.schedulerGroupIds;
    filterRequireExperiences = a.filterRequireExperiences;
    filterMinAvgRating = a.filterMinAvgRating;
    filterDistanceEnabled = a.filterDistanceEnabled;
    filterMaxDistanceKm = a.filterMaxDistanceKm;
    filterUseMedian = a.filterUseMedian;
    filterUseSpecificRating = a.filterUseSpecificRating;
    filterSpecificRatingField = a.filterSpecificRatingField;
    activeAktivitaetUuid = a.uuid;
    deviceId = a.deviceId;
  }

  /// Builds an [Aktivitaet] snapshot of the current SharedPreferences values.
  Aktivitaet snapshotAsAktivitaet({
    required String uuid,
    required String name,
  }) {
    return Aktivitaet(
      uuid: uuid,
      name: name,
      gpsIntervalSeconds: gpsIntervalSeconds,
      stayDetectionSeconds: stayDetectionSeconds,
      autoPlaceSeconds: autoPlaceSeconds,
      defaultRadiusMeters: defaultRadiusMeters,
      autoCreatePlaces: autoCreatePlaces,
      autoPlaceGroupUuid: autoPlaceGroupUuid,
      defaultPlaceGroupUuid: defaultPlaceGroupUuid,
      timelineHistoryDays: timelineHistoryDays,
      searchCountry: searchCountry,
      addressOnAutoCreate: addressOnAutoCreate,
      addressOnManualCreate: addressOnManualCreate,
      addressOnInterval: addressOnInterval,
      schedulerColorRange: schedulerColorRange,
      schedulerGroupIds: schedulerGroupIds,
      filterRequireExperiences: filterRequireExperiences,
      filterMinAvgRating: filterMinAvgRating,
      filterDistanceEnabled: filterDistanceEnabled,
      filterMaxDistanceKm: filterMaxDistanceKm,
      filterUseMedian: filterUseMedian,
      filterUseSpecificRating: filterUseSpecificRating,
      filterSpecificRatingField: filterSpecificRatingField,
      deviceId: deviceId,
    );
  }
}
