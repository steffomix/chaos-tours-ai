import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

/// A Matrix room connection used to send place reports.
class MatrixConnection {
  final String uuid;

  /// Display name for this connection.
  final String name;

  /// Optional description / notes.
  final String description;

  /// Homeserver URL, e.g. "https://matrix.org"
  final String homeserver;

  /// Room ID, e.g. "!roomid:homeserver"
  final String roomId;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  MatrixConnection({
    String? uuid,
    required this.name,
    this.description = '',
    required this.homeserver,
    required this.roomId,
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  factory MatrixConnection.fromMap(Map<String, dynamic> map) {
    return MatrixConnection(
      uuid: map['uuid'] as String?,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      homeserver: (map['homeserver'] as String?) ?? '',
      roomId: (map['room_id'] as String?) ?? '',
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
      deviceId:
          (map['device_id'] as String?) ?? SettingsService.instance.deviceId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'name': name,
      'description': description,
      'homeserver': homeserver,
      'room_id': roomId,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  MatrixConnection copyWith({
    String? uuid,
    String? name,
    String? description,
    String? homeserver,
    String? roomId,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return MatrixConnection(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      description: description ?? this.description,
      homeserver: homeserver ?? this.homeserver,
      roomId: roomId ?? this.roomId,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  String toString() => 'MatrixConnection($uuid, $name, $homeserver, $roomId)';
}
