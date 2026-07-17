import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../models/place_photo.dart';
import '../../services/database_service.dart';
import '../../utils/format.dart';

class FotoViewer extends StatefulWidget {
  final List<PlacePhoto> photos;
  final int initialIndex;
  final VoidCallback onChanged;

  /// Optional guard: if provided, the delete button is only shown (and
  /// the delete action only executed) when this returns [true].
  /// If omitted, delete is always available.
  final bool Function()? canDelete;

  const FotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onChanged,
    this.canDelete,
  });

  @override
  State<FotoViewer> createState() => _FotoViewerState();
}

class _FotoViewerState extends State<FotoViewer> {
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
    if (widget.canDelete != null && !widget.canDelete!()) return;
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
          if (widget.canDelete == null || widget.canDelete!())
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
