// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Chaos Tours';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get search => 'Search';

  @override
  String get none => 'None';

  @override
  String get all => 'All';

  @override
  String get create => 'Create';

  @override
  String get close => 'Close';

  @override
  String get send => 'Send';

  @override
  String get apply => 'Apply';

  @override
  String get unknown => 'Unknown';

  @override
  String get version => 'Version 2.0.0';

  @override
  String get name => 'Name';

  @override
  String get reset => 'Reset';

  @override
  String get required => 'Required';

  @override
  String get description => 'Description';

  @override
  String get active => 'Active';

  @override
  String get type => 'Type';

  @override
  String get replace => 'Replace';

  @override
  String get synchronize => 'Synchronize';

  @override
  String get navHome => 'Home';

  @override
  String get navMap => 'Map';

  @override
  String get navPlaces => 'Places';

  @override
  String get navVisits => 'Visits';

  @override
  String get navPhotos => 'Photos';

  @override
  String get trackingDisabled => 'Tracking disabled';

  @override
  String get trackingRunning => 'Tracking running…';

  @override
  String get trackingActive => 'Tracking active';

  @override
  String get trackingInactive => 'Tracking inactive';

  @override
  String get trackingStatusMoving => 'Moving';

  @override
  String trackingStatusHaltKnown(String place) {
    return 'Staying at $place';
  }

  @override
  String trackingStatusHaltUnknown(String address) {
    return 'Staying: $address';
  }

  @override
  String get trackingStatusHalt => 'Staying';

  @override
  String get trackingStatusDetecting => 'Detecting stay…';

  @override
  String get trackingCollecting => 'Tracking collecting GPS data…';

  @override
  String get virtualDeviceLoading => 'Loading Virtual Device…';

  @override
  String get unknownPlace => 'Unknown place';

  @override
  String sinceHoursMinutes(int h, int m) {
    return 'For ${h}h ${m}min';
  }

  @override
  String sinceMinutes(int m) {
    return 'For ${m}min';
  }

  @override
  String get endStayNow => 'End & share stay now';

  @override
  String get endStayTitle => 'End stay?';

  @override
  String get endStayContent =>
      'The current stay will be ended now. Tracking continues and will start a new stay if you remain at the same place.';

  @override
  String get endStayButton => 'End';

  @override
  String get endStayEnding => 'Ending stay…';

  @override
  String get noVisitsYet => 'No visits recorded yet.';

  @override
  String get recentVisits => 'Recent visits';

  @override
  String get enableTracking => 'Enable tracking?';

  @override
  String get disableTracking => 'Disable tracking?';

  @override
  String get enableTrackingContent => 'Start automatic background tracking?';

  @override
  String get disableTrackingContent => 'Stop automatic background tracking?';

  @override
  String get activate => 'Activate';

  @override
  String get deactivate => 'Deactivate';

  @override
  String get batteryOptTitle => 'Disable battery optimization';

  @override
  String get batteryOptContent =>
      'The background service could not be started.\n\nPlease disable battery optimization for Chaos Tours:\nSettings → Apps → Chaos Tours → Battery → Unrestricted';

  @override
  String get openSettings => 'Open settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get sectionVirtualDevices => 'Virtual Devices';

  @override
  String get noVirtualDevices => 'No Virtual Devices';

  @override
  String virtualDevicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Virtual Devices',
      one: '$count Virtual Device',
    );
    return '$_temp0';
  }

  @override
  String get tooltipRename => 'Rename';

  @override
  String get tooltipSwitchCreate => 'Switch / Create new';

  @override
  String get deviceId => 'Device ID';

  @override
  String get deviceIdCopied => 'Device ID copied';

  @override
  String get uuidCopied => 'UUID copied';

  @override
  String get messageCopied => 'Message text copied';

  @override
  String get sectionTracking => 'Tracking';

  @override
  String gpsInterval(int value) {
    return 'GPS interval: ${value}s';
  }

  @override
  String get gpsIntervalHint =>
      'Note: Changes of the GPS interval require a complete restart of the App including the Background Tracking.';

  @override
  String gpsSmoothing(String value) {
    return 'GPS smoothing: $value';
  }

  @override
  String get gpsSmoothingDisabled => 'disabled';

  @override
  String gpsSmoothingPoints(int n) {
    return '$n points';
  }

  @override
  String get gpsSmoothingHint => 'Averages the last N GPS points.';

  @override
  String stayDetection(int min) {
    return 'Detect stay after: $min min';
  }

  @override
  String autoPlaceTime(int min) {
    return 'Create auto-place after: $min min';
  }

  @override
  String defaultRadius(String m) {
    return 'Default radius: $m m';
  }

  @override
  String get autoCreatePlaces => 'Automatically create places';

  @override
  String get autoCreatePlacesSubtitle =>
      'Create new places for long stays at unknown locations';

  @override
  String get autoPlaceGroup => 'Group for auto-places';

  @override
  String get defaultPlaceGroup => 'Default group for new places';

  @override
  String get defaultPlaceGroupSubtitle =>
      'Preset group when manually creating places';

  @override
  String get syncPlaceGroup => 'Sync source group';

  @override
  String get syncPlaceGroupSubtitle =>
      'Group for auto-created places as message sync-sources location';

  @override
  String get sectionMapDisplay => 'Map display';

  @override
  String get showGpsPoints => 'Show GPS points';

  @override
  String get showGpsPointsSubtitle =>
      'Show tracking points in color on the map';

  @override
  String pointSize(String m) {
    return 'Point size: $m m';
  }

  @override
  String visitHistory(String days) {
    return 'Visit history: $days';
  }

  @override
  String visitHistoryDay(int days) {
    return '$days day';
  }

  @override
  String visitHistoryDays(int days) {
    return '$days days';
  }

  @override
  String get visitHistoryHint =>
      'How many days of travel history are shown on the timeline map.';

  @override
  String get sectionPlanner => 'Interval Planner';

  @override
  String colorRange(int days) {
    return 'Color range: $days';
  }

  @override
  String colorRangeHint(int range) {
    return '$range days = green  •  0 = yellow  •  -$range = red';
  }

  @override
  String get shownGroups => 'Shown groups (map & planner)';

  @override
  String get noGroupsAvailable => 'No groups available';

  @override
  String get sectionAddressSearch => 'Address search';

  @override
  String get addressOnAutoCreateTitle => 'Address on automatic place creation';

  @override
  String get addressOnAutoCreateSubtitle =>
      'Query the address via OSM and use it when a place is created automatically.';

  @override
  String get addressOnManualCreateTitle => 'Address on manual place creation';

  @override
  String get addressOnManualCreateSubtitle =>
      'Query the address via OSM and pre-fill it as the name when creating a place via long-press on the map.';

  @override
  String get addressOnIntervalTitle => 'Address on every GPS interval';

  @override
  String get addressOnIntervalSubtitle =>
      'Query the address via OSM on every tracking interval and show it on the home screen.';

  @override
  String get nominatimUserAgent => 'Custom User-Agent (OSM)';

  @override
  String get nominatimUserAgentHint => 'e.g. MyApp/1.0 (contact@example.com)';

  @override
  String get nominatimUserAgentSubtitle =>
      'The User-Agent identifies the app to the OSM Nominatim service. Leave empty to use the default. If many devices share the same User-Agent, the service may throttle or block requests.';

  @override
  String get defaultCountry => 'Default country for address search';

  @override
  String get defaultCountryHint => 'e.g. Germany';

  @override
  String get defaultCountrySubtitle =>
      'Pre-filled as default country in the map address search.';

  @override
  String get sectionManagement => 'Management';

  @override
  String get placeGroups => 'Place groups';

  @override
  String get persons => 'Persons';

  @override
  String get activities => 'Activities';

  @override
  String get sectionDatabase => 'Database maintenance';

  @override
  String get databaseDump => 'Database dump';

  @override
  String get databaseDumpSubtitle => 'Create, load & share dump';

  @override
  String get dbCleanupTitle => 'Clean up database';

  @override
  String get dbCleanupSubtitle => 'Remove orphaned entries';

  @override
  String get dbCleanupConfirmTitle => 'Clean up database?';

  @override
  String get dbCleanupConfirmContent =>
      'All orphaned entries (without a valid parent record) will be permanently removed. Device ID fields are not affected.';

  @override
  String dbCleanupSuccess(int deleted) {
    return '$deleted entries deleted';
  }

  @override
  String get dbPurgeForeignDevicesTitle => 'Remove foreign device entries';

  @override
  String get dbPurgeForeignDevicesSubtitle =>
      'Delete all records from untrusted devices across all tables';

  @override
  String get dbPurgeForeignDevicesConfirmTitle =>
      'Remove foreign device entries?';

  @override
  String get dbPurgeForeignDevicesConfirmContent =>
      'All records in every table whose device ID is neither the current device nor listed as trusted will be permanently deleted. The currently active device is always treated as trusted. Broken foreign key references are not corrected.';

  @override
  String dbPurgeForeignDevicesSuccess(int deleted) {
    return '$deleted entries deleted';
  }

  @override
  String get dbPurgeDeletedTitle => 'Purge soft-deleted records';

  @override
  String get dbPurgeDeletedSubtitle =>
      'Permanently remove all records marked as deleted';

  @override
  String get dbPurgeDeletedConfirmTitle => 'Purge deleted records?';

  @override
  String get dbPurgeDeletedConfirmContent =>
      'All records across every table that have been soft-deleted (deleted_at is set) will be permanently and irrecoverably removed.';

  @override
  String dbPurgeDeletedSuccess(int deleted) {
    return '$deleted records purged';
  }

  @override
  String get syncSources => 'Sync sources';

  @override
  String get syncSourcesSubtitle => 'Manage and synchronize sync server';

  @override
  String get telegramConnections => 'Telegram connections';

  @override
  String get telegramConnectionsSubtitle =>
      'Manage Telegram bots for place reports';

  @override
  String get sectionPermissions => 'Permissions';

  @override
  String get locationPermission => 'Location permission';

  @override
  String get locationPermissionSubtitle => 'Request foreground location';

  @override
  String get backgroundLocation => 'Background location';

  @override
  String get backgroundLocationSubtitle => 'Request background location';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle => 'Request notification permission';

  @override
  String get calendarSync => 'Calendar sync';

  @override
  String get calendarSyncSubtitle =>
      'Automatically add stays to device calendar';

  @override
  String get calendarPermission => 'Request calendar permission';

  @override
  String get locationGranted => 'Location granted';

  @override
  String get locationDenied => 'Location denied';

  @override
  String get backgroundLocationGranted => 'Background location granted';

  @override
  String get backgroundLocationDenied => 'Background location denied';

  @override
  String get notificationsGranted => 'Notifications granted';

  @override
  String get notificationsDenied => 'Notifications denied';

  @override
  String get calendarGranted => 'Calendar granted';

  @override
  String get calendarDenied => 'Calendar denied';

  @override
  String get deleteLastVirtualDeviceNotAllowed =>
      'The last Virtual Device can not be deleted';

  @override
  String get deleteVirtualDevice => 'Permanently remove current Virtual Device';

  @override
  String get pickVirtualDevice => 'Select Virtual Device';

  @override
  String get newVirtualDeviceCreate => 'Create new Virtual Device';

  @override
  String get newVirtualDeviceLabel => 'New Virtual Device';

  @override
  String get copySettingsFrom => 'Copy settings from:';

  @override
  String get renameVirtualDevice => 'Rename Virtual Device';

  @override
  String get deleteVirtualDeviceTitle => 'Delete Virtual Device?';

  @override
  String deleteVirtualDeviceContent(String name) {
    return 'Really delete \"$name\"?\n\nThe settings of this Virtual Device will be permanently removed.';
  }

  @override
  String virtualDeviceDeleted(String name) {
    return '\"$name\" deleted';
  }

  @override
  String deleteVirtualDeviceLabel(String name) {
    return 'Delete \"$name\"';
  }

  @override
  String get visitsTitle => 'Visits';

  @override
  String get searchStaysHint => 'Search stays…';

  @override
  String get searchStays => 'Search stays…';

  @override
  String get closeSearch => 'Close search';

  @override
  String get filterByDate => 'Filter by date range';

  @override
  String get filterByPlace => 'Filter by place';

  @override
  String get resetFilter => 'Reset filter';

  @override
  String get tabList => 'Visits';

  @override
  String get tabJourney => 'Journey';

  @override
  String get tabPlanner => 'Planner';

  @override
  String get noStaysFound =>
      'No completed stays found.\nTurn on tracking to record stays.';

  @override
  String get toLastPosition => 'To last position';

  @override
  String get noSchedulerPlaces =>
      'No planner places available.\n\nEnable the visit interval for places in the place settings.';

  @override
  String get schedulerToday => 'Today';

  @override
  String schedulerInDays(int n) {
    return 'in $n days';
  }

  @override
  String schedulerInDay(int n) {
    return 'in $n day';
  }

  @override
  String schedulerOverdueDays(int n) {
    return '$n days overdue';
  }

  @override
  String schedulerOverdueDay(int n) {
    return '$n day overdue';
  }

  @override
  String intervalDays(int n) {
    return 'Interval: $n days';
  }

  @override
  String get allPlaces => 'All places';

  @override
  String get placesTitle => 'Places';

  @override
  String get searchPlaces => 'Search places…';

  @override
  String get showIntervalOnly => 'Interval places only';

  @override
  String get showAllPlaces => 'Show all places';

  @override
  String get filter => 'Filter';

  @override
  String get tabPlaces => 'Places';

  @override
  String get noPlacesFound => 'No places found.';

  @override
  String get noPlacesSaved =>
      'No places saved.\nAdd places on the map with a long press.';

  @override
  String get notVisitedYet => 'Not visited yet';

  @override
  String visitCount(int count) {
    return '$count visit';
  }

  @override
  String visitCountPlural(int count) {
    return '$count visits';
  }

  @override
  String lastVisit(String date, String time) {
    return 'Last: $date  $time';
  }

  @override
  String get toCurrentPosition => 'To current position';

  @override
  String get activitiesScreenTitle => 'Activities';

  @override
  String get noActivitiesYet => 'No activities yet.';

  @override
  String get taskDeleteTitle => 'Delete activity?';

  @override
  String taskDeleteContent(String name) {
    return 'Really remove \"$name\"?';
  }

  @override
  String get newTask => 'New activity';

  @override
  String get editTask => 'Edit activity';

  @override
  String get addTaskTooltip => 'Add activity';

  @override
  String get databaseTitle => 'Database';

  @override
  String get tabExport => 'Export';

  @override
  String get tabImport => 'Import';

  @override
  String get tabReset => 'Reset';

  @override
  String get exportTitle => 'Export database';

  @override
  String get exportDescription =>
      'The SQLite database file is shared directly. It can be saved as a backup or transferred to another device.';

  @override
  String get shareDatabase => 'Share database';

  @override
  String get importTitle => 'Import database';

  @override
  String get importHowTo =>
      'How to import a database:\n\n1. Open the Files app\n2. Long-press the .db file\n3. Tap \"Share\"\n4. Select \"Chaos Tours\" from the list';

  @override
  String get importHint =>
      'This app opens automatically when you share a file to it.';

  @override
  String get fileReceived => 'File received:';

  @override
  String get importButton => 'Import';

  @override
  String get dbReplaceTitle => 'Replace database?';

  @override
  String get dbReplaceContent =>
      'The current database will be completely replaced by the shared file.\n\nAll existing data will be lost.\n\nProceed?';

  @override
  String get importSuccess => 'Database imported successfully';

  @override
  String get dbResetTitle => 'Reset database?';

  @override
  String get dbResetContent =>
      'All data will be permanently deleted. The database structure will be preserved.\n\nProceed?';

  @override
  String get resetSuccess => 'Database reset';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String resetFailed(String error) {
    return 'Reset failed: $error';
  }

  @override
  String get mapTitle => 'Chaos Tours – Map';

  @override
  String get tooltipFilter => 'Filter';

  @override
  String get tooltipAddressSearch => 'Search address';

  @override
  String get whichPlaceToOpen => 'Which place to open?';

  @override
  String get createPlaceHere => 'Create place here';

  @override
  String get routeInGoogleMaps => 'Route in Google Maps';

  @override
  String get toMyPosition => 'To my position';

  @override
  String get noResultsFound => 'No results found.';

  @override
  String get addressSearch => 'Search address';

  @override
  String get country => 'Country';

  @override
  String get countryHint => 'e.g. Germany';

  @override
  String get cityPlace => 'City / Place';

  @override
  String get cityHint => 'e.g. Munich';

  @override
  String get streetOptional => 'Street (optional)';

  @override
  String get streetHint => 'e.g. Marienplatz 1';

  @override
  String get personsScreenTitle => 'Persons';

  @override
  String get noPersonsYet => 'No persons yet.';

  @override
  String get personDeleteTitle => 'Delete person?';

  @override
  String personDeleteContent(String name) {
    return 'Really remove \"$name\"?';
  }

  @override
  String get newPerson => 'New person';

  @override
  String get editPerson => 'Edit person';

  @override
  String get roleOptional => 'Role / Description (optional)';

  @override
  String get addPersonTooltip => 'Add person';

  @override
  String get photoAlbumTitle => 'Photo album';

  @override
  String get noPhotosYet => 'No photos yet';

  @override
  String get noPhotosHint => 'Photos can be added at places and visits.';

  @override
  String get withoutPlace => 'Without place';

  @override
  String photoCount(int count) {
    return '$count photo';
  }

  @override
  String photoCountPlural(int count) {
    return '$count photos';
  }

  @override
  String get photoDeleteTitle => 'Delete photo';

  @override
  String get photoDeleteContent => 'Really delete this photo?';

  @override
  String get placeGroupsTitle => 'Place groups';

  @override
  String get noGroupsYet => 'No groups yet.';

  @override
  String get groupDeleteTitle => 'Delete group?';

  @override
  String groupDeleteContent(String name) {
    return 'Really delete \"$name\"?';
  }

  @override
  String get newGroup => 'New group';

  @override
  String get editGroup => 'Edit group';

  @override
  String get calendarChosen => 'Calendar selected';

  @override
  String get noCalendar => 'No calendar';

  @override
  String get telegramChosen => 'Telegram selected';

  @override
  String get noTelegram => 'No Telegram';

  @override
  String get choose => 'Select';

  @override
  String get notesInCalendar => 'Notes in calendar';

  @override
  String get personsInCalendar => 'Persons in calendar';

  @override
  String get activitiesInCalendar => 'Activities in calendar';

  @override
  String get autoGroup => 'Auto group';

  @override
  String get autoGroupSubtitle =>
      'Automatically recognized places are sorted here';

  @override
  String get pickCalendar => 'Select calendar';

  @override
  String get addGroupTooltip => 'Add group';

  @override
  String repositionTitle(String name) {
    return 'Position: $name';
  }

  @override
  String get repositionConfirmTitle => 'Apply position?';

  @override
  String repositionConfirmContent(String name, String lat, String lng) {
    return '\"$name\" will be moved to\n$lat, $lng.';
  }

  @override
  String get showCurrentLocation => 'Show current location';

  @override
  String placeVisitsTitle(String name) {
    return 'Visits: $name';
  }

  @override
  String get syncSourcesTitle => 'Sync sources';

  @override
  String get stayPersons => 'Stay persons';

  @override
  String get stayActivities => 'Stay activities';

  @override
  String get placeExperiences => 'Place experiences';

  @override
  String get sourceExperiences => 'Source experiences';

  @override
  String get sourceDeleteTitle => 'Delete source?';

  @override
  String sourceDeleteContent(String name) {
    return '\"$name\" will be permanently deleted.';
  }

  @override
  String get syncWarning =>
      '⚠️ It is strongly recommended to export a database backup before syncing (Settings → Database dump).\n\nSynchronize now?';

  @override
  String get syncAllTitle => 'Sync all';

  @override
  String get syncAllWarning =>
      '⚠️ It is strongly recommended to export a database backup before syncing (Settings → Database dump).\n\nSynchronize with all active sync sources?';

  @override
  String get newSyncSource => 'New sync source';

  @override
  String get editSyncSource => 'Edit source';

  @override
  String get syncAddress => 'Sync address *';

  @override
  String get syncAddressHint => 'http://192.168.1.10:8000';

  @override
  String get apiKey => 'API key';

  @override
  String get infoUrlOptional => 'Info URL (optional)';

  @override
  String get infoUrlHint => 'https://example.com';

  @override
  String get syncOptionsTitle => 'Sync options';

  @override
  String get syncOptionsWarning =>
      '⚠️ It is recommended to export a database backup before enabling edit/delete.';

  @override
  String get insert => 'Insert';

  @override
  String get noSyncOptions => 'No sync options active';

  @override
  String tablesActive(int count) {
    return '$count tables active';
  }

  @override
  String get noExperiences => 'No experiences yet.';

  @override
  String get experiencesTitle => 'Experiences';

  @override
  String get syncTitle => 'Synchronize';

  @override
  String syncResultSuccess(int pulled, int pushed) {
    return '$pulled received, $pushed sent';
  }

  @override
  String syncError(String error) {
    return 'Error: $error';
  }

  @override
  String get noActiveSyncSources => 'No active sync sources configured';

  @override
  String syncAllResult(int ok, int pulled, int pushed) {
    return '$ok source(s) OK ($pulled received, $pushed sent)';
  }

  @override
  String syncAllResultWithErrors(int ok, int pulled, int pushed, int fail) {
    return '$ok source(s) OK ($pulled received, $pushed sent), $fail error(s)';
  }

  @override
  String get syncAllTooltip => 'Sync all';

  @override
  String get addSourceTooltip => 'Add source';

  @override
  String get noSyncSources => 'No sync sources available.\nTap + to add one.';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncOptionsMenu => 'Sync options';

  @override
  String get addExperience => 'Add experience';

  @override
  String get experienceHint => 'Note, experience or rating…';

  @override
  String get syncAddressLabel => 'Sync address';

  @override
  String get infoUrlLabel => 'Info URL';

  @override
  String get activeSyncOptions => 'Active sync options';

  @override
  String get telegramConnectionsTitle => 'Telegram connections';

  @override
  String get noTelegramConnections => 'No Telegram connections yet.';

  @override
  String get connectionDeleteTitle => 'Delete connection?';

  @override
  String connectionDeleteContent(String name) {
    return '\"$name\" will be permanently deleted.';
  }

  @override
  String get newTelegramConnection => 'New Telegram connection';

  @override
  String get editTelegramConnection => 'Edit connection';

  @override
  String get chatIdLabel => 'Chat ID or @channel *';

  @override
  String get chatIdHint => '-123... or @channel';

  @override
  String get botTokenLabel => 'Bot token *';

  @override
  String get botTokenHint => '123456:ABC-DEF…';

  @override
  String get distance => 'Distance';

  @override
  String maxDistance(String dist) {
    return 'max. $dist';
  }

  @override
  String get resetFilter2 => 'Reset';

  @override
  String get activateExperienceFilter => 'Activate experience filter';

  @override
  String get deviceIdExperienceFilter => 'Only this device ID experiences';

  @override
  String get deviceIdPlaceFilter => 'Only this device ID Places';

  @override
  String get deviceIdStayFilter => 'Only this device ID Stays';

  @override
  String get minAvgRating => 'Min. ∅ rating:';

  @override
  String get minMedianRating => 'Min. x̃ rating:';

  @override
  String get minSpecialRating => 'Min. rating:';

  @override
  String get ratingMetricAverage => 'Average';

  @override
  String get ratingMetricMedian => 'Median';

  @override
  String get camera => 'Camera';

  @override
  String get fromGallery => 'From gallery';

  @override
  String get noPhotosGrid => 'No photos yet';

  @override
  String get captionTitle => 'Caption';

  @override
  String get captionHint => 'Enter caption';

  @override
  String get editCaptionTooltip => 'Edit caption';

  @override
  String get deletePhotoTooltip => 'Delete photo';

  @override
  String get photosAtPlace => 'Photos at place';

  @override
  String get noPlacePhotos => 'No photos at this place yet.';

  @override
  String get photosFromVisits => 'Photos from visits';

  @override
  String get noVisitPhotos => 'No visit photos available.';

  @override
  String get visit => 'Visit';

  @override
  String get stillRunning => 'still running…';

  @override
  String get editStay => 'Edit stay';

  @override
  String get openPlaceSettings => 'Open place settings';

  @override
  String get begin => 'Start';

  @override
  String get end => 'End';

  @override
  String get notes => 'Notes';

  @override
  String get intervalVisit => 'Interval visit';

  @override
  String get intervalVisitSubtitle =>
      'Visit counts toward interval calculation';

  @override
  String get addPersonSheetTitle => 'Add person';

  @override
  String get nameNewHint => 'Enter name (new)';

  @override
  String get addActivitySheetTitle => 'Add activity';

  @override
  String get activityNewHint => 'Enter activity (new)';

  @override
  String get photos => 'Photos';

  @override
  String get deleteStayTitle => 'Delete stay';

  @override
  String get deleteStayContent =>
      'Do you really want to delete this stay? This action cannot be undone.';

  @override
  String get personNewHint => 'Enter name (new)';

  @override
  String get experienceDeleteTitle => 'Delete experience?';

  @override
  String get experienceDeleteContent =>
      'This entry will be permanently deleted.';

  @override
  String get addOrEditExperienceTitle => 'Add experience';

  @override
  String get editExperienceTitle => 'Edit experience';

  @override
  String get reportOptional => 'Report (optional)';

  @override
  String get ratingsLabel => 'Ratings (−9 to +9):';

  @override
  String get ratingDangerFriendly => 'Dangerous ↔ Friendly';

  @override
  String get ratingFraudReliable => 'Fraudulent ↔ Reliable';

  @override
  String get ratingDismissiveAccommodation =>
      'Dismissive ↔ Provides accommodation';

  @override
  String get ratingFood => 'Demands ↔ Provides food';

  @override
  String get ratingEquipment => 'Demands ↔ Provides equipment';

  @override
  String get ratingTransport => 'Demands ↔ Provides transport';

  @override
  String get ratingMedicine => 'Demands ↔ Provides medical care';

  @override
  String get filterByGroup => 'Filter by group';

  @override
  String get filterByPlaceType => 'Filter by place type';

  @override
  String get filterModeGeneral => 'General filter';

  @override
  String get filterModeSpecific => 'Specific filter';

  @override
  String get selectRatingDimension => 'Rating dimension:';

  @override
  String get ratingTableOverall => 'Overall';

  @override
  String get loadingRatings => 'Loading...';

  @override
  String get noExperiencesYet => 'No experience reports yet.';

  @override
  String get survivalExperiences => 'Survival experiences';

  @override
  String get statistics => 'Statistics';

  @override
  String get visitNow => 'Visit now';

  @override
  String get copyBasicReport => 'Copy basic place report';

  @override
  String get copyFullReport => 'Copy full place report';

  @override
  String get sendReportToTelegram => 'Send report to Telegram';

  @override
  String get visitInterval => 'Visit interval';

  @override
  String get intervalDaysLabel => 'Interval (days)';

  @override
  String get intervalDaysHint => 'e.g. 14';

  @override
  String get intervalDaysSuffix => 'days';

  @override
  String get changePositionOnMap => 'Change position on map';

  @override
  String radius(String m) {
    return 'Radius: $m m';
  }

  @override
  String get group => 'Group';

  @override
  String get noGroup => 'No group';

  @override
  String get placeDeleteTitle => 'Delete place?';

  @override
  String placeDeleteContent(String name) {
    return 'Really delete \"$name\"?';
  }

  @override
  String get gpsCopied => 'GPS coordinates copied';

  @override
  String get reportCopied => 'Report copied to clipboard';

  @override
  String get telegramSendTitle => 'Send to Telegram?';

  @override
  String telegramSendContent(String place, String connection) {
    return 'Send report for \"$place\" to \"$connection\"?';
  }

  @override
  String get openInGoogleMaps => 'Open in Google Maps';

  @override
  String get noteName => 'Note';

  @override
  String get website => 'Website';

  @override
  String get email => 'Email';

  @override
  String get phone => 'Phone';

  @override
  String get importAutoOpenHint =>
      'This app opens automatically when you share a file here.';

  @override
  String get importOverwriteWarning => 'All existing data will be overwritten.';

  @override
  String get importNow => 'Import now';

  @override
  String get importWaiting => 'Waiting for shared file…';

  @override
  String get syncFromFileNow => 'Merge';

  @override
  String get syncFromFileTitle => 'Merge databases?';

  @override
  String get syncFromFileContent =>
      'The received database will be merged into the current one. Newer entries overwrite older ones (last-write-wins). Existing data is preserved.\n\nProceed?';

  @override
  String syncFromFileSuccess(int count) {
    return 'Databases merged ($count entries processed)';
  }

  @override
  String syncFromFileFailed(String error) {
    return 'Merge failed: $error';
  }

  @override
  String get syncFromFileModeTitle => 'Choose sync scope';

  @override
  String get syncFromFileModeDescription =>
      'Do you want to merge all tables completely, or select individual tables and operations?';

  @override
  String get syncFromFileModeAll => 'Merge everything';

  @override
  String get syncFromFileModeCustom => 'Customize…';

  @override
  String get placePhotos => 'Photos';

  @override
  String get resetTitle => 'Reset database';

  @override
  String get resetDescription =>
      'All data will be permanently deleted. The database structure will be preserved.';

  @override
  String get resetIrreversibleWarning => 'This action cannot be undone.';

  @override
  String get deleteAllData => 'Delete all data';

  @override
  String get trackingActivateTitle => 'Enable tracking?';

  @override
  String get trackingDeactivateTitle => 'Disable tracking?';

  @override
  String get trackingActivateContent =>
      'Should automatic background tracking be started?';

  @override
  String get trackingDeactivateContent =>
      'Should automatic background tracking be stopped?';

  @override
  String get trackingActiveTooltip => 'Tracking active';

  @override
  String get trackingInactiveTooltip => 'Tracking inactive';

  @override
  String get trackingNotificationText => 'Automatic tracking active';

  @override
  String trackingStatusHaltUnknownAddress(String address) {
    return 'Staying: $address';
  }

  @override
  String get newPlaceTitle => 'New place';

  @override
  String get placeEditTitle => 'Edit place';

  @override
  String get placeOriginAuto => 'Auto-created';

  @override
  String get placeOriginImported => 'Imported';

  @override
  String get managePlaceGroups => 'Manage place groups';

  @override
  String get visitIntervalSubtitle => 'Regular reminder to visit this place';

  @override
  String get infoAndStats => 'Information & Statistics';

  @override
  String get neverVisited => 'Never visited';

  @override
  String lastVisitedAt(String date) {
    return '· last: $date';
  }

  @override
  String placeCreatedAt(String date) {
    return 'Created: $date';
  }

  @override
  String get showVisits => 'Show visits';

  @override
  String showVisitsCount(int count) {
    return 'Show visits ($count)';
  }

  @override
  String get copyReportHint =>
      'Copies a full report of the place including all visits and survival experiences in Markdown format to the clipboard.';

  @override
  String get copyToProtectedArea => 'Copy to protected area';

  @override
  String get copyToProtectedAreaHint =>
      'Creates a copy of this place with a new UUID and the device ID of a protected area, shielding it from sync imports.';

  @override
  String get copyToProtectedAreaSelectTitle => 'Select protected area';

  @override
  String get copyToProtectedAreaSelectSubtitle =>
      'The copy will receive the device ID of the selected Virtual Device.';

  @override
  String get copyToProtectedAreaSuccess => 'Place copied to protected area.';

  @override
  String get gpsSettings => 'GPS Settings';

  @override
  String get telegramSent => 'Report sent to Telegram';

  @override
  String telegramError(String error) {
    return 'Error: $error';
  }

  @override
  String get createVisitTitle => 'Create visit';

  @override
  String get noVisitsRecorded => 'No visits recorded yet.';

  @override
  String get statFirstVisit => 'First visit';

  @override
  String get statLastVisit => 'Last visit';

  @override
  String get statShortest => 'Shortest visit';

  @override
  String get statLongest => 'Longest visit';

  @override
  String get statAverage => 'Average';

  @override
  String get statMedian => 'x̃';

  @override
  String openLabel(String label) {
    return 'Open $label';
  }

  @override
  String get sectionPhotos => 'Photos';

  @override
  String photoMaxWidth(int value) {
    return 'Max. width ($value px)';
  }

  @override
  String photoMaxHeight(int value) {
    return 'Max. height ($value px)';
  }

  @override
  String get photoMaxDimensionSubtitle => '0 = unlimited';

  @override
  String photoImageQuality(int value) {
    return 'Image quality ($value %)';
  }

  @override
  String get sharePhoto => 'Share photo';

  @override
  String get skip => 'Skip';

  @override
  String get address => 'Address';

  @override
  String get filterByTrustedSources => 'Trusted sources only';

  @override
  String get trustedSourcesTitle => 'Trusted Sources';

  @override
  String get trustedSourcesSubtitle => 'Manage trusted device IDs';

  @override
  String get noTrustedSources =>
      'No known device IDs.\nUse Refresh to collect device IDs from the database.';

  @override
  String get refreshTrustedSources => 'Collect device IDs from database';

  @override
  String get addTrustedSource => 'Add trusted source';

  @override
  String get editTrustedSource => 'Edit trusted source';

  @override
  String get trustedDeviceIdLabel => 'Device ID';

  @override
  String get trustedSourceDeleteTitle => 'Remove trusted source?';

  @override
  String get trustedDevicesSection => 'Trusted';

  @override
  String get knownDevicesSection => 'Known Devices';

  @override
  String get createVirtualDeviceForSource =>
      'Create virtual device for this source';

  @override
  String get virtualDeviceAlreadyExistsForSource =>
      'A virtual device for this device ID already exists';

  @override
  String get virtualDeviceCreatedFromTemplate => 'Virtual device created';

  @override
  String get confirmMarkTrustedTitle => 'Mark as trusted?';

  @override
  String get confirmMarkUntrustedTitle => 'Revoke trust?';

  @override
  String get deviceNameDialogTitle => 'Name this device';

  @override
  String get deviceNameDialogContent =>
      'Enter a name for this device (3–20 characters). The name is permanently bound to a UUID and forms the device ID: name@uuid\n\nThis name cannot be changed later.';

  @override
  String get deviceNameLabel => 'Device name';

  @override
  String get deviceNameHint => 'e.g. Alice, MyPhone';

  @override
  String get deviceNameLengthHint => '3–20 characters, required';

  @override
  String get databaseExplorerButton => 'Database explorer';

  @override
  String get generateRandomData => 'Create random test data';

  @override
  String get databaseExplorerScreenHeader => 'SQLite explorer';

  @override
  String get databaseExplorerTableLabel => 'Table';

  @override
  String get noDataOrTableSelected => 'No data or nor table selected';

  @override
  String get loadMoreRows => 'Load more Data';

  @override
  String get endOfTableReached => 'Reached end of table';

  @override
  String editFieldTitle(String value) {
    return 'Edit ${value}s columns';
  }

  @override
  String get newValueLabel => 'New Value';

  @override
  String get databaseUpdated => 'Database updated';

  @override
  String get sharedPrefsExplorerButton => 'Shared preferences explorer';

  @override
  String get sharedPrefsExplorerScreenHeader => 'Shared preferences explorer';

  @override
  String get sharedPrefsNoEntries => 'No entries available';

  @override
  String sharedPrefsEditTitle(String key) {
    return 'Edit $key';
  }

  @override
  String get sharedPrefsDeleteTitle => 'Delete entry';

  @override
  String sharedPrefsDeleteConfirm(String key) {
    return 'Do you really want to delete the entry \"$key\"?';
  }

  @override
  String get sharedPrefsDeleted => 'Entry deleted';

  @override
  String get sharedPrefsUpdated => 'Entry updated';

  @override
  String sharedPrefsInvalidValue(String type) {
    return 'Invalid value for type $type';
  }

  @override
  String nextGpsIn(int value) {
    return 'Next GPS in $value sec.';
  }

  @override
  String get devToolsSectionTitle => 'Developer tools';

  @override
  String get devToolsWarning =>
      'WARNING: These tools are potentially DESTRUCTIVE. They can irreversibly modify or delete data. Once unlocked they stay usable for one hour. It is STRONGLY, STRONGLY, STRONGLY advised to at least make a backup of the database first!';

  @override
  String get devToolsUnlockButton => 'Unlock developer tools';

  @override
  String get devToolsChallengeInstruction =>
      'Type the following 8-character string exactly to unlock:';

  @override
  String get devToolsChallengeHint => 'Enter the string';

  @override
  String get devToolsUnlockSuccess => 'Developer tools unlocked for one hour.';

  @override
  String devToolsUnlockedUntil(String time) {
    return 'Unlocked until $time';
  }

  @override
  String get devToolsRelock => 'Lock now';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get messageAttachments => 'Message attachments';

  @override
  String get messagesPlaceTitle => 'Place messages';

  @override
  String get messagesRegionTitle => 'Regional messages';

  @override
  String get messagesEmpty => 'No messages yet.';

  @override
  String get messageDeleteTitle => 'Delete message?';

  @override
  String get messageNeedsPlace =>
      'Messages require a place. Please compose within a place.';

  @override
  String get messageAuthorSelf => 'Me';

  @override
  String get messageDeleted => '[deleted message]';

  @override
  String get messagePhotoPlaceholder => '[photo]';

  @override
  String get reply => 'Reply';

  @override
  String replyingTo(String preview) {
    return 'Replying to: $preview';
  }

  @override
  String get noPlaceAvailable => 'No place available.';

  @override
  String get noPhotosAtPlace => 'No photos at this place.';

  @override
  String get gallery => 'Gallery';

  @override
  String get existingPlacePhoto => 'Existing place photo';

  @override
  String get messageHint => 'Message…';

  @override
  String get placeMessagesButton => 'P2P Place messages';

  @override
  String get createPlace => 'Create place';

  @override
  String get showRegionMessages => 'Show messages of the region';

  @override
  String get regionRadiusTitle => 'Region radius';

  @override
  String get radiusInKm => 'Radius in km';

  @override
  String get showAction => 'Show';

  @override
  String get sectionP2pMessenger => 'P2P messenger';

  @override
  String get messengerEnable => 'Enable messenger';

  @override
  String get messengerEnableSubtitle =>
      'Location-bound P2P chat in the Places tab (store-and-forward).';

  @override
  String get createPlaceOnSync => 'Create places on sync opportunity';

  @override
  String get createPlaceOnSyncSubtitle =>
      'Automatically creates a \"sync source\" place on a synchronization opportunity — even when automatic place creation is disabled. Required so messages received there have a reference place.';

  @override
  String get syncPhotos => 'Sync photos';

  @override
  String get syncPhotosSubtitle =>
      'Transfer images over the mesh (base64 in JSON — can get large).';

  @override
  String get photoSizeLimitUnlimited => 'Photo size limit: unlimited';

  @override
  String photoSizeLimitKib(int kib) {
    return 'Photo size limit: $kib KiB';
  }

  @override
  String get unlimited => 'unlimited';

  @override
  String get nodeScanModeLabel => 'Node scan mode';

  @override
  String get nodeScanOnHalt => 'On halt at place';

  @override
  String get nodeScanPerGps => 'Per GPS interval';

  @override
  String nodeScanEvery(int count) {
    return 'Scan every $count GPS intervals';
  }

  @override
  String get autoCreatePlacesMessengerNote =>
      'Note: Location-bound messages of the P2P messenger strictly require a place as reference point. If automatic place creation is off, places can still be created as \"sync source\" on synchronization opportunities (see P2P messenger).';

  @override
  String get locatorCopied => 'Ham Radio QTH Locator copied';

  @override
  String get compassTitle => 'Compass';

  @override
  String get compassRefHere => 'From here';

  @override
  String get compassRefPlace => 'From place';

  @override
  String get compassFromHere => 'Compass from here';

  @override
  String get compassFromPlace => 'Compass from this place';

  @override
  String get virtualDevicesScreenTitle => 'Virtual Deviced';

  @override
  String virtualDeviceDetailTitle(String name) {
    return 'V-Device: $name';
  }

  @override
  String get switchToVirtualDevice => 'Switch to this Virtual Device';

  @override
  String get switchToVirtualDeviceSubtitle =>
      'Makes this Virtual Device and its device ID active';

  @override
  String get virtualDeviceCurrentlyActive => 'Currently active';

  @override
  String get privateSpaceSection => 'Private Space';

  @override
  String get protectFromExportLabel => 'Protect from sync export';

  @override
  String get protectFromExportSubtitle =>
      'Data from this Virtual Device will not be pushed to sync servers (invisible to the outside world)';

  @override
  String get protectFromImportLabel => 'Protect from sync import';

  @override
  String get protectFromImportSubtitle =>
      'Incoming sync data with this device ID will be ignored (protects privacy)';

  @override
  String get purgeDataLabel => 'Clean database entries';

  @override
  String get purgeDataSubtitle =>
      'Remove all entries with this device ID from the database (not the Virtual Device itself)';

  @override
  String get purgeDataConfirmTitle => 'Clean entries?';

  @override
  String purgeDataConfirmContent(String name) {
    return 'All database entries with the device ID of \"$name\" will be permanently removed.';
  }

  @override
  String purgeDataSuccess(int count) {
    return '$count entries removed';
  }

  @override
  String get deleteWithCleanupCheckbox => 'Also clean database';

  @override
  String get deleteWithCleanupCheckboxSubtitle =>
      'All entries with the device ID of this activity will be removed';

  @override
  String get movePlacesTitle => 'Move places';

  @override
  String get moveButton => 'Move';

  @override
  String placesMovedCount(int count) {
    return '$count places moved';
  }

  @override
  String placeDetailPhotoCount(int n) {
    return 'Photos inline: $n';
  }

  @override
  String get placeDetailPhotoCountSubtitle =>
      'Number of photos shown directly in place details';

  @override
  String showAllPhotosButton(int count) {
    return 'Show all $count photos';
  }

  @override
  String get allPhotosScreenTitle => 'All photos';

  @override
  String get openVisitButton => 'Open visit';

  @override
  String get openPlaceButton => 'Open place';

  @override
  String get placeNotFoundTitle => 'Place not found';

  @override
  String get placeNotFoundContent =>
      'This place no longer exists in the database. It may have been deleted or not yet synced.';

  @override
  String get visitNotFoundTitle => 'Visit not found';

  @override
  String get visitNotFoundContent =>
      'This visit no longer exists in the database. It may have been deleted or not yet synced.';
}
