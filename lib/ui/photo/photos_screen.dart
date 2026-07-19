import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/place_photo.dart';
import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';
import '../place/place_detail_screen.dart';
import '../stay/stay_detail_screen.dart';
import 'photo_viewer.dart';
import 'photo_card.dart';

/// Full-screen view of all photos for a place, a single stay, or the entire
/// database (global photo album).
///
/// Use [PhotosScreen] for a place (loads all photos incl. stay photos).
/// Use [PhotosScreen.forStay] for a single stay's photos.
/// Use [PhotosScreen.global] for the global photo album (all photos,
/// newest first, with "Open place" / "Open visit" navigation).
class PhotosScreen extends StatefulWidget {
  /// Non-null when showing photos for a place.
  final String? placeUuid;

  /// Non-null when showing photos for a specific stay only.
  final String? stayUuid;

  /// Primary title shown in the AppBar.
  final String title;

  /// Optional subtitle (e.g. place name when in stay mode).
  final String? subtitle;

  /// Whether this instance shows the global photo album.
  final bool globalMode;

  const PhotosScreen({
    super.key,
    required this.placeUuid,
    required this.title,
    this.subtitle,
  }) : stayUuid = null,
       globalMode = false;

  const PhotosScreen.forStay({
    super.key,
    required String this.stayUuid,
    required this.title,
    this.subtitle,
  }) : placeUuid = null,
       globalMode = false;

  /// Global photo album — shows all photos across the entire database,
  /// chronological (newest first), with place and stay navigation.
  const PhotosScreen.global({super.key})
    : placeUuid = null,
      stayUuid = null,
      title = '',
      subtitle = null,
      globalMode = true;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  static const int _chunkSize = 20;

  final ScrollController _scrollCtrl = ScrollController();
  final List<PlacePhoto> _photos = [];
  final Map<String, Stay> _stayCache = {};
  final Map<String, SavedPlace> _placeCache = {};

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
    final List<PlacePhoto> chunk;
    if (widget.globalMode) {
      chunk = await DatabaseService.instance.loadAllPhotosPaged(
        limit: _chunkSize,
        offset: _offset,
      );
    } else if (widget.stayUuid != null) {
      chunk = await DatabaseService.instance.loadPhotosForStayPaged(
        widget.stayUuid!,
        limit: _chunkSize,
        offset: _offset,
      );
    } else {
      chunk = await DatabaseService.instance.loadPhotosForPlacePaged(
        widget.placeUuid!,
        limit: _chunkSize,
        offset: _offset,
      );
    }
    // Prefetch stay and place metadata for any new photos.
    for (final p in chunk) {
      final stayUuid = p.stayUuid;
      if (stayUuid != null && !_stayCache.containsKey(stayUuid)) {
        final stay = await DatabaseService.instance.loadStayByUuid(stayUuid);
        if (stay != null) {
          _stayCache[stayUuid] = stay;
          if (widget.globalMode &&
              stay.placeUuid != null &&
              !_placeCache.containsKey(stay.placeUuid)) {
            final place = await DatabaseService.instance.getSavedPlace(
              stay.placeUuid,
            );
            if (place != null) _placeCache[stay.placeUuid!] = place;
          }
        }
      }
      if (widget.globalMode &&
          p.placeUuid != null &&
          !_placeCache.containsKey(p.placeUuid)) {
        final place = await DatabaseService.instance.getSavedPlace(p.placeUuid);
        if (place != null) _placeCache[p.placeUuid!] = place;
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
      _stayCache.clear();
      _placeCache.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadNextChunk();
  }

  /// Resolves the effective place UUID for a photo (direct or via stay).
  String? _effectivePlaceUuid(PlacePhoto photo) {
    if (photo.placeUuid != null) return photo.placeUuid;
    if (photo.stayUuid != null) return _stayCache[photo.stayUuid]?.placeUuid;
    return null;
  }

  Future<void> _openPlace(BuildContext ctx, PlacePhoto photo) async {
    final l10n = AppLocalizations.of(ctx)!;
    final placeUuid = _effectivePlaceUuid(photo);
    SavedPlace? place = placeUuid != null ? _placeCache[placeUuid] : null;
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
      await Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => StayDetailSheet(stay: stay!, onUpdated: _reload),
        ),
      );
    }
  }

  void _openPhoto(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FotoViewer(
          photos: _photos,
          initialIndex: index,
          onChanged: _reload,
        ),
      ),
    );
  }

  void _openStay(Stay stay) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StayDetailSheet(stay: stay, onUpdated: _reload),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget emptyState;
    if (widget.globalMode) {
      emptyState = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(l10n.noPhotosYet, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            l10n.noPhotosHint,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      emptyState = Center(child: Text(l10n.noPhotosAtPlace));
    }

    Widget? appBarTitle;
    if (widget.globalMode) {
      appBarTitle = Text(l10n.photoAlbumTitle);
    } else {
      appBarTitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title),
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: appBarTitle),
      body: _photos.isEmpty && !_loading
          ? Center(child: emptyState)
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
                  if (widget.globalMode) {
                    final effectivePlaceUuid = _effectivePlaceUuid(photo);
                    final placeName = effectivePlaceUuid != null
                        ? _placeCache[effectivePlaceUuid]?.name
                        : null;
                    return PhotoCard(
                      photo: photo,
                      placeName: placeName,
                      onTap: () => _openPhoto(i),
                      onOpenPlace: () => _openPlace(ctx, photo),
                      onOpenVisit: photo.stayUuid != null
                          ? () => _openVisit(ctx, photo)
                          : null,
                    );
                  }
                  final stay = photo.stayUuid != null
                      ? _stayCache[photo.stayUuid]
                      : null;
                  return PhotoCard(
                    photo: photo,
                    placeName: widget.subtitle,
                    onTap: () => _openPhoto(i),
                    onOpenVisit: stay != null ? () => _openStay(stay) : null,
                  );
                },
              ),
            ),
    );
  }
}
