import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

/// A user experience / review entry linked to a [SavedPlace] by its UUID.
/// Contains textual report and seven rating dimensions (-9 to +9).
class PlaceExperience {
  final String uuid;

  /// UUID of the parent saved_place.
  final String savedPlaceUuid;

  /// Freetext experience report.
  final String text;

  /// Gefährlich (−9) bis Freundlich (+9).
  final int ratingDangerousFriendly;

  /// Betrügerisch (−9) bis Zuverlässig (+9).
  final int ratingFraudReliable;

  /// Abweisend (−9) bis Bietet Unterkunft (+9).
  final int ratingDismissiveAccommodation;

  /// Fordert (−9) über Teilt (0) bis Bietet Verpflegung (+9).
  final int ratingFood;

  /// Fordert (−9) über Teilt (0) bis Bietet Equipment (+9).
  final int ratingEquipment;

  /// Fordert (−9) über Teilt (0) bis Bietet Transportmöglichkeiten (+9).
  final int ratingTransport;

  /// Fordert (−9) über Teilt (0) bis Bietet Medizin/Erstversorgung (+9).
  final int ratingMedicine;

  /// When this entry was created (ms since epoch).
  final int createdAt;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  PlaceExperience({
    String? uuid,
    required this.savedPlaceUuid,
    this.text = '',
    this.ratingDangerousFriendly = 0,
    this.ratingFraudReliable = 0,
    this.ratingDismissiveAccommodation = 0,
    this.ratingFood = 0,
    this.ratingEquipment = 0,
    this.ratingTransport = 0,
    this.ratingMedicine = 0,
    int? createdAt,
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  /// Average rating across all seven dimensions (−9.0 to +9.0).
  double get averageRating =>
      (ratingDangerousFriendly +
          ratingFraudReliable +
          ratingDismissiveAccommodation +
          ratingFood +
          ratingEquipment +
          ratingTransport +
          ratingMedicine) /
      7.0;

  factory PlaceExperience.fromMap(Map<String, dynamic> map) {
    return PlaceExperience(
      uuid: map['uuid'] as String?,
      savedPlaceUuid: (map['saved_place_uuid'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      ratingDangerousFriendly: (map['rating_dangerous_friendly'] as int?) ?? 0,
      ratingFraudReliable: (map['rating_fraud_reliable'] as int?) ?? 0,
      ratingDismissiveAccommodation:
          (map['rating_dismissive_accommodation'] as int?) ?? 0,
      ratingFood: (map['rating_food'] as int?) ?? 0,
      ratingEquipment: (map['rating_equipment'] as int?) ?? 0,
      ratingTransport: (map['rating_transport'] as int?) ?? 0,
      ratingMedicine: (map['rating_medicine'] as int?) ?? 0,
      createdAt:
          (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
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
      'saved_place_uuid': savedPlaceUuid,
      'text': text,
      'rating_dangerous_friendly': ratingDangerousFriendly,
      'rating_fraud_reliable': ratingFraudReliable,
      'rating_dismissive_accommodation': ratingDismissiveAccommodation,
      'rating_food': ratingFood,
      'rating_equipment': ratingEquipment,
      'rating_transport': ratingTransport,
      'rating_medicine': ratingMedicine,
      'created_at': createdAt,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  PlaceExperience copyWith({
    String? uuid,
    String? savedPlaceUuid,
    String? text,
    int? ratingDangerousFriendly,
    int? ratingFraudReliable,
    int? ratingDismissiveAccommodation,
    int? ratingFood,
    int? ratingEquipment,
    int? ratingTransport,
    int? ratingMedicine,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
    String? deviceId,
  }) {
    return PlaceExperience(
      uuid: uuid ?? this.uuid,
      savedPlaceUuid: savedPlaceUuid ?? this.savedPlaceUuid,
      text: text ?? this.text,
      ratingDangerousFriendly:
          ratingDangerousFriendly ?? this.ratingDangerousFriendly,
      ratingFraudReliable: ratingFraudReliable ?? this.ratingFraudReliable,
      ratingDismissiveAccommodation:
          ratingDismissiveAccommodation ?? this.ratingDismissiveAccommodation,
      ratingFood: ratingFood ?? this.ratingFood,
      ratingEquipment: ratingEquipment ?? this.ratingEquipment,
      ratingTransport: ratingTransport ?? this.ratingTransport,
      ratingMedicine: ratingMedicine ?? this.ratingMedicine,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
