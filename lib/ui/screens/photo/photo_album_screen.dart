import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../../models/place_photo.dart';
import '../../../models/saved_place.dart';
import '../../../models/stay.dart';
import '../../../services/database_service.dart';
import '../../../utils/time.dart';
import '../place/place_detail_screen.dart';
import '../stay/stay_detail_sheet.dart';
import 'photo_album_fullscreen_viewer.dart' show PhotoAlbumFullScreenViewer;

/// Global photo album — shows all photos (chronological, newest first) with
/// chunk loader. Each photo card shows "Ort öffnen" and "Besuch öffnen" buttons
/// with DB existence checks (alert on missing).
class PhotoAlbumScreen extends StatefulWidget {
  const PhotoAlbumScreen({super.key});

  @override
  State<PhotoAlbumScreen> createState() => _PhotoAlbumScreenState();
}

class _PhotoAlbumScreenState extends State<PhotoAlbumScreen> {
  static const int _chunkSize = 20;

  final ScrollController _scrollCtrl = ScrollController();
  final List<PlacePhoto> _photos = [];
  final Map<String, SavedPlace> _placeCache = {};
  final Map<String, Stay> _stayCache = {};

  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadNextChunk();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400 && _hasMore && !_loading) {
      _loadNextChunk();
    }
  }

  Future<void> _loadNextChunk() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final chunk = await DatabaseService.instance.loadAllPhotosPaged(
      limit: _chunkSize,
      offset: _offset,
    );
    for (final p in chunk) {
      // Resolve place via direct placeUuid.
      if (p.placeUuid != null && !_placeCache.containsKey(p.placeUuid)) {
        final place = await DatabaseService.instance.getSavedPlace(p.placeUuid);
        if (place != null) _placeCache[p.placeUuid!] = place;
      }
      // Resolve stay + its place.
      if (p.stayUuid != null && !_stayCache.containsKey(p.stayUuid)) {
        final stay = await DatabaseService.instance.loadStayByUuid(p.stayUuid!);
        if (stay != null) {
          _stayCache[p.stayUuid!] = stay;
          if (stay.placeUuid != null &&
              !_placeCache.containsKey(stay.placeUuid)) {
            final place = await DatabaseService.instance.getSavedPlace(
              stay.placeUuid,
            );
            if (place != null) _placeCache[stay.placeUuid!] = place;
          }
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _photos.addAll(chunk);
      _offset += chunk.length;
      _hasMore = chunk.length == _chunkSize;
      _loading = false;
    });
  }

  Future<void> _reload() async {
    setState(() {
      _photos.clear();
      _placeCache.clear();
      _stayCache.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadNextChunk();
  }

  void _openPhoto(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoAlbumFullScreenViewer(
          photos: _photos,
          initialIndex: index,
          onChanged: _reload,
        ),
      ),
    );
  }

  /// Resolves the effective place UUID for a photo (direct or via stay).
  String? _effectivePlaceUuid(PlacePhoto photo) {
    if (photo.placeUuid != null) return photo.placeUuid;
    if (photo.stayUuid != null) return _stayCache[photo.stayUuid]?.placeUuid;
    return null;
  }

  Future<void> _openPlace(BuildContext ctx, PlacePhoto photo) async {
    final l10n = AppLocalizations.of(ctx)!;
    String? placeUuid = _effectivePlaceUuid(photo);
    SavedPlace? place = placeUuid != null ? _placeCache[placeUuid] : null;
    // Fallback: query DB directly.
    if (place == null && placeUuid != null) {
      place = await DatabaseService.instance.getSavedPlace(placeUuid);
    }
    if (!ctx.mounted) return;
    if (place == null) {
      await showDialog<void>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: Text(l10n.placeNotFoundTitle),
          content: Text(l10n.placeNotFoundContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }
    if (ctx.mounted) {
      await Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaceDetailScreen(
            place: place!,
            onUpdated: _reload,
            onDeleted: _reload,
          ),
        ),
      );
    }
  }

  Future<void> _openVisit(BuildContext ctx, PlacePhoto photo) async {
    final l10n = AppLocalizations.of(ctx)!;
    if (photo.stayUuid == null) return;
    Stay? stay = _stayCache[photo.stayUuid];
    stay ??= await DatabaseService.instance.loadStayByUuid(photo.stayUuid!);
    if (!ctx.mounted) return;
    if (stay == null) {
      await showDialog<void>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: Text(l10n.visitNotFoundTitle),
          content: Text(l10n.visitNotFoundContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }
    if (ctx.mounted) {
      await showModalBottomSheet<void>(
        context: ctx,
        isScrollControlled: true,
        builder: (_) => StayDetailSheet(stay: stay!, onUpdated: _reload),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.photoAlbumTitle)),
      body: _photos.isEmpty && !_loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noPhotosYet,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.noPhotosHint,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(8),
                itemCount: _photos.length + (_hasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i >= _photos.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final photo = _photos[i];
                  final effectivePlaceUuid = _effectivePlaceUuid(photo);
                  final placeName = effectivePlaceUuid != null
                      ? _placeCache[effectivePlaceUuid]?.name
                      : null;
                  return _AlbumPhotoCard(
                    photo: photo,
                    placeName: placeName,
                    onTap: () => _openPhoto(i),
                    onOpenPlace: () => _openPlace(ctx, photo),
                    onOpenVisit: photo.stayUuid != null
                        ? () => _openVisit(ctx, photo)
                        : null,
                  );
                },
              ),
            ),
    );
  }
}

// ── Photo card ───────────────────────────────────────────────────────────────

class _AlbumPhotoCard extends StatelessWidget {
  final PlacePhoto photo;
  final String? placeName;
  final VoidCallback onTap;
  final VoidCallback onOpenPlace;
  final VoidCallback? onOpenVisit;

  const _AlbumPhotoCard({
    required this.photo,
    this.placeName,
    required this.onTap,
    required this.onOpenPlace,
    this.onOpenVisit,
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
          // ── Photo ────────────────────────────────────────────────────
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
          ),
        ],
      ),
    );
  }
}

// ── Full-screen photo viewer ─────────────────────────────────────────────────
