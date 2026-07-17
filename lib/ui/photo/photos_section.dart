import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../models/place_photo.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../stay/stay_detail_sheet.dart';
import 'photo_viewer.dart';
import 'photos_screen.dart';
import 'photo_card.dart';

class PhotosSection extends StatefulWidget {
  final String? placeUuid;
  final String placeName;
  final String deviceId;

  /// If set, photos are loaded for this stay instead of for the place.
  final String? stayUuid;

  /// When true, a "Photos" title is shown in the header row (useful when
  /// the section is embedded in a sheet that has no outer ExpansionTile).
  final bool showSectionTitle;

  const PhotosSection({
    super.key,
    this.placeUuid,
    required this.placeName,
    required this.deviceId,
    this.stayUuid,
    this.showSectionTitle = false,
  });

  @override
  State<PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends State<PhotosSection> {
  List<PlacePhoto> _allPhotos = [];
  final Map<String, Stay> _stayCache = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PhotosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeUuid != widget.placeUuid ||
        oldWidget.stayUuid != widget.stayUuid) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseService.instance;
    final List<PlacePhoto> all;
    if (widget.stayUuid != null) {
      all = await db.loadPhotosForStay(widget.stayUuid!);
    } else {
      all = await db.loadPhotosForPlace(widget.placeUuid!);
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
    await DatabaseService.instance.insertPlacePhoto(
      PlacePhoto(
        placeUuid: widget.placeUuid,
        stayUuid: widget.stayUuid,
        photoData: bytes,
        takenAt: DateTime.now().millisecondsSinceEpoch,
      ),
      deviceId: widget.deviceId,
    );
    await _load();
  }

  void _openFullViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FotoViewer(
          photos: _allPhotos,
          initialIndex: index,
          onChanged: _load,
        ),
      ),
    );
  }

  void _openAllPhotosScreen() {
    final l10n = AppLocalizations.of(context)!;
    if (widget.stayUuid != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PhotosScreen.forStay(
            stayUuid: widget.stayUuid!,
            title: l10n.allPhotosScreenTitle,
            subtitle: widget.placeName.isNotEmpty ? widget.placeName : null,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PhotosScreen(
            placeUuid: widget.placeUuid,
            title: l10n.allPhotosScreenTitle,
            subtitle: widget.placeName,
          ),
        ),
      );
    }
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
    final hasMore = _allPhotos.length > n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Add photo buttons ───────────────────────────────────────────
        Row(
          mainAxisAlignment: widget.showSectionTitle
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            if (widget.showSectionTitle) ...[
              Text(l10n.photos, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
            ],
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
          // ── Inline photo cards ────────────────────────────────────────
          ...inlinePhotos.asMap().entries.map((entry) {
            final photo = entry.value;
            final stay = photo.stayUuid != null
                ? _stayCache[photo.stayUuid]
                : null;
            return PhotoCard(
              photo: photo,
              placeName: widget.placeName.isNotEmpty ? widget.placeName : null,
              onTap: () => _openFullViewer(entry.key),
              onOpenVisit: stay != null ? () => _openStay(stay) : null,
            );
          }),
          // ── "Show all" button ─────────────────────────────────────────
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: OutlinedButton.icon(
                onPressed: _openAllPhotosScreen,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.showAllPhotosButton(_allPhotos.length)),
              ),
            ),
        ],
      ],
    );
  }
}
