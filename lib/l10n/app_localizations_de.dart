// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Chaos Tours';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get add => 'Hinzufügen';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get search => 'Suchen';

  @override
  String get none => 'Keine';

  @override
  String get all => 'Alle';

  @override
  String get create => 'Erstellen';

  @override
  String get close => 'Schließen';

  @override
  String get send => 'Senden';

  @override
  String get apply => 'Übernehmen';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get version => 'Version 2.0.0';

  @override
  String get name => 'Name';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get required => 'Pflichtfeld';

  @override
  String get description => 'Beschreibung';

  @override
  String get active => 'Aktiv';

  @override
  String get type => 'Typ';

  @override
  String get replace => 'Ersetzen';

  @override
  String get synchronize => 'Synchronisieren';

  @override
  String get navHome => 'Home';

  @override
  String get navMap => 'Karte';

  @override
  String get navPlaces => 'Orte';

  @override
  String get navVisits => 'Besuche';

  @override
  String get navPhotos => 'Fotos';

  @override
  String get trackingDisabled => 'Tracking deaktiviert';

  @override
  String get trackingRunning => 'Tracking läuft…';

  @override
  String get trackingActive => 'Tracking aktiv';

  @override
  String get trackingInactive => 'Tracking inaktiv';

  @override
  String get trackingStatusMoving => 'Unterwegs';

  @override
  String trackingStatusHaltKnown(String place) {
    return 'Halten bei $place';
  }

  @override
  String trackingStatusHaltUnknown(String address) {
    return 'Halten: $address';
  }

  @override
  String get trackingStatusHalt => 'Halten';

  @override
  String get trackingStatusDetecting => 'Aufenthalt wird erkannt…';

  @override
  String get trackingCollecting => 'Tracking sammelt GPS Daten…';

  @override
  String get aktivitaetLoading => 'Aktivität laden…';

  @override
  String get unknownPlace => 'Unbekannter Ort';

  @override
  String sinceHoursMinutes(int h, int m) {
    return 'Seit ${h}h ${m}min';
  }

  @override
  String sinceMinutes(int m) {
    return 'Seit ${m}min';
  }

  @override
  String get endStayNow => 'Aufenthalt jetzt beenden & teilen';

  @override
  String get endStayTitle => 'Aufenthalt beenden?';

  @override
  String get endStayContent =>
      'Der aktuelle Aufenthalt wird jetzt abgeschlossen. Das Tracking läuft weiter und startet bei gleichem Ort sofort einen neuen Aufenthalt.';

  @override
  String get endStayButton => 'Beenden';

  @override
  String get endStayEnding => 'Aufenthalt wird beendet…';

  @override
  String get noVisitsYet => 'Noch keine Besuche aufgezeichnet.';

  @override
  String get recentVisits => 'Letzte Besuche';

  @override
  String get enableTracking => 'Tracking aktivieren?';

  @override
  String get disableTracking => 'Tracking deaktivieren?';

  @override
  String get enableTrackingContent =>
      'Soll das automatische Hintergrund-Tracking gestartet werden?';

  @override
  String get disableTrackingContent =>
      'Soll das automatische Hintergrund-Tracking gestoppt werden?';

  @override
  String get activate => 'Aktivieren';

  @override
  String get deactivate => 'Deaktivieren';

  @override
  String get batteryOptTitle => 'Akkuoptimierung deaktivieren';

  @override
  String get batteryOptContent =>
      'Der Hintergrund-Dienst konnte nicht gestartet werden.\n\nBitte deaktiviere die Akkuoptimierung für Chaos Tours:\nEinstellungen → Apps → Chaos Tours → Akku → Nicht eingeschränkt';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSaved => 'Einstellungen gespeichert';

  @override
  String get sectionActivity => 'Aktivität';

  @override
  String get noActivity => 'Keine Aktivität';

  @override
  String activityCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aktivitäten vorhanden',
      one: '$count Aktivität vorhanden',
    );
    return '$_temp0';
  }

  @override
  String get tooltipRename => 'Umbenennen';

  @override
  String get tooltipSwitchCreate => 'Wechseln / Neu erstellen';

  @override
  String get deviceId => 'Geräte ID';

  @override
  String get deviceIdCopied => 'Geräte ID Kopiert';

  @override
  String get sectionTracking => 'Tracking';

  @override
  String gpsInterval(int value) {
    return 'GPS-Intervall: ${value}s';
  }

  @override
  String get gpsIntervalHint =>
      'Hinweis: Änderungen des Intervalls erforderdern einen vollständigen Neustart der App inklusive des Hintergrund Tracking.';

  @override
  String gpsSmoothing(String value) {
    return 'GPS-Glättung: $value';
  }

  @override
  String get gpsSmoothingDisabled => 'deaktiviert';

  @override
  String gpsSmoothingPoints(int n) {
    return '$n Punkte';
  }

  @override
  String get gpsSmoothingHint => 'Mittelt die letzten N GPS-Punkte.';

  @override
  String stayDetection(int min) {
    return 'Aufenthalt erkennen nach: $min min';
  }

  @override
  String autoPlaceTime(int min) {
    return 'Auto-Ort erstellen nach: $min min';
  }

  @override
  String defaultRadius(String m) {
    return 'Standard-Radius: $m m';
  }

  @override
  String get autoCreatePlaces => 'Orte automatisch erstellen';

  @override
  String get autoCreatePlacesSubtitle =>
      'Neue Orte bei langen Aufenthalten an unbekannten Orten anlegen';

  @override
  String get autoPlaceGroup => 'Gruppe für Auto-Orte';

  @override
  String get defaultPlaceGroup => 'Standard-Gruppe für neue Orte';

  @override
  String get defaultPlaceGroupSubtitle =>
      'Voreingestellte Gruppe beim manuellen Erstellen von Orten';

  @override
  String get sectionMapDisplay => 'Kartendarstellung';

  @override
  String get showGpsPoints => 'GPS-Punkte anzeigen';

  @override
  String get showGpsPointsSubtitle =>
      'Tracking-Punkte farbig auf der Karte einblenden';

  @override
  String pointSize(String m) {
    return 'Punktgröße: $m m';
  }

  @override
  String visitHistory(String days) {
    return 'Besuchs-Verlauf: $days';
  }

  @override
  String visitHistoryDay(int days) {
    return '$days Tag';
  }

  @override
  String visitHistoryDays(int days) {
    return '$days Tage';
  }

  @override
  String get visitHistoryHint =>
      'Wie viele Tage der Reiseverlauf auf der Zeitachsen-Karte angezeigt wird.';

  @override
  String get sectionPlanner => 'Planer';

  @override
  String colorRange(int days) {
    return 'Farbskala-Bereich: $days';
  }

  @override
  String colorRangeHint(int range) {
    return '$range Tage = grün  •  0 = gelb  •  -$range = rot';
  }

  @override
  String get shownGroups => 'Angezeigte Gruppen (Karte & Planer)';

  @override
  String get noGroupsAvailable => 'Keine Gruppen vorhanden';

  @override
  String get sectionAddressSearch => 'Adresssuche';

  @override
  String get addressOnAutoCreateTitle =>
      'Adresse bei automatischer Ortserstellung';

  @override
  String get addressOnAutoCreateSubtitle =>
      'Adresse per OSM abfragen und beim automatischen Erstellen eines Ortes verwenden.';

  @override
  String get addressOnManualCreateTitle =>
      'Adresse bei manueller Ortserstellung';

  @override
  String get addressOnManualCreateSubtitle =>
      'Adresse per OSM abfragen und als Namensvorschlag beim Anlegen per Langdruck auf der Karte vorausfüllen.';

  @override
  String get addressOnIntervalTitle => 'Adresse bei jedem GPS-Intervall';

  @override
  String get addressOnIntervalSubtitle =>
      'Adresse per OSM bei jedem Tracking-Intervall abfragen und im Startbildschirm anzeigen.';

  @override
  String get nominatimUserAgent => 'Eigener User-Agent (OSM)';

  @override
  String get nominatimUserAgentHint =>
      'z. B. MeineApp/1.0 (kontakt@example.com)';

  @override
  String get nominatimUserAgentSubtitle =>
      'Der User-Agent identifiziert die App gegenüber dem OSM-Nominatim-Dienst. Leer lassen für den Standardwert. Verwenden viele Geräte denselben User-Agent, kann der Dienst Anfragen drosseln oder blockieren.';

  @override
  String get defaultCountry => 'Standard-Land für Adresssuche';

  @override
  String get defaultCountryHint => 'z. B. Deutschland';

  @override
  String get defaultCountrySubtitle =>
      'Wird in der Karten-Adresssuche als Standardland vorausgefüllt.';

  @override
  String get sectionManagement => 'Verwaltung';

  @override
  String get placeGroups => 'Ortsgruppen';

  @override
  String get persons => 'Personen';

  @override
  String get activities => 'Tätigkeiten';

  @override
  String get databaseDump => 'Datenbank-Dump';

  @override
  String get databaseDumpSubtitle => 'Dump erstellen, laden & teilen';

  @override
  String get syncSources => 'Sync-Quellen';

  @override
  String get syncSourcesSubtitle => 'Sync-Server verwalten und synchronisieren';

  @override
  String get telegramConnections => 'Telegram-Verbindungen';

  @override
  String get telegramConnectionsSubtitle =>
      'Telegram-Bots für Ortsberichte verwalten';

  @override
  String get sectionPermissions => 'Berechtigungen';

  @override
  String get locationPermission => 'Standortberechtigung';

  @override
  String get locationPermissionSubtitle => 'Standort im Vordergrund anfordern';

  @override
  String get backgroundLocation => 'Hintergrund-Standort';

  @override
  String get backgroundLocationSubtitle => 'Standort im Hintergrund anfordern';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get notificationsSubtitle => 'Benachrichtigungsberechtigung anfordern';

  @override
  String get calendarSync => 'Kalender-Sync';

  @override
  String get calendarSyncSubtitle =>
      'Aufenthalte automatisch im Gerätekalender eintragen';

  @override
  String get calendarPermission => 'Kalenderberechtigung anfordern';

  @override
  String get locationGranted => 'Standort gewährt';

  @override
  String get locationDenied => 'Standort verweigert';

  @override
  String get backgroundLocationGranted => 'Hintergrund-Standort gewährt';

  @override
  String get backgroundLocationDenied => 'Hintergrund-Standort verweigert';

  @override
  String get notificationsGranted => 'Benachrichtigungen gewährt';

  @override
  String get notificationsDenied => 'Benachrichtigungen verweigert';

  @override
  String get calendarGranted => 'Kalender gewährt';

  @override
  String get calendarDenied => 'Kalender verweigert';

  @override
  String get deleteActivity => 'Aktuelle Aktivität dauerhaft entfernen';

  @override
  String get pickActivity => 'Aktivität wählen';

  @override
  String get newActivityCreate => 'Neue Aktivität erstellen';

  @override
  String get newActivityLabel => 'Neue Aktivität';

  @override
  String get copySettingsFrom => 'Einstellungen kopieren von:';

  @override
  String get renameActivity => 'Aktivität umbenennen';

  @override
  String get deleteActivityTitle => 'Aktivität löschen?';

  @override
  String deleteActivityContent(String name) {
    return '„$name\" wirklich löschen?\n\nDie Einstellungen dieser Aktivität werden unwiderruflich entfernt.';
  }

  @override
  String activityDeleted(String name) {
    return '„$name\" gelöscht';
  }

  @override
  String deleteActivityLabel(String name) {
    return '„$name\" löschen';
  }

  @override
  String get visitsTitle => 'Besuche';

  @override
  String get searchStaysHint => 'Aufenthalte durchsuchen…';

  @override
  String get searchStays => 'Aufenthalte durchsuchen…';

  @override
  String get closeSearch => 'Suche schließen';

  @override
  String get filterByDate => 'Datumsbereich filtern';

  @override
  String get filterByPlace => 'Nach Ort filtern';

  @override
  String get resetFilter => 'Filter zurücksetzen';

  @override
  String get tabList => 'Besuche';

  @override
  String get tabJourney => 'Reise';

  @override
  String get tabPlanner => 'Planer';

  @override
  String get noStaysFound =>
      'Keine abgeschlossenen Aufenthalte gefunden.\nTracking einschalten um Aufenthalte aufzuzeichnen.';

  @override
  String get toLastPosition => 'Zur letzten Position';

  @override
  String get noSchedulerPlaces =>
      'Keine Planer-Orte vorhanden.\n\nAktiviere das Besuchs-Intervall für Orte in den Ortseinstellungen.';

  @override
  String get schedulerToday => 'Heute';

  @override
  String schedulerInDays(int n) {
    return 'in $n Tagen';
  }

  @override
  String schedulerInDay(int n) {
    return 'in $n Tag';
  }

  @override
  String schedulerOverdueDays(int n) {
    return '$n Tage überfällig';
  }

  @override
  String schedulerOverdueDay(int n) {
    return '$n Tag überfällig';
  }

  @override
  String intervalDays(int n) {
    return 'Intervall: $n Tage';
  }

  @override
  String get allPlaces => 'Alle Orte';

  @override
  String get placesTitle => 'Orte';

  @override
  String get searchPlaces => 'Orte durchsuchen…';

  @override
  String get showIntervalOnly => 'Nur Intervall-Orte';

  @override
  String get showAllPlaces => 'Alle Orte anzeigen';

  @override
  String get filter => 'Filter';

  @override
  String get tabPlaces => 'Orte';

  @override
  String get noPlacesFound => 'Keine Orte gefunden.';

  @override
  String get noPlacesSaved =>
      'Keine Orte gespeichert.\nOrte auf der Karte per Langer Druck hinzufügen.';

  @override
  String get notVisitedYet => 'Noch nicht besucht';

  @override
  String visitCount(int count) {
    return '$count Besuch';
  }

  @override
  String visitCountPlural(int count) {
    return '$count Besuche';
  }

  @override
  String lastVisit(String date, String time) {
    return 'Zuletzt: $date  $time';
  }

  @override
  String get toCurrentPosition => 'Zur aktuellen Position';

  @override
  String get activitiesScreenTitle => 'Tätigkeiten';

  @override
  String get noActivitiesYet => 'Noch keine Tätigkeiten vorhanden.';

  @override
  String get taskDeleteTitle => 'Tätigkeit löschen?';

  @override
  String taskDeleteContent(String name) {
    return '„$name\" wirklich entfernen?';
  }

  @override
  String get newTask => 'Neue Tätigkeit';

  @override
  String get editTask => 'Tätigkeit bearbeiten';

  @override
  String get addTaskTooltip => 'Tätigkeit hinzufügen';

  @override
  String get databaseTitle => 'Datenbank';

  @override
  String get tabExport => 'Exportieren';

  @override
  String get tabImport => 'Importieren';

  @override
  String get tabReset => 'Zurücksetzen';

  @override
  String get exportTitle => 'Datenbank exportieren';

  @override
  String get exportDescription =>
      'Die SQLite-Datenbankdatei wird direkt geteilt. Sie kann als Backup gespeichert oder auf ein anderes Gerät übertragen werden.';

  @override
  String get shareDatabase => 'Datenbank teilen';

  @override
  String get importTitle => 'Datenbank importieren';

  @override
  String get importHowTo =>
      'So importierst du eine Datenbank:\n\n1. Öffne die Dateien-App\n2. Halte die .db-Datei gedrückt\n3. Tippe auf „Teilen\"\n4. Wähle „Chaos Tours\" aus der Liste';

  @override
  String get importHint =>
      'Diese App öffnet sich automatisch, wenn du eine Datei hierher teilst.';

  @override
  String get fileReceived => 'Datei empfangen:';

  @override
  String get importButton => 'Importieren';

  @override
  String get dbReplaceTitle => 'Datenbank ersetzen?';

  @override
  String get dbReplaceContent =>
      'Die aktuelle Datenbank wird vollständig durch die geteilte Datei ersetzt.\n\nAlle vorhandenen Daten gehen verloren.\n\nFortfahren?';

  @override
  String get importSuccess => 'Datenbank erfolgreich importiert';

  @override
  String get dbResetTitle => 'Datenbank zurücksetzen?';

  @override
  String get dbResetContent =>
      'Alle Daten werden unwiderruflich gelöscht. Die Datenbankstruktur bleibt erhalten.\n\nFortfahren?';

  @override
  String get resetSuccess => 'Datenbank zurückgesetzt';

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String importFailed(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String resetFailed(String error) {
    return 'Zurücksetzen fehlgeschlagen: $error';
  }

  @override
  String get mapTitle => 'Chaos Tours – Karte';

  @override
  String get tooltipFilter => 'Filter';

  @override
  String get tooltipAddressSearch => 'Adresse suchen';

  @override
  String get whichPlaceToOpen => 'Welchen Ort öffnen?';

  @override
  String get createPlaceHere => 'Ort hier erstellen';

  @override
  String get routeInGoogleMaps => 'Route in Google Maps';

  @override
  String get toMyPosition => 'Zu meiner Position';

  @override
  String get noResultsFound => 'Keine Ergebnisse gefunden.';

  @override
  String get addressSearch => 'Adresse suchen';

  @override
  String get country => 'Land';

  @override
  String get countryHint => 'z. B. Deutschland';

  @override
  String get cityPlace => 'Stadt / Ort';

  @override
  String get cityHint => 'z. B. München';

  @override
  String get streetOptional => 'Straße (optional)';

  @override
  String get streetHint => 'z. B. Marienplatz 1';

  @override
  String get personsScreenTitle => 'Personen';

  @override
  String get noPersonsYet => 'Noch keine Personen vorhanden.';

  @override
  String get personDeleteTitle => 'Person löschen?';

  @override
  String personDeleteContent(String name) {
    return '„$name\" wirklich entfernen?';
  }

  @override
  String get newPerson => 'Neue Person';

  @override
  String get editPerson => 'Person bearbeiten';

  @override
  String get roleOptional => 'Rolle / Beschreibung (optional)';

  @override
  String get addPersonTooltip => 'Person hinzufügen';

  @override
  String get photoAlbumTitle => 'Fotoalbum';

  @override
  String get noPhotosYet => 'Noch keine Fotos vorhanden';

  @override
  String get noPhotosHint =>
      'Fotos können bei Orten und Besuchen hinzugefügt werden.';

  @override
  String get withoutPlace => 'Ohne Ort';

  @override
  String photoCount(int count) {
    return '$count Foto';
  }

  @override
  String photoCountPlural(int count) {
    return '$count Fotos';
  }

  @override
  String get photoDeleteTitle => 'Foto löschen';

  @override
  String get photoDeleteContent => 'Dieses Foto wirklich löschen?';

  @override
  String get placeGroupsTitle => 'Ortsgruppen';

  @override
  String get noGroupsYet => 'Noch keine Gruppen vorhanden.';

  @override
  String get groupDeleteTitle => 'Gruppe löschen?';

  @override
  String groupDeleteContent(String name) {
    return '„$name\" wirklich löschen?';
  }

  @override
  String get newGroup => 'Neue Gruppe';

  @override
  String get editGroup => 'Gruppe bearbeiten';

  @override
  String get calendarChosen => 'Kalender gewählt';

  @override
  String get noCalendar => 'Kein Kalender';

  @override
  String get telegramChosen => 'Telegram gewählt';

  @override
  String get noTelegram => 'Kein Telegram';

  @override
  String get choose => 'Wählen';

  @override
  String get notesInCalendar => 'Notizen in Kalender';

  @override
  String get personsInCalendar => 'Personen in Kalender';

  @override
  String get activitiesInCalendar => 'Tätigkeiten in Kalender';

  @override
  String get autoGroup => 'Auto-Gruppe';

  @override
  String get autoGroupSubtitle =>
      'Automatisch erkannte Orte werden hier einsortiert';

  @override
  String get pickCalendar => 'Kalender wählen';

  @override
  String get addGroupTooltip => 'Gruppe hinzufügen';

  @override
  String repositionTitle(String name) {
    return 'Position: $name';
  }

  @override
  String get repositionConfirmTitle => 'Position übernehmen?';

  @override
  String repositionConfirmContent(String name, String lat, String lng) {
    return '„$name\" wird auf\n$lat, $lng\nverschoben.';
  }

  @override
  String get showCurrentLocation => 'Aktuellen Standort anzeigen';

  @override
  String placeVisitsTitle(String name) {
    return 'Besuche: $name';
  }

  @override
  String get syncSourcesTitle => 'Sync-Quellen';

  @override
  String get stayPersons => 'Aufenthalts-Personen';

  @override
  String get stayActivities => 'Aufenthalts-Tätigkeiten';

  @override
  String get placeExperiences => 'Orts-Erfahrungen';

  @override
  String get sourceExperiences => 'Quellen-Erfahrungen';

  @override
  String get sourceDeleteTitle => 'Quelle löschen?';

  @override
  String sourceDeleteContent(String name) {
    return '„$name\" wird unwiderruflich gelöscht.';
  }

  @override
  String get syncWarning =>
      '⚠️ Es wird dringend empfohlen, vor der Synchronisation eine Sicherheitskopie der Datenbank zu exportieren (Einstellungen → Datenbank-Dump).\n\nJetzt synchronisieren?';

  @override
  String get syncAllTitle => 'Alle synchronisieren';

  @override
  String get syncAllWarning =>
      '⚠️ Es wird dringend empfohlen, vor der Synchronisation eine Sicherheitskopie der Datenbank zu exportieren (Einstellungen → Datenbank-Dump).\n\nMit allen aktiven Sync-Quellen synchronisieren?';

  @override
  String get newSyncSource => 'Neue Sync-Quelle';

  @override
  String get editSyncSource => 'Quelle bearbeiten';

  @override
  String get syncAddress => 'Sync-Adresse *';

  @override
  String get syncAddressHint => 'http://192.168.1.10:8000';

  @override
  String get apiKey => 'API-Key';

  @override
  String get infoUrlOptional => 'Info-URL (optional)';

  @override
  String get infoUrlHint => 'https://example.com';

  @override
  String get syncOptionsTitle => 'Sync-Optionen';

  @override
  String get syncOptionsWarning =>
      '⚠️ Vor dem Aktivieren von Bearbeiten/Löschen empfiehlt sich ein Datenbank-Export als Sicherheitskopie.';

  @override
  String get insert => 'Einfügen';

  @override
  String get noSyncOptions => 'Keine Sync-Optionen aktiv';

  @override
  String tablesActive(int count) {
    return '$count Tabellen aktiv';
  }

  @override
  String get noExperiences => 'Noch keine Erfahrungen vorhanden.';

  @override
  String get experiencesTitle => 'Erfahrungen';

  @override
  String get syncTitle => 'Synchronisieren';

  @override
  String syncResultSuccess(int pulled, int pushed) {
    return '$pulled empfangen, $pushed gesendet';
  }

  @override
  String syncError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get noActiveSyncSources => 'Keine aktiven Sync-Quellen konfiguriert';

  @override
  String syncAllResult(int ok, int pulled, int pushed) {
    return '$ok Quelle(n) OK ($pulled empfangen, $pushed gesendet)';
  }

  @override
  String syncAllResultWithErrors(int ok, int pulled, int pushed, int fail) {
    return '$ok Quelle(n) OK ($pulled empfangen, $pushed gesendet), $fail Fehler';
  }

  @override
  String get syncAllTooltip => 'Alle synchronisieren';

  @override
  String get addSourceTooltip => 'Quelle hinzufügen';

  @override
  String get noSyncSources =>
      'Keine Sync-Quellen vorhanden.\nTippe + um eine hinzuzufügen.';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncOptionsMenu => 'Sync-Optionen';

  @override
  String get addExperience => 'Erfahrung hinzufügen';

  @override
  String get experienceHint => 'Notiz, Erfahrung oder Bewertung…';

  @override
  String get syncAddressLabel => 'Sync-Adresse';

  @override
  String get infoUrlLabel => 'Info-URL';

  @override
  String get activeSyncOptions => 'Aktive Sync-Optionen';

  @override
  String get telegramConnectionsTitle => 'Telegram-Verbindungen';

  @override
  String get noTelegramConnections =>
      'Noch keine Telegram-Verbindungen vorhanden.';

  @override
  String get connectionDeleteTitle => 'Verbindung löschen?';

  @override
  String connectionDeleteContent(String name) {
    return '„$name\" wird unwiderruflich gelöscht.';
  }

  @override
  String get newTelegramConnection => 'Neue Telegram-Verbindung';

  @override
  String get editTelegramConnection => 'Verbindung bearbeiten';

  @override
  String get chatIdLabel => '-ID-Nummer oder @Kanalname *';

  @override
  String get chatIdHint => '-123... oder @Kanal';

  @override
  String get botTokenLabel => 'Bot-Token *';

  @override
  String get botTokenHint => '123456:ABC-DEF…';

  @override
  String get distance => 'Entfernung';

  @override
  String maxDistance(String dist) {
    return 'max. $dist';
  }

  @override
  String get resetFilter2 => 'Zurücksetzen';

  @override
  String get activateExperienceFilter => 'Aktiviere Erfahrungsfilter';

  @override
  String get deviceIdExperienceFilter =>
      'Nur Erfahrungen mit\n aktueller Geräte ID';

  @override
  String get deviceIdPlaceFilter => 'Nur Orte mit\n aktueller Geräte ID';

  @override
  String get deviceIdStayFilter => 'Nur Besuche mit\n aktueller Geräte ID';

  @override
  String get minAvgRating => 'Min. ⌀ Bewertung:';

  @override
  String get minMedianRating => 'Min. x̃ Bewertung:';

  @override
  String get minSpecialRating => 'Min. Bewertung:';

  @override
  String get ratingMetricAverage => 'Durchschnitt';

  @override
  String get ratingMetricMedian => 'Median';

  @override
  String get camera => 'Kamera';

  @override
  String get fromGallery => 'Aus Galerie';

  @override
  String get noPhotosGrid => 'Noch keine Fotos';

  @override
  String get captionTitle => 'Beschriftung';

  @override
  String get captionHint => 'Beschriftung eingeben';

  @override
  String get editCaptionTooltip => 'Beschriftung bearbeiten';

  @override
  String get deletePhotoTooltip => 'Foto löschen';

  @override
  String get photosAtPlace => 'Fotos am Ort';

  @override
  String get noPlacePhotos => 'Noch keine Fotos am Ort.';

  @override
  String get photosFromVisits => 'Fotos aus Besuchen';

  @override
  String get noVisitPhotos => 'Keine Besuchs-Fotos vorhanden.';

  @override
  String get visit => 'Besuch';

  @override
  String get stillRunning => 'läuft noch…';

  @override
  String get editStay => 'Aufenthalt bearbeiten';

  @override
  String get openPlaceSettings => 'Ort-Einstellungen öffnen';

  @override
  String get begin => 'Beginn';

  @override
  String get end => 'Ende';

  @override
  String get notes => 'Notizen';

  @override
  String get intervalVisit => 'Intervall-Besuch';

  @override
  String get intervalVisitSubtitle => 'Besuch zählt zur Intervall-Berechnung';

  @override
  String get addPersonSheetTitle => 'Person hinzufügen';

  @override
  String get nameNewHint => 'Name eingeben (neu)';

  @override
  String get addActivitySheetTitle => 'Tätigkeit hinzufügen';

  @override
  String get activityNewHint => 'Tätigkeit eingeben (neu)';

  @override
  String get photos => 'Fotos';

  @override
  String get deleteStay => 'Aufenthalt löschen';

  @override
  String get deleteStayTitle => 'Aufenthalt löschen';

  @override
  String get deleteStayContent =>
      'Soll dieser Aufenthalt wirklich gelöscht werden? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get personNewHint => 'Name eingeben (neu)';

  @override
  String get experienceDeleteTitle => 'Erfahrung löschen?';

  @override
  String get experienceDeleteContent =>
      'Dieser Eintrag wird unwiderruflich gelöscht.';

  @override
  String get addOrEditExperienceTitle => 'Erfahrung hinzufügen';

  @override
  String get editExperienceTitle => 'Erfahrung bearbeiten';

  @override
  String get reportOptional => 'Bericht (optional)';

  @override
  String get ratingsLabel => 'Bewertungen (−9 bis +9):';

  @override
  String get ratingDangerFriendly => 'Gefährlich ↔ Freundlich';

  @override
  String get ratingFraudReliable => 'Betrügerisch ↔ Zuverlässig';

  @override
  String get ratingDismissiveAccommodation => 'Abweisend ↔ Bietet Unterkunft';

  @override
  String get ratingFood => 'Fordert ↔ Bietet Verpflegung';

  @override
  String get ratingEquipment => 'Fordert ↔ Bietet Equipment';

  @override
  String get ratingTransport => 'Fordert ↔ Bietet Transport';

  @override
  String get ratingMedicine => 'Fordert ↔ Bietet Medizinische Versorgung';

  @override
  String get filterByGroup => 'Nach Gruppe filtern';

  @override
  String get filterByPlaceType => 'Nach Ortstyp filtern';

  @override
  String get filterModeGeneral => 'Allgemeiner Filter';

  @override
  String get filterModeSpecific => 'Spezieller Filter';

  @override
  String get selectRatingDimension => 'Bewertungsdimension:';

  @override
  String get ratingTableOverall => 'Gesamt';

  @override
  String get loadingRatings => 'Lade...';

  @override
  String get noExperiencesYet => 'Noch keine Erfahrungsberichte vorhanden.';

  @override
  String get survivalExperiences => 'Survival-Erfahrungen';

  @override
  String get statistics => 'Statistik';

  @override
  String get visitNow => 'Jetzt besuchen';

  @override
  String get copyFullReport => 'Vollständigen Bericht kopieren';

  @override
  String get sendReportToTelegram => 'Bericht an Telegram senden';

  @override
  String get visitInterval => 'Besuchs-Intervall';

  @override
  String get intervalDaysLabel => 'Intervall (Tage)';

  @override
  String get intervalDaysHint => 'z. B. 14';

  @override
  String get intervalDaysSuffix => 'Tage';

  @override
  String get changePositionOnMap => 'Position auf Karte ändern';

  @override
  String radius(String m) {
    return 'Radius: $m m';
  }

  @override
  String get group => 'Gruppe';

  @override
  String get noGroup => 'Keine Gruppe';

  @override
  String get placeDeleteTitle => 'Ort löschen?';

  @override
  String placeDeleteContent(String name) {
    return '„$name\" wirklich löschen?';
  }

  @override
  String get gpsCopied => 'GPS-Koordinaten kopiert';

  @override
  String get reportCopied => 'Bericht in Zwischenablage kopiert';

  @override
  String get telegramSendTitle => 'An Telegram senden?';

  @override
  String telegramSendContent(String place, String connection) {
    return 'Bericht für „$place\" an „$connection\" senden?';
  }

  @override
  String get openInGoogleMaps => 'In Google Maps öffnen';

  @override
  String get noteName => 'Notiz';

  @override
  String get website => 'Website';

  @override
  String get email => 'E-Mail';

  @override
  String get phone => 'Telefon';

  @override
  String get saveVisit => 'Besuch speichern';

  @override
  String get importAutoOpenHint =>
      'Diese App öffnet sich automatisch, wenn du eine Datei hierher teilst.';

  @override
  String get importOverwriteWarning =>
      'Alle vorhandenen Daten werden überschrieben.';

  @override
  String get importNow => 'Jetzt importieren';

  @override
  String get importWaiting => 'Warte auf geteilte Datei …';

  @override
  String get syncFromFileNow => 'Zusammenführen';

  @override
  String get syncFromFileTitle => 'Datenbank zusammenführen?';

  @override
  String get syncFromFileContent =>
      'Die empfangene Datenbank wird mit der aktuellen zusammengeführt. Neuere Einträge überschreiben ältere (Last-Write-Wins). Bestehende Daten bleiben erhalten.\n\nFortfahren?';

  @override
  String syncFromFileSuccess(int count) {
    return 'Datenbank zusammengeführt ($count Einträge verarbeitet)';
  }

  @override
  String syncFromFileFailed(String error) {
    return 'Zusammenführen fehlgeschlagen: $error';
  }

  @override
  String get syncFromFileModeTitle => 'Sync-Umfang wählen';

  @override
  String get syncFromFileModeDescription =>
      'Sollen alle Tabellen vollständig zusammengeführt werden, oder möchtest du einzelne Tabellen und Operationen auswählen?';

  @override
  String get syncFromFileModeAll => 'Alles zusammenführen';

  @override
  String get syncFromFileModeCustom => 'Auswählen …';

  @override
  String get placePhotos => 'Fotos';

  @override
  String get resetTitle => 'Datenbank zurücksetzen';

  @override
  String get resetDescription =>
      'Alle Daten werden unwiderruflich gelöscht. Die Datenbankstruktur bleibt erhalten.';

  @override
  String get resetIrreversibleWarning =>
      'Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get deleteAllData => 'Alle Daten löschen';

  @override
  String get trackingActivateTitle => 'Tracking aktivieren?';

  @override
  String get trackingDeactivateTitle => 'Tracking deaktivieren?';

  @override
  String get trackingActivateContent =>
      'Soll das automatische Hintergrund-Tracking gestartet werden?';

  @override
  String get trackingDeactivateContent =>
      'Soll das automatische Hintergrund-Tracking gestoppt werden?';

  @override
  String get trackingActiveTooltip => 'Tracking aktiv';

  @override
  String get trackingInactiveTooltip => 'Tracking inaktiv';

  @override
  String get trackingNotificationText => 'Automatisches Tracking aktiv';

  @override
  String trackingStatusHaltUnknownAddress(String address) {
    return 'Halten: $address';
  }

  @override
  String get newPlaceTitle => 'Neuer Ort';

  @override
  String get placeEditTitle => 'Ort bearbeiten';

  @override
  String get placeOriginAuto => 'Automatisch erstellt';

  @override
  String get placeOriginImported => 'Importiert';

  @override
  String get managePlaceGroups => 'Ortsgruppen verwalten';

  @override
  String get visitIntervalSubtitle =>
      'Regelmäßige Erinnerung, diesen Ort zu besuchen';

  @override
  String get infoAndStats => 'Informationen & Statistik';

  @override
  String get neverVisited => 'Noch nicht besucht';

  @override
  String lastVisitedAt(String date) {
    return '· zuletzt $date';
  }

  @override
  String placeCreatedAt(String date) {
    return 'Erstellt: $date';
  }

  @override
  String get showVisits => 'Besuche anzeigen';

  @override
  String showVisitsCount(int count) {
    return 'Besuche anzeigen ($count)';
  }

  @override
  String get copyReportHint =>
      'Kopiert einen vollständigen Bericht des Ortes einschließlich aller Besuche und Survival-Erfahrungen im Markdown Format in die Zwischenablage.';

  @override
  String get gpsSettings => 'GPS Einstellungen';

  @override
  String get telegramSent => 'Bericht an Telegram gesendet';

  @override
  String telegramError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get createVisitTitle => 'Besuch erstellen';

  @override
  String get noVisitsRecorded => 'Noch keine Besuche aufgezeichnet.';

  @override
  String get statFirstVisit => 'Erster Besuch';

  @override
  String get statLastVisit => 'Letzter Besuch';

  @override
  String get statShortest => 'Kürzester Besuch';

  @override
  String get statLongest => 'Längster Besuch';

  @override
  String get statAverage => 'Durchschnitt';

  @override
  String get statMedian => 'x̃';

  @override
  String openLabel(String label) {
    return '$label öffnen';
  }

  @override
  String get sectionPhotos => 'Fotos';

  @override
  String photoMaxWidth(int value) {
    return 'Max. Breite ($value px)';
  }

  @override
  String photoMaxHeight(int value) {
    return 'Max. Höhe ($value px)';
  }

  @override
  String get photoMaxDimensionSubtitle => '0 = unbegrenzt';

  @override
  String photoImageQuality(int value) {
    return 'Bildqualität ($value %)';
  }

  @override
  String get sharePhoto => 'Foto teilen';

  @override
  String get skip => 'Überspringen';

  @override
  String get address => 'Adresse';

  @override
  String get filterByTrustedSources => 'Nur vertrauenswürdige Quellen';

  @override
  String get trustedSourcesTitle => 'Vertrauenswürdige Quellen';

  @override
  String get trustedSourcesSubtitle => 'Bekannte Geräte-IDs verwalten';

  @override
  String get noTrustedSources =>
      'Keine bekannten Geräte-IDs.\nNutze Aktualisieren um Geräte-IDs aus der Datenbank zu sammeln.';

  @override
  String get refreshTrustedSources => 'Geräte-IDs aus Datenbank sammeln';

  @override
  String get addTrustedSource => 'Vertrauenswürdige Quelle hinzufügen';

  @override
  String get editTrustedSource => 'Quelle bearbeiten';

  @override
  String get trustedDeviceIdLabel => 'Geräte-ID';

  @override
  String get trustedSourceDeleteTitle => 'Vertrauenswürdige Quelle entfernen?';

  @override
  String get trustedDevicesSection => 'Vertrauenswürdig';

  @override
  String get knownDevicesSection => 'Bekannte Geräte';

  @override
  String get confirmMarkTrustedTitle => 'Als vertrauenswürdig markieren?';

  @override
  String get confirmMarkUntrustedTitle => 'Vertrauen entziehen?';

  @override
  String get deviceNameDialogTitle => 'Gerät benennen';

  @override
  String get deviceNameDialogContent =>
      'Gib diesem Gerät einen Namen (3–20 Zeichen). Der Name wird fest mit einer UUID verbunden und bildet die Geräte-ID: Name@uuid\n\nDieser Name kann später nicht geändert werden.';

  @override
  String get deviceNameLabel => 'Gerätename';

  @override
  String get deviceNameHint => 'z. B. Alice, MeinHandy';

  @override
  String get deviceNameLengthHint => '3–20 Zeichen, Pflichtfeld';

  @override
  String get databaseExplorerButton => 'Datenbank Explorer';

  @override
  String get generateRandomData => 'Erstelle zufällige Testdaten';

  @override
  String get databaseExplorerScreenHeader => 'SQLite Explorer';

  @override
  String get databaseExplorerTableLabel => 'Tabelle';

  @override
  String get noDataOrTableSelected =>
      'Keine Daten oder keine Tabelle ausgewählt';

  @override
  String get loadMoreRows => 'Lade mehr Daten';

  @override
  String get endOfTableReached => 'Ende der Tabelle erreicht';

  @override
  String editFieldTitle(String value) {
    return 'Bearbeite Tabelle $value';
  }

  @override
  String get newValueLabel => 'Neuer Wert';

  @override
  String get databaseUpdated => 'Datenbank aktualisiert';

  @override
  String get sharedPrefsExplorerButton => 'Shared Preferences Explorer';

  @override
  String get sharedPrefsExplorerScreenHeader => 'Shared Preferences Explorer';

  @override
  String get sharedPrefsNoEntries => 'Keine Einträge vorhanden';

  @override
  String sharedPrefsEditTitle(String key) {
    return 'Bearbeite $key';
  }

  @override
  String get sharedPrefsDeleteTitle => 'Eintrag löschen';

  @override
  String sharedPrefsDeleteConfirm(String key) {
    return 'Soll der Eintrag \"$key\" wirklich gelöscht werden?';
  }

  @override
  String get sharedPrefsDeleted => 'Eintrag gelöscht';

  @override
  String get sharedPrefsUpdated => 'Eintrag aktualisiert';

  @override
  String sharedPrefsInvalidValue(String type) {
    return 'Ungültiger Wert für Typ $type';
  }

  @override
  String nextGpsIn(int value) {
    return 'Nächster GPS in $value sek.';
  }

  @override
  String get devToolsSectionTitle => 'Entwicklerwerkzeuge';

  @override
  String get devToolsWarning =>
      'WARNUNG: Diese Werkzeuge sind potentiell ZERSTÖRERISCH. Sie können Daten unwiderruflich verändern oder löschen. Nach dem Freischalten sind sie für eine Stunde nutzbar. Es ist SEHR SEHR SEHR ratsam, vorher wenigstens ein Backup der Datenbank anzulegen!';

  @override
  String get devToolsUnlockButton => 'Entwicklerwerkzeuge freischalten';

  @override
  String get devToolsChallengeInstruction =>
      'Tippe die folgende 8-stellige Zeichenfolge exakt ab, um freizuschalten:';

  @override
  String get devToolsChallengeHint => 'Zeichenfolge eingeben';

  @override
  String get devToolsUnlockSuccess =>
      'Entwicklerwerkzeuge für eine Stunde freigeschaltet.';

  @override
  String devToolsUnlockedUntil(String time) {
    return 'Freigeschaltet bis $time';
  }

  @override
  String get devToolsRelock => 'Jetzt sperren';

  @override
  String get messagesTitle => 'Nachrichten';

  @override
  String get messagesPlaceTitle => 'Ort-Nachrichten';

  @override
  String get messagesRegionTitle => 'Nachrichten der Region';

  @override
  String get messagesEmpty => 'Noch keine Nachrichten.';

  @override
  String get messageDeleteTitle => 'Nachricht löschen?';

  @override
  String get messageNeedsPlace =>
      'Nachrichten benötigen einen Ort. Bitte in einem Ort verfassen.';

  @override
  String get messageAuthorSelf => 'Ich';

  @override
  String get messageDeleted => '[gelöschte Nachricht]';

  @override
  String get messagePhotoPlaceholder => '[Foto]';

  @override
  String get reply => 'Antworten';

  @override
  String replyingTo(String preview) {
    return 'Antwort auf: $preview';
  }

  @override
  String get noPlaceAvailable => 'Kein Ort verfügbar.';

  @override
  String get noPhotosAtPlace => 'Keine Fotos an diesem Ort.';

  @override
  String get gallery => 'Galerie';

  @override
  String get existingPlacePhoto => 'Vorhandenes Foto des Ortes';

  @override
  String get messageHint => 'Nachricht…';

  @override
  String get placeMessagesButton => 'Nachrichten zum Ort';

  @override
  String get createPlace => 'Ort erstellen';

  @override
  String get showRegionMessages => 'Nachrichten der Region zeigen';

  @override
  String get regionRadiusTitle => 'Radius der Region';

  @override
  String get radiusInKm => 'Radius in km';

  @override
  String get showAction => 'Anzeigen';

  @override
  String get sectionP2pMessenger => 'P2P-Messenger';

  @override
  String get messengerEnable => 'Messenger aktivieren';

  @override
  String get messengerEnableSubtitle =>
      'Ortsgebundener P2P-Chat im Orte-Tab (Store-and-Forward).';

  @override
  String get createPlaceOnSync => 'Orte bei Sync-Gelegenheit erstellen';

  @override
  String get createPlaceOnSyncSubtitle =>
      'Legt bei einer Synchronisationsgelegenheit automatisch einen Ort als „Sync-Quelle\" an – auch wenn die automatische Ortserstellung deaktiviert ist. Nötig, damit dort empfangene Nachrichten einen Bezugsort haben.';

  @override
  String get syncPhotos => 'Fotos synchronisieren';

  @override
  String get syncPhotosSubtitle =>
      'Bilder über das Mesh übertragen (base64 im JSON – kann groß werden).';

  @override
  String get photoSizeLimitUnlimited => 'Foto-Größenlimit: unbegrenzt';

  @override
  String photoSizeLimitKib(int kib) {
    return 'Foto-Größenlimit: $kib KiB';
  }

  @override
  String get unlimited => 'unbegrenzt';

  @override
  String get nodeScanModeLabel => 'Node-Scan-Modus';

  @override
  String get nodeScanOnHalt => 'Bei Halt am Ort';

  @override
  String get nodeScanPerGps => 'Pro GPS-Intervall';

  @override
  String nodeScanEvery(int count) {
    return 'Scan alle $count GPS-Intervalle';
  }

  @override
  String get autoCreatePlacesMessengerNote =>
      'Hinweis: Ortsgebundene Nachrichten des P2P-Messengers benötigen zwingend einen Ort als Bezugspunkt. Ist die automatische Ortserstellung aus, können bei Synchronisationsgelegenheiten dennoch Orte als „Sync-Quelle\" angelegt werden (siehe P2P-Messenger).';
}
