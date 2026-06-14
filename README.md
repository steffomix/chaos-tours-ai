# Chaos Tours

**Automatische Aufenthaltserkennung und persönliches Bewegungsprotokoll**

Chaos Tours ist eine Android-App, die im Hintergrund deinen Aufenthaltsort verfolgt, automatisch erkennt wo du dich aufhältst, und daraus ein detailliertes, durchsuchbares Bewegungsprotokoll erstellt – mit Orten, Personen, Aktivitäten und optionaler Kalenderintegration.

---

## Features

### 🛰️ GPS-Tracking im Hintergrund
- Läuft als Foreground-Service dauerhaft im Hintergrund
- Konfigurierbares Aufnahmeintervall (5–120 Sekunden)
- GPS-Glättung zur Rauschreduktion (einstellbares Fenster)

### 🧠 Intelligente Aufenthaltserkennung
- State-Machine-Algorithmus erkennt automatisch Stopps und Bewegungsphasen
- Kurzes Erkennungsfenster (~3 min) für vorläufige Halts
- Langes Bestätigungsfenster (~15 min) für unbekannte Orte
- Automatische Ortserstellung für neue, unbekannte Haltepunkte
- Berechnet GPS-Cluster-Schwerpunkte für präzise Ortsbestimmung

### 🗺️ Kartendarstellung
- Interaktive Karte (OpenStreetMap) mit allen gespeicherten Orten
- Live-Visualisierung der aktuellen GPS-Tracking-Punkte
- Ortsneupositionierung direkt auf der Karte
- Aktueller Standort mit Genauigkeitsanzeige

### 📍 Ortsverwaltung
- Orte mit Namen, Radius und Adresse speichern
- Reverse-Geocoding via Nominatim (OpenStreetMap)
- **4 Ortstypen** mit unterschiedlichem Datenschutzverhalten:
  - 🟢 **Öffentlich** – vollständiges Tracking, Benachrichtigungen, Kalender
  - 🔵 **Privat** – Tracking und Benachrichtigungen, kein Kalender
  - 🔴 **Geheim** – nur Kartendarstellung, kein Tracking, keine Notizen
  - ⚫ **Verboten** – standardmäßig ausgeblendet, kein Tracking
- **Ortsgruppen** mit geteiltem Kalender und Privatsphäreeinstellungen
- **Besuchs-Intervall** pro Ort: konfigurierbares Wiederbesuchs-Intervall in Tagen
  mit Ein-/Ausschalter direkt in den Ortseinstellungen
- Intervall-Filter in der Ortsliste zeigt nur Orte mit aktivem Intervall

### 📅 Zeitachse & Aufenthaltsverlauf
- Chronologische Auflistung aller Aufenthalte
- Filter nach Datum und Ort
- Suche in Notizen und Ortsbezeichnungen
- Visualisierung auf der Karte

### 🗓️ Planer (Scheduler)
- Eigener Tab in der Zeitachse mit allen Orten, für die ein Besuchs-Intervall aktiv ist
- Sortierung nach Dringlichkeit: überfällige Orte zuerst
- Farbige Dringlichkeitsanzeige (Kreis mit verbleibenden Tagen):
  - 🟢 Grün – noch viel Zeit (≥ Farbskala-Bereich)
  - 🟡 Gelb – heute fällig (0 Tage)
  - 🔴 Rot – überfällig (≤ –Farbskala-Bereich)
- Noch nie besuchte Orte gelten als heute fällig
- Gruppenfilter: nur bestimmte Ortsgruppen im Planer und auf der Karte anzeigen

### 👤 Aufenthaltsannotationen
Jedem Aufenthalt können zugeordnet werden:
- **Personen** (wer war dabei?)
- **Aktivitäten** (was wurde getan?)
- **Notizen** (freier Text)
- **Fotos** (direkt am Aufenthalt oder am Ort)
- **Kalendereinträge** (optionale Synchronisation mit dem Gerätekalender)

### 📸 Fotos & Fotoalbum
- Fotos können Orten und/oder einzelnen Aufenthalten zugeordnet werden
- Fotoalbum-Screen mit nach Ort gruppierten Galerie-Ansichten
- Fotos werden als Base64 in der SQLite-Datenbank gespeichert und mit dem Sync-Server synchronisiert

### ⭐ Ortserfahrungen & Bewertungen
- Zu jedem Ort können Erfahrungsberichte mit Freitext gespeichert werden
- **6 Bewertungsdimensionen** auf einer Skala von −9 bis +9:
  - Gefährlich ↔ Freundlich
  - Betrügerisch ↔ Zuverlässig
  - Abweisend ↔ Bietet Unterkunft
  - Fordert ↔ Bietet Verpflegung
  - Fordert ↔ Bietet Equipment
  - Fordert ↔ Bietet Transport
- Durchschnittsbewertung über alle Dimensionen berechnet

### 🔒 Datenschutz
- Überlappende Orte bestimmen die effektive Privatsphärestufe
- Geheime/verbotene Orte unterdrücken Kalender und Tracking
- Verbotene Orte standardmäßig verborgen (manuell einblendbar)

### ⚙️ Konfigurationsprofile (Aktivitäten)
- Mehrere benannte Tracking-Profile
- Je Profil konfigurierbar:
  - GPS-Intervall
  - Erkennungsfenster für Halts
  - Verzögerung für Auto-Ortserstellung
  - Standard-Ortsradius
  - GPS-Glättungsfenster
  - Zeitachsentiefe (Tage)
  - **Farbskala-Bereich** für den Planer (Standard: 14 Tage)
  - **Gruppenfilter** für Karte und Planer (einzelne Gruppen oder alle)

### 🔄 Geräteübergreifende Synchronisation
- Optionaler Self-Hosted **Sync-Server** (FastAPI + PostgreSQL)
- Mehrere **Sync-Quellen** konfigurierbar (verschiedene Server oder Instanzen)
- Delta-Sync: nur seit dem letzten Sync geänderte Datensätze werden übertragen
- Feingranulare Kontrolle: je Sync-Quelle wählbar, welche Tabellen synchronisiert werden und ob Einfügen/Bearbeiten/Löschen erlaubt ist
- Alle Tabellen synchronisierbar: Orte, Gruppen, Aufenthalte, Personen, Aktivitäten, Fotos, Erfahrungen, Kalender u. a.
- **Erfahrungs-Feeds**: Sync-Quelle kann als externer Erfahrungs-Feed abonniert werden (nur Lesen)

### 📬 Telegram-Benachrichtigungen
- Aufenthalts-Benachrichtigungen per Telegram Bot an einen Kanal oder Chat senden
- Mehrere **Telegram-Verbindungen** (Bot-Token + Chat-ID) konfigurierbar
- Nachrichten werden bei Ankunft/Abfahrt automatisch gesendet oder bearbeitet

### 💾 Datenverwaltung
- SQLite-Datenbank (lokal, kein Cloud-Zwang)
- Export/Import der SQLite Datenbank via Sharing
- Datenbankrücksetzung
- Direktzugriff auf die PostgreSQL-Datenbank des Sync-Servers z. B. via LibreOffice Base

---

## Screenshots

| Übersicht | Karte | Orte | Zeitachse |
|-----------|-------|------|-----------|
| Aktueller Trackingstatus, aktiver Aufenthalt, letzte Besuche | Interaktive Karte mit Orten und Live-GPS | Gespeicherte Orte mit Besuchszähler | Chronologischer Aufenthaltsverlauf |

---

## Technik

| Komponente | Technologie |
|------------|-------------|
| Framework | Flutter (Dart) |
| Datenbank | SQLite via sqflite |
| Karten | flutter_map + OpenStreetMap |
| GPS | geolocator |
| Geocoding | Nominatim (OpenStreetMap) |
| Kalender | device_calendar |
| Hintergrundservice | flutter_foreground_task |
| Sync-Server | FastAPI + PostgreSQL (self-hosted) |
| Messaging | Telegram Bot API |

---

## Architektur

```
lib/
├── main.dart                  # Entry Point
├── app.dart                   # App-Konfiguration & Routing
├── models/                    # Datenmodelle (Stay, SavedPlace, Person, PlacePhoto, PlaceExperience, …)
├── services/
│   ├── tracking_engine.dart   # State-Machine: Kern-Tracking-Logik
│   ├── location_service.dart  # GPS-Stream
│   ├── database_service.dart  # SQLite-Persistenz
│   ├── settings_service.dart  # SharedPreferences
│   ├── calendar_service.dart  # Kalenderintegration
│   ├── nominatim_service.dart # Reverse Geocoding
│   ├── sync_service.dart      # Geräteübergreifende Synchronisation
│   ├── telegram_service.dart  # Telegram-Benachrichtigungen
│   └── foreground_service_handler.dart
├── ui/
│   ├── screens/               # Hauptbildschirme (4 Tabs + Einstellungen)
│   └── widgets/               # Wiederverwendbare UI-Komponenten
└── utils/
    ├── geo_utils.dart         # Geo-Algorithmen (Clustering, Centroid, …)
    └── permission_helper.dart
```

---

## Installation & Setup

### Voraussetzungen
- Flutter SDK ≥ 3.x
- Android SDK (API Level 21+)
- Ein Android-Gerät oder Emulator

### Build

```bash
git clone <repo-url>
cd chaos_tours_ai_2
flutter pub get
flutter run
```

### Berechtigungen
Die App benötigt folgende Android-Berechtigungen:
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` – GPS
- `ACCESS_BACKGROUND_LOCATION` – Hintergrundtracking
- `FOREGROUND_SERVICE` – dauerhafter Hintergrundservice
- `READ_CALENDAR` / `WRITE_CALENDAR` – optionale Kalenderintegration
- `POST_NOTIFICATIONS` – Tracking-Benachrichtigung

---

## Datenschutz

Alle Daten werden **ausschließlich lokal** auf dem Gerät gespeichert. Es findet keine Übertragung an externe Server statt (außer anonymer Geocoding-Anfragen an die öffentliche Nominatim-API von OpenStreetMap).

---

## Lizenz

Dieses Projekt steht unter der [MIT License](LICENSE).
