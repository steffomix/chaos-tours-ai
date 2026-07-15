import 'dart:typed_data';

import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/message.dart';
import '../../../models/place_photo.dart';
import '../../../services/database_service.dart';
import '../../../services/settings_service.dart';

class P2pMessageComposer extends StatefulWidget {
  final Message? replyTo;
  final String? defaultPlaceUuid;
  final VoidCallback onCancelReply;
  final Future<void> Function(String body, List<Uint8List> photos) onSend;

  const P2pMessageComposer({
    super.key,
    required this.replyTo,
    required this.defaultPlaceUuid,
    required this.onCancelReply,
    required this.onSend,
  });

  @override
  State<P2pMessageComposer> createState() => _P2pMessageComposerState();
}

class _P2pMessageComposerState extends State<P2pMessageComposer> {
  final TextEditingController _ctrl = TextEditingController();
  final List<Uint8List> _pendingPhotos = [];
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickNewPhoto(ImageSource source) async {
    if (_pendingPhotos.isNotEmpty) return;
    final s = SettingsService.instance;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: s.photoImageQuality,
      maxWidth: s.photoMaxWidth == 0 ? null : s.photoMaxWidth.toDouble(),
      maxHeight: s.photoMaxHeight == 0 ? null : s.photoMaxHeight.toDouble(),
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _pendingPhotos.add(bytes));
  }

  /// Lets the user reference an existing photo of the anchored place / its
  /// visits. The referenced image bytes are attached as a new message photo.
  Future<void> _referenceExistingPhoto() async {
    if (_pendingPhotos.isNotEmpty) return;
    final placeUuid = widget.replyTo?.placeUuid ?? widget.defaultPlaceUuid;
    if (placeUuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noPlaceAvailable)),
      );
      return;
    }
    final photos = await DatabaseService.instance.loadPhotosForPlace(placeUuid);
    if (!mounted) return;
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noPhotosAtPlace)),
      );
      return;
    }
    final picked = await showModalBottomSheet<PlacePhoto>(
      context: context,
      builder: (ctx) => GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(8),
        children: photos
            .map(
              (p) => GestureDetector(
                onTap: () => Navigator.pop(ctx, p),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Image.memory(p.photoData, fit: BoxFit.cover),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _pendingPhotos.add(picked.photoData));
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty && _pendingPhotos.isEmpty) return;
    setState(() => _sending = true);
    await widget.onSend(body, List.of(_pendingPhotos));
    if (!mounted) return;
    setState(() {
      _ctrl.clear();
      _pendingPhotos.clear();
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyTo != null)
            Container(
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.replyingTo(
                        widget.replyTo!.body.isEmpty
                            ? l10n.messagePhotoPlaceholder
                            : widget.replyTo!.body,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onCancelReply,
                  ),
                ],
              ),
            ),
          if (_pendingPhotos.isNotEmpty)
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: _pendingPhotos.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          _pendingPhotos[i],
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _pendingPhotos.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                if (_pendingPhotos.isEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    onSelected: (v) {
                      switch (v) {
                        case 'camera':
                          _pickNewPhoto(ImageSource.camera);
                        case 'gallery':
                          _pickNewPhoto(ImageSource.gallery);
                        case 'existing':
                          _referenceExistingPhoto();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(value: 'camera', child: Text(l10n.camera)),
                      PopupMenuItem(
                        value: 'gallery',
                        child: Text(l10n.gallery),
                      ),
                      PopupMenuItem(
                        value: 'existing',
                        child: Text(l10n.existingPlacePhoto),
                      ),
                    ],
                  ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.messageHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _sending ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
