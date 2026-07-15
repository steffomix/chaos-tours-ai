import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../models/stay_activity.dart';
import '../../models/stay_person.dart';
import '../../utils/unified_widget.dart';
import 'stay_detail_sheet.dart';

class StayCard extends StatelessWidget {
  final Stay stay;
  final SavedPlace? place;
  final List<StayPerson> persons;
  final List<StayActivity> activities;
  final VoidCallback? onUpdated;

  const StayCard({
    super.key,
    required this.stay,
    this.place,
    this.persons = const [],
    this.activities = const [],
    this.onUpdated,
  });

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes % 60}min';
    }
    return '${d.inMinutes}min';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StayDetailSheet(stay: stay, onUpdated: onUpdated),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final placeName = place?.name ?? stay.address ?? l10n.unknownPlace;
    final startDt = stay.startDateTime;
    final endDt = stay.endDateTime;
    final isActive = stay.isActive;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isActive
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  isActive ? Icons.location_on : Icons.location_on_outlined,
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: () => _openSheet(context),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(
                    placeName,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.active,
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Time row
            Text(
              endDt != null
                  ? '${_formatDate(startDt)}  ${_formatTime(startDt)} – ${_formatTime(endDt)}  (${_formatDuration(stay.duration)})'
                  : '${_formatDate(startDt)}  ${_formatTime(startDt)} – ${l10n.stillRunning}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            // Address (if different from place name)
            if (stay.address != null && place == null) ...[
              const SizedBox(height: 2),
              Text(
                stay.address!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Notes preview
            if (stay.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              UnifiedWidget(context).markdownText(stay.notes),

              // Text(
              //   stay.notes,
              //   maxLines: 20,
              //   overflow: TextOverflow.ellipsis,
              //   style: Theme.of(context).textTheme.bodySmall,
              // ),
            ],
            // Persons + activities chips
            if (persons.isNotEmpty || activities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ...persons.map(
                    (p) => Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      avatar: const Icon(Icons.person, size: 14),
                      label: Text(p.name, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  ...activities.map(
                    (a) => Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      avatar: const Icon(Icons.work_outline, size: 14),
                      label: Text(
                        a.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
