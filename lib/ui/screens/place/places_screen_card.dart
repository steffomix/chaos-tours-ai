import 'package:chaos_tours_ai/models/stay.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/place_experience.dart';
import '../../../models/saved_place.dart';
import '../../../services/database_service.dart';
import '../../../utils/geo_utils.dart';
import '../../../utils/unified_widget.dart';
import 'places_filter_panel.dart';

class PlacesScreenCard extends StatefulWidget {
  final SavedPlace place;
  final int count;
  final Stay? lastStay;
  final double? distance;
  final double? avgRating;
  final PlacesFilterState filter;
  final String Function(int ms) fmtDate;
  final String Function(DateTime dt) fmtTime;
  final String Function(Duration d) fmtDuration;
  final String Function(double m) fmtDistance;
  final VoidCallback onTap;

  /// When set (compass mode), the card shows a bearing + distance row from this
  /// origin to the place.
  final ({double lat, double lng})? compassOrigin;

  /// Highlights the card as the compass navigation target.
  final bool isCompassTarget;

  const PlacesScreenCard({
    super.key,
    required this.place,
    required this.count,
    required this.lastStay,
    required this.fmtDate,
    required this.fmtTime,
    required this.fmtDuration,
    required this.fmtDistance,
    required this.onTap,
    required this.filter,
    this.distance,
    this.avgRating,
    this.compassOrigin,
    this.isCompassTarget = false,
  });

  @override
  State<PlacesScreenCard> createState() => _PlacesScreenCardState();
}

class _PlacesScreenCardState extends State<PlacesScreenCard> {
  List<PlaceExperience>? _experiences;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.filter.specificFilterActive) {
      _loadExperiences();
    }
  }

  @override
  void didUpdateWidget(PlacesScreenCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter.specificFilterActive &&
        _experiences == null &&
        !_loading) {
      _loadExperiences();
    }
  }

  Future<void> _loadExperiences() async {
    if (_loading || widget.place.uuid.isEmpty) return;
    setState(() => _loading = true);
    try {
      final exps = await DatabaseService.instance.loadExperiencesForPlace(
        widget.place.uuid,
      );
      if (mounted) {
        setState(() {
          _experiences = exps;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _avg(int Function(PlaceExperience e) getter) {
    final exps = _experiences;
    if (exps == null || exps.isEmpty) return null;
    return exps.map(getter).reduce((a, b) => a + b) / exps.length;
  }

  double? _median(int Function(PlaceExperience e) getter) {
    final exps = _experiences;
    if (exps == null || exps.isEmpty) return null;
    final sorted = exps.map(getter).toList()..sort();
    final n = sorted.length;
    if (n % 2 == 1) return sorted[n ~/ 2].toDouble();
    return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
  }

  String _fmtVal(double? v) => v == null ? '–' : v.toStringAsFixed(1);

  Widget _buildRatingsTable(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(l10n.loadingRatings, style: textTheme.bodySmall),
          ],
        ),
      );
    }

    // Header row.
    Widget headerRow = Row(
      children: [
        Expanded(flex: 5, child: Text('', style: textTheme.bodySmall)),
        SizedBox(
          width: 42,
          child: Text(
            'Ø',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            l10n.ratingMetricMedian,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );

    Widget tableRow(
      String label,
      double? avg,
      double? median, {
      bool bold = false,
    }) {
      final style = textTheme.bodySmall?.copyWith(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      );
      return Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(label, style: style, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 42,
            child: Text(
              _fmtVal(avg),
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              _fmtVal(median),
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
        ],
      );
    }

    final fields = PlacesFilterSpecificRatingField.values;
    final selectedField = widget.filter.specificRatingField;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerRow,
        const Divider(height: 4, thickness: 0.5),
        // Overall rating (from saved_places cache) – bold.
        tableRow(
          l10n.ratingTableOverall,
          widget.place.experienceRatingAverage,
          widget.place.experienceRatingMedian,
          bold: true,
        ),
        const Divider(height: 4, thickness: 0.5),
        // Per-dimension rows (lazy-loaded).
        for (final f in fields)
          tableRow(
            f.label(l10n),
            _avg(f.extractFrom),
            _median(f.extractFrom),
            bold: selectedField == f,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final specificActive = widget.filter.specificFilterActive;
    final selectedField = widget.filter.specificRatingField;

    // In specific mode, show the selected dimension's avg as the headline rating.
    double? headlineRating;
    if (specificActive && selectedField != null && _experiences != null) {
      headlineRating = _avg(selectedField.extractFrom);
    } else if (!specificActive) {
      headlineRating = widget.avgRating;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: widget.isCompassTarget
          ? RoundedRectangleBorder(
              side: BorderSide(color: colorScheme.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,

      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.place.placeType.icon,
                  color: widget.place.placeType.dotColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.edit, size: 16),
                  onPressed: widget.onTap,
                  label: Text(
                    widget.place.name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(child: Container()),
                if (widget.distance != null)
                  Text(
                    widget.fmtDistance(widget.distance!),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (headlineRating != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star, size: 14, color: Colors.amber),
                  Text(
                    headlineRating.toStringAsFixed(1),
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            // ── Kompass-Zeile (Peilung + Distanz) ────────────────────
            if (widget.compassOrigin != null) ...[
              const SizedBox(height: 6),
              Builder(
                builder: (_) {
                  final o = widget.compassOrigin!;
                  final bearing = GeoUtils.bearingDegrees(
                    o.lat,
                    o.lng,
                    widget.place.lat,
                    widget.place.lng,
                  );
                  final dist = GeoUtils.distanceMeters(
                    o.lat,
                    o.lng,
                    widget.place.lat,
                    widget.place.lng,
                  );
                  return Row(
                    children: [
                      Icon(Icons.explore, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        GeoUtils.formatBearingDegMin(bearing),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        Icons.straighten,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        GeoUtils.formatDistanceKm(dist),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            // ── Ratings table (specific filter mode) ─────────────────
            if (specificActive) ...[
              const SizedBox(height: 8),
              _buildRatingsTable(context),
              const SizedBox(height: 8),
            ],
            // ── Visit info ────────────────────────────────────────────
            const SizedBox(height: 4),
            Text(
              widget.count == 0
                  ? l10n.notVisitedYet
                  : (widget.count == 1
                        ? l10n.visitCount(widget.count)
                        : l10n.visitCountPlural(widget.count)),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.lastStay != null) ...[
              const SizedBox(height: 2),
              Text(
                '${l10n.lastVisit(widget.fmtDate(widget.lastStay!.startTime), widget.fmtTime(widget.lastStay!.startDateTime))}'
                '${widget.lastStay!.endDateTime != null ? ' – ${widget.fmtTime(widget.lastStay!.endDateTime!)}' : ''}'
                '${widget.lastStay!.endDateTime != null ? '  (${widget.fmtDuration(widget.lastStay!.duration)})' : ''}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (widget.place.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              UnifiedWidget(context).markdownText(widget.place.notes),

              // Text(
              //   widget.place.notes,
              //   maxLines: 20,
              //   overflow: TextOverflow.ellipsis,
              //   style: textTheme.bodySmall,
              // ),
            ],
          ],
        ),
      ),
    );
  }
}
