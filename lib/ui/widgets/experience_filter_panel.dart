import 'package:flutter/material.dart';

/// Immutable filter state for experience-based place filtering.
class ExperienceFilterState {
  /// Whether the filter requires places to have at least one experience.
  final bool requireExperiences;

  /// Minimum average rating across all 6 dimensions (−9.0 to 9.0).
  final double minAvgRating;

  /// Whether the distance filter is enabled.
  final bool distanceEnabled;

  /// Maximum distance in kilometres (10 km – 1000+ km).
  final double maxDistanceKm;

  const ExperienceFilterState({
    this.requireExperiences = false,
    this.minAvgRating = 0.0,
    this.distanceEnabled = false,
    this.maxDistanceKm = 100.0,
  });

  bool get isActive => requireExperiences || minAvgRating > -9.0;

  ExperienceFilterState copyWith({
    bool? requireExperiences,
    double? minAvgRating,
    bool? distanceEnabled,
    double? maxDistanceKm,
  }) => ExperienceFilterState(
    requireExperiences: requireExperiences ?? this.requireExperiences,
    minAvgRating: minAvgRating ?? this.minAvgRating,
    distanceEnabled: distanceEnabled ?? this.distanceEnabled,
    maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
  );
}

/// Collapsible filter panel shown above the places list / map.
class ExperienceFilterPanel extends StatelessWidget {
  final ExperienceFilterState filter;
  final ValueChanged<ExperienceFilterState> onChanged;

  const ExperienceFilterPanel({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  String _fmtDist(double km) {
    if (km >= 1000) return '>1000 km';
    if (km < 10) return '<10 km';
    return '${km.round()} km';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      child: Container(
        color: colorScheme.surfaceContainerHighest,
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
                const Text(
                  'Entfernung',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (filter.distanceEnabled)
                  Text(
                    'max. ${_fmtDist(filter.maxDistanceKm)}',
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
                onChanged: (v) => onChanged(filter.copyWith(maxDistanceKm: v)),
              ),
            ],
            const Divider(height: 8),
            // ── Experience filter ─────────────────────────────────────────
            Row(
              children: [
                const Text(
                  'Erfahrungs-Filter',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => onChanged(
                    filter.copyWith(
                      minAvgRating: -9.0,
                      requireExperiences: false,
                    ),
                  ),
                  child: const Text('Zurücksetzen'),
                ),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: filter.requireExperiences,
                  onChanged: (v) => onChanged(
                    filter.copyWith(requireExperiences: v ?? false),
                  ),
                ),
                const Text('Nur Orte mit Erfahrungsberichten'),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 8),
                const Text('Min. ⌀ Bewertung:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: filter.minAvgRating.clamp(-9.0, 9.0),
                    min: -9,
                    max: 9,
                    divisions: 18,
                    label: filter.minAvgRating.toStringAsFixed(0),
                    onChanged: (v) =>
                        onChanged(filter.copyWith(minAvgRating: v)),
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
        ),
      ),
    );
  }
}
