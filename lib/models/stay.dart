import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

enum StayStatus { detecting, active, completed }

class Stay {
  final String uuid;
  final String? placeUuid;
  final int startTime;
  final int? endTime;
  final String notes;
  final String? calendarEventId;
  final String? telegramMessageId;
  final String? address;
  final StayStatus status;

  /// Whether this stay counts toward the interval scheduler.
  final bool isInterval;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  Stay({
    String? uuid,
    this.placeUuid,
    required this.startTime,
    this.endTime,
    this.notes = '',
    this.calendarEventId,
    this.telegramMessageId,
    this.address,
    this.status = StayStatus.detecting,
    this.isInterval = true,
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  bool get isActive => status != StayStatus.completed;

  DateTime get startDateTime => DateTime.fromMillisecondsSinceEpoch(startTime);
  DateTime? get endDateTime =>
      endTime != null ? DateTime.fromMillisecondsSinceEpoch(endTime!) : null;

  Duration get duration {
    final end = endDateTime ?? DateTime.now();
    return end.difference(startDateTime);
  }

  factory Stay.fromMap(Map<String, dynamic> map) {
    return Stay(
      uuid: map['uuid'] as String?,
      placeUuid: map['place_uuid'] as String?,
      startTime: map['start_time'] as int,
      endTime: map['end_time'] as int?,
      notes: (map['notes'] as String?) ?? '',
      calendarEventId: map['calendar_event_id'] as String?,
      telegramMessageId: map['telegram_message_id'] as String?,
      address: map['address'] as String?,
      status: StayStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String? ?? 'detecting'),
        orElse: () => StayStatus.detecting,
      ),
      isInterval: (map['is_interval'] as int? ?? 1) == 1,
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
      if (placeUuid != null) 'place_uuid': placeUuid,
      'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      'notes': notes,
      if (calendarEventId != null) 'calendar_event_id': calendarEventId,
      if (telegramMessageId != null) 'telegram_message_id': telegramMessageId,
      if (address != null) 'address': address,
      'status': status.name,
      'is_interval': isInterval ? 1 : 0,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  Stay copyWith({
    String? uuid,
    String? placeUuid,
    int? startTime,
    int? endTime,
    String? notes,
    String? calendarEventId,
    String? telegramMessageId,
    String? address,
    StayStatus? status,
    bool? isInterval,
    bool clearEndTime = false,
    bool clearPlaceUuid = false,
    bool clearCalendarEventId = false,
    bool clearTelegramMessageId = false,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return Stay(
      uuid: uuid ?? this.uuid,
      placeUuid: clearPlaceUuid ? null : (placeUuid ?? this.placeUuid),
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      notes: notes ?? this.notes,
      calendarEventId: clearCalendarEventId
          ? null
          : (calendarEventId ?? this.calendarEventId),
      telegramMessageId: clearTelegramMessageId
          ? null
          : (telegramMessageId ?? this.telegramMessageId),
      address: address ?? this.address,
      status: status ?? this.status,
      isInterval: isInterval ?? this.isInterval,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
