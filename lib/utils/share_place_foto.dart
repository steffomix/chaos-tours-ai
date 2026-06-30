import 'dart:io';
import 'dart:math';

import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/place_photo.dart';
import '../services/database_service.dart';

Future<void> sharePhoto(PlacePhoto photo) async {
  final bytes = photo.photoData;
  if (bytes.isEmpty) return;

  // 1. SavedPlace Infos aus der DB holen
  final place = await DatabaseService.instance.getSavedPlace(photo.placeUuid);
  final placeName = place?.name ?? 'Unknown Place';

  // 2. Dateinamen bereinigen (Sonderzeichen entfernen, die im OS-Dateisystem verboten sind)
  // Tipp: RegExp ist oft sicherer als Uri.encodeComponent für Dateinamen
  final safePlaceName = placeName
      .replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '_',
      ) // Illegale Windows/Android Zeichen
      .replaceAll(' ', '_'); // Leerzeichen ersetzen

  // Namen auf maximal 50 Zeichen kürzen
  final maxLength = 50;
  final truncatedPlaceName = safePlaceName.length > maxLength
      ? safePlaceName.substring(0, maxLength)
      : safePlaceName;

  // 3. Mime-Type und Dateiendung bestimmen
  // Sicherstellen, dass getRange nicht crasht, falls das Bild winzig ist
  final headerLength = min(300, bytes.length);
  final mime = lookupMimeType(
    'file.jpg',
    headerBytes: bytes.sublist(
      0,
      headerLength,
    ), // sublist ist sicherer als getRange().toList()
  );
  final extension = mime != null ? extensionFromMime(mime) : 'jpg';

  // 4. Datum für den Dateinamen formatieren
  final dateTime = DateTime.fromMillisecondsSinceEpoch(photo.takenAt);
  final date = dateTime.toIso8601String().split('T').first;

  // 5. Temporäre Datei erstellen und beschreiben
  final tmp = await getTemporaryDirectory();
  final file = File(
    '${tmp.path}/chaos_tours_${date}_$truncatedPlaceName.$extension',
  );
  await file.writeAsBytes(bytes);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mime)],
      text: photo.caption.isNotEmpty ? photo.caption : null,
      title: placeName,
      subject: placeName,
    ),
  );
}
