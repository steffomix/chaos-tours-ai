import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/place_photo.dart';
import '../../services/database_service.dart';

/// A reusable photo grid widget that shows photos for a place and/or stay.
///
/// Pass [placeUuid] to show all photos of a place (including its stays).
/// Pass [stayUuid] to show only the stay's own photos.
/// Both can be passed when adding a new photo to associate it with a stay
/// that belongs to a specific place.
class PhotoGrid extends StatefulWidget {
  /// Restricts display to this place's photos (+ its stays when [includeStayPhotos] is true).
  final String? placeUuid;

  /// Restricts display to this stay's photos only.
  final String? stayUuid;

  /// When true and [placeUuid] is set, also shows photos from linked stays.
  final bool includeStayPhotos;

  /// Device-id used when writing new records.
  final String deviceId;

  const PhotoGrid({
    super.key,
    this.placeUuid,
    this.stayUuid,
    this.includeStayPhotos = true,
    this.deviceId = '',
  });

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  List<PlacePhoto> _photos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<PlacePhoto> photos;
    if (widget.stayUuid != null) {
      photos = await DatabaseService.instance.loadPhotosForStay(
        widget.stayUuid!,
      );
    } else if (widget.placeUuid != null && widget.includeStayPhotos) {
      photos = await DatabaseService.instance.loadPhotosForPlace(
        widget.placeUuid!,
      );
    } else if (widget.placeUuid != null) {
      // Only place-level photos (no stay photos)
      final all = await DatabaseService.instance.loadPhotosForPlace(
        widget.placeUuid!,
      );
      photos = all.where((p) => p.stayUuid == null).toList();
    } else {
      photos = await DatabaseService.instance.loadAllPhotos();
    }
    if (mounted)
      setState(() {
        _photos = photos;
        _loading = false;
      });
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final base64Data = base64Encode(bytes);

    final photo = PlacePhoto(
      placeUuid: widget.placeUuid,
      stayUuid: widget.stayUuid,
      photoData: base64Data,
      takenAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseService.instance.insertPlacePhoto(
      photo,
      deviceId: widget.deviceId,
    );
    await _load();
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final base64Data = base64Encode(bytes);

    final photo = PlacePhoto(
      placeUuid: widget.placeUuid,
      stayUuid: widget.stayUuid,
      photoData: base64Data,
      takenAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseService.instance.insertPlacePhoto(
      photo,
      deviceId: widget.deviceId,
    );
    await _load();
  }

  void _openPhoto(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PhotoViewer(
          photos: _photos,
          initialIndex: index,
          deviceId: widget.deviceId,
          onChanged: _load,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _takePicture,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Kamera'),
            ),
            TextButton.icon(
              onPressed: _addPhoto,
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: const Text('Hinzufügen'),
            ),
          ],
        ),
        if (_photos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Noch keine Fotos',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              final photo = _photos[index];
              Uint8List? bytes;
              try {
                bytes = base64Decode(photo.photoData);
              } catch (_) {}
              return GestureDetector(
                onTap: () => _openPhoto(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ── Full-screen photo viewer ──────────────────────────────────────────────────

class _PhotoViewer extends StatefulWidget {
  final List<PlacePhoto> photos;
  final int initialIndex;
  final String deviceId;
  final VoidCallback onChanged;

  const _PhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.deviceId,
    required this.onChanged,
  });

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  PlacePhoto get _current => widget.photos[_currentIndex];

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Foto löschen'),
        content: const Text('Dieses Foto wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await DatabaseService.instance.softDeletePlacePhoto(
      _current.uuid,
      deviceId: widget.deviceId,
    );
    widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editCaption() async {
    final ctrl = TextEditingController(text: _current.caption);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Beschriftung'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Beschriftung eingeben'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    await DatabaseService.instance.updatePlacePhotoCaption(
      _current.uuid,
      result,
      deviceId: widget.deviceId,
    );
    widget.onChanged();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final photo = _current;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Beschriftung bearbeiten',
            onPressed: _editCaption,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Foto löschen',
            onPressed: _delete,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
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
