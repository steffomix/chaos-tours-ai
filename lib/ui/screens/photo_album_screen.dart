import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:focus_detector/focus_detector.dart';

import '../../models/place_photo.dart';
import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';

/// Global photo album — shows all photos grouped by place.
class PhotoAlbumScreen extends StatefulWidget {
  const PhotoAlbumScreen({super.key});

  @override
  State<PhotoAlbumScreen> createState() => _PhotoAlbumScreenState();
}

class _PhotoAlbumScreenState extends State<PhotoAlbumScreen> {
  List<PlacePhoto> _allPhotos = [];
  Map<String, SavedPlace> _placesByUuid = {};
  Map<String, Stay> _staysByUuid = {};
  bool _loading = true;

  // Chunk loading
  static const int _kChunkSize = 20;
  int _displayedGroups = _kChunkSize;
  int _totalGroupCount = 0;
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
        _displayedGroups < _totalGroupCount) {
      setState(() {
        _displayedGroups = (_displayedGroups + _kChunkSize).clamp(
          0,
          _totalGroupCount,
        );
      });
    }
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DatabaseService.instance.loadAllPhotos(),
      DatabaseService.instance.loadAllPlaces(),
      DatabaseService.instance.loadAllStays(),
    ]);
    final photos = results[0] as List<PlacePhoto>;
    final places = results[1] as List<SavedPlace>;
    final stays = results[2] as List<Stay>;

    // Compute group count for scroll listener guard
    final staysByUuid = {for (final s in stays) s.uuid: s};
    final groupKeys = <String?>{};
    for (final photo in photos) {
      String? pUuid = photo.placeUuid;
      if (pUuid == null && photo.stayUuid != null) {
        pUuid = staysByUuid[photo.stayUuid]?.placeUuid;
      }
      groupKeys.add(pUuid);
    }

    if (mounted) {
      setState(() {
        _allPhotos = photos;
        _placesByUuid = {for (final p in places) p.uuid: p};
        _staysByUuid = staysByUuid;
        _loading = false;
        _displayedGroups = _kChunkSize;
        _totalGroupCount = groupKeys.length;
      });
    }
  }

  /// Groups photos by their effective place (direct or via stay).
  Map<String?, List<PlacePhoto>> _grouped() {
    final map = <String?, List<PlacePhoto>>{};
    for (final photo in _allPhotos) {
      String? pUuid = photo.placeUuid;
      if (pUuid == null && photo.stayUuid != null) {
        pUuid = _staysByUuid[photo.stayUuid]?.placeUuid;
      }
      (map[pUuid] ??= []).add(photo);
    }
    return map;
  }

  @override
  void dispose() {
    _albumScrollCtrl.dispose();
    super.dispose();
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
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _allPhotos.isEmpty
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
    final grouped = _grouped();
    // Sort: known places first (by name), then unknown
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        final nameA = _placesByUuid[a]?.name ?? '';
        final nameB = _placesByUuid[b]?.name ?? '';
        return nameA.compareTo(nameB);
      });

    return ListView.builder(
      controller: _albumScrollCtrl,
      itemCount:
          sortedKeys.length.clamp(0, _displayedGroups) +
          (_displayedGroups < sortedKeys.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == sortedKeys.length.clamp(0, _displayedGroups)) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final placeUuid = sortedKeys[index];
        final photos = grouped[placeUuid]!;
        final placeName = placeUuid != null
            ? (_placesByUuid[placeUuid]?.name ?? l10n.unknownPlace)
            : l10n.withoutPlace;
        return _PlacePhotoGroup(
          placeName: placeName,
          photos: photos,
          onTap: (photoIndex) => _openViewer(photos, photoIndex),
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

class _PlacePhotoGroup extends StatelessWidget {
  final String placeName;
  final List<PlacePhoto> photos;
  final void Function(int index) onTap;

  const _PlacePhotoGroup({
    required this.placeName,
    required this.photos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  placeName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                photos.length == 1
                    ? AppLocalizations.of(context)!.photoCount(photos.length)
                    : AppLocalizations.of(
                        context,
                      )!.photoCountPlural(photos.length),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              Uint8List? bytes;
              try {
                bytes = base64Decode(photos[index].photoData);
              } catch (_) {}
              return GestureDetector(
                onTap: () => onTap(index),
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
