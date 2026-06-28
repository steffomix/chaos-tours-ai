import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/activity.dart';
import '../models/aktivitaet.dart';
import '../models/person.dart';
import '../models/place_experience.dart';
import '../models/place_group.dart';
import '../models/place_photo.dart';
import '../models/saved_place.dart';
import '../models/stay.dart';
import '../models/stay_activity.dart';
import '../models/stay_person.dart';
import '../models/sync_source.dart';
import '../models/telegram_connection.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

class RandomDataProgressNotifier extends ValueNotifier<String> {
  RandomDataProgressNotifier(super.value);

  String _status = 'Ready';
  int _progress = 0;
  int _countPlaces = 0;
  int _countStays = 0;
  int _countPlacePhotos = 0;
  int _countStayPhotos = 0;
  int _countPlaceExperiences = 0;
  int _countStayExperiences = 0;
  int _countAktivitaeten = 0;
  int _countPersons = 0;
  int _countActivities = 0;
  int _countTelegramConnections = 0;
  int _countSyncSources = 0;
  int _countPlaceGroups = 0;
  int _countStayPersons = 0;
  int _countStayActivities = 0;

  int _totalCount = 0;

  set status(String newStatus) {
    _status = newStatus;
    _updateValue();
  }

  void setProgress(int totalCount, int doneCount) {
    // don't update value here
    _progress = (doneCount / totalCount * 100).toInt();
  }

  void addPlace() {
    _countPlaces++;
    _updateValue();
  }

  void addStay() {
    _countStays++;
    _updateValue();
  }

  void addPlacePhoto() {
    _countPlacePhotos++;
    _updateValue();
  }

  void addStayPhoto() {
    _countStayPhotos++;
    _updateValue();
  }

  void addPlaceExperience() {
    _countPlaceExperiences++;
    _updateValue();
  }

  void addStayExperience() {
    _countStayExperiences++;
    _updateValue();
  }

  void addAktivitaet() {
    _countAktivitaeten++;
    _updateValue();
  }

  void addPerson() {
    _countPersons++;
    _updateValue();
  }

  void addActivity() {
    _countActivities++;
    _updateValue();
  }

  void addTelegramConnection() {
    _countTelegramConnections++;
    _updateValue();
  }

  void addSyncSource() {
    _countSyncSources++;
    _updateValue();
  }

  void addPlaceGroup() {
    _countPlaceGroups++;
    _updateValue();
  }

  void addStayPerson() {
    _countStayPersons++;
    _updateValue();
  }

  void addStayActivity() {
    _countStayActivities++;
    _updateValue();
  }

  void updateProgress(String newValue) {
    value = newValue;
  }

  void _updateValue() {
    _totalCount =
        _countPlaces +
        _countStays +
        _countPlacePhotos +
        _countStayPhotos +
        _countPlaceExperiences +
        _countStayExperiences +
        _countAktivitaeten +
        _countPersons +
        _countActivities +
        _countTelegramConnections +
        _countSyncSources +
        _countPlaceGroups +
        _countStayPersons +
        _countStayActivities;
    value =
        '''Status: $_status

Fortschritt: $_progress%
Total: $_totalCount

Aktivitaeten: $_countAktivitaeten
Persons: $_countPersons
Activities: $_countActivities
Telegram Connections: $_countTelegramConnections
Sync Sources: $_countSyncSources
Place Groups: $_countPlaceGroups
Places: $_countPlaces
Place Photos: $_countPlacePhotos
Place Experiences: $_countPlaceExperiences
Stays: $_countStays
Stay Photos: $_countStayPhotos
Stay Experiences: $_countStayExperiences
Stay Persons: $_countStayPersons
Stay Activities: $_countStayActivities''';
  }
}

class ImageGenerator {
  static int _imageCounter = 0;

  // Konstanten für das Bild (Einmalig definieren spart RAM bei tausenden Aufrufen)
  static const double _imgWidth = 50.0;
  static const double _imgHeight = 14.0;

  static final _textStyle = ui.TextStyle(
    color: Colors.black,
    fontSize: 14.0,
    fontWeight: FontWeight.bold,
  );

  static final _paragraphStyle = ui.ParagraphStyle(
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );

  static Future<ui.Image> createNumberImage() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    final ui.Paint backgroundPaint = ui.Paint()..color = Colors.white;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _imgWidth, _imgHeight),
      backgroundPaint,
    );

    final paragraphBuilder = ui.ParagraphBuilder(_paragraphStyle)
      ..pushStyle(_textStyle)
      ..addText('${_imageCounter++}'.padLeft(5, '0'));

    final ui.Paragraph paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: _imgWidth));

    final double yOffset = (_imgHeight - paragraph.height) / 2;
    canvas.drawParagraph(paragraph, Offset(0, yOffset));

    final ui.Picture picture = recorder.endRecording();
    return await picture.toImage(_imgWidth.toInt(), _imgHeight.toInt());
  }
}

class RandomDataGenerator {
  bool generatingData = false;

  // NEU: Ein Notifier, der den aktuellen Status-Text hält
  final RandomDataProgressNotifier progressNotifier =
      RandomDataProgressNotifier('Bereit');

  final DatabaseService _db = DatabaseService.instance;
  static const _uuid = Uuid();
  static final _random = Random();
  static final List<String> deviceIdPool = [];

  static final firstStayStartTime = DateTime.now()
      .subtract(const Duration(days: 365))
      .millisecondsSinceEpoch;
  static final stayStepTime = Duration(hours: 1).inMilliseconds;
  static final stayDuration = Duration(minutes: 30).inMilliseconds;
  static int stayCounter = 0;

  RandomDataGenerator();

  String randomUuid() => _uuid.v4();

  String generateDeviceId() {
    final name = randomString(5);
    final uuid = randomUuid();
    return '$name@$uuid';
  }

  String deviceIdFromPool() {
    if (deviceIdPool.isEmpty) {
      deviceIdPool.addAll(
        List.generate(25, (_) => '${randomString(5)}@${randomUuid()}'),
      );
    }
    return deviceIdPool[_random.nextInt(deviceIdPool.length)];
  }

  bool randomBool() => _random.nextBool();

  String randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    // BEHOBEN: Nutze statisches _random statt jedes Mal "final rand = Random();"
    return List.generate(
      length,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  String get email => '${randomString(8)}@${randomString(5)}.com';
  String get url => 'https://www.${randomString(5)}.com';
  String get phone =>
      '+1-${_random.nextInt(900) + 100}-${_random.nextInt(900) + 100}-${_random.nextInt(9000) + 1000}';
  String get address =>
      '${_random.nextInt(9999) + 1} ${randomString(6)} St, ${randomString(6)}, ${randomString(2).toUpperCase()} ${_random.nextInt(90000) + 10000}';
  String get notes => 'Notes: ${randomString(_random.nextInt(50) + 10)}';
  double get rating => ((_random.nextDouble() * 18) - 9).clamp(-9.0, 9.0);
  double get latitude => 47 + (_random.nextDouble() * 7);
  double get longitude => 4 + (_random.nextDouble() * 7);
  int get intervalDays => _random.nextInt(30) + 1;

  int get stayStartTime {
    final pastDays = _random.nextInt(30) + 10;
    return DateTime.now()
        .subtract(Duration(days: pastDays))
        .millisecondsSinceEpoch;
  }

  int get randomPastTimeStamp {
    final pastDays = _random.nextInt(30);
    return DateTime.now()
        .subtract(Duration(days: pastDays))
        .millisecondsSinceEpoch;
  }

  int randomTimeStampAfter(int afterMs) {
    final futureHours = _random.nextInt(24);
    return DateTime.fromMillisecondsSinceEpoch(
      afterMs,
    ).add(Duration(hours: futureHours)).millisecondsSinceEpoch;
  }

  StayStatus get randomStayStatus =>
      StayStatus.values[_random.nextInt(StayStatus.values.length)];

  PlaceExperience randomPlaceExperience(
    String savedPlaceUuid, {
    String? stayUuid,
  }) {
    final ts = randomPastTimeStamp;
    return PlaceExperience(
      uuid: randomUuid(),
      savedPlaceUuid: savedPlaceUuid,
      stayUuid: stayUuid,
      text: notes,
      ratingDangerousFriendly: _random.nextInt(19) - 9,
      ratingFraudReliable: _random.nextInt(19) - 9,
      ratingDismissiveAccommodation: _random.nextInt(19) - 9,
      ratingFood: _random.nextInt(19) - 9,
      ratingEquipment: _random.nextInt(19) - 9,
      ratingTransport: _random.nextInt(19) - 9,
      ratingMedicine: _random.nextInt(19) - 9,
      createdAt: ts,
      updatedAt: randomTimeStampAfter(ts),
      deletedAt: null,
      deviceId: deviceIdFromPool(),
    );
  }

  SyncSourceOptions get randomSyncSourceOptions {
    final tables = SyncSourceOptions.allTables;
    final options = <String, SyncTableOptions>{};
    for (var table in tables) {
      options[table] = SyncTableOptions(
        insert: _random.nextBool(),
        update: _random.nextBool(),
        delete: _random.nextBool(),
      );
    }
    return SyncSourceOptions(tables: options);
  }

  Activity get randomActivity => Activity(name: notes);

  Map<String, dynamic> _withSyncFields(
    Map<String, dynamic> map,
    String deviceId,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final effectiveDeviceId = deviceId.isNotEmpty
        ? deviceId
        : ((map['device_id'] as String?)?.isNotEmpty == true
              ? map['device_id'] as String
              : SettingsService.instance.deviceId);
    return {
      ...map,
      'uuid': (map['uuid'] as String?)?.isNotEmpty == true
          ? map['uuid']
          : randomUuid(),
      'updated_at': now,
      'device_id': effectiveDeviceId,
    };
  }

  // Hilfsmethoden für Batch-Inserts (Rückgabetyp zu void geändert, da im Generator nicht benötigt)
  void insertAktivitaet(Batch batch, Aktivitaet a) {
    batch.insert(
      'aktivitaeten',
      _withSyncFields(a.toMap(), a.deviceId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void insertPlace(Batch batch, SavedPlace place) {
    batch.insert(
      'saved_places',
      _withSyncFields(place.toMap(), ''),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void insertPlaceGroup(Batch batch, PlaceGroup group) {
    batch.insert(
      'place_groups',
      _withSyncFields(group.toMap(), ''),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void insertStay(Batch batch, Stay stay) {
    batch.insert(
      'stays',
      _withSyncFields(stay.toMap(), ''),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void insertPerson(Batch batch, Person person) {
    batch.insert(
      'persons',
      _withSyncFields(person.toMap(), ''),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void insertActivity(Batch batch, Activity activity) {
    batch.insert(
      'activities',
      _withSyncFields(activity.toMap(), ''),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void insertStayPerson(Batch batch, StayPerson sp) {
    batch.insert(
      'stay_persons',
      _withSyncFields(sp.toMap(), ''),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void insertStayActivity(Batch batch, StayActivity sa) {
    batch.insert(
      'stay_activities',
      _withSyncFields(sa.toMap(), ''),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void insertSyncSource(Batch batch, SyncSource source) {
    batch.insert(
      'sync_sources',
      _withSyncFields(source.toMap(), ''),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void insertTelegramConnection(Batch batch, TelegramConnection conn) {
    batch.insert(
      'telegram_connections',
      _withSyncFields(conn.toMap(), ''),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void insertPhoto(Batch batch, PlacePhoto photo) {
    batch.insert(
      'place_photos',
      _withSyncFields(photo.toMap(), ''),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void insertPlaceExperience(Batch batch, PlaceExperience exp) {
    batch.insert(
      'place_experiences',
      _withSyncFields(exp.toMap(), ''),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Objekt-Erstellungen
  Aktivitaet _createAktivitaet() {
    final deviceId = generateDeviceId();
    deviceIdPool.add(deviceId);
    return Aktivitaet(
      uuid: randomUuid(),
      name: 'Aktivitaet ${randomString(5)}',
      deviceId: deviceId,
    );
  }

  SavedPlace _createPlace(String? groupUuid) {
    return SavedPlace(
      uuid: randomUuid(),
      name: 'Place ${randomString(5)}',
      notes: notes,
      website: url,
      email: email,
      phone: phone,
      lat: latitude,
      lng: longitude,
      intervalEnabled: randomBool(),
      intervalDays: intervalDays,
      groupUuid: groupUuid,
      deviceId: deviceIdFromPool(),
    );
  }

  PlaceGroup _createPlaceGroup() {
    return PlaceGroup(
      uuid: randomUuid(),
      name: 'Group ${randomString(5)}',
      placeType: PlaceType.private,
      isAutoGroup: false,
      deviceId: deviceIdFromPool(),
    );
  }

  Stay _createStay(String placeUuid) {
    final stay = Stay(
      uuid: randomUuid(),
      placeUuid: placeUuid,
      startTime: firstStayStartTime + (stayCounter * stayStepTime),
      endTime: firstStayStartTime + (stayCounter * stayStepTime) + stayDuration,
      address: address,
      notes: '(Stay #$stayCounter) - $notes',
      status: StayStatus.completed,
      isInterval: randomBool(),
      deviceId: deviceIdFromPool(),
    );
    stayCounter++; // Increment stayCounter for each new stay
    return stay;
  }

  Person _createPerson() => Person(
    uuid: randomUuid(),
    name: 'Person ${randomString(5)}',
    deviceId: deviceIdFromPool(),
  );
  Activity _createActivity() => Activity(
    uuid: randomUuid(),
    name: 'Activity ${randomString(5)}',
    deviceId: deviceIdFromPool(),
  );
  StayActivity _createStayActivity(String stayUuid, String activityUuid) =>
      StayActivity(
        uuid: randomUuid(),
        stayUuid: stayUuid,
        activityUuid: activityUuid,
        description: notes,
        deviceId: deviceIdFromPool(),
      );
  StayPerson _createStayPerson(String stayUuid, String personUuid) =>
      StayPerson(
        uuid: randomUuid(),
        stayUuid: stayUuid,
        personUuid: personUuid,
        name: 'StayPerson ${randomString(5)}',
        deviceId: deviceIdFromPool(),
      );
  TelegramConnection _createTelegramConnection() => TelegramConnection(
    uuid: randomUuid(),
    name: 'TelegramConnection ${randomString(5)}',
    botToken: randomString(10),
    chatId: randomString(10),
    description: notes,
    updatedAt: randomPastTimeStamp,
    deletedAt: null,
    deviceId: deviceIdFromPool(),
  );

  SyncSource _createSyncSource() {
    return SyncSource(
      uuid: randomUuid(),
      name: 'SyncSource ${randomString(5)}',
      syncUrl: url,
      apiKey: randomString(10),
      infoUrl: url,
      description: notes,
      syncOptions: randomSyncSourceOptions,
      updatedAt: randomPastTimeStamp,
      deletedAt: null,
      deviceId: deviceIdFromPool(),
    );
  }

  Future<PlacePhoto> _createPhoto(String placeUuid, {String? stayUuid}) async {
    final image = await ImageGenerator.createNumberImage();
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List pngBytes = byteData!.buffer.asUint8List();
    return PlacePhoto(
      uuid: randomUuid(),
      placeUuid: placeUuid,
      stayUuid: stayUuid,
      photoData: pngBytes,
      createdAt: randomPastTimeStamp,
      updatedAt: randomTimeStampAfter(randomPastTimeStamp),
      deletedAt: null,
      deviceId: deviceIdFromPool(),
    );
  }

  Future<void> generateRandomData({
    int numAktivitaeten = 2,
    int numTelegramConnections = 2,
    int numSyncSources = 2,
    int numPersons = 5,
    int numActivities = 5,
    int numPlaceGroups = 2,
    int numPlacesPerGroup = 100,
    int maxPhotosPerPlace = 2,
    int maxExperiencesPerPlace = 2,
    int maxStaysPerPlace = 20,
    int numStayPersons = 2,
    int numStayActivities = 2,
    int maxPhotosPerStay = 2,
    int maxExperiencesPerStay = 2,
  }) async {
    if (generatingData) {
      debugPrint('Random data generation is already in progress.');
      return;
    }

    final deviceId = SettingsService.instance.deviceId;
    if (deviceIdPool.isEmpty) {
      deviceIdPool.add(deviceId);
    } else if (!deviceIdPool.contains(deviceId)) {
      deviceIdPool.add(deviceId);
    }

    generatingData = true;
    final totalCount = numPlacesPerGroup * numPlaceGroups;
    int doneCount = 0;
    try {
      progressNotifier.status = 'Generating...';
      final db = await _db.database;
      final batch = db.batch();

      // create top level objects
      List<Aktivitaet> aktivitaetPool = List.generate(
        numAktivitaeten,
        (_) => _createAktivitaet(),
      );
      for (var a in aktivitaetPool) {
        progressNotifier.addAktivitaet();
        insertAktivitaet(batch, a);
      }

      for (int i = 0; i < numTelegramConnections; i++) {
        progressNotifier.addTelegramConnection();
        insertTelegramConnection(batch, _createTelegramConnection());
      }
      for (int i = 0; i < numSyncSources; i++) {
        progressNotifier.addSyncSource();
        insertSyncSource(batch, _createSyncSource());
      }

      List<Person> personPool = List.generate(
        numPersons,
        (_) => _createPerson(),
      );
      for (var p in personPool) {
        progressNotifier.addPerson();
        insertPerson(batch, p);
      }

      List<Activity> activityPool = List.generate(
        numActivities,
        (_) => _createActivity(),
      );
      for (var act in activityPool) {
        progressNotifier.addActivity();
        insertActivity(batch, act);
      }

      List<PlaceGroup> placeGroupPool = [];
      placeGroupPool.addAll(
        List.generate(numPlaceGroups, (_) => _createPlaceGroup()),
      );
      for (var group in placeGroupPool) {
        progressNotifier.addPlaceGroup();
        insertPlaceGroup(batch, group);
      }

      // generate relational data for each place group
      for (PlaceGroup group in placeGroupPool) {
        for (int i = 0; i < numPlacesPerGroup; i++) {
          SavedPlace place = _createPlace(group.uuid);
          progressNotifier.setProgress(totalCount, ++doneCount);
          progressNotifier.addPlace();
          insertPlace(batch, place);

          // Place Experiences (Batch korrigiert)
          final expCount = _random.nextInt(maxExperiencesPerPlace);
          for (int j = 0; j < expCount; j++) {
            progressNotifier.addPlaceExperience();
            insertPlaceExperience(batch, randomPlaceExperience(place.uuid));
          }

          // Stays für diesen Ort
          final stayCount = _random.nextInt(maxStaysPerPlace);
          for (int j = 0; j < stayCount; j++) {
            Stay stay = _createStay(place.uuid);
            progressNotifier.addStay();
            insertStay(batch, stay);

            // Stay Persons
            for (int k = 0; k < numStayPersons; k++) {
              if (personPool.isNotEmpty) {
                progressNotifier.addStayPerson();
                insertStayPerson(
                  batch,
                  _createStayPerson(
                    stay.uuid,
                    personPool[_random.nextInt(personPool.length)].uuid,
                  ),
                );
              }
            }

            // Stay Activities
            for (int k = 0; k < numStayActivities; k++) {
              if (activityPool.isNotEmpty) {
                progressNotifier.addStayActivity();
                insertStayActivity(
                  batch,
                  _createStayActivity(
                    stay.uuid,
                    activityPool[_random.nextInt(activityPool.length)].uuid,
                  ),
                );
              }
            }

            // Stay Experiences
            final stayExpCount = _random.nextInt(maxExperiencesPerStay);
            for (int k = 0; k < stayExpCount; k++) {
              progressNotifier.addStayExperience();
              insertPlaceExperience(
                batch,
                randomPlaceExperience(place.uuid, stayUuid: stay.uuid),
              );
            }

            // Stay Photos (Hier brauchen wir ein 'await', da Bilder generiert werden)
            final stayPhotoCount = _random.nextInt(maxPhotosPerStay);
            for (int k = 0; k < stayPhotoCount; k++) {
              progressNotifier.addStayPhoto();
              PlacePhoto photo = await _createPhoto(
                place.uuid,
                stayUuid: stay.uuid,
              );
              insertPhoto(batch, photo);
            }
          }

          // Place Photos
          final photoCount = _random.nextInt(maxPhotosPerPlace);
          for (int j = 0; j < photoCount; j++) {
            progressNotifier.addPlacePhoto();
            PlacePhoto photo = await _createPhoto(place.uuid);
            insertPhoto(batch, photo);
          }
        }
      }
      progressNotifier.status = 'Finalizing...';
      // Alles gesammelt abschicken
      await batch.commit(noResult: true);
      debugPrint('Random data generation completed successfully.');
    } catch (e) {
      debugPrint('Error during data generation: $e');
    } finally {
      generatingData = false;
    }
    progressNotifier.status = 'Ready';
  }
}
