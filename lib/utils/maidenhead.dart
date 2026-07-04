import 'package:uuid/uuid.dart';

/// Extended Maidenhead Locator (QTH) encoding/decoding.
///
/// The locator alternates pairs: field (letters), square (digits), subsquare
/// (letters), and so on. This app uses:
///   * 10 chars (6+4 = 5 pairs) as the stable, sync-shared cell identity.
///     One 10-char cell is roughly ~25 m x ~19 m — matching what a smoothed GPS
///     fix can realistically hold, and easily inside WLAN range.
///   * 12 chars (6+4+2 = 6 pairs) as an optional finer, device-local
///     refinement (stored in the non-synced fine-adjust table).
///
/// All output is upper-cased so it can be used verbatim as a deterministic key.
class Maidenhead {
  Maidenhead._();

  static const _uuid = Uuid();

  /// Fixed namespace for deriving deterministic place UUIDs from a locator.
  static const String placeNamespace = '00000000-0000-0000-0000-000000000000';

  /// Number of character pairs used for the shared cell identity (10 chars).
  static const int idPairs = 5;

  /// Number of character pairs for the full, refined locator (12 chars).
  static const int fullPairs = 6;

  /// Encodes ([lat], [lng]) into an extended Maidenhead locator with [pairs]
  /// character pairs (2 chars each). Result is upper-cased.
  static String encode(double lat, double lng, {int pairs = idPairs}) {
    assert(pairs >= 1);
    var lon = (lng + 180.0).clamp(0.0, 359.999999);
    var la = (lat + 90.0).clamp(0.0, 179.999999);
    final sb = StringBuffer();
    var lonSize = 360.0;
    var latSize = 180.0;

    for (var p = 0; p < pairs; p++) {
      if (p == 0) {
        lonSize = 20.0;
        latSize = 10.0;
        final x = (lon / lonSize).floor();
        final y = (la / latSize).floor();
        sb.writeCharCode(65 + x);
        sb.writeCharCode(65 + y);
        lon -= x * lonSize;
        la -= y * latSize;
      } else if (p.isOdd) {
        lonSize /= 10.0;
        latSize /= 10.0;
        final x = (lon / lonSize).floor();
        final y = (la / latSize).floor();
        sb.write(x);
        sb.write(y);
        lon -= x * lonSize;
        la -= y * latSize;
      } else {
        lonSize /= 24.0;
        latSize /= 24.0;
        final x = (lon / lonSize).floor();
        final y = (la / latSize).floor();
        sb.writeCharCode(65 + x);
        sb.writeCharCode(65 + y);
        lon -= x * lonSize;
        la -= y * latSize;
      }
    }
    return sb.toString();
  }

  /// The 10-char (6+4) shared cell identity for ([lat], [lng]).
  static String encodeId(double lat, double lng) =>
      encode(lat, lng, pairs: idPairs);

  /// The 12-char (6+4+2) refined locator for ([lat], [lng]).
  static String encodeFull(double lat, double lng) =>
      encode(lat, lng, pairs: fullPairs);

  /// Decodes a locator to the center coordinate of its cell.
  static ({double lat, double lng}) decodeCenter(String locator) {
    final loc = locator.replaceAll('_', '').toUpperCase();
    if (loc.length < 2) return (lat: 0.0, lng: 0.0);
    var lon = (loc.codeUnitAt(0) - 65) * 20.0;
    var la = (loc.codeUnitAt(1) - 65) * 10.0;
    var lonSize = 20.0;
    var latSize = 10.0;

    var pairIndex = 1;
    var ci = 2;
    while (ci + 1 < loc.length) {
      if (pairIndex.isOdd) {
        lonSize /= 10.0;
        latSize /= 10.0;
        lon += (loc.codeUnitAt(ci) - 48) * lonSize;
        la += (loc.codeUnitAt(ci + 1) - 48) * latSize;
      } else {
        lonSize /= 24.0;
        latSize /= 24.0;
        lon += (loc.codeUnitAt(ci) - 65) * lonSize;
        la += (loc.codeUnitAt(ci + 1) - 65) * latSize;
      }
      ci += 2;
      pairIndex++;
    }
    lon += lonSize / 2.0;
    la += latSize / 2.0;
    return (lat: la - 90.0, lng: lon - 180.0);
  }

  /// Groups a raw locator for display: first 6 chars, then '_' every 4 chars.
  /// e.g. "AB12CD34EF56" -> "AB12CD_34EF_56".
  static String format(String locator) {
    final loc = locator.replaceAll('_', '');
    if (loc.length <= 6) return loc;
    final head = loc.substring(0, 6);
    final rest = loc.substring(6);
    final chunks = <String>[];
    for (var i = 0; i < rest.length; i += 4) {
      final end = (i + 4) < rest.length ? i + 4 : rest.length;
      chunks.add(rest.substring(i, end));
    }
    return '${head}_${chunks.join('_')}';
  }

  /// Deterministic place UUID (UUID v5) derived from the 10-char cell identity
  /// of ([lat], [lng]). Every device in the same cell derives the same UUID, so
  /// the UUID-merge sync collapses them into a single shared place.
  static String deterministicPlaceUuid(double lat, double lng) =>
      _uuid.v5(placeNamespace, 'geo:${encodeId(lat, lng)}');
}
