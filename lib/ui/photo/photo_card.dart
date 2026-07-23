import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

import '../../l10n/app_localizations.dart';
import '../../models/place_photo.dart';
import '../../utils/format.dart';

class PhotoCard extends StatelessWidget {
  final PlacePhoto photo;
  final String? placeName;
  final VoidCallback onTap;

  /// When provided, the place button is interactive and navigates to the place.
  /// When null, the button is shown disabled (place name as context only).
  final VoidCallback? onOpenPlace;

  /// When provided, an additional "open visit" button is shown.
  final VoidCallback? onOpenVisit;

  const PhotoCard({
    super.key,
    required this.photo,
    this.placeName,
    required this.onTap,
    this.onOpenPlace,
    this.onOpenVisit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bytes = photo.photoData;
    final hasData = bytes.isNotEmpty;
    final showBottomRow =
        placeName != null || onOpenPlace != null || onOpenVisit != null;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Photo ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: onTap,
            child: hasData
                ? Image.memory(
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: Colors.grey[300],
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image),
                            // TODO Translate next line
                            Text('Error loading image'),
                            Builder(
                              builder: (context) {
                                final mime = lookupMimeType(
                                  '*',
                                  headerBytes: bytes.sublist(0, 100),
                                );
                                if (mime != null) {
                                  // TODO Translate next line
                                  return Text('File type looks like: $mime');
                                } else {
                                  // TODO Translate next line
                                  return Text('Unknown file type');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    bytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  )
                : Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
          ),
          // ── Date + caption ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              formatMillisecond(photo.takenAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          if (photo.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(photo.caption, style: const TextStyle(fontSize: 13)),
            ),
          // ── Action buttons ────────────────────────────────────────────
          if (showBottomRow)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.place_outlined, size: 16),
                      label: Text(
                        placeName ?? l10n.openPlaceButton,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: onOpenPlace,
                    ),
                  ),
                  if (onOpenVisit != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(l10n.openVisitButton),
                      onPressed: onOpenVisit,
                    ),
                ],
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}
