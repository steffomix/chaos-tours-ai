import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// App title
  ///
  /// In de, this message translates to:
  /// **'Chaos Tours'**
  String get appTitle;

  /// Cancel button
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// Save button
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// Delete button
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// Edit button
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get edit;

  /// Add button
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get add;

  /// OK button
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get ok;

  /// Yes
  ///
  /// In de, this message translates to:
  /// **'Ja'**
  String get yes;

  /// No
  ///
  /// In de, this message translates to:
  /// **'Nein'**
  String get no;

  /// Search
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get search;

  /// None
  ///
  /// In de, this message translates to:
  /// **'Keine'**
  String get none;

  /// All label
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get all;

  /// Create button
  ///
  /// In de, this message translates to:
  /// **'Erstellen'**
  String get create;

  /// Close
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get close;

  /// Send
  ///
  /// In de, this message translates to:
  /// **'Senden'**
  String get send;

  /// Apply
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get apply;

  /// Unknown
  ///
  /// In de, this message translates to:
  /// **'Unbekannt'**
  String get unknown;

  /// App version
  ///
  /// In de, this message translates to:
  /// **'Version 2.0.0'**
  String get version;

  /// Name label
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get name;

  /// Reset
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get reset;

  /// Required field validation message
  ///
  /// In de, this message translates to:
  /// **'Pflichtfeld'**
  String get required;

  /// Description label
  ///
  /// In de, this message translates to:
  /// **'Beschreibung'**
  String get description;

  /// Active status
  ///
  /// In de, this message translates to:
  /// **'Aktiv'**
  String get active;

  /// Type label
  ///
  /// In de, this message translates to:
  /// **'Typ'**
  String get type;

  /// Replace button
  ///
  /// In de, this message translates to:
  /// **'Ersetzen'**
  String get replace;

  /// Synchronize button
  ///
  /// In de, this message translates to:
  /// **'Synchronisieren'**
  String get synchronize;

  /// Bottom nav: Home
  ///
  /// In de, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom nav: Map
  ///
  /// In de, this message translates to:
  /// **'Karte'**
  String get navMap;

  /// Bottom nav: Places
  ///
  /// In de, this message translates to:
  /// **'Orte'**
  String get navPlaces;

  /// Bottom nav: Visits
  ///
  /// In de, this message translates to:
  /// **'Besuche'**
  String get navVisits;

  /// Bottom nav: Photos
  ///
  /// In de, this message translates to:
  /// **'Fotos'**
  String get navPhotos;

  /// Tracking disabled status
  ///
  /// In de, this message translates to:
  /// **'Tracking deaktiviert'**
  String get trackingDisabled;

  /// Tracking running status
  ///
  /// In de, this message translates to:
  /// **'Tracking läuft…'**
  String get trackingRunning;

  /// Tracking active
  ///
  /// In de, this message translates to:
  /// **'Tracking aktiv'**
  String get trackingActive;

  /// Tracking inactive
  ///
  /// In de, this message translates to:
  /// **'Tracking inaktiv'**
  String get trackingInactive;

  /// Tracking status: moving
  ///
  /// In de, this message translates to:
  /// **'Unterwegs'**
  String get trackingStatusMoving;

  /// Staying at known place
  ///
  /// In de, this message translates to:
  /// **'Halten bei {place}'**
  String trackingStatusHaltKnown(String place);

  /// Staying at unknown address
  ///
  /// In de, this message translates to:
  /// **'Halten: {address}'**
  String trackingStatusHaltUnknown(String address);

  /// Staying (generic)
  ///
  /// In de, this message translates to:
  /// **'Halten'**
  String get trackingStatusHalt;

  /// Detecting stay
  ///
  /// In de, this message translates to:
  /// **'Aufenthalt wird erkannt…'**
  String get trackingStatusDetecting;

  /// Tracking collecting GPS data
  ///
  /// In de, this message translates to:
  /// **'Tracking sammelt GPS Daten…'**
  String get trackingCollecting;

  /// Loading Virtual Device
  ///
  /// In de, this message translates to:
  /// **'Virtuelles Gerät laden…'**
  String get virtualDeviceLoading;

  /// Unknown place
  ///
  /// In de, this message translates to:
  /// **'Unbekannter Ort'**
  String get unknownPlace;

  /// Since hours and minutes
  ///
  /// In de, this message translates to:
  /// **'Seit {h}h {m}min'**
  String sinceHoursMinutes(int h, int m);

  /// Since minutes
  ///
  /// In de, this message translates to:
  /// **'Seit {m}min'**
  String sinceMinutes(int m);

  /// End and share stay button
  ///
  /// In de, this message translates to:
  /// **'Aufenthalt jetzt beenden & teilen'**
  String get endStayNow;

  /// End stay dialog title
  ///
  /// In de, this message translates to:
  /// **'Aufenthalt beenden?'**
  String get endStayTitle;

  /// End stay dialog content
  ///
  /// In de, this message translates to:
  /// **'Der aktuelle Aufenthalt wird jetzt abgeschlossen. Das Tracking läuft weiter und startet bei gleichem Ort sofort einen neuen Aufenthalt.'**
  String get endStayContent;

  /// End stay button
  ///
  /// In de, this message translates to:
  /// **'Beenden'**
  String get endStayButton;

  /// Button label while end-stay is in progress
  ///
  /// In de, this message translates to:
  /// **'Aufenthalt wird beendet…'**
  String get endStayEnding;

  /// No visits recorded yet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Besuche aufgezeichnet.'**
  String get noVisitsYet;

  /// Recent visits section title
  ///
  /// In de, this message translates to:
  /// **'Letzte Besuche'**
  String get recentVisits;

  /// Enable tracking dialog title
  ///
  /// In de, this message translates to:
  /// **'Tracking aktivieren?'**
  String get enableTracking;

  /// Disable tracking dialog title
  ///
  /// In de, this message translates to:
  /// **'Tracking deaktivieren?'**
  String get disableTracking;

  /// Enable tracking dialog content
  ///
  /// In de, this message translates to:
  /// **'Soll das automatische Hintergrund-Tracking gestartet werden?'**
  String get enableTrackingContent;

  /// Disable tracking dialog content
  ///
  /// In de, this message translates to:
  /// **'Soll das automatische Hintergrund-Tracking gestoppt werden?'**
  String get disableTrackingContent;

  /// Activate button
  ///
  /// In de, this message translates to:
  /// **'Aktivieren'**
  String get activate;

  /// Deactivate button
  ///
  /// In de, this message translates to:
  /// **'Deaktivieren'**
  String get deactivate;

  /// Battery optimization dialog title
  ///
  /// In de, this message translates to:
  /// **'Akkuoptimierung deaktivieren'**
  String get batteryOptTitle;

  /// Battery optimization dialog content
  ///
  /// In de, this message translates to:
  /// **'Der Hintergrund-Dienst konnte nicht gestartet werden.\n\nBitte deaktiviere die Akkuoptimierung für Chaos Tours:\nEinstellungen → Apps → Chaos Tours → Akku → Nicht eingeschränkt'**
  String get batteryOptContent;

  /// Open settings button
  ///
  /// In de, this message translates to:
  /// **'Einstellungen öffnen'**
  String get openSettings;

  /// Settings screen title
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settingsTitle;

  /// Settings saved snackbar
  ///
  /// In de, this message translates to:
  /// **'Einstellungen gespeichert'**
  String get settingsSaved;

  /// VirtualDevices section header
  ///
  /// In de, this message translates to:
  /// **'Virtuelle Geräte'**
  String get sectionVirtualDevices;

  /// No Virtual Device
  ///
  /// In de, this message translates to:
  /// **'Kein Virtuelles Gerät'**
  String get noVirtualDevices;

  /// Virtual Devices count
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one{{count} virtuelles Gerät vorhanden} other{{count} virtuelle Geräte vorhanden}}'**
  String virtualDevicesCount(int count);

  /// Rename tooltip
  ///
  /// In de, this message translates to:
  /// **'Umbenennen'**
  String get tooltipRename;

  /// Switch or create tooltip
  ///
  /// In de, this message translates to:
  /// **'Wechseln / Neu erstellen'**
  String get tooltipSwitchCreate;

  /// No description provided for @deviceId.
  ///
  /// In de, this message translates to:
  /// **'Geräte ID'**
  String get deviceId;

  /// No description provided for @deviceIdCopied.
  ///
  /// In de, this message translates to:
  /// **'Geräte ID Kopiert'**
  String get deviceIdCopied;

  /// No description provided for @uuidCopied.
  ///
  /// In de, this message translates to:
  /// **'UUID Kopiert'**
  String get uuidCopied;

  /// No description provided for @messageCopied.
  ///
  /// In de, this message translates to:
  /// **'Nachrichtentext kopiert'**
  String get messageCopied;

  /// Tracking section header
  ///
  /// In de, this message translates to:
  /// **'Tracking'**
  String get sectionTracking;

  /// GPS interval setting
  ///
  /// In de, this message translates to:
  /// **'GPS-Intervall: {value}s'**
  String gpsInterval(int value);

  /// GPS interval hint
  ///
  /// In de, this message translates to:
  /// **'Hinweis: Änderungen des Intervalls erforderdern einen vollständigen Neustart der App inklusive des Hintergrund Tracking.'**
  String get gpsIntervalHint;

  /// GPS smoothing setting
  ///
  /// In de, this message translates to:
  /// **'GPS-Glättung: {value}'**
  String gpsSmoothing(String value);

  /// GPS smoothing disabled
  ///
  /// In de, this message translates to:
  /// **'deaktiviert'**
  String get gpsSmoothingDisabled;

  /// GPS smoothing points
  ///
  /// In de, this message translates to:
  /// **'{n} Punkte'**
  String gpsSmoothingPoints(int n);

  /// GPS smoothing hint
  ///
  /// In de, this message translates to:
  /// **'Mittelt die letzten N GPS-Punkte.'**
  String get gpsSmoothingHint;

  /// Stay detection setting
  ///
  /// In de, this message translates to:
  /// **'Aufenthalt erkennen nach: {min} min'**
  String stayDetection(int min);

  /// Auto place creation time
  ///
  /// In de, this message translates to:
  /// **'Auto-Ort erstellen nach: {min} min'**
  String autoPlaceTime(int min);

  /// Default radius setting
  ///
  /// In de, this message translates to:
  /// **'Standard-Radius: {m} m'**
  String defaultRadius(String m);

  /// Auto create places toggle
  ///
  /// In de, this message translates to:
  /// **'Orte automatisch erstellen'**
  String get autoCreatePlaces;

  /// Auto create places subtitle
  ///
  /// In de, this message translates to:
  /// **'Neue Orte bei langen Aufenthalten an unbekannten Orten anlegen'**
  String get autoCreatePlacesSubtitle;

  /// Auto place group setting
  ///
  /// In de, this message translates to:
  /// **'Gruppe für Auto-Orte'**
  String get autoPlaceGroup;

  /// Default place group setting
  ///
  /// In de, this message translates to:
  /// **'Standard-Gruppe für neue Orte'**
  String get defaultPlaceGroup;

  /// Default place group subtitle
  ///
  /// In de, this message translates to:
  /// **'Voreingestellte Gruppe beim manuellen Erstellen von Orten'**
  String get defaultPlaceGroupSubtitle;

  /// Sync place group setting
  ///
  /// In de, this message translates to:
  /// **'Gruppe für Sync-Orte'**
  String get syncPlaceGroup;

  /// Sync place group subtitle
  ///
  /// In de, this message translates to:
  /// **'Gruppe für automatisch erstellte Orte zur Nachrichtensynchronisation'**
  String get syncPlaceGroupSubtitle;

  /// Map display section header
  ///
  /// In de, this message translates to:
  /// **'Kartendarstellung'**
  String get sectionMapDisplay;

  /// Show GPS points toggle
  ///
  /// In de, this message translates to:
  /// **'GPS-Punkte anzeigen'**
  String get showGpsPoints;

  /// Show GPS points subtitle
  ///
  /// In de, this message translates to:
  /// **'Tracking-Punkte farbig auf der Karte einblenden'**
  String get showGpsPointsSubtitle;

  /// Point size setting
  ///
  /// In de, this message translates to:
  /// **'Punktgröße: {m} m'**
  String pointSize(String m);

  /// Visit history setting
  ///
  /// In de, this message translates to:
  /// **'Besuchs-Verlauf: {days}'**
  String visitHistory(String days);

  /// Visit history one day
  ///
  /// In de, this message translates to:
  /// **'{days} Tag'**
  String visitHistoryDay(int days);

  /// Visit history multiple days
  ///
  /// In de, this message translates to:
  /// **'{days} Tage'**
  String visitHistoryDays(int days);

  /// Visit history hint
  ///
  /// In de, this message translates to:
  /// **'Wie viele Tage der Reiseverlauf auf der Zeitachsen-Karte angezeigt wird.'**
  String get visitHistoryHint;

  /// Planner section header
  ///
  /// In de, this message translates to:
  /// **'Intervall Planer'**
  String get sectionPlanner;

  /// Color range setting
  ///
  /// In de, this message translates to:
  /// **'Farbskala-Bereich: {days}'**
  String colorRange(int days);

  /// Color range hint
  ///
  /// In de, this message translates to:
  /// **'{range} Tage = grün  •  0 = gelb  •  -{range} = rot'**
  String colorRangeHint(int range);

  /// Shown groups setting
  ///
  /// In de, this message translates to:
  /// **'Angezeigte Gruppen (Karte & Planer)'**
  String get shownGroups;

  /// No groups available
  ///
  /// In de, this message translates to:
  /// **'Keine Gruppen vorhanden'**
  String get noGroupsAvailable;

  /// Address search section header
  ///
  /// In de, this message translates to:
  /// **'Adresssuche'**
  String get sectionAddressSearch;

  /// Checkbox: query address on auto place creation
  ///
  /// In de, this message translates to:
  /// **'Adresse bei automatischer Ortserstellung'**
  String get addressOnAutoCreateTitle;

  /// Subtitle for address on auto create
  ///
  /// In de, this message translates to:
  /// **'Adresse per OSM abfragen und beim automatischen Erstellen eines Ortes verwenden.'**
  String get addressOnAutoCreateSubtitle;

  /// Checkbox: query address on manual place creation
  ///
  /// In de, this message translates to:
  /// **'Adresse bei manueller Ortserstellung'**
  String get addressOnManualCreateTitle;

  /// Subtitle for address on manual create
  ///
  /// In de, this message translates to:
  /// **'Adresse per OSM abfragen und als Namensvorschlag beim Anlegen per Langdruck auf der Karte vorausfüllen.'**
  String get addressOnManualCreateSubtitle;

  /// Checkbox: query address on every GPS interval
  ///
  /// In de, this message translates to:
  /// **'Adresse bei jedem GPS-Intervall'**
  String get addressOnIntervalTitle;

  /// Subtitle for address on interval
  ///
  /// In de, this message translates to:
  /// **'Adresse per OSM bei jedem Tracking-Intervall abfragen und im Startbildschirm anzeigen.'**
  String get addressOnIntervalSubtitle;

  /// Custom Nominatim user agent setting
  ///
  /// In de, this message translates to:
  /// **'Eigener User-Agent (OSM)'**
  String get nominatimUserAgent;

  /// Custom Nominatim user agent hint
  ///
  /// In de, this message translates to:
  /// **'z. B. MeineApp/1.0 (kontakt@example.com)'**
  String get nominatimUserAgentHint;

  /// Custom Nominatim user agent subtitle
  ///
  /// In de, this message translates to:
  /// **'Der User-Agent identifiziert die App gegenüber dem OSM-Nominatim-Dienst. Leer lassen für den Standardwert. Verwenden viele Geräte denselben User-Agent, kann der Dienst Anfragen drosseln oder blockieren.'**
  String get nominatimUserAgentSubtitle;

  /// Default country setting
  ///
  /// In de, this message translates to:
  /// **'Standard-Land für Adresssuche'**
  String get defaultCountry;

  /// Default country hint
  ///
  /// In de, this message translates to:
  /// **'z. B. Deutschland'**
  String get defaultCountryHint;

  /// Default country subtitle
  ///
  /// In de, this message translates to:
  /// **'Wird in der Karten-Adresssuche als Standardland vorausgefüllt.'**
  String get defaultCountrySubtitle;

  /// Management section header
  ///
  /// In de, this message translates to:
  /// **'Verwaltung'**
  String get sectionManagement;

  /// Place groups
  ///
  /// In de, this message translates to:
  /// **'Ortsgruppen'**
  String get placeGroups;

  /// Persons
  ///
  /// In de, this message translates to:
  /// **'Personen'**
  String get persons;

  /// Activities
  ///
  /// In de, this message translates to:
  /// **'Tätigkeiten'**
  String get activities;

  /// Database section header
  ///
  /// In de, this message translates to:
  /// **'Datenbank Wartung'**
  String get sectionDatabase;

  /// Database dump
  ///
  /// In de, this message translates to:
  /// **'Datenbank-Dump'**
  String get databaseDump;

  /// Database dump subtitle
  ///
  /// In de, this message translates to:
  /// **'Dump erstellen, laden & teilen'**
  String get databaseDumpSubtitle;

  /// Database cleanup button title
  ///
  /// In de, this message translates to:
  /// **'Datenbank bereinigen'**
  String get dbCleanupTitle;

  /// Database cleanup subtitle
  ///
  /// In de, this message translates to:
  /// **'Herrenlose Einträge entfernen'**
  String get dbCleanupSubtitle;

  /// Database cleanup confirmation dialog title
  ///
  /// In de, this message translates to:
  /// **'Datenbank bereinigen?'**
  String get dbCleanupConfirmTitle;

  /// Database cleanup confirmation dialog content
  ///
  /// In de, this message translates to:
  /// **'Alle verwaisten Einträge (ohne gültigen Elterndatensatz) werden dauerhaft entfernt. Geräte-ID-Felder bleiben dabei unberührt.'**
  String get dbCleanupConfirmContent;

  /// Database cleanup success message
  ///
  /// In de, this message translates to:
  /// **'{deleted} Einträge bereinigt'**
  String dbCleanupSuccess(int deleted);

  /// Purge foreign device entries button title
  ///
  /// In de, this message translates to:
  /// **'Fremde Geräteeinträge entfernen'**
  String get dbPurgeForeignDevicesTitle;

  /// Purge foreign device entries subtitle
  ///
  /// In de, this message translates to:
  /// **'Einträge aller Tabellen von nicht vertrauenswürdigen Geräten löschen'**
  String get dbPurgeForeignDevicesSubtitle;

  /// Purge foreign device entries confirmation dialog title
  ///
  /// In de, this message translates to:
  /// **'Fremde Geräteeinträge entfernen?'**
  String get dbPurgeForeignDevicesConfirmTitle;

  /// Purge foreign device entries confirmation dialog content
  ///
  /// In de, this message translates to:
  /// **'Alle Einträge in sämtlichen Tabellen, deren Geräte-ID weder dem aktuellen Gerät noch einem als vertrauenswürdig markierten Gerät entspricht, werden dauerhaft gelöscht. Das aktuell aktive Gerät gilt grundsätzlich als vertrauenswürdig. Gebrochene Fremdschlüsselreferenzen werden nicht korrigiert.'**
  String get dbPurgeForeignDevicesConfirmContent;

  /// Purge foreign device entries success message
  ///
  /// In de, this message translates to:
  /// **'{deleted} Einträge gelöscht'**
  String dbPurgeForeignDevicesSuccess(int deleted);

  /// Purge soft-deleted records button title
  ///
  /// In de, this message translates to:
  /// **'Gelöschte Einträge bereinigen'**
  String get dbPurgeDeletedTitle;

  /// Purge soft-deleted records subtitle
  ///
  /// In de, this message translates to:
  /// **'Alle als gelöscht markierten Einträge endgültig entfernen'**
  String get dbPurgeDeletedSubtitle;

  /// Purge soft-deleted records confirmation dialog title
  ///
  /// In de, this message translates to:
  /// **'Gelöschte Einträge bereinigen?'**
  String get dbPurgeDeletedConfirmTitle;

  /// Purge soft-deleted records confirmation dialog content
  ///
  /// In de, this message translates to:
  /// **'Alle Einträge in sämtlichen Tabellen, bei denen deleted_at gesetzt ist, werden endgültig und unwiderruflich gelöscht.'**
  String get dbPurgeDeletedConfirmContent;

  /// Purge soft-deleted records success message
  ///
  /// In de, this message translates to:
  /// **'{deleted} Einträge bereinigt'**
  String dbPurgeDeletedSuccess(int deleted);

  /// Sync sources
  ///
  /// In de, this message translates to:
  /// **'Sync-Quellen'**
  String get syncSources;

  /// Sync sources subtitle
  ///
  /// In de, this message translates to:
  /// **'Sync-Server verwalten und synchronisieren'**
  String get syncSourcesSubtitle;

  /// Telegram connections
  ///
  /// In de, this message translates to:
  /// **'Telegram-Verbindungen'**
  String get telegramConnections;

  /// Telegram connections subtitle
  ///
  /// In de, this message translates to:
  /// **'Telegram-Bots für Ortsberichte verwalten'**
  String get telegramConnectionsSubtitle;

  /// Permissions section header
  ///
  /// In de, this message translates to:
  /// **'Berechtigungen'**
  String get sectionPermissions;

  /// Location permission
  ///
  /// In de, this message translates to:
  /// **'Standortberechtigung'**
  String get locationPermission;

  /// Location permission subtitle
  ///
  /// In de, this message translates to:
  /// **'Standort im Vordergrund anfordern'**
  String get locationPermissionSubtitle;

  /// Background location
  ///
  /// In de, this message translates to:
  /// **'Hintergrund-Standort'**
  String get backgroundLocation;

  /// Background location subtitle
  ///
  /// In de, this message translates to:
  /// **'Standort im Hintergrund anfordern'**
  String get backgroundLocationSubtitle;

  /// Notifications
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen'**
  String get notifications;

  /// Notifications subtitle
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungsberechtigung anfordern'**
  String get notificationsSubtitle;

  /// Calendar sync
  ///
  /// In de, this message translates to:
  /// **'Kalender-Sync'**
  String get calendarSync;

  /// Calendar sync subtitle
  ///
  /// In de, this message translates to:
  /// **'Aufenthalte automatisch im Gerätekalender eintragen'**
  String get calendarSyncSubtitle;

  /// Calendar permission
  ///
  /// In de, this message translates to:
  /// **'Kalenderberechtigung anfordern'**
  String get calendarPermission;

  /// Location permission granted
  ///
  /// In de, this message translates to:
  /// **'Standort gewährt'**
  String get locationGranted;

  /// Location permission denied
  ///
  /// In de, this message translates to:
  /// **'Standort verweigert'**
  String get locationDenied;

  /// Background location granted
  ///
  /// In de, this message translates to:
  /// **'Hintergrund-Standort gewährt'**
  String get backgroundLocationGranted;

  /// Background location denied
  ///
  /// In de, this message translates to:
  /// **'Hintergrund-Standort verweigert'**
  String get backgroundLocationDenied;

  /// Notifications permission granted
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen gewährt'**
  String get notificationsGranted;

  /// Notifications permission denied
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen verweigert'**
  String get notificationsDenied;

  /// Calendar permission granted
  ///
  /// In de, this message translates to:
  /// **'Kalender gewährt'**
  String get calendarGranted;

  /// Calendar permission denied
  ///
  /// In de, this message translates to:
  /// **'Kalender verweigert'**
  String get calendarDenied;

  /// Last virtual device can not be deleted
  ///
  /// In de, this message translates to:
  /// **'Das letzte Virtuelle Gerät kann nicht gelöscht werden'**
  String get deleteLastVirtualDeviceNotAllowed;

  /// Delete current virtual Device
  ///
  /// In de, this message translates to:
  /// **'Aktuelles virtuelles Gerät dauerhaft entfernen'**
  String get deleteVirtualDevice;

  /// Pick virtual Device
  ///
  /// In de, this message translates to:
  /// **'Virtuelles Gerät wählen'**
  String get pickVirtualDevice;

  /// Create new virtual Device
  ///
  /// In de, this message translates to:
  /// **'Neues virtuelles Gerät erstellen'**
  String get newVirtualDeviceCreate;

  /// New virtual Device label
  ///
  /// In de, this message translates to:
  /// **'Neues virtuelles Gerät'**
  String get newVirtualDeviceLabel;

  /// Copy settings from
  ///
  /// In de, this message translates to:
  /// **'Einstellungen kopieren von:'**
  String get copySettingsFrom;

  /// Rename virtual device
  ///
  /// In de, this message translates to:
  /// **'Virtuelles Gerät umbenennen'**
  String get renameVirtualDevice;

  /// Delete virtual device dialog title
  ///
  /// In de, this message translates to:
  /// **'Virtuelles Gerät löschen?'**
  String get deleteVirtualDeviceTitle;

  /// Delete virtual device dialog content
  ///
  /// In de, this message translates to:
  /// **'„{name}\" wirklich löschen?\n\nDie Einstellungen dieses virtuellen Gerätes werden unwiderruflich entfernt.'**
  String deleteVirtualDeviceContent(String name);

  /// Virtual device deleted snackbar
  ///
  /// In de, this message translates to:
  /// **'„{name}\" gelöscht'**
  String virtualDeviceDeleted(String name);

  /// Delete virtual Device button label
  ///
  /// In de, this message translates to:
  /// **'„{name}\" löschen'**
  String deleteVirtualDeviceLabel(String name);

  /// Visits screen title
  ///
  /// In de, this message translates to:
  /// **'Besuche'**
  String get visitsTitle;

  /// Search stays hint
  ///
  /// In de, this message translates to:
  /// **'Aufenthalte durchsuchen…'**
  String get searchStaysHint;

  /// Search stays hint
  ///
  /// In de, this message translates to:
  /// **'Aufenthalte durchsuchen…'**
  String get searchStays;

  /// Close search tooltip
  ///
  /// In de, this message translates to:
  /// **'Suche schließen'**
  String get closeSearch;

  /// Filter by date range tooltip
  ///
  /// In de, this message translates to:
  /// **'Datumsbereich filtern'**
  String get filterByDate;

  /// Filter by place tooltip
  ///
  /// In de, this message translates to:
  /// **'Nach Ort filtern'**
  String get filterByPlace;

  /// Reset filter tooltip
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen'**
  String get resetFilter;

  /// Visits tab
  ///
  /// In de, this message translates to:
  /// **'Besuche'**
  String get tabList;

  /// Journey tab
  ///
  /// In de, this message translates to:
  /// **'Reise'**
  String get tabJourney;

  /// Planner tab
  ///
  /// In de, this message translates to:
  /// **'Planer'**
  String get tabPlanner;

  /// No stays found message
  ///
  /// In de, this message translates to:
  /// **'Keine abgeschlossenen Aufenthalte gefunden.\nTracking einschalten um Aufenthalte aufzuzeichnen.'**
  String get noStaysFound;

  /// To last position button
  ///
  /// In de, this message translates to:
  /// **'Zur letzten Position'**
  String get toLastPosition;

  /// No scheduler places message
  ///
  /// In de, this message translates to:
  /// **'Keine Planer-Orte vorhanden.\n\nAktiviere das Besuchs-Intervall für Orte in den Ortseinstellungen.'**
  String get noSchedulerPlaces;

  /// Scheduler today
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get schedulerToday;

  /// Scheduler in N days
  ///
  /// In de, this message translates to:
  /// **'in {n} Tagen'**
  String schedulerInDays(int n);

  /// Scheduler in 1 day
  ///
  /// In de, this message translates to:
  /// **'in {n} Tag'**
  String schedulerInDay(int n);

  /// Scheduler overdue by N days
  ///
  /// In de, this message translates to:
  /// **'{n} Tage überfällig'**
  String schedulerOverdueDays(int n);

  /// Scheduler overdue by 1 day
  ///
  /// In de, this message translates to:
  /// **'{n} Tag überfällig'**
  String schedulerOverdueDay(int n);

  /// Visit interval days
  ///
  /// In de, this message translates to:
  /// **'Intervall: {n} Tage'**
  String intervalDays(int n);

  /// All places
  ///
  /// In de, this message translates to:
  /// **'Alle Orte'**
  String get allPlaces;

  /// Places screen title
  ///
  /// In de, this message translates to:
  /// **'Orte'**
  String get placesTitle;

  /// Search places hint
  ///
  /// In de, this message translates to:
  /// **'Orte durchsuchen…'**
  String get searchPlaces;

  /// Show interval places only tooltip
  ///
  /// In de, this message translates to:
  /// **'Nur Intervall-Orte'**
  String get showIntervalOnly;

  /// Show all places tooltip
  ///
  /// In de, this message translates to:
  /// **'Alle Orte anzeigen'**
  String get showAllPlaces;

  /// Filter
  ///
  /// In de, this message translates to:
  /// **'Filter'**
  String get filter;

  /// Places tab
  ///
  /// In de, this message translates to:
  /// **'Orte'**
  String get tabPlaces;

  /// No places found
  ///
  /// In de, this message translates to:
  /// **'Keine Orte gefunden.'**
  String get noPlacesFound;

  /// No places saved
  ///
  /// In de, this message translates to:
  /// **'Keine Orte gespeichert.\nOrte auf der Karte per Langer Druck hinzufügen.'**
  String get noPlacesSaved;

  /// Not visited yet
  ///
  /// In de, this message translates to:
  /// **'Noch nicht besucht'**
  String get notVisitedYet;

  /// Visit count singular
  ///
  /// In de, this message translates to:
  /// **'{count} Besuch'**
  String visitCount(int count);

  /// Visit count plural
  ///
  /// In de, this message translates to:
  /// **'{count} Besuche'**
  String visitCountPlural(int count);

  /// Last visit
  ///
  /// In de, this message translates to:
  /// **'Zuletzt: {date}  {time}'**
  String lastVisit(String date, String time);

  /// To current position tooltip
  ///
  /// In de, this message translates to:
  /// **'Zur aktuellen Position'**
  String get toCurrentPosition;

  /// Activities screen title
  ///
  /// In de, this message translates to:
  /// **'Tätigkeiten'**
  String get activitiesScreenTitle;

  /// No activities yet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Tätigkeiten vorhanden.'**
  String get noActivitiesYet;

  /// Delete task dialog title
  ///
  /// In de, this message translates to:
  /// **'Tätigkeit löschen?'**
  String get taskDeleteTitle;

  /// Delete task dialog content
  ///
  /// In de, this message translates to:
  /// **'„{name}\" wirklich entfernen?'**
  String taskDeleteContent(String name);

  /// New task dialog title
  ///
  /// In de, this message translates to:
  /// **'Neue Tätigkeit'**
  String get newTask;

  /// Edit task dialog title
  ///
  /// In de, this message translates to:
  /// **'Tätigkeit bearbeiten'**
  String get editTask;

  /// Add task tooltip
  ///
  /// In de, this message translates to:
  /// **'Tätigkeit hinzufügen'**
  String get addTaskTooltip;

  /// Database screen title
  ///
  /// In de, this message translates to:
  /// **'Datenbank'**
  String get databaseTitle;

  /// Export tab
  ///
  /// In de, this message translates to:
  /// **'Exportieren'**
  String get tabExport;

  /// Import tab
  ///
  /// In de, this message translates to:
  /// **'Importieren'**
  String get tabImport;

  /// Reset tab
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get tabReset;

  /// Export database title
  ///
  /// In de, this message translates to:
  /// **'Datenbank exportieren'**
  String get exportTitle;

  /// Export description
  ///
  /// In de, this message translates to:
  /// **'Die SQLite-Datenbankdatei wird direkt geteilt. Sie kann als Backup gespeichert oder auf ein anderes Gerät übertragen werden.'**
  String get exportDescription;

  /// Share database button
  ///
  /// In de, this message translates to:
  /// **'Datenbank teilen'**
  String get shareDatabase;

  /// Import database title
  ///
  /// In de, this message translates to:
  /// **'Datenbank importieren'**
  String get importTitle;

  /// Import how-to instructions
  ///
  /// In de, this message translates to:
  /// **'So importierst du eine Datenbank:\n\n1. Öffne die Dateien-App\n2. Halte die .db-Datei gedrückt\n3. Tippe auf „Teilen\"\n4. Wähle „Chaos Tours\" aus der Liste'**
  String get importHowTo;

  /// Import hint
  ///
  /// In de, this message translates to:
  /// **'Diese App öffnet sich automatisch, wenn du eine Datei hierher teilst.'**
  String get importHint;

  /// File received label
  ///
  /// In de, this message translates to:
  /// **'Datei empfangen:'**
  String get fileReceived;

  /// Import button
  ///
  /// In de, this message translates to:
  /// **'Importieren'**
  String get importButton;

  /// Replace database dialog title
  ///
  /// In de, this message translates to:
  /// **'Datenbank ersetzen?'**
  String get dbReplaceTitle;

  /// Replace database dialog content
  ///
  /// In de, this message translates to:
  /// **'Die aktuelle Datenbank wird vollständig durch die geteilte Datei ersetzt.\n\nAlle vorhandenen Daten gehen verloren.\n\nFortfahren?'**
  String get dbReplaceContent;

  /// Import success message
  ///
  /// In de, this message translates to:
  /// **'Datenbank erfolgreich importiert'**
  String get importSuccess;

  /// Reset database dialog title
  ///
  /// In de, this message translates to:
  /// **'Datenbank zurücksetzen?'**
  String get dbResetTitle;

  /// Reset database dialog content
  ///
  /// In de, this message translates to:
  /// **'Alle Daten werden unwiderruflich gelöscht. Die Datenbankstruktur bleibt erhalten.\n\nFortfahren?'**
  String get dbResetContent;

  /// Reset success message
  ///
  /// In de, this message translates to:
  /// **'Datenbank zurückgesetzt'**
  String get resetSuccess;

  /// Export failed message
  ///
  /// In de, this message translates to:
  /// **'Export fehlgeschlagen: {error}'**
  String exportFailed(String error);

  /// Import failed message
  ///
  /// In de, this message translates to:
  /// **'Import fehlgeschlagen: {error}'**
  String importFailed(String error);

  /// Reset failed message
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen fehlgeschlagen: {error}'**
  String resetFailed(String error);

  /// Map screen title
  ///
  /// In de, this message translates to:
  /// **'Chaos Tours – Karte'**
  String get mapTitle;

  /// Filter tooltip
  ///
  /// In de, this message translates to:
  /// **'Filter'**
  String get tooltipFilter;

  /// Address search tooltip
  ///
  /// In de, this message translates to:
  /// **'Adresse suchen'**
  String get tooltipAddressSearch;

  /// Which place to open
  ///
  /// In de, this message translates to:
  /// **'Welchen Ort öffnen?'**
  String get whichPlaceToOpen;

  /// Create place here
  ///
  /// In de, this message translates to:
  /// **'Ort hier erstellen'**
  String get createPlaceHere;

  /// Route in Google Maps
  ///
  /// In de, this message translates to:
  /// **'Route in Google Maps'**
  String get routeInGoogleMaps;

  /// To my position tooltip
  ///
  /// In de, this message translates to:
  /// **'Zu meiner Position'**
  String get toMyPosition;

  /// No results found
  ///
  /// In de, this message translates to:
  /// **'Keine Ergebnisse gefunden.'**
  String get noResultsFound;

  /// Address search sheet title
  ///
  /// In de, this message translates to:
  /// **'Adresse suchen'**
  String get addressSearch;

  /// Country label
  ///
  /// In de, this message translates to:
  /// **'Land'**
  String get country;

  /// Country hint
  ///
  /// In de, this message translates to:
  /// **'z. B. Deutschland'**
  String get countryHint;

  /// City or place label
  ///
  /// In de, this message translates to:
  /// **'Stadt / Ort'**
  String get cityPlace;

  /// City hint
  ///
  /// In de, this message translates to:
  /// **'z. B. München'**
  String get cityHint;

  /// Street optional label
  ///
  /// In de, this message translates to:
  /// **'Straße (optional)'**
  String get streetOptional;

  /// Street hint
  ///
  /// In de, this message translates to:
  /// **'z. B. Marienplatz 1'**
  String get streetHint;

  /// Persons screen title
  ///
  /// In de, this message translates to:
  /// **'Personen'**
  String get personsScreenTitle;

  /// No persons yet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Personen vorhanden.'**
  String get noPersonsYet;

  /// Delete person dialog title
  ///
  /// In de, this message translates to:
  /// **'Person löschen?'**
  String get personDeleteTitle;

  /// Delete person dialog content
  ///
  /// In de, this message translates to:
  /// **'„{name}\" wirklich entfernen?'**
  String personDeleteContent(String name);

  /// New person dialog title
  ///
  /// In de, this message translates to:
  /// **'Neue Person'**
  String get newPerson;

  /// Edit person dialog title
  ///
  /// In de, this message translates to:
  /// **'Person bearbeiten'**
  String get editPerson;

  /// Role optional label
  ///
  /// In de, this message translates to:
  /// **'Rolle / Beschreibung (optional)'**
  String get roleOptional;

  /// Add person tooltip
  ///
  /// In de, this message translates to:
  /// **'Person hinzufügen'**
  String get addPersonTooltip;

  /// Photo album screen title
  ///
  /// In de, this message translates to:
  /// **'Fotoalbum'**
  String get photoAlbumTitle;

  /// No photos yet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Fotos vorhanden'**
  String get noPhotosYet;

  /// No photos hint
  ///
  /// In de, this message translates to:
  /// **'Fotos können bei Orten und Besuchen hinzugefügt werden.'**
  String get noPhotosHint;

  /// Without place label
  ///
  /// In de, this message translates to:
  /// **'Ohne Ort'**
  String get withoutPlace;

  /// Photo count singular
  ///
  /// In de, this message translates to:
  /// **'{count} Foto'**
  String photoCount(int count);

  /// Photo count plural
  ///
  /// In de, this message translates to:
  /// **'{count} Fotos'**
  String photoCountPlural(int count);

  /// Delete photo dialog title
  ///
  /// In de, this message translates to:
  /// **'Foto löschen'**
  String get photoDeleteTitle;

  /// Delete photo dialog content
  ///
  /// In de, this message translates to:
  /// **'Dieses Foto wirklich löschen?'**
  String get photoDeleteContent;

  /// Place groups screen title
  ///
  /// In de, this message translates to:
  /// **'Ortsgruppen'**
  String get placeGroupsTitle;

  /// No groups yet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Gruppen vorhanden.'**
  String get noGroupsYet;

  /// Delete group dialog title
  ///
  /// In de, this message translates to:
  /// **'Gruppe löschen?'**
  String get groupDeleteTitle;

  /// Delete group dialog content
  ///
  /// In de, this message translates to:
  /// **'„{name}\" wirklich löschen?'**
  String groupDeleteContent(String name);

  /// New group dialog title
  ///
  /// In de, this message translates to:
  /// **'Neue Gruppe'**
  String get newGroup;

  /// Edit group dialog title
  ///
  /// In de, this message translates to:
  /// **'Gruppe bearbeiten'**
  String get editGroup;

  /// Calendar chosen
  ///
  /// In de, this message translates to:
  /// **'Kalender gewählt'**
  String get calendarChosen;

  /// No calendar
  ///
  /// In de, this message translates to:
  /// **'Kein Kalender'**
  String get noCalendar;

  /// Telegram connection chosen
  ///
  /// In de, this message translates to:
  /// **'Telegram gewählt'**
  String get telegramChosen;

  /// No Telegram connection
  ///
  /// In de, this message translates to:
  /// **'Kein Telegram'**
  String get noTelegram;

  /// Choose hint
  ///
  /// In de, this message translates to:
  /// **'Wählen'**
  String get choose;

  /// Notes in calendar checkbox
  ///
  /// In de, this message translates to:
  /// **'Notizen in Kalender'**
  String get notesInCalendar;

  /// Persons in calendar checkbox
  ///
  /// In de, this message translates to:
  /// **'Personen in Kalender'**
  String get personsInCalendar;

  /// Activities in calendar checkbox
  ///
  /// In de, this message translates to:
  /// **'Tätigkeiten in Kalender'**
  String get activitiesInCalendar;

  /// Auto group checkbox
  ///
  /// In de, this message translates to:
  /// **'Auto-Gruppe'**
  String get autoGroup;

  /// Auto group subtitle
  ///
  /// In de, this message translates to:
  /// **'Automatisch erkannte Orte werden hier einsortiert'**
  String get autoGroupSubtitle;

  /// Pick calendar dialog title
  ///
  /// In de, this message translates to:
  /// **'Kalender wählen'**
  String get pickCalendar;

  /// Add group tooltip
  ///
  /// In de, this message translates to:
  /// **'Gruppe hinzufügen'**
  String get addGroupTooltip;

  /// Reposition screen title
  ///
  /// In de, this message translates to:
  /// **'Position: {name}'**
  String repositionTitle(String name);

  /// Reposition confirm dialog title
  ///
  /// In de, this message translates to:
  /// **'Position übernehmen?'**
  String get repositionConfirmTitle;

  /// Reposition confirm dialog content
  ///
  /// In de, this message translates to:
  /// **'„{name}\" wird auf\n{lat}, {lng}\nverschoben.'**
  String repositionConfirmContent(String name, String lat, String lng);

  /// Show current location tooltip
  ///
  /// In de, this message translates to:
  /// **'Aktuellen Standort anzeigen'**
  String get showCurrentLocation;

  /// Place visits screen title
  ///
  /// In de, this message translates to:
  /// **'Besuche: {name}'**
  String placeVisitsTitle(String name);

  /// Sync sources screen title
  ///
  /// In de, this message translates to:
  /// **'Sync-Quellen'**
  String get syncSourcesTitle;

  /// Stay persons table label
  ///
  /// In de, this message translates to:
  /// **'Aufenthalts-Personen'**
  String get stayPersons;

  /// Stay activities table label
  ///
  /// In de, this message translates to:
  /// **'Aufenthalts-Tätigkeiten'**
  String get stayActivities;

  /// Place experiences table label
  ///
  /// In de, this message translates to:
  /// **'Orts-Erfahrungen'**
  String get placeExperiences;

  /// Source experiences table label
  ///
  /// In de, this message translates to:
  /// **'Quellen-Erfahrungen'**
  String get sourceExperiences;

  /// Delete source dialog title
  ///
  /// In de, this message translates to:
  /// **'Quelle löschen?'**
  String get sourceDeleteTitle;

  /// Delete source dialog content
  ///
  /// In de, this message translates to:
  /// **'„{name}\" wird unwiderruflich gelöscht.'**
  String sourceDeleteContent(String name);

  /// Sync warning dialog content
  ///
  /// In de, this message translates to:
  /// **'⚠️ Es wird dringend empfohlen, vor der Synchronisation eine Sicherheitskopie der Datenbank zu exportieren (Einstellungen → Datenbank-Dump).\n\nJetzt synchronisieren?'**
  String get syncWarning;

  /// Sync all dialog title
  ///
  /// In de, this message translates to:
  /// **'Alle synchronisieren'**
  String get syncAllTitle;

  /// Sync all warning dialog content
  ///
  /// In de, this message translates to:
  /// **'⚠️ Es wird dringend empfohlen, vor der Synchronisation eine Sicherheitskopie der Datenbank zu exportieren (Einstellungen → Datenbank-Dump).\n\nMit allen aktiven Sync-Quellen synchronisieren?'**
  String get syncAllWarning;

  /// New sync source dialog title
  ///
  /// In de, this message translates to:
  /// **'Neue Sync-Quelle'**
  String get newSyncSource;

  /// Edit sync source dialog title
  ///
  /// In de, this message translates to:
  /// **'Quelle bearbeiten'**
  String get editSyncSource;

  /// Sync address label
  ///
  /// In de, this message translates to:
  /// **'Sync-Adresse *'**
  String get syncAddress;

  /// Sync address hint
  ///
  /// In de, this message translates to:
  /// **'http://192.168.1.10:8000'**
  String get syncAddressHint;

  /// API key label
  ///
  /// In de, this message translates to:
  /// **'API-Key'**
  String get apiKey;

  /// Info URL optional label
  ///
  /// In de, this message translates to:
  /// **'Info-URL (optional)'**
  String get infoUrlOptional;

  /// Info URL hint
  ///
  /// In de, this message translates to:
  /// **'https://example.com'**
  String get infoUrlHint;

  /// Sync options dialog title
  ///
  /// In de, this message translates to:
  /// **'Sync-Optionen'**
  String get syncOptionsTitle;

  /// Sync options warning
  ///
  /// In de, this message translates to:
  /// **'⚠️ Vor dem Aktivieren von Bearbeiten/Löschen empfiehlt sich ein Datenbank-Export als Sicherheitskopie.'**
  String get syncOptionsWarning;

  /// Insert column header
  ///
  /// In de, this message translates to:
  /// **'Einfügen'**
  String get insert;

  /// No sync options active
  ///
  /// In de, this message translates to:
  /// **'Keine Sync-Optionen aktiv'**
  String get noSyncOptions;

  /// Tables active count
  ///
  /// In de, this message translates to:
  /// **'{count} Tabellen aktiv'**
  String tablesActive(int count);

  /// No experiences yet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Erfahrungen vorhanden.'**
  String get noExperiences;

  /// Experiences section title
  ///
  /// In de, this message translates to:
  /// **'Erfahrungen'**
  String get experiencesTitle;

  /// Sync dialog title
  ///
  /// In de, this message translates to:
  /// **'Synchronisieren'**
  String get syncTitle;

  /// Sync result success
  ///
  /// In de, this message translates to:
  /// **'{pulled} empfangen, {pushed} gesendet'**
  String syncResultSuccess(int pulled, int pushed);

  /// Sync error message
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String syncError(String error);

  /// No active sync sources
  ///
  /// In de, this message translates to:
  /// **'Keine aktiven Sync-Quellen konfiguriert'**
  String get noActiveSyncSources;

  /// Sync all result
  ///
  /// In de, this message translates to:
  /// **'{ok} Quelle(n) OK ({pulled} empfangen, {pushed} gesendet)'**
  String syncAllResult(int ok, int pulled, int pushed);

  /// Sync all result with errors
  ///
  /// In de, this message translates to:
  /// **'{ok} Quelle(n) OK ({pulled} empfangen, {pushed} gesendet), {fail} Fehler'**
  String syncAllResultWithErrors(int ok, int pulled, int pushed, int fail);

  /// Sync all tooltip
  ///
  /// In de, this message translates to:
  /// **'Alle synchronisieren'**
  String get syncAllTooltip;

  /// Add source tooltip
  ///
  /// In de, this message translates to:
  /// **'Quelle hinzufügen'**
  String get addSourceTooltip;

  /// No sync sources message
  ///
  /// In de, this message translates to:
  /// **'Keine Sync-Quellen vorhanden.\nTippe + um eine hinzuzufügen.'**
  String get noSyncSources;

  /// Sync now menu item
  ///
  /// In de, this message translates to:
  /// **'Jetzt synchronisieren'**
  String get syncNow;

  /// Sync options menu item
  ///
  /// In de, this message translates to:
  /// **'Sync-Optionen'**
  String get syncOptionsMenu;

  /// Add experience button
  ///
  /// In de, this message translates to:
  /// **'Erfahrung hinzufügen'**
  String get addExperience;

  /// Experience hint text
  ///
  /// In de, this message translates to:
  /// **'Notiz, Erfahrung oder Bewertung…'**
  String get experienceHint;

  /// Sync address detail label
  ///
  /// In de, this message translates to:
  /// **'Sync-Adresse'**
  String get syncAddressLabel;

  /// Info URL detail label
  ///
  /// In de, this message translates to:
  /// **'Info-URL'**
  String get infoUrlLabel;

  /// Active sync options title
  ///
  /// In de, this message translates to:
  /// **'Aktive Sync-Optionen'**
  String get activeSyncOptions;

  /// Telegram connections screen title
  ///
  /// In de, this message translates to:
  /// **'Telegram-Verbindungen'**
  String get telegramConnectionsTitle;

  /// No Telegram connections yet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Telegram-Verbindungen vorhanden.'**
  String get noTelegramConnections;

  /// Delete connection dialog title
  ///
  /// In de, this message translates to:
  /// **'Verbindung löschen?'**
  String get connectionDeleteTitle;

  /// Delete connection dialog content
  ///
  /// In de, this message translates to:
  /// **'„{name}\" wird unwiderruflich gelöscht.'**
  String connectionDeleteContent(String name);

  /// New Telegram connection dialog title
  ///
  /// In de, this message translates to:
  /// **'Neue Telegram-Verbindung'**
  String get newTelegramConnection;

  /// Edit Telegram connection dialog title
  ///
  /// In de, this message translates to:
  /// **'Verbindung bearbeiten'**
  String get editTelegramConnection;

  /// Chat ID label
  ///
  /// In de, this message translates to:
  /// **'-ID-Nummer oder @Kanalname *'**
  String get chatIdLabel;

  /// Chat ID hint
  ///
  /// In de, this message translates to:
  /// **'-123... oder @Kanal'**
  String get chatIdHint;

  /// Bot token label
  ///
  /// In de, this message translates to:
  /// **'Bot-Token *'**
  String get botTokenLabel;

  /// Bot token hint
  ///
  /// In de, this message translates to:
  /// **'123456:ABC-DEF…'**
  String get botTokenHint;

  /// Distance filter label
  ///
  /// In de, this message translates to:
  /// **'Entfernung'**
  String get distance;

  /// Max distance label
  ///
  /// In de, this message translates to:
  /// **'max. {dist}'**
  String maxDistance(String dist);

  /// Reset filter button in experience panel
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get resetFilter2;

  /// Experience filter switch
  ///
  /// In de, this message translates to:
  /// **'Aktiviere Erfahrungsfilter'**
  String get activateExperienceFilter;

  /// Only places with experiences with current deviceId switch
  ///
  /// In de, this message translates to:
  /// **'Nur Erfahrungen mit\n aktueller Geräte ID'**
  String get deviceIdExperienceFilter;

  /// Only places with current deviceId switch
  ///
  /// In de, this message translates to:
  /// **'Nur Orte mit\n aktueller Geräte ID'**
  String get deviceIdPlaceFilter;

  /// Only Stays with experiences with current deviceId switch
  ///
  /// In de, this message translates to:
  /// **'Nur Besuche mit\n aktueller Geräte ID'**
  String get deviceIdStayFilter;

  /// Min average rating label
  ///
  /// In de, this message translates to:
  /// **'Min. ⌀ Bewertung:'**
  String get minAvgRating;

  /// Min median rating label
  ///
  /// In de, this message translates to:
  /// **'Min. x̃ Bewertung:'**
  String get minMedianRating;

  /// Min selected rating rating label
  ///
  /// In de, this message translates to:
  /// **'Min. Bewertung:'**
  String get minSpecialRating;

  /// Rating metric: average
  ///
  /// In de, this message translates to:
  /// **'Durchschnitt'**
  String get ratingMetricAverage;

  /// Rating metric: median
  ///
  /// In de, this message translates to:
  /// **'Median'**
  String get ratingMetricMedian;

  /// Camera button
  ///
  /// In de, this message translates to:
  /// **'Kamera'**
  String get camera;

  /// From gallery
  ///
  /// In de, this message translates to:
  /// **'Aus Galerie'**
  String get fromGallery;

  /// No photos in grid
  ///
  /// In de, this message translates to:
  /// **'Noch keine Fotos'**
  String get noPhotosGrid;

  /// Caption dialog title
  ///
  /// In de, this message translates to:
  /// **'Beschriftung'**
  String get captionTitle;

  /// Caption hint
  ///
  /// In de, this message translates to:
  /// **'Beschriftung eingeben'**
  String get captionHint;

  /// Edit caption tooltip
  ///
  /// In de, this message translates to:
  /// **'Beschriftung bearbeiten'**
  String get editCaptionTooltip;

  /// Delete photo tooltip
  ///
  /// In de, this message translates to:
  /// **'Foto löschen'**
  String get deletePhotoTooltip;

  /// Photos at place section header
  ///
  /// In de, this message translates to:
  /// **'Fotos am Ort'**
  String get photosAtPlace;

  /// No place photos
  ///
  /// In de, this message translates to:
  /// **'Noch keine Fotos am Ort.'**
  String get noPlacePhotos;

  /// Photos from visits section header
  ///
  /// In de, this message translates to:
  /// **'Fotos aus Besuchen'**
  String get photosFromVisits;

  /// No visit photos
  ///
  /// In de, this message translates to:
  /// **'Keine Besuchs-Fotos vorhanden.'**
  String get noVisitPhotos;

  /// Visit label
  ///
  /// In de, this message translates to:
  /// **'Besuch'**
  String get visit;

  /// Stay still running
  ///
  /// In de, this message translates to:
  /// **'läuft noch…'**
  String get stillRunning;

  /// Edit stay sheet title
  ///
  /// In de, this message translates to:
  /// **'Aufenthalt bearbeiten'**
  String get editStay;

  /// Tooltip/hint for opening place settings
  ///
  /// In de, this message translates to:
  /// **'Ort-Einstellungen öffnen'**
  String get openPlaceSettings;

  /// Begin/start label
  ///
  /// In de, this message translates to:
  /// **'Beginn'**
  String get begin;

  /// End label
  ///
  /// In de, this message translates to:
  /// **'Ende'**
  String get end;

  /// Notes label
  ///
  /// In de, this message translates to:
  /// **'Notizen'**
  String get notes;

  /// Interval visit toggle
  ///
  /// In de, this message translates to:
  /// **'Intervall-Besuch'**
  String get intervalVisit;

  /// Interval visit subtitle
  ///
  /// In de, this message translates to:
  /// **'Besuch zählt zur Intervall-Berechnung'**
  String get intervalVisitSubtitle;

  /// Add person sheet title
  ///
  /// In de, this message translates to:
  /// **'Person hinzufügen'**
  String get addPersonSheetTitle;

  /// New name hint
  ///
  /// In de, this message translates to:
  /// **'Name eingeben (neu)'**
  String get nameNewHint;

  /// Add activity sheet title
  ///
  /// In de, this message translates to:
  /// **'Tätigkeit hinzufügen'**
  String get addActivitySheetTitle;

  /// New activity hint
  ///
  /// In de, this message translates to:
  /// **'Tätigkeit eingeben (neu)'**
  String get activityNewHint;

  /// Photos section title
  ///
  /// In de, this message translates to:
  /// **'Fotos'**
  String get photos;

  /// Delete stay dialog title
  ///
  /// In de, this message translates to:
  /// **'Aufenthalt löschen'**
  String get deleteStayTitle;

  /// Delete stay dialog content
  ///
  /// In de, this message translates to:
  /// **'Soll dieser Aufenthalt wirklich gelöscht werden? Diese Aktion kann nicht rückgängig gemacht werden.'**
  String get deleteStayContent;

  /// New person name hint
  ///
  /// In de, this message translates to:
  /// **'Name eingeben (neu)'**
  String get personNewHint;

  /// Delete experience dialog title
  ///
  /// In de, this message translates to:
  /// **'Erfahrung löschen?'**
  String get experienceDeleteTitle;

  /// Delete experience dialog content
  ///
  /// In de, this message translates to:
  /// **'Dieser Eintrag wird unwiderruflich gelöscht.'**
  String get experienceDeleteContent;

  /// Add experience dialog title
  ///
  /// In de, this message translates to:
  /// **'Erfahrung hinzufügen'**
  String get addOrEditExperienceTitle;

  /// Edit experience dialog title
  ///
  /// In de, this message translates to:
  /// **'Erfahrung bearbeiten'**
  String get editExperienceTitle;

  /// Report optional label
  ///
  /// In de, this message translates to:
  /// **'Bericht (optional)'**
  String get reportOptional;

  /// Ratings label
  ///
  /// In de, this message translates to:
  /// **'Bewertungen (−9 bis +9):'**
  String get ratingsLabel;

  /// Rating: dangerous to friendly
  ///
  /// In de, this message translates to:
  /// **'Gefährlich ↔ Freundlich'**
  String get ratingDangerFriendly;

  /// Rating: fraudulent to reliable
  ///
  /// In de, this message translates to:
  /// **'Betrügerisch ↔ Zuverlässig'**
  String get ratingFraudReliable;

  /// Rating: dismissive to accommodation
  ///
  /// In de, this message translates to:
  /// **'Abweisend ↔ Bietet Unterkunft'**
  String get ratingDismissiveAccommodation;

  /// Rating: demands to provides food
  ///
  /// In de, this message translates to:
  /// **'Fordert ↔ Bietet Verpflegung'**
  String get ratingFood;

  /// Rating: demands to provides equipment
  ///
  /// In de, this message translates to:
  /// **'Fordert ↔ Bietet Equipment'**
  String get ratingEquipment;

  /// Rating: demands to provides transport
  ///
  /// In de, this message translates to:
  /// **'Fordert ↔ Bietet Transport'**
  String get ratingTransport;

  /// Rating: demands to provides medical care
  ///
  /// In de, this message translates to:
  /// **'Fordert ↔ Bietet Medizinische Versorgung'**
  String get ratingMedicine;

  /// Filter by group label
  ///
  /// In de, this message translates to:
  /// **'Nach Gruppe filtern'**
  String get filterByGroup;

  /// Filter by place type label
  ///
  /// In de, this message translates to:
  /// **'Nach Ortstyp filtern'**
  String get filterByPlaceType;

  /// General experience filter mode label
  ///
  /// In de, this message translates to:
  /// **'Allgemeiner Filter'**
  String get filterModeGeneral;

  /// Specific experience filter mode label
  ///
  /// In de, this message translates to:
  /// **'Spezieller Filter'**
  String get filterModeSpecific;

  /// Label for the rating dimension dropdown
  ///
  /// In de, this message translates to:
  /// **'Bewertungsdimension:'**
  String get selectRatingDimension;

  /// Overall rating row label in the rating table on place cards
  ///
  /// In de, this message translates to:
  /// **'Gesamt'**
  String get ratingTableOverall;

  /// Loading indicator text for rating table
  ///
  /// In de, this message translates to:
  /// **'Lade...'**
  String get loadingRatings;

  /// No experiences yet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Erfahrungsberichte vorhanden.'**
  String get noExperiencesYet;

  /// Survival experiences section
  ///
  /// In de, this message translates to:
  /// **'Survival-Erfahrungen'**
  String get survivalExperiences;

  /// Statistics section
  ///
  /// In de, this message translates to:
  /// **'Statistik'**
  String get statistics;

  /// Visit now button
  ///
  /// In de, this message translates to:
  /// **'Jetzt besuchen'**
  String get visitNow;

  /// Copy basic report button
  ///
  /// In de, this message translates to:
  /// **'Bericht mit Basisdaten kopieren'**
  String get copyBasicReport;

  /// Copy full report button
  ///
  /// In de, this message translates to:
  /// **'Vollständigen Bericht kopieren'**
  String get copyFullReport;

  /// Send report to Telegram button
  ///
  /// In de, this message translates to:
  /// **'Bericht an Telegram senden'**
  String get sendReportToTelegram;

  /// Visit interval section
  ///
  /// In de, this message translates to:
  /// **'Besuchs-Intervall'**
  String get visitInterval;

  /// Interval days label
  ///
  /// In de, this message translates to:
  /// **'Intervall (Tage)'**
  String get intervalDaysLabel;

  /// Interval days hint
  ///
  /// In de, this message translates to:
  /// **'z. B. 14'**
  String get intervalDaysHint;

  /// Interval days suffix
  ///
  /// In de, this message translates to:
  /// **'Tage'**
  String get intervalDaysSuffix;

  /// Change position on map button
  ///
  /// In de, this message translates to:
  /// **'Position auf Karte ändern'**
  String get changePositionOnMap;

  /// Radius display
  ///
  /// In de, this message translates to:
  /// **'Radius: {m} m'**
  String radius(String m);

  /// Group label
  ///
  /// In de, this message translates to:
  /// **'Gruppe'**
  String get group;

  /// No group option
  ///
  /// In de, this message translates to:
  /// **'Keine Gruppe'**
  String get noGroup;

  /// Delete place dialog title
  ///
  /// In de, this message translates to:
  /// **'Ort löschen?'**
  String get placeDeleteTitle;

  /// Delete place dialog content
  ///
  /// In de, this message translates to:
  /// **'„{name}\" wirklich löschen?'**
  String placeDeleteContent(String name);

  /// GPS coordinates copied snackbar
  ///
  /// In de, this message translates to:
  /// **'GPS-Koordinaten kopiert'**
  String get gpsCopied;

  /// Report copied snackbar
  ///
  /// In de, this message translates to:
  /// **'Bericht in Zwischenablage kopiert'**
  String get reportCopied;

  /// Send to Telegram dialog title
  ///
  /// In de, this message translates to:
  /// **'An Telegram senden?'**
  String get telegramSendTitle;

  /// Send to Telegram dialog content
  ///
  /// In de, this message translates to:
  /// **'Bericht für „{place}\" an „{connection}\" senden?'**
  String telegramSendContent(String place, String connection);

  /// Open in Google Maps tooltip
  ///
  /// In de, this message translates to:
  /// **'In Google Maps öffnen'**
  String get openInGoogleMaps;

  /// Note label
  ///
  /// In de, this message translates to:
  /// **'Notiz'**
  String get noteName;

  /// Website label
  ///
  /// In de, this message translates to:
  /// **'Website'**
  String get website;

  /// Email label
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get email;

  /// Phone label
  ///
  /// In de, this message translates to:
  /// **'Telefon'**
  String get phone;

  /// Import auto-open hint
  ///
  /// In de, this message translates to:
  /// **'Diese App öffnet sich automatisch, wenn du eine Datei hierher teilst.'**
  String get importAutoOpenHint;

  /// Import overwrite warning
  ///
  /// In de, this message translates to:
  /// **'Alle vorhandenen Daten werden überschrieben.'**
  String get importOverwriteWarning;

  /// Import now button
  ///
  /// In de, this message translates to:
  /// **'Jetzt importieren'**
  String get importNow;

  /// Import waiting for shared file
  ///
  /// In de, this message translates to:
  /// **'Warte auf geteilte Datei …'**
  String get importWaiting;

  /// Merge / sync-from-file button label
  ///
  /// In de, this message translates to:
  /// **'Zusammenführen'**
  String get syncFromFileNow;

  /// Merge database dialog title
  ///
  /// In de, this message translates to:
  /// **'Datenbank zusammenführen?'**
  String get syncFromFileTitle;

  /// Merge database dialog content
  ///
  /// In de, this message translates to:
  /// **'Die empfangene Datenbank wird mit der aktuellen zusammengeführt. Neuere Einträge überschreiben ältere (Last-Write-Wins). Bestehende Daten bleiben erhalten.\n\nFortfahren?'**
  String get syncFromFileContent;

  /// Merge success message
  ///
  /// In de, this message translates to:
  /// **'Datenbank zusammengeführt ({count} Einträge verarbeitet)'**
  String syncFromFileSuccess(int count);

  /// Merge failed message
  ///
  /// In de, this message translates to:
  /// **'Zusammenführen fehlgeschlagen: {error}'**
  String syncFromFileFailed(String error);

  /// Sync mode selection dialog title
  ///
  /// In de, this message translates to:
  /// **'Sync-Umfang wählen'**
  String get syncFromFileModeTitle;

  /// Sync mode selection dialog description
  ///
  /// In de, this message translates to:
  /// **'Sollen alle Tabellen vollständig zusammengeführt werden, oder möchtest du einzelne Tabellen und Operationen auswählen?'**
  String get syncFromFileModeDescription;

  /// Sync all tables button
  ///
  /// In de, this message translates to:
  /// **'Alles zusammenführen'**
  String get syncFromFileModeAll;

  /// Custom sync options button
  ///
  /// In de, this message translates to:
  /// **'Auswählen …'**
  String get syncFromFileModeCustom;

  /// Place photos table label
  ///
  /// In de, this message translates to:
  /// **'Fotos'**
  String get placePhotos;

  /// Reset database section title
  ///
  /// In de, this message translates to:
  /// **'Datenbank zurücksetzen'**
  String get resetTitle;

  /// Reset database description
  ///
  /// In de, this message translates to:
  /// **'Alle Daten werden unwiderruflich gelöscht. Die Datenbankstruktur bleibt erhalten.'**
  String get resetDescription;

  /// Reset irreversible warning
  ///
  /// In de, this message translates to:
  /// **'Diese Aktion kann nicht rückgängig gemacht werden.'**
  String get resetIrreversibleWarning;

  /// Delete all data button
  ///
  /// In de, this message translates to:
  /// **'Alle Daten löschen'**
  String get deleteAllData;

  /// Tracking activate dialog title
  ///
  /// In de, this message translates to:
  /// **'Tracking aktivieren?'**
  String get trackingActivateTitle;

  /// Tracking deactivate dialog title
  ///
  /// In de, this message translates to:
  /// **'Tracking deaktivieren?'**
  String get trackingDeactivateTitle;

  /// Tracking activate dialog content
  ///
  /// In de, this message translates to:
  /// **'Soll das automatische Hintergrund-Tracking gestartet werden?'**
  String get trackingActivateContent;

  /// Tracking deactivate dialog content
  ///
  /// In de, this message translates to:
  /// **'Soll das automatische Hintergrund-Tracking gestoppt werden?'**
  String get trackingDeactivateContent;

  /// Tracking active tooltip
  ///
  /// In de, this message translates to:
  /// **'Tracking aktiv'**
  String get trackingActiveTooltip;

  /// Tracking inactive tooltip
  ///
  /// In de, this message translates to:
  /// **'Tracking inaktiv'**
  String get trackingInactiveTooltip;

  /// Foreground service notification text
  ///
  /// In de, this message translates to:
  /// **'Automatisches Tracking aktiv'**
  String get trackingNotificationText;

  /// Tracking status halt at unknown address
  ///
  /// In de, this message translates to:
  /// **'Halten: {address}'**
  String trackingStatusHaltUnknownAddress(String address);

  /// New place dialog title
  ///
  /// In de, this message translates to:
  /// **'Neuer Ort'**
  String get newPlaceTitle;

  /// Edit place bottom sheet title
  ///
  /// In de, this message translates to:
  /// **'Ort bearbeiten'**
  String get placeEditTitle;

  /// Place origin: automatically created
  ///
  /// In de, this message translates to:
  /// **'Automatisch erstellt'**
  String get placeOriginAuto;

  /// Place origin: imported
  ///
  /// In de, this message translates to:
  /// **'Importiert'**
  String get placeOriginImported;

  /// Manage place groups list tile label
  ///
  /// In de, this message translates to:
  /// **'Ortsgruppen verwalten'**
  String get managePlaceGroups;

  /// Visit interval switch subtitle
  ///
  /// In de, this message translates to:
  /// **'Regelmäßige Erinnerung, diesen Ort zu besuchen'**
  String get visitIntervalSubtitle;

  /// Info and statistics section divider label
  ///
  /// In de, this message translates to:
  /// **'Informationen & Statistik'**
  String get infoAndStats;

  /// Place never visited label
  ///
  /// In de, this message translates to:
  /// **'Noch nicht besucht'**
  String get neverVisited;

  /// Last visited at label
  ///
  /// In de, this message translates to:
  /// **'· zuletzt {date}'**
  String lastVisitedAt(String date);

  /// Place created at label
  ///
  /// In de, this message translates to:
  /// **'Erstellt: {date}'**
  String placeCreatedAt(String date);

  /// Show visits button label
  ///
  /// In de, this message translates to:
  /// **'Besuche anzeigen'**
  String get showVisits;

  /// Show visits button label with count
  ///
  /// In de, this message translates to:
  /// **'Besuche anzeigen ({count})'**
  String showVisitsCount(int count);

  /// Copy report hint text
  ///
  /// In de, this message translates to:
  /// **'Kopiert einen vollständigen Bericht des Ortes einschließlich aller Besuche und Survival-Erfahrungen im Markdown Format in die Zwischenablage.'**
  String get copyReportHint;

  /// Button to copy a place into a protected area
  ///
  /// In de, this message translates to:
  /// **'In geschützten Bereich kopieren'**
  String get copyToProtectedArea;

  /// Hint text for copy to protected area
  ///
  /// In de, this message translates to:
  /// **'Erstellt eine Kopie dieses Ortes mit neuer UUID und der Device-ID eines geschützten Bereichs, sodass er vor Sync-Importen geschützt ist.'**
  String get copyToProtectedAreaHint;

  /// Dialog title for selecting a protected Virtual Device
  ///
  /// In de, this message translates to:
  /// **'Geschützten Bereich wählen'**
  String get copyToProtectedAreaSelectTitle;

  /// Subtitle in the select protected area dialog
  ///
  /// In de, this message translates to:
  /// **'Die Kopie erhält die Device-ID des gewählten virtuellen Gerätes.'**
  String get copyToProtectedAreaSelectSubtitle;

  /// Snackbar message after successfully copying a place to a protected area
  ///
  /// In de, this message translates to:
  /// **'Ort in geschützten Bereich kopiert.'**
  String get copyToProtectedAreaSuccess;

  /// GPS settings section divider label
  ///
  /// In de, this message translates to:
  /// **'GPS Einstellungen'**
  String get gpsSettings;

  /// Report sent to Telegram snackbar
  ///
  /// In de, this message translates to:
  /// **'Bericht an Telegram gesendet'**
  String get telegramSent;

  /// Telegram error message
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String telegramError(String error);

  /// Create visit sheet title
  ///
  /// In de, this message translates to:
  /// **'Besuch erstellen'**
  String get createVisitTitle;

  /// No visits recorded yet label
  ///
  /// In de, this message translates to:
  /// **'Noch keine Besuche aufgezeichnet.'**
  String get noVisitsRecorded;

  /// Statistics: first visit label
  ///
  /// In de, this message translates to:
  /// **'Erster Besuch'**
  String get statFirstVisit;

  /// Statistics: last visit label
  ///
  /// In de, this message translates to:
  /// **'Letzter Besuch'**
  String get statLastVisit;

  /// Statistics: shortest visit label
  ///
  /// In de, this message translates to:
  /// **'Kürzester Besuch'**
  String get statShortest;

  /// Statistics: longest visit label
  ///
  /// In de, this message translates to:
  /// **'Längster Besuch'**
  String get statLongest;

  /// Statistics: average label
  ///
  /// In de, this message translates to:
  /// **'Durchschnitt'**
  String get statAverage;

  /// Statistics: median label
  ///
  /// In de, this message translates to:
  /// **'x̃'**
  String get statMedian;

  /// Open {label} tooltip
  ///
  /// In de, this message translates to:
  /// **'{label} öffnen'**
  String openLabel(String label);

  /// Photos section header in settings
  ///
  /// In de, this message translates to:
  /// **'Fotos'**
  String get sectionPhotos;

  /// Photo max width setting label
  ///
  /// In de, this message translates to:
  /// **'Max. Breite ({value} px)'**
  String photoMaxWidth(int value);

  /// Photo max height setting label
  ///
  /// In de, this message translates to:
  /// **'Max. Höhe ({value} px)'**
  String photoMaxHeight(int value);

  /// Photo max dimension subtitle
  ///
  /// In de, this message translates to:
  /// **'0 = unbegrenzt'**
  String get photoMaxDimensionSubtitle;

  /// Photo image quality setting label
  ///
  /// In de, this message translates to:
  /// **'Bildqualität ({value} %)'**
  String photoImageQuality(int value);

  /// Share photo tooltip
  ///
  /// In de, this message translates to:
  /// **'Foto teilen'**
  String get sharePhoto;

  /// Skip button
  ///
  /// In de, this message translates to:
  /// **'Überspringen'**
  String get skip;

  /// Address field label
  ///
  /// In de, this message translates to:
  /// **'Adresse'**
  String get address;

  /// Filter by trusted sources label
  ///
  /// In de, this message translates to:
  /// **'Nur vertrauenswürdige Quellen'**
  String get filterByTrustedSources;

  /// Trusted sources screen title
  ///
  /// In de, this message translates to:
  /// **'Vertrauenswürdige Quellen'**
  String get trustedSourcesTitle;

  /// Trusted sources settings subtitle
  ///
  /// In de, this message translates to:
  /// **'Bekannte Geräte-IDs verwalten'**
  String get trustedSourcesSubtitle;

  /// Empty state for trusted sources
  ///
  /// In de, this message translates to:
  /// **'Keine bekannten Geräte-IDs.\nNutze Aktualisieren um Geräte-IDs aus der Datenbank zu sammeln.'**
  String get noTrustedSources;

  /// Collect device IDs tooltip
  ///
  /// In de, this message translates to:
  /// **'Geräte-IDs aus Datenbank sammeln'**
  String get refreshTrustedSources;

  /// FAB tooltip
  ///
  /// In de, this message translates to:
  /// **'Vertrauenswürdige Quelle hinzufügen'**
  String get addTrustedSource;

  /// Edit trusted source sheet title
  ///
  /// In de, this message translates to:
  /// **'Quelle bearbeiten'**
  String get editTrustedSource;

  /// Device ID field label in trusted source sheet
  ///
  /// In de, this message translates to:
  /// **'Geräte-ID'**
  String get trustedDeviceIdLabel;

  /// Confirm delete trusted source title
  ///
  /// In de, this message translates to:
  /// **'Vertrauenswürdige Quelle entfernen?'**
  String get trustedSourceDeleteTitle;

  /// Section header for trusted devices
  ///
  /// In de, this message translates to:
  /// **'Vertrauenswürdig'**
  String get trustedDevicesSection;

  /// Section header for known but untrusted devices
  ///
  /// In de, this message translates to:
  /// **'Bekannte Geräte'**
  String get knownDevicesSection;

  /// Button to create a virtual device profile for the selected trusted source device
  ///
  /// In de, this message translates to:
  /// **'Virtuelles Gerät für diese Quelle erstellen'**
  String get createVirtualDeviceForSource;

  /// Snackbar when a virtual device for this device ID already exists
  ///
  /// In de, this message translates to:
  /// **'Für diese Geräte-ID existiert bereits ein virtuelles Gerät'**
  String get virtualDeviceAlreadyExistsForSource;

  /// Snackbar after successfully creating a virtual device from the active template
  ///
  /// In de, this message translates to:
  /// **'Virtuelles Gerät wurde erstellt'**
  String get virtualDeviceCreatedFromTemplate;

  /// Confirm dialog title when marking a device trusted
  ///
  /// In de, this message translates to:
  /// **'Als vertrauenswürdig markieren?'**
  String get confirmMarkTrustedTitle;

  /// Confirm dialog title when revoking trust
  ///
  /// In de, this message translates to:
  /// **'Vertrauen entziehen?'**
  String get confirmMarkUntrustedTitle;

  /// First-start device name dialog title
  ///
  /// In de, this message translates to:
  /// **'Gerät benennen'**
  String get deviceNameDialogTitle;

  /// First-start device name dialog content
  ///
  /// In de, this message translates to:
  /// **'Gib diesem Gerät einen Namen (3–20 Zeichen). Der Name wird fest mit einer UUID verbunden und bildet die Geräte-ID: Name@uuid\n\nDieser Name kann später nicht geändert werden.'**
  String get deviceNameDialogContent;

  /// Device name field label
  ///
  /// In de, this message translates to:
  /// **'Gerätename'**
  String get deviceNameLabel;

  /// Device name field hint
  ///
  /// In de, this message translates to:
  /// **'z. B. Alice, MeinHandy'**
  String get deviceNameHint;

  /// Helper text below the device name field
  ///
  /// In de, this message translates to:
  /// **'3–20 Zeichen, Pflichtfeld'**
  String get deviceNameLengthHint;

  /// No description provided for @databaseExplorerButton.
  ///
  /// In de, this message translates to:
  /// **'Datenbank Explorer'**
  String get databaseExplorerButton;

  /// Button to create random test data
  ///
  /// In de, this message translates to:
  /// **'Erstelle zufällige Testdaten'**
  String get generateRandomData;

  /// header on SQLite Database Explorer Screen
  ///
  /// In de, this message translates to:
  /// **'SQLite Explorer'**
  String get databaseExplorerScreenHeader;

  /// Label for table dropdown selector
  ///
  /// In de, this message translates to:
  /// **'Tabelle'**
  String get databaseExplorerTableLabel;

  /// Database Explorer no data found or no table selected message
  ///
  /// In de, this message translates to:
  /// **'Keine Daten oder keine Tabelle ausgewählt'**
  String get noDataOrTableSelected;

  /// Text button to load more data into table
  ///
  /// In de, this message translates to:
  /// **'Lade mehr Daten'**
  String get loadMoreRows;

  /// Message on end of data table
  ///
  /// In de, this message translates to:
  /// **'Ende der Tabelle erreicht'**
  String get endOfTableReached;

  /// Header for edit row data of given table name
  ///
  /// In de, this message translates to:
  /// **'Bearbeite Tabelle {value}'**
  String editFieldTitle(String value);

  /// Label for new value input
  ///
  /// In de, this message translates to:
  /// **'Neuer Wert'**
  String get newValueLabel;

  /// Database has been updated message
  ///
  /// In de, this message translates to:
  /// **'Datenbank aktualisiert'**
  String get databaseUpdated;

  /// Button to Shared Preferences Explorer Screen
  ///
  /// In de, this message translates to:
  /// **'Shared Preferences Explorer'**
  String get sharedPrefsExplorerButton;

  /// Header on Shared Preferences Explorer Screen
  ///
  /// In de, this message translates to:
  /// **'Shared Preferences Explorer'**
  String get sharedPrefsExplorerScreenHeader;

  /// Message when no shared preferences entries exist
  ///
  /// In de, this message translates to:
  /// **'Keine Einträge vorhanden'**
  String get sharedPrefsNoEntries;

  /// Header for editing a shared preferences entry
  ///
  /// In de, this message translates to:
  /// **'Bearbeite {key}'**
  String sharedPrefsEditTitle(String key);

  /// Title of the delete confirmation dialog
  ///
  /// In de, this message translates to:
  /// **'Eintrag löschen'**
  String get sharedPrefsDeleteTitle;

  /// Delete confirmation message for a shared preferences entry
  ///
  /// In de, this message translates to:
  /// **'Soll der Eintrag \"{key}\" wirklich gelöscht werden?'**
  String sharedPrefsDeleteConfirm(String key);

  /// Confirmation that an entry was deleted
  ///
  /// In de, this message translates to:
  /// **'Eintrag gelöscht'**
  String get sharedPrefsDeleted;

  /// Confirmation that an entry was updated
  ///
  /// In de, this message translates to:
  /// **'Eintrag aktualisiert'**
  String get sharedPrefsUpdated;

  /// Error message when the entered value cannot be parsed to the entry type
  ///
  /// In de, this message translates to:
  /// **'Ungültiger Wert für Typ {type}'**
  String sharedPrefsInvalidValue(String type);

  /// Shows next gps timer in seconds in home screen
  ///
  /// In de, this message translates to:
  /// **'Nächster GPS in {value} sek.'**
  String nextGpsIn(int value);

  /// Title of the developer tools section at the bottom of settings
  ///
  /// In de, this message translates to:
  /// **'Entwicklerwerkzeuge'**
  String get devToolsSectionTitle;

  /// Warning shown above the developer tools unlock challenge
  ///
  /// In de, this message translates to:
  /// **'WARNUNG: Diese Werkzeuge sind potentiell ZERSTÖRERISCH. Sie können Daten unwiderruflich verändern oder löschen. Nach dem Freischalten sind sie für eine Stunde nutzbar. Es ist SEHR SEHR SEHR ratsam, vorher wenigstens ein Backup der Datenbank anzulegen!'**
  String get devToolsWarning;

  /// Button that starts the unlock challenge
  ///
  /// In de, this message translates to:
  /// **'Entwicklerwerkzeuge freischalten'**
  String get devToolsUnlockButton;

  /// Instruction above the code the user must type
  ///
  /// In de, this message translates to:
  /// **'Tippe die folgende 8-stellige Zeichenfolge exakt ab, um freizuschalten:'**
  String get devToolsChallengeInstruction;

  /// Hint text for the challenge input field
  ///
  /// In de, this message translates to:
  /// **'Zeichenfolge eingeben'**
  String get devToolsChallengeHint;

  /// Snackbar shown after a successful unlock
  ///
  /// In de, this message translates to:
  /// **'Entwicklerwerkzeuge für eine Stunde freigeschaltet.'**
  String get devToolsUnlockSuccess;

  /// Shows until when the dev tools stay unlocked
  ///
  /// In de, this message translates to:
  /// **'Freigeschaltet bis {time}'**
  String devToolsUnlockedUntil(String time);

  /// Button to immediately re-lock the developer tools
  ///
  /// In de, this message translates to:
  /// **'Jetzt sperren'**
  String get devToolsRelock;

  /// No description provided for @messagesTitle.
  ///
  /// In de, this message translates to:
  /// **'Nachrichten'**
  String get messagesTitle;

  /// No description provided for @messageAttachments.
  ///
  /// In de, this message translates to:
  /// **'Nachrichten Anhänge'**
  String get messageAttachments;

  /// No description provided for @messagesPlaceTitle.
  ///
  /// In de, this message translates to:
  /// **'Ort-Nachrichten'**
  String get messagesPlaceTitle;

  /// No description provided for @messagesRegionTitle.
  ///
  /// In de, this message translates to:
  /// **'Nachrichten der Region'**
  String get messagesRegionTitle;

  /// No description provided for @messagesEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Nachrichten.'**
  String get messagesEmpty;

  /// No description provided for @messageDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Nachricht löschen?'**
  String get messageDeleteTitle;

  /// No description provided for @messageNeedsPlace.
  ///
  /// In de, this message translates to:
  /// **'Nachrichten benötigen einen Ort. Bitte in einem Ort verfassen.'**
  String get messageNeedsPlace;

  /// No description provided for @messageAuthorSelf.
  ///
  /// In de, this message translates to:
  /// **'Ich'**
  String get messageAuthorSelf;

  /// No description provided for @messageDeleted.
  ///
  /// In de, this message translates to:
  /// **'[gelöschte Nachricht]'**
  String get messageDeleted;

  /// No description provided for @messagePhotoPlaceholder.
  ///
  /// In de, this message translates to:
  /// **'[Foto]'**
  String get messagePhotoPlaceholder;

  /// No description provided for @reply.
  ///
  /// In de, this message translates to:
  /// **'Antworten'**
  String get reply;

  /// Banner shown while composing a reply
  ///
  /// In de, this message translates to:
  /// **'Antwort auf: {preview}'**
  String replyingTo(String preview);

  /// No description provided for @noPlaceAvailable.
  ///
  /// In de, this message translates to:
  /// **'Kein Ort verfügbar.'**
  String get noPlaceAvailable;

  /// No description provided for @noPhotosAtPlace.
  ///
  /// In de, this message translates to:
  /// **'Keine Fotos an diesem Ort.'**
  String get noPhotosAtPlace;

  /// No description provided for @gallery.
  ///
  /// In de, this message translates to:
  /// **'Galerie'**
  String get gallery;

  /// No description provided for @existingPlacePhoto.
  ///
  /// In de, this message translates to:
  /// **'Vorhandenes Foto des Ortes'**
  String get existingPlacePhoto;

  /// No description provided for @messageHint.
  ///
  /// In de, this message translates to:
  /// **'Nachricht…'**
  String get messageHint;

  /// No description provided for @placeMessagesButton.
  ///
  /// In de, this message translates to:
  /// **'P2P Nachrichten zum Ort'**
  String get placeMessagesButton;

  /// No description provided for @createPlace.
  ///
  /// In de, this message translates to:
  /// **'Ort erstellen'**
  String get createPlace;

  /// No description provided for @showRegionMessages.
  ///
  /// In de, this message translates to:
  /// **'Nachrichten der Region zeigen'**
  String get showRegionMessages;

  /// No description provided for @regionRadiusTitle.
  ///
  /// In de, this message translates to:
  /// **'Radius der Region'**
  String get regionRadiusTitle;

  /// No description provided for @radiusInKm.
  ///
  /// In de, this message translates to:
  /// **'Radius in km'**
  String get radiusInKm;

  /// No description provided for @showAction.
  ///
  /// In de, this message translates to:
  /// **'Anzeigen'**
  String get showAction;

  /// No description provided for @sectionP2pMessenger.
  ///
  /// In de, this message translates to:
  /// **'P2P-Messenger'**
  String get sectionP2pMessenger;

  /// No description provided for @messengerEnable.
  ///
  /// In de, this message translates to:
  /// **'Messenger aktivieren'**
  String get messengerEnable;

  /// No description provided for @messengerEnableSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Ortsgebundener P2P-Chat im Orte-Tab (Store-and-Forward).'**
  String get messengerEnableSubtitle;

  /// No description provided for @createPlaceOnSync.
  ///
  /// In de, this message translates to:
  /// **'Orte bei Sync-Gelegenheit erstellen'**
  String get createPlaceOnSync;

  /// No description provided for @createPlaceOnSyncSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Legt bei einer Synchronisationsgelegenheit automatisch einen Ort als „Sync-Quelle\" an – auch wenn die automatische Ortserstellung deaktiviert ist. Nötig, damit dort empfangene Nachrichten einen Bezugsort haben.'**
  String get createPlaceOnSyncSubtitle;

  /// No description provided for @syncPhotos.
  ///
  /// In de, this message translates to:
  /// **'Fotos synchronisieren'**
  String get syncPhotos;

  /// No description provided for @syncPhotosSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Bilder über das Mesh übertragen (base64 im JSON – kann groß werden).'**
  String get syncPhotosSubtitle;

  /// No description provided for @photoSizeLimitUnlimited.
  ///
  /// In de, this message translates to:
  /// **'Foto-Größenlimit: unbegrenzt'**
  String get photoSizeLimitUnlimited;

  /// Photo sync size limit in KiB
  ///
  /// In de, this message translates to:
  /// **'Foto-Größenlimit: {kib} KiB'**
  String photoSizeLimitKib(int kib);

  /// No description provided for @unlimited.
  ///
  /// In de, this message translates to:
  /// **'unbegrenzt'**
  String get unlimited;

  /// No description provided for @nodeScanModeLabel.
  ///
  /// In de, this message translates to:
  /// **'Node-Scan-Modus'**
  String get nodeScanModeLabel;

  /// No description provided for @nodeScanOnHalt.
  ///
  /// In de, this message translates to:
  /// **'Bei Halt am Ort'**
  String get nodeScanOnHalt;

  /// No description provided for @nodeScanPerGps.
  ///
  /// In de, this message translates to:
  /// **'Pro GPS-Intervall'**
  String get nodeScanPerGps;

  /// Periodic node scan interval
  ///
  /// In de, this message translates to:
  /// **'Scan alle {count} GPS-Intervalle'**
  String nodeScanEvery(int count);

  /// No description provided for @autoCreatePlacesMessengerNote.
  ///
  /// In de, this message translates to:
  /// **'Hinweis: Ortsgebundene Nachrichten des P2P-Messengers benötigen zwingend einen Ort als Bezugspunkt. Ist die automatische Ortserstellung aus, können bei Synchronisationsgelegenheiten dennoch Orte als „Sync-Quelle\" angelegt werden (siehe P2P-Messenger).'**
  String get autoCreatePlacesMessengerNote;

  /// No description provided for @locatorCopied.
  ///
  /// In de, this message translates to:
  /// **'Amateurfunk QTH Locator kopiert'**
  String get locatorCopied;

  /// No description provided for @compassTitle.
  ///
  /// In de, this message translates to:
  /// **'Kompass'**
  String get compassTitle;

  /// No description provided for @compassRefHere.
  ///
  /// In de, this message translates to:
  /// **'Von hier'**
  String get compassRefHere;

  /// No description provided for @compassRefPlace.
  ///
  /// In de, this message translates to:
  /// **'Von Ort'**
  String get compassRefPlace;

  /// No description provided for @compassFromHere.
  ///
  /// In de, this message translates to:
  /// **'Mit Kompass von hier'**
  String get compassFromHere;

  /// No description provided for @compassFromPlace.
  ///
  /// In de, this message translates to:
  /// **'Mit Kompass von diesem Ort'**
  String get compassFromPlace;

  /// No description provided for @virtualDevicesScreenTitle.
  ///
  /// In de, this message translates to:
  /// **'Virtuelle Geräte'**
  String get virtualDevicesScreenTitle;

  /// Virtual Device detail screen title
  ///
  /// In de, this message translates to:
  /// **'V-Gerät: {name}'**
  String virtualDeviceDetailTitle(String name);

  /// No description provided for @switchToVirtualDevice.
  ///
  /// In de, this message translates to:
  /// **'Zu diesem virtuellen Gerät wechseln'**
  String get switchToVirtualDevice;

  /// No description provided for @switchToVirtualDeviceSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Dieses virtuelle Gerät und ihre Geräte-ID werden aktiv'**
  String get switchToVirtualDeviceSubtitle;

  /// No description provided for @virtualDeviceCurrentlyActive.
  ///
  /// In de, this message translates to:
  /// **'Aktuell aktiv'**
  String get virtualDeviceCurrentlyActive;

  /// No description provided for @privateSpaceSection.
  ///
  /// In de, this message translates to:
  /// **'Privater Bereich'**
  String get privateSpaceSection;

  /// No description provided for @protectFromExportLabel.
  ///
  /// In de, this message translates to:
  /// **'Gegen Sync-Export schützen'**
  String get protectFromExportLabel;

  /// No description provided for @protectFromExportSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Daten dieses virtuellen Gerätes werden nicht an Sync-Server übertragen (für die Außenwelt unsichtbar)'**
  String get protectFromExportSubtitle;

  /// No description provided for @protectFromImportLabel.
  ///
  /// In de, this message translates to:
  /// **'Gegen Sync-Import schützen'**
  String get protectFromImportLabel;

  /// No description provided for @protectFromImportSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Eingehende Sync-Daten mit diesem virtuellen Gerät werden ignoriert (schützt die Privatsphäre)'**
  String get protectFromImportSubtitle;

  /// No description provided for @purgeDataLabel.
  ///
  /// In de, this message translates to:
  /// **'Datenbankeinträge säubern'**
  String get purgeDataLabel;

  /// No description provided for @purgeDataSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Alle Einträge mit dieser Geräte-ID aus der Datenbank entfernen (nicht das virtuelle Gerät selbst)'**
  String get purgeDataSubtitle;

  /// No description provided for @purgeDataConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Einträge säubern?'**
  String get purgeDataConfirmTitle;

  /// Purge confirmation dialog content
  ///
  /// In de, this message translates to:
  /// **'Alle Datenbankeinträge der Geräte-ID von „{name}“ werden unwiderruflich entfernt.'**
  String purgeDataConfirmContent(String name);

  /// Purge success message
  ///
  /// In de, this message translates to:
  /// **'{count} Einträge entfernt'**
  String purgeDataSuccess(int count);

  /// No description provided for @deleteWithCleanupCheckbox.
  ///
  /// In de, this message translates to:
  /// **'Datenbank ebenfalls säubern'**
  String get deleteWithCleanupCheckbox;

  /// No description provided for @deleteWithCleanupCheckboxSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Alle Einträge mit der Geräte-ID dieses virtuellen Geräts werden entfernt'**
  String get deleteWithCleanupCheckboxSubtitle;

  /// No description provided for @movePlacesTitle.
  ///
  /// In de, this message translates to:
  /// **'Orte verschieben'**
  String get movePlacesTitle;

  /// No description provided for @moveButton.
  ///
  /// In de, this message translates to:
  /// **'Verschieben'**
  String get moveButton;

  /// Snackbar after moving places to another group
  ///
  /// In de, this message translates to:
  /// **'{count} Orte verschoben'**
  String placesMovedCount(int count);

  /// No description provided for @placeDetailPhotoCount.
  ///
  /// In de, this message translates to:
  /// **'Fotos direkt anzeigen: {n}'**
  String placeDetailPhotoCount(int n);

  /// No description provided for @placeDetailPhotoCountSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Anzahl der Fotos, die direkt in den Ortsdetails angezeigt werden'**
  String get placeDetailPhotoCountSubtitle;

  /// No description provided for @showAllPhotosButton.
  ///
  /// In de, this message translates to:
  /// **'Alle {count} Fotos anzeigen'**
  String showAllPhotosButton(int count);

  /// No description provided for @allPhotosScreenTitle.
  ///
  /// In de, this message translates to:
  /// **'Alle Fotos'**
  String get allPhotosScreenTitle;

  /// No description provided for @openVisitButton.
  ///
  /// In de, this message translates to:
  /// **'Besuch öffnen'**
  String get openVisitButton;

  /// No description provided for @openPlaceButton.
  ///
  /// In de, this message translates to:
  /// **'Ort öffnen'**
  String get openPlaceButton;

  /// No description provided for @placeNotFoundTitle.
  ///
  /// In de, this message translates to:
  /// **'Ort nicht gefunden'**
  String get placeNotFoundTitle;

  /// No description provided for @placeNotFoundContent.
  ///
  /// In de, this message translates to:
  /// **'Dieser Ort existiert nicht mehr in der Datenbank. Er wurde möglicherweise gelöscht oder noch nicht synchronisiert.'**
  String get placeNotFoundContent;

  /// No description provided for @visitNotFoundTitle.
  ///
  /// In de, this message translates to:
  /// **'Besuch nicht gefunden'**
  String get visitNotFoundTitle;

  /// No description provided for @visitNotFoundContent.
  ///
  /// In de, this message translates to:
  /// **'Dieser Besuch existiert nicht mehr in der Datenbank. Er wurde möglicherweise gelöscht oder noch nicht synchronisiert.'**
  String get visitNotFoundContent;

  /// No description provided for @imageFileHasNoData.
  ///
  /// In de, this message translates to:
  /// **'Datei ist leer'**
  String get imageFileHasNoData;

  /// No description provided for @imageFileTypeLooksLike.
  ///
  /// In de, this message translates to:
  /// **'Datei schein vom Typ {type} zu sein'**
  String imageFileTypeLooksLike(String type);

  /// No description provided for @imageFileHasUnknownType.
  ///
  /// In de, this message translates to:
  /// **'Datetyp unbekannt'**
  String get imageFileHasUnknownType;

  /// No description provided for @imageLoadingError.
  ///
  /// In de, this message translates to:
  /// **'Fehler beim laden des Bildes'**
  String get imageLoadingError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
