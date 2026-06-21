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
  String get aktivitaetLoading => 'Loading activity…';

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
  String get sectionActivity => 'Activity';

  @override
  String get noActivity => 'No activity';

  @override
  String activityCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activities',
      one: '$count activity',
    );
    return '$_temp0';
  }

  @override
  String get tooltipRename => 'Rename';

  @override
  String get tooltipSwitchCreate => 'Switch / Create new';

  @override
  String get deviceId => 'Geräte ID';

  @override
  String get deviceIdDescription =>
      'Diese ID hilft Ihnen dabei, importierte oder synchronisierte Inhalte von Ihren eigenen zu unterscheiden. Sie können frei eine eigene ID eintragen oder die automatisch generierte ID mit einem Namen versehen. Bitte beachten Sie jedoch, dass nicht geprüft wird, ob diese ID bereits anderweitig verwendet wird.';

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
  String get sectionPlanner => 'Planner';

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
  String get databaseDump => 'Database dump';

  @override
  String get databaseDumpSubtitle => 'Create, load & share dump';

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
  String get deleteActivity => 'Permanently remove current activity';

  @override
  String get pickActivity => 'Select activity';

  @override
  String get newActivityCreate => 'Create new activity';

  @override
  String get newActivityLabel => 'New activity';

  @override
  String get copySettingsFrom => 'Copy settings from:';

  @override
  String get renameActivity => 'Rename activity';

  @override
  String get deleteActivityTitle => 'Delete activity?';

  @override
  String deleteActivityContent(String name) {
    return 'Really delete \"$name\"?\n\nThe settings of this activity will be permanently removed.';
  }

  @override
  String activityDeleted(String name) {
    return '\"$name\" deleted';
  }

  @override
  String deleteActivityLabel(String name) {
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
  String get experienceFilter => 'Experience filter';

  @override
  String get resetFilter2 => 'Reset';

  @override
  String get activateExperienceFilter => 'Activate experience filter';

  @override
  String get minAvgRating => 'Min. avg rating:';

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
  String get deleteStay => 'Delete stay';

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
  String get noExperiencesYet => 'No experience reports yet.';

  @override
  String get survivalExperiences => 'Survival experiences';

  @override
  String get statistics => 'Statistics';

  @override
  String get visitNow => 'Visit now';

  @override
  String get copyFullReport => 'Copy full report';

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
  String get saveVisit => 'Save visit';

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
  String get statMedian => 'Median';

  @override
  String openLabel(String label) {
    return 'Open $label';
  }
}
