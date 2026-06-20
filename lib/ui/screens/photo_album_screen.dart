import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:focus_detector/focus_detector.dart';

import '../../models/place_photo.dart';
import '../../services/database_service.dart';

/// Global photo album — shows all photos grouped by place.
class PhotoAlbumScreen extends StatefulWidget {
  const PhotoAlbumScreen({super.key});

  @override
  State<PhotoAlbumScreen> createState() => _PhotoAlbumScreenState();
}

class _PhotoAlbumScreenState extends State<PhotoAlbumScreen> {
  // ── Group metadata (DB-paginated, accumulated) ───────────────────────────
  List<({String? placeUuid, int photoCount, String? placeName})> _groups = [];
  bool _groupsHasMore = false;
  bool _groupsLoading = false;

  // ── Photo cache: keyed by placeUuid or '' for the null group ─────────────
  final Map<String, List<PlacePhoto>> _photoCache = {};

  static const int _kChunkSize = 20;
  final ScrollController _albumScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _albumScrollCtrl.addListener(_onAlbumScroll);
    _load();
  }

  void _onAlbumScroll() {
    if (!_albumScrollCtrl.hasClients) return;
    final pos = _albumScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 &&
        _groupsHasMore &&
        !_groupsLoading) {
      _loadNextGroupChunk();
    }
  }

  @override
  void dispose() {
    _albumScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _groups = [];
      _groupsHasMore = false;
      _groupsLoading = true;
      _photoCache.clear();
    });
    await _loadNextGroupChunk();
  }

  Future<void> _loadNextGroupChunk() async {
    if (_groupsLoading && _groups.isNotEmpty) return;
    if (!mounted) return;
    setState(() => _groupsLoading = true);
    try {
      final page = await DatabaseService.instance.loadPhotoGroupsPaged(
        limit: _kChunkSize,
        offset: _groups.length,
      );
      if (mounted) {
        setState(() {
          _groups = [..._groups, ...page];
          _groupsHasMore = page.length == _kChunkSize;
          _groupsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _groupsLoading = false);
    }
  }

  /// Returns (and caches) the photos for a group identified by [placeUuid].
  Future<List<PlacePhoto>> _photosForGroup(String? placeUuid) async {
    final key = placeUuid ?? '';
    if (_photoCache.containsKey(key)) return _photoCache[key]!;
    final photos = await DatabaseService.instance.loadPhotosForEffectivePlace(
      placeUuid,
    );
    _photoCache[key] = photos;
    return photos;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FocusDetector(
      onFocusGained: () {
        _load();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.photoAlbumTitle)),
        body: _groupsLoading && _groups.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : !_groupsLoading && _groups.isEmpty
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
            : _buildGroupedList(l10n),
      ),
    );
  }

  Widget _buildGroupedList(AppLocalizations l10n) {
    return ListView.builder(
      controller: _albumScrollCtrl,
      itemCount: _groups.length + (_groupsHasMore || _groupsLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _groups.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final group = _groups[index];
        final placeName = group.placeName ?? l10n.withoutPlace;
        return _LazyPlacePhotoGroup(
          key: ValueKey(group.placeUuid),
          placeUuid: group.placeUuid,
          placeName: placeName,
          photoCount: group.photoCount,
          loadPhotos: () => _photosForGroup(group.placeUuid),
          onViewerOpen: (photos, idx) => _openViewer(photos, idx),
        );
      },
    );
  }

  void _openViewer(List<PlacePhoto> photos, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AlbumPhotoViewer(
          photos: photos,
          initialIndex: index,
          onChanged: _load,
        ),
      ),
    );
  }
}

/// A photo group row that loads its photos lazily via [loadPhotos].
class _LazyPlacePhotoGroup extends StatefulWidget {
  final String? placeUuid;
  final String placeName;
  final int photoCount;
  final Future<List<PlacePhoto>> Function() loadPhotos;
  final void Function(List<PlacePhoto> photos, int index) onViewerOpen;

  const _LazyPlacePhotoGroup({
    super.key,
    required this.placeUuid,
    required this.placeName,
    required this.photoCount,
    required this.loadPhotos,
    required this.onViewerOpen,
  });

  @override
  State<_LazyPlacePhotoGroup> createState() => _LazyPlacePhotoGroupState();
}

class _LazyPlacePhotoGroupState extends State<_LazyPlacePhotoGroup> {
  List<PlacePhoto>? _photos;

  @override
  void initState() {
    super.initState();
    widget.loadPhotos().then((photos) {
      if (mounted) setState(() => _photos = photos);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final photos = _photos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.placeName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                widget.photoCount == 1
                    ? l10n.photoCount(widget.photoCount)
                    : l10n.photoCountPlural(widget.photoCount),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: photos == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    Uint8List? bytes;
                    try {
                      bytes = base64Decode(photos[index].photoData);
                    } catch (_) {}
                    return GestureDetector(
                      onTap: () => widget.onViewerOpen(photos, index),
                      child: Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: bytes != null
                              ? Image.memory(bytes, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
      ],
    );
  }
}

/// Simple full-screen viewer reused from the album screen.
class _AlbumPhotoViewer extends StatefulWidget {
  final List<PlacePhoto> photos;
  final int initialIndex;
  final VoidCallback onChanged;

  const _AlbumPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.onChanged,
  });

  @override
  State<_AlbumPhotoViewer> createState() => _AlbumPhotoViewerState();
}

class _AlbumPhotoViewerState extends State<_AlbumPhotoViewer> {
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
        title: Text(
          '${_index + 1} / ${widget.photos.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _delete,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
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
                            color: Colors.white54,
                            size: 64,
                          ),
                  ),
                );
              },
            ),
          ),
          if (photo.caption.isNotEmpty)
            Container(
              color: Colors.black54,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: Text(
                photo.caption,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
