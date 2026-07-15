import 'package:chaos_tours_ai/utils/share_place_foto.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/place_photo.dart';
import '../../services/database_service.dart';

class DatabaseExplorerPhotoViewer extends StatefulWidget {
  final List<PlacePhoto> photos;
  final int initialIndex;
  final VoidCallback onChanged;
  final Function() deleteEnabled;

  const DatabaseExplorerPhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onChanged,
    required this.deleteEnabled,
  });

  @override
  State<DatabaseExplorerPhotoViewer> createState() =>
      DatabaseExplorerPhotoViewerState();
}

class DatabaseExplorerPhotoViewerState
    extends State<DatabaseExplorerPhotoViewer> {
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
    if (photo.photoData.isEmpty) return;
    sharePhoto(photo);
  }

  Future<void> _delete() async {
    if (!widget.deleteEnabled()) return;
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
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: AppLocalizations.of(context)!.sharePhoto,
            onPressed: _share,
          ),
          if (widget.deleteEnabled())
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
                final b = widget.photos[i].photoData;
                return InteractiveViewer(
                  constrained: true,
                  maxScale: 50.0,
                  child: Center(
                    child: b.isNotEmpty
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
