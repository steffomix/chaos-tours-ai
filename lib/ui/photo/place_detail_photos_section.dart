import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/place_photo.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../utils/time.dart';
import 'all_photos_screen.dart';
import '../stay/stay_detail_sheet.dart';

/// Shows the newest [n] photos for a place inline, combined (place + stay),
/// sorted by date (newest first), in card style with BoxFit.contain.
///
/// If there are more than [n] photos, shows a "Show all X photos" button
/// that opens [AllPhotosScreen].
class PlaceDetailPhotosSection extends StatefulWidget {
  final String placeUuid;
  final String placeName;
  final String deviceId;

  const PlaceDetailPhotosSection({
    super.key,
    required this.placeUuid,
    required this.placeName,
    required this.deviceId,
  });

  @override
  State<PlaceDetailPhotosSection> createState() =>
      _PlaceDetailPhotosSectionState();
}

class _PlaceDetailPhotosSectionState extends State<PlaceDetailPhotosSection> {
  /// All photos (place + stay), sorted newest-first.
  List<PlacePhoto> _allPhotos = [];

  /// Stay metadata keyed by stay UUID.
  final Map<String, Stay> _stayCache = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlaceDetailPhotosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeUuid != widget.placeUuid) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseService.instance;
    final all = await db.loadPhotosForPlace(widget.placeUuid);

    // Pre-cache stay metadata for stay photos.
    final stayUuids = all
        .where((p) => p.stayUuid != null)
        .map((p) => p.stayUuid!)
        .toSet();
    for (final uuid in stayUuids) {
      if (!_stayCache.containsKey(uuid)) {
        final stay = await db.loadStayByUuid(uuid);
        if (stay != null) _stayCache[uuid] = stay;
      }
    }

    if (mounted) {
      setState(() {
        _allPhotos = all;
        _loading = false;
      });
    }
  }

  Future<void> _addPhoto({required ImageSource source}) async {
    final s = SettingsService.instance;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: s.photoImageQuality,
      maxWidth: s.photoMaxWidth == 0 ? null : s.photoMaxWidth.toDouble(),
      maxHeight: s.photoMaxHeight == 0 ? null : s.photoMaxHeight.toDouble(),
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final photo = PlacePhoto(
      placeUuid: widget.placeUuid,
      photoData: bytes,
      takenAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseService.instance.insertPlacePhoto(
      photo,
      deviceId: widget.deviceId,
    );
    await _load();
  }

  void _openFullViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _InlineFullScreenViewer(
          photos: _allPhotos,
          initialIndex: index,
          onChanged: _load,
        ),
      ),
    );
  }

  void _openAllPhotosScreen() {
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AllPhotosScreen(
          placeUuid: widget.placeUuid,
          title: l10n.allPhotosScreenTitle,
          subtitle: widget.placeName,
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
    final n = SettingsService.instance.placeDetailPhotoCount;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final inlinePhotos = _allPhotos.take(n).toList();
    final totalCount = _allPhotos.length;
    final hasMore = totalCount > n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Add photo buttons ─────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.camera_alt, size: 20),
              tooltip: l10n.camera,
              onPressed: () => _addPhoto(source: ImageSource.camera),
            ),
            IconButton(
              icon: const Icon(Icons.add_photo_alternate, size: 20),
              tooltip: l10n.fromGallery,
              onPressed: () => _addPhoto(source: ImageSource.gallery),
            ),
          ],
        ),
        if (_allPhotos.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              l10n.noPlacePhotos,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else ...[
          // ── Inline photo cards ──────────────────────────────────────────
          ...inlinePhotos.asMap().entries.map((entry) {
            final index = entry.key;
            final photo = entry.value;
            final stay = photo.stayUuid != null
                ? _stayCache[photo.stayUuid]
                : null;
            return _PhotoCard(
              photo: photo,
              stay: stay,
              onTap: () => _openFullViewer(index),
              onOpenStay: stay != null ? () => _openStay(stay) : null,
            );
          }),
          // ── "Show all" button ───────────────────────────────────────────
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: OutlinedButton.icon(
                onPressed: _openAllPhotosScreen,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.showAllPhotosButton(totalCount)),
              ),
            ),
        ],
      ],
    );
  }
}

// ── Photo card ───────────────────────────────────────────────────────────────

class _PhotoCard extends StatelessWidget {
  final PlacePhoto photo;
  final Stay? stay;
  final VoidCallback onTap;
  final VoidCallback? onOpenStay;

  const _PhotoCard({
    required this.photo,
    this.stay,
    required this.onTap,
    this.onOpenStay,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bytes = photo.photoData;
    final hasData = bytes.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Photo ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: onTap,
            child: hasData
                ? Image.memory(
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
          // ── Date + caption ─────────────────────────────────────────────
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
          // ── Visit button ───────────────────────────────────────────────
          if (onOpenStay != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(l10n.openVisitButton),
                onPressed: onOpenStay,
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Full-screen viewer (for inline tap) ─────────────────────────────────────

class _InlineFullScreenViewer extends StatefulWidget {
  final List<PlacePhoto> photos;
  final int initialIndex;
  final VoidCallback onChanged;

  const _InlineFullScreenViewer({
    required this.photos,
    required this.initialIndex,
    required this.onChanged,
  });

  @override
  State<_InlineFullScreenViewer> createState() =>
      _InlineFullScreenViewerState();
}

class _InlineFullScreenViewerState extends State<_InlineFullScreenViewer> {
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

  Future<void> _share() async {
    final photo = widget.photos[_index];
    final bytes = photo.photoData;
    if (bytes.isEmpty || !mounted) return;
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/share_${photo.uuid}.jpg');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/jpeg')],
        text: photo.caption.isNotEmpty ? photo.caption : null,
      ),
    );
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
    final l10n = AppLocalizations.of(context)!;
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
              formatMillisecond(photo.takenAt),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: l10n.sharePhoto,
            onPressed: _share,
          ),
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
          final b = widget.photos[i].photoData;
          return InteractiveViewer(
            child: Center(
              child: b.isNotEmpty
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
