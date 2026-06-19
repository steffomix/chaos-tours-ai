import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/place_photo.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';
import 'stay_detail_sheet.dart';

String _fmtMs(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final d = dt.day.toString().padLeft(2, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final y = dt.year;
  final h = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  return '$d.$mo.$y $h:$mi';
}

/// Zeigt Fotos eines Ortes in zwei Bereichen:
/// 1. Ort-eigene Fotos (kein Stay) mit Datum und Hinzufügen-Buttons.
/// 2. Fotos aus den Besuchen, gruppiert nach Besuch mit Datum und Link.
class PlacePhotosSection extends StatefulWidget {
  final String placeUuid;
  final String deviceId;
  final List<Stay> completedStays;

  const PlacePhotosSection({
    super.key,
    required this.placeUuid,
    required this.deviceId,
    required this.completedStays,
  });

  @override
  State<PlacePhotosSection> createState() => _PlacePhotosSectionState();
}

class _PlacePhotosSectionState extends State<PlacePhotosSection> {
  /// Photos directly at the place (no stayUuid).
  List<PlacePhoto> _placePhotos = [];

  /// Photos per stayUuid.
  Map<String, List<PlacePhoto>> _stayPhotos = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlacePhotosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeUuid != widget.placeUuid) {
      _load();
    }
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;

    // Load all photos for the place (includes stay photos).
    final all = await db.loadPhotosForPlace(widget.placeUuid);

    final placeOnly = all.where((p) => p.stayUuid == null).toList();
    final byStay = <String, List<PlacePhoto>>{};
    for (final p in all.where((p) => p.stayUuid != null)) {
      (byStay[p.stayUuid!] ??= []).add(p);
    }

    if (mounted) {
      setState(() {
        _placePhotos = placeOnly;
        _stayPhotos = byStay;
        _loading = false;
      });
    }
  }

  Future<void> _addPlacePhoto({required ImageSource source}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final photo = PlacePhoto(
      placeUuid: widget.placeUuid,
      photoData: base64Encode(bytes),
      takenAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseService.instance.insertPlacePhoto(
      photo,
      deviceId: widget.deviceId,
    );
    await _load();
  }

  void _openPhoto(List<PlacePhoto> photos, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenViewer(
          photos: photos,
          initialIndex: index,
          onChanged: _load,
        ),
      ),
    );
  }

  void _openStay(Stay stay) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StayDetailSheet(stay: stay, onUpdated: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Ort-Fotos ────────────────────────────────────────────────────
        _SectionHeader(
          icon: Icons.place_outlined,
          label: l10n.photosAtPlace,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.camera_alt, size: 20),
                tooltip: l10n.camera,
                onPressed: () => _addPlacePhoto(source: ImageSource.camera),
              ),
              IconButton(
                icon: const Icon(Icons.add_photo_alternate, size: 20),
                tooltip: l10n.fromGallery,
                onPressed: () => _addPlacePhoto(source: ImageSource.gallery),
              ),
            ],
          ),
        ),
        if (_placePhotos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text(
              l10n.noPlacePhotos,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else
          _PhotoStrip(
            photos: _placePhotos,
            onTap: (i) => _openPhoto(_placePhotos, i),
          ),
        const Divider(height: 24),
        // ── Besuche-Fotos ─────────────────────────────────────────────────
        _SectionHeader(icon: Icons.history, label: l10n.photosFromVisits),
        ..._buildStaySections(l10n),
        if (_stayPhotos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text(
              l10n.noVisitPhotos,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildStaySections(AppLocalizations l10n) {
    final result = <Widget>[];
    // Build a lookup map from the passed completedStays for metadata.
    final stayByUuid = {for (final s in widget.completedStays) s.uuid: s};

    // Sort stay sections by most recent first.
    final stayUuids = _stayPhotos.keys.toList()
      ..sort((a, b) {
        final sa = stayByUuid[a];
        final sb = stayByUuid[b];
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sb.startTime.compareTo(sa.startTime);
      });

    for (final stayUuid in stayUuids) {
      final photos = _stayPhotos[stayUuid]!;
      final stay = stayByUuid[stayUuid];

      final startLabel = stay != null ? _fmtMs(stay.startTime) : l10n.visit;
      final endLabel = stay?.endTime != null
          ? ' – ${_fmtMs(stay!.endTime!)}'
          : '';

      result.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              const Icon(Icons.event, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$startLabel$endLabel',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
              if (stay != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(l10n.visit),
                  onPressed: () => _openStay(stay),
                ),
            ],
          ),
        ),
      );
      result.add(
        _PhotoStrip(photos: photos, onTap: (i) => _openPhoto(photos, i)),
      );
    }
    return result;
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Horizontal strip of photos with date caption below each thumbnail.
class _PhotoStrip extends StatelessWidget {
  final List<PlacePhoto> photos;
  final void Function(int index) onTap;

  const _PhotoStrip({required this.photos, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          Uint8List? bytes;
          try {
            bytes = base64Decode(photo.photoData);
          } catch (_) {}

          return GestureDetector(
            onTap: () => onTap(index),
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: bytes != null
                          ? Image.memory(bytes, fit: BoxFit.cover, width: 100)
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmtMs(photo.takenAt),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Full-screen photo viewer ─────────────────────────────────────────────────

class _FullScreenViewer extends StatefulWidget {
  final List<PlacePhoto> photos;
  final int initialIndex;
  final VoidCallback onChanged;

  const _FullScreenViewer({
    required this.photos,
    required this.initialIndex,
    required this.onChanged,
  });

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer> {
  late PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.photoDeleteTitle),
        content: Text(l10n.photoDeleteContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await DatabaseService.instance.softDeletePlacePhoto(
      widget.photos[_index].uuid,
    );
    widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_index + 1} / ${widget.photos.length}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              _fmtMs(photo.takenAt),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _delete,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          Uint8List? b;
          try {
            b = base64Decode(widget.photos[i].photoData);
          } catch (_) {}
          return InteractiveViewer(
            child: Center(
              child: b != null
                  ? Image.memory(b)
                  : const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
            ),
          );
        },
      ),
    );
  }
}
