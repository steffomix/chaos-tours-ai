import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/place_photo.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';
import '../stay/stay_detail_sheet.dart';
import 'all_photo_fullscreen_viewer.dart';

String _fmtMs(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Full-screen view of all photos for a place or a single stay, with chunk loader.
///
/// Use [AllPhotosScreen] for a place (loads all photos incl. stay photos).
/// Use [AllPhotosScreen.forStay] for a single stay's photos.
class AllPhotosScreen extends StatefulWidget {
  /// Non-null when showing photos for a place.
  final String? placeUuid;

  /// Non-null when showing photos for a specific stay only.
  final String? stayUuid;

  /// Primary title shown in the AppBar.
  final String title;

  /// Optional subtitle (e.g. place name when in stay mode).
  final String? subtitle;

  const AllPhotosScreen({
    super.key,
    required this.placeUuid,
    required this.title,
    this.subtitle,
  }) : stayUuid = null;

  const AllPhotosScreen.forStay({
    super.key,
    required String this.stayUuid,
    required this.title,
    this.subtitle,
  }) : placeUuid = null;

  @override
  State<AllPhotosScreen> createState() => _AllPhotosScreenState();
}

class _AllPhotosScreenState extends State<AllPhotosScreen> {
  static const int _chunkSize = 20;

  final ScrollController _scrollCtrl = ScrollController();
  final List<PlacePhoto> _photos = [];
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
    final List<PlacePhoto> chunk;
    if (widget.stayUuid != null) {
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
    // Prefetch stay metadata for any new stayUuids.
    for (final p in chunk) {
      final stayUuid = p.stayUuid;
      if (stayUuid != null && !_stayCache.containsKey(stayUuid)) {
        final stay = await DatabaseService.instance.loadStayByUuid(stayUuid);
        if (stay != null) _stayCache[stayUuid] = stay;
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
      _offset = 0;
      _hasMore = true;
    });
    await _loadNextChunk();
  }

  void _openPhoto(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AllFotoFullScreenViewer(
          photos: _photos,
          initialIndex: index,
          onChanged: _reload,
        ),
      ),
    );
  }

  void _openStay(Stay stay) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StayDetailSheet(stay: stay, onUpdated: _reload),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Column(
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
        ),
      ),
      body: _photos.isEmpty && !_loading
          ? Center(child: Text(l10n.noPhotosAtPlace))
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
                  final stay = photo.stayUuid != null
                      ? _stayCache[photo.stayUuid]
                      : null;
                  return _PhotoCard(
                    photo: photo,
                    stay: stay,
                    onTap: () => _openPhoto(i),
                    onOpenStay: stay != null ? () => _openStay(stay) : null,
                  );
                },
              ),
            ),
    );
  }
}

// ── Shared photo card widget ─────────────────────────────────────────────────

class PhotoCard extends StatelessWidget {
  final PlacePhoto photo;
  final Stay? stay;
  final VoidCallback onTap;
  final VoidCallback? onOpenStay;

  const PhotoCard({
    super.key,
    required this.photo,
    this.stay,
    required this.onTap,
    this.onOpenStay,
  });

  @override
  Widget build(BuildContext context) {
    return _PhotoCard(
      photo: photo,
      stay: stay,
      onTap: onTap,
      onOpenStay: onOpenStay,
    );
  }
}

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
          // ── Date + caption ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              _fmtMs(photo.takenAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          if (photo.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(photo.caption, style: const TextStyle(fontSize: 13)),
            ),
          // ── Visit button ──────────────────────────────────────────────
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
