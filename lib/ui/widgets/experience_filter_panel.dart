import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/place_experience.dart';
import '../../models/place_group.dart';
import '../../models/saved_place.dart';
import '../../services/database_service.dart';

/// The 7 specific rating dimensions of a [PlaceExperience].
enum SpecificRatingField {
  dangerousFriendly,
  fraudReliable,
  dismissiveAccommodation,
  food,
  equipment,
  transport,
  medicine;

  String get dbColumn => switch (this) {
    dangerousFriendly => 'rating_dangerous_friendly',
    fraudReliable => 'rating_fraud_reliable',
    dismissiveAccommodation => 'rating_dismissive_accommodation',
    food => 'rating_food',
    equipment => 'rating_equipment',
    transport => 'rating_transport',
    medicine => 'rating_medicine',
  };

  static SpecificRatingField? fromDbColumn(String column) {
    for (final f in SpecificRatingField.values) {
      if (f.dbColumn == column) return f;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
    dangerousFriendly => l10n.ratingDangerFriendly,
    fraudReliable => l10n.ratingFraudReliable,
    dismissiveAccommodation => l10n.ratingDismissiveAccommodation,
    food => l10n.ratingFood,
    equipment => l10n.ratingEquipment,
    transport => l10n.ratingTransport,
    medicine => l10n.ratingMedicine,
  };

  int extractFrom(PlaceExperience e) => switch (this) {
    dangerousFriendly => e.ratingDangerousFriendly,
    fraudReliable => e.ratingFraudReliable,
    dismissiveAccommodation => e.ratingDismissiveAccommodation,
    food => e.ratingFood,
    equipment => e.ratingEquipment,
    transport => e.ratingTransport,
    medicine => e.ratingMedicine,
  };
}

/// Immutable filter state for experience-based place filtering.
class ExperienceFilterState {
  /// Whether to show only places that have experiences from the current device.
  final bool ownDeviceOnly;

  /// Minimum average rating across all 6 dimensions (−9.0 to 9.0).
  final double minAvgRating;

  /// Whether to use the median rating instead of the average for filtering.
  final bool useMedian;

  /// Whether the distance filter is enabled.
  final bool distanceEnabled;

  /// Maximum distance in kilometres (10 km – 1000+ km).
  final double maxDistanceKm;

  /// Whether the specific rating filter sub-mode is active.
  final bool useSpecificRating;

  /// The specific rating field to filter and sort by (only used when
  /// [useSpecificRating] is true).
  final SpecificRatingField? specificRatingField;

  /// Whether the experience sub-filter panel is open. When true, only places
  /// with at least one experience entry are shown.
  final bool subPanelOpen;

  /// Group UUIDs to filter by (empty = all groups / fall back to scheduler).
  final List<String> groupFilter;

  /// [PlaceType.index] values to filter by (empty = all types).
  final List<int> placeTypeFilter;

  const ExperienceFilterState({
    this.subPanelOpen = false,
    this.ownDeviceOnly = false,
    this.minAvgRating = 0.0,
    this.useMedian = false,
    this.distanceEnabled = false,
    this.maxDistanceKm = 100.0,
    this.useSpecificRating = false,
    this.specificRatingField,
    this.groupFilter = const [],
    this.placeTypeFilter = const [],
  });

  /// True when experience-based filtering requires experiences to be present.
  /// This is always the case when [specificFilterActive] is true or the
  /// experience sub-panel is open.
  bool get requireExperiences =>
      subPanelOpen || ownDeviceOnly || specificFilterActive;

  bool get isActive => ownDeviceOnly || minAvgRating != 0.0 || distanceEnabled;

  /// Whether the specific filter is fully configured and active.
  bool get specificFilterActive =>
      useSpecificRating && specificRatingField != null;

  ExperienceFilterState copyWith({
    bool? subPanelOpen,
    bool? ownDeviceOnly,
    double? minAvgRating,
    bool? useMedian,
    bool? distanceEnabled,
    double? maxDistanceKm,
    bool? useSpecificRating,
    SpecificRatingField? specificRatingField,
    bool clearSpecificRatingField = false,
    List<String>? groupFilter,
    List<int>? placeTypeFilter,
  }) => ExperienceFilterState(
    subPanelOpen: subPanelOpen ?? this.subPanelOpen,
    ownDeviceOnly: ownDeviceOnly ?? this.ownDeviceOnly,
    minAvgRating: minAvgRating ?? this.minAvgRating,
    useMedian: useMedian ?? this.useMedian,
    distanceEnabled: distanceEnabled ?? this.distanceEnabled,
    maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
    useSpecificRating: useSpecificRating ?? this.useSpecificRating,
    specificRatingField: clearSpecificRatingField
        ? null
        : specificRatingField ?? this.specificRatingField,
    groupFilter: groupFilter ?? this.groupFilter,
    placeTypeFilter: placeTypeFilter ?? this.placeTypeFilter,
  );
}

/// Collapsible filter panel shown above the places list / map.
class ExperienceFilterPanel extends StatefulWidget {
  final ExperienceFilterState filter;
  final ValueChanged<ExperienceFilterState> onChanged;

  const ExperienceFilterPanel({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  @override
  State<ExperienceFilterPanel> createState() => _ExperienceFilterPanelState();
}

class _ExperienceFilterPanelState extends State<ExperienceFilterPanel> {
  bool _subPanelOpen = false;
  List<PlaceGroup> _allGroups = [];

  ExperienceFilterState get filter => widget.filter;
  ValueChanged<ExperienceFilterState> get onChanged => widget.onChanged;

  @override
  void initState() {
    super.initState();
    _subPanelOpen = widget.filter.subPanelOpen;
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseService.instance.loadAllPlaceGroups();
    if (mounted)
      setState(
        () => _allGroups = groups.where((g) => g.deletedAt == null).toList(),
      );
  }

  String _fmtDist(double km) {
    if (km >= 1000) return '>1000 km';
    if (km < 10) return '<10 km';
    return '${km.round()} km';
  }

  Widget _ratingSliderRow(BuildContext context, ExperienceFilterState filter) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 8),
            filter.useSpecificRating
                ? Text(l10n.minSpecialRating)
                : filter.useMedian
                ? Text(l10n.minMedianRating)
                : Text(l10n.minAvgRating),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: filter.minAvgRating.clamp(-9.0, 9.0),
                min: -9,
                max: 9,
                divisions: 18,
                label: filter.minAvgRating.toStringAsFixed(0),
                onChanged: (v) => onChanged(filter.copyWith(minAvgRating: v)),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                filter.minAvgRating.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _avgMedianRadio(BuildContext context, ExperienceFilterState filter) {
    final l10n = AppLocalizations.of(context)!;
    return RadioGroup<bool>(
      groupValue: filter.useMedian,
      onChanged: (v) {
        if (v != null) onChanged(filter.copyWith(useMedian: v));
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: l10n.ratingMetricAverage,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<bool>(
                  value: false,
                  groupValue: filter.useMedian,
                  onChanged: (v) {
                    if (v != null) onChanged(filter.copyWith(useMedian: v));
                  },
                ),
                const Text('∅'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: l10n.ratingMetricMedian,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: filter.useMedian,
                  onChanged: (v) {
                    if (v != null) onChanged(filter.copyWith(useMedian: v));
                  },
                ),
                const Text('x̃'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height / 2;
    return Material(
      elevation: 6,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          color: colorScheme.surfaceContainerHighest,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Distance filter ──────────────────────────────────────────
                Row(
                  children: [
                    Switch(
                      value: filter.distanceEnabled,
                      onChanged: (v) =>
                          onChanged(filter.copyWith(distanceEnabled: v)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.distance,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (filter.distanceEnabled)
                      Text(
                        l10n.maxDistance(_fmtDist(filter.maxDistanceKm)),
                        style: TextStyle(color: colorScheme.primary),
                      ),
                  ],
                ),
                if (filter.distanceEnabled) ...[
                  Slider(
                    value: filter.maxDistanceKm.clamp(10.0, 1000.0),
                    min: 10,
                    max: 1000,
                    divisions: 99,
                    label: _fmtDist(filter.maxDistanceKm),
                    onChanged: (v) =>
                        onChanged(filter.copyWith(maxDistanceKm: v)),
                  ),
                ],
                // ── Group filter ─────────────────────────────────────────────
                if (_allGroups.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Text(
                      l10n.filterByGroup,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: _allGroups.map((g) {
                      final selected = filter.groupFilter.contains(g.uuid);
                      return FilterChip(
                        label: Text(g.name),
                        selected: selected,
                        onSelected: (v) {
                          final updated = v
                              ? [...filter.groupFilter, g.uuid]
                              : filter.groupFilter
                                    .where((id) => id != g.uuid)
                                    .toList();
                          onChanged(filter.copyWith(groupFilter: updated));
                        },
                      );
                    }).toList(),
                  ),
                ],
                // ── Place type filter ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    l10n.filterByPlaceType,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: PlaceType.values.map((t) {
                    final selected = filter.placeTypeFilter.contains(t.index);
                    return FilterChip(
                      avatar: Icon(t.icon, color: t.dotColor, size: 16),
                      label: Text(t.label),
                      selected: selected,
                      onSelected: (v) {
                        final updated = v
                            ? [...filter.placeTypeFilter, t.index]
                            : filter.placeTypeFilter
                                  .where((i) => i != t.index)
                                  .toList();
                        onChanged(filter.copyWith(placeTypeFilter: updated));
                      },
                    );
                  }).toList(),
                ),
                // ── Experience filter ─────────────────────────────────────────
                Row(
                  children: [
                    Switch(
                      value: _subPanelOpen,
                      onChanged: (v) {
                        setState(() => _subPanelOpen = v);
                        onChanged(filter.copyWith(subPanelOpen: v));
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.activateExperienceFilter,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                // Sub-filter options are only shown when sub-panel is open.
                if (_subPanelOpen) ...[
                  // ── Own device only toggle ────────────────────────────────
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Switch(
                        value: filter.ownDeviceOnly,
                        onChanged: (v) =>
                            onChanged(filter.copyWith(ownDeviceOnly: v)),
                      ),
                      const SizedBox(width: 4),
                      Text(l10n.deviceIdExperienceFilter),
                    ],
                  ),
                  // ── Specific sub-filter toggle ─────────────────────────────
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Switch(
                        value: filter.useSpecificRating,
                        onChanged: (v) {
                          if (v) {
                            // Ensure a default field is selected when toggling on.
                            final field =
                                filter.specificRatingField ??
                                SpecificRatingField.values.first;
                            onChanged(
                              filter.copyWith(
                                useSpecificRating: true,
                                specificRatingField: field,
                              ),
                            );
                          } else {
                            onChanged(
                              filter.copyWith(useSpecificRating: false),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.filterModeSpecific,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  // ── General filter content ────────────────────────────────
                  if (!filter.useSpecificRating) ...[
                    _avgMedianRadio(context, filter),
                  ],
                  // ── Specific filter content ───────────────────────────────
                  if (filter.useSpecificRating) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        bottom: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButton<SpecificRatingField>(
                              value:
                                  filter.specificRatingField ??
                                  SpecificRatingField.values.first,
                              isExpanded: true,
                              onChanged: (v) {
                                if (v != null) {
                                  onChanged(
                                    filter.copyWith(specificRatingField: v),
                                  );
                                }
                              },
                              items: SpecificRatingField.values
                                  .map(
                                    (f) => DropdownMenuItem(
                                      value: f,
                                      child: Text(
                                        f.label(l10n),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Rating slider shown when experiences are required.
                  if (filter.requireExperiences)
                    _ratingSliderRow(context, filter),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: () {
                          setState(() => _subPanelOpen = false);
                          onChanged(
                            filter.copyWith(
                              subPanelOpen: false,
                              minAvgRating: 0.0,
                              ownDeviceOnly: false,
                              useSpecificRating: false,
                              clearSpecificRatingField: true,
                            ),
                          );
                        },
                        child: Text(l10n.resetFilter),
                      ),
                    ],
                  ),
                ],
                // ── Global reset ─────────────────────────────────────────────
                if (filter.groupFilter.isNotEmpty ||
                    filter.placeTypeFilter.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: Text(l10n.resetFilter2),
                          onPressed: () {
                            setState(() => _subPanelOpen = false);
                            onChanged(
                              filter.copyWith(
                                subPanelOpen: false,
                                minAvgRating: 0.0,
                                ownDeviceOnly: false,
                                useSpecificRating: false,
                                clearSpecificRatingField: true,
                                groupFilter: [],
                                placeTypeFilter: [],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
