import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

/// Represents a known device found anywhere in the database.
/// All device IDs collected from any table are represented here; the user can
/// mark them as trusted and add extra metadata (note, URL, address, GPS).
class TrustedSource {
  final String uuid;

  /// The device ID being catalogued (e.g. "Alice@abc-def-…").
  /// Maps to the `trusted_device_id` column for backwards-compatibility.
  final String deviceId;

  /// Whether this device is trusted (i.e. its data is accepted during sync).
  final bool trusted;

  final String note;
  final String url;
  final String email;
  final String address;

  /// Optional GPS latitude.
  final double? lat;

  /// Optional GPS longitude.
  final double? lng;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;

  /// ID of the device that created / owns this record.
  final String ownerId;

  TrustedSource({
    String? uuid,
    required this.deviceId,
    this.trusted = false,
    this.note = '',
    this.url = '',
    this.email = '',
    this.address = '',
    this.lat,
    this.lng,
    int? updatedAt,
    this.deletedAt,
    String? ownerId,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       ownerId = ownerId?.isNotEmpty == true
           ? ownerId!
           : SettingsService.instance.deviceId;

  factory TrustedSource.fromMap(Map<String, dynamic> map) => TrustedSource(
    uuid: map['uuid'] as String,
    deviceId: map['trusted_device_id'] as String,
    trusted: (map['trusted'] as int? ?? 0) != 0,
    note: (map['note'] as String?) ?? '',
    url: (map['url'] as String?) ?? '',
    email: (map['email'] as String?) ?? '',
    address: (map['address'] as String?) ?? '',
    lat: (map['lat'] as num?)?.toDouble(),
    lng: (map['lng'] as num?)?.toDouble(),
    updatedAt:
        (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
    deletedAt: map['deleted_at'] as int?,
    ownerId: (map['device_id'] as String?) ?? SettingsService.instance.deviceId,
  );

  Map<String, dynamic> toMap() => {
    'uuid': uuid,
    'trusted_device_id': deviceId,
    'trusted': trusted ? 1 : 0,
    'note': note,
    'url': url,
    'email': email,
    'address': address,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    'updated_at': updatedAt,
    if (deletedAt != null) 'deleted_at': deletedAt,
    'device_id': ownerId,
  };

  TrustedSource copyWith({
    String? deviceId,
    bool? trusted,
    String? note,
    String? url,
    String? email,
    String? address,
    double? lat,
    double? lng,
    bool clearLat = false,
    bool clearLng = false,
  }) => TrustedSource(
    uuid: uuid,
    deviceId: deviceId ?? this.deviceId,
    trusted: trusted ?? this.trusted,
    note: note ?? this.note,
    url: url ?? this.url,
    email: email ?? this.email,
    address: address ?? this.address,
    lat: clearLat ? null : (lat ?? this.lat),
    lng: clearLng ? null : (lng ?? this.lng),
    ownerId: ownerId,
  );
}
