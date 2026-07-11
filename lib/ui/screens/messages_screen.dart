import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/message.dart';
import '../../models/message_attachment.dart';
import '../../models/place_photo.dart';
import '../../models/saved_place.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';

/// Scope of the shared [MessagesScreen].
enum MessagesFilter {
  /// All messages across all places, newest first.
  all,

  /// Messages anchored to a single place.
  place,

  /// Messages of all places within a radius around a coordinate.
  region,
}

/// A single unified screen that renders the P2P message feed in one of three
/// scopes ([MessagesFilter]). Sharing one screen keeps the look consistent and
/// simplifies maintenance. Messages are paginated (chunk-loaded) because the
/// volume can be large.
class MessagesScreen extends StatefulWidget {
  final MessagesFilter filter;

  /// Required when [filter] is [MessagesFilter.place].
  final String? placeUuid;

  /// Required when [filter] is [MessagesFilter.region].
  final double? lat;
  final double? lng;
  final double? radiusKm;

  /// Optional title override.
  final String? title;

  const MessagesScreen({
    super.key,
    this.filter = MessagesFilter.all,
    this.placeUuid,
    this.lat,
    this.lng,
    this.radiusKm,
    this.title,
  });

  const MessagesScreen.place({
    super.key,
    required String this.placeUuid,
    this.title,
  }) : filter = MessagesFilter.place,
       lat = null,
       lng = null,
       radiusKm = null;

  const MessagesScreen.region({
    super.key,
    required double this.lat,
    required double this.lng,
    required double this.radiusKm,
    this.title,
  }) : filter = MessagesFilter.region,
       placeUuid = null;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const int _chunkSize = 30;

  final ScrollController _scrollCtrl = ScrollController();
  final List<Message> _messages = [];
  final Map<String, SavedPlace> _placeCache = {};
  final Map<String, List<PlacePhoto>> _photoCache = {};

  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;

  Message? _replyTo;

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
    if (pos.pixels >= pos.maxScrollExtent - 300 && _hasMore && !_loading) {
      _loadNextChunk();
    }
  }

  Future<List<Message>> _fetchChunk(int offset) {
    final db = DatabaseService.instance;
    switch (widget.filter) {
      case MessagesFilter.all:
        return db.loadMessagesPaged(limit: _chunkSize, offset: offset);
      case MessagesFilter.place:
        return db.loadMessagesForPlace(
          widget.placeUuid!,
          limit: _chunkSize,
          offset: offset,
        );
      case MessagesFilter.region:
        return db.loadMessagesForRegion(
          lat: widget.lat!,
          lng: widget.lng!,
          radiusKm: widget.radiusKm!,
          limit: _chunkSize,
          offset: offset,
        );
    }
  }

  Future<void> _loadNextChunk() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final chunk = await _fetchChunk(_offset);
    await _hydrate(chunk);
    if (!mounted) return;
    setState(() {
      _messages.addAll(chunk);
      _offset += chunk.length;
      _hasMore = chunk.length == _chunkSize;
      _loading = false;
    });
  }

  Future<void> _reload() async {
    setState(() {
      _messages.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadNextChunk();
  }

  /// Loads place metadata and attached photos referenced by the chunk.
  Future<void> _hydrate(List<Message> chunk) async {
    final db = DatabaseService.instance;
    for (final m in chunk) {
      if (!_placeCache.containsKey(m.placeUuid)) {
        final place = await db.getSavedPlace(m.placeUuid);
        if (place != null) _placeCache[m.placeUuid] = place;
      }
      if (!_photoCache.containsKey(m.uuid)) {
        _photoCache[m.uuid] = await db.loadPhotosForMessage(m.uuid);
      }
    }
  }

  String _titleFor(AppLocalizations l10n) {
    if (widget.title != null) return widget.title!;
    switch (widget.filter) {
      case MessagesFilter.all:
        return l10n.messagesTitle;
      case MessagesFilter.place:
        return _placeCache[widget.placeUuid]?.name ?? l10n.messagesPlaceTitle;
      case MessagesFilter.region:
        return l10n.messagesRegionTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = Column(
      children: [
        Expanded(
          child: _messages.isEmpty && !_loading
              ? Center(child: Text(l10n.messagesEmpty))
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length + (_hasMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i >= _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _MessageCard(
                        message: _messages[i],
                        place: _placeCache[_messages[i].placeUuid],
                        photos: _photoCache[_messages[i].uuid] ?? const [],
                        showPlace: widget.filter != MessagesFilter.place,
                        onReply: () => setState(() => _replyTo = _messages[i]),
                        onDelete: () => _deleteMessage(_messages[i]),
                        onDeletePhoto: _reload,
                      );
                    },
                  ),
                ),
        ),
        _Composer(
          replyTo: _replyTo,
          defaultPlaceUuid: widget.placeUuid,
          onCancelReply: () => setState(() => _replyTo = null),
          onSend: _sendMessage,
        ),
      ],
    );

    // When embedded as a tab (place filter used inside PlaceDetailScreen keeps
    // its own Scaffold), the 'all' filter tab has no AppBar of its own.
    if (widget.filter == MessagesFilter.all && widget.title == null) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(title: Text(_titleFor(l10n))),
      body: body,
    );
  }

  Future<void> _deleteMessage(Message m) async {
    final ownId = SettingsService.instance.deviceId;
    if (m.deviceId != ownId) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.messageDeleteTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await DatabaseService.instance.softDeleteMessage(m.uuid);
    await _reload();
  }

  Future<void> _sendMessage(String body, List<Uint8List> newPhotos) async {
    final placeUuid = _replyTo?.placeUuid ?? widget.placeUuid;
    if (placeUuid == null) {
      // Without a place there is nothing to anchor to.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.messageNeedsPlace),
          ),
        );
      }
      return;
    }
    final db = DatabaseService.instance;
    final message = Message(
      placeUuid: placeUuid,
      replyToUuid: _replyTo?.uuid,
      body: body,
    );
    await db.insertMessage(message);

    for (final bytes in newPhotos) {
      final photo = PlacePhoto(placeUuid: placeUuid, photoData: bytes);
      final photoUuid = await db.insertPlacePhoto(photo);
      await db.insertMessageAttachment(
        MessageAttachment(messageUuid: message.uuid, photoUuid: photoUuid),
      );
    }

    if (!mounted) return;
    setState(() => _replyTo = null);
    await _reload();
  }
}

// ── Message card ────────────────────────────────────────────────────────────

class _MessageCard extends StatelessWidget {
  final Message message;
  final SavedPlace? place;
  final List<PlacePhoto> photos;
  final bool showPlace;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback? onDeletePhoto;

  const _MessageCard({
    required this.message,
    required this.place,
    required this.photos,
    required this.showPlace,
    required this.onReply,
    required this.onDelete,
    this.onDeletePhoto,
  });

  String _authorLabel(AppLocalizations l10n) {
    final ownId = SettingsService.instance.deviceId;
    if (message.deviceId == ownId) return l10n.messageAuthorSelf;
    if (message.authorName.isNotEmpty) return message.authorName;
    final id = message.deviceId;
    return id.length > 8 ? '${id.substring(0, 8)}…' : id;
  }

  String get _time {
    final dt = DateTime.fromMillisecondsSinceEpoch(message.createdAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final own = message.deviceId == SettingsService.instance.deviceId;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  own ? Icons.person : Icons.person_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  _authorLabel(l10n),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  _time,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
            if (showPlace && place != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(
                      place!.placeType.icon,
                      size: 13,
                      color: theme.hintColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        place!.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (message.replyToUuid != null)
              _ReplyReference(replyToUuid: message.replyToUuid!),
            if (message.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy, size: 16, color: theme.hintColor),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: message.body));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.messageCopied)),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: Text(message.body)),
                  ],
                ),
              ),

            if (photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _MessagePhotoViewer(
                        photo: photos.first,
                        isOwn: own,
                        onDeleted: onDeletePhoto,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      photos.first.photoData,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (own)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(l10n.delete),
                  ),
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply, size: 16),
                  label: Text(l10n.reply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads and renders a compact quote of the referenced (parent) message.
class _ReplyReference extends StatefulWidget {
  final String replyToUuid;
  const _ReplyReference({required this.replyToUuid});

  @override
  State<_ReplyReference> createState() => _ReplyReferenceState();
}

class _ReplyReferenceState extends State<_ReplyReference> {
  Message? _parent;

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.loadMessage(widget.replyToUuid).then((m) {
      if (mounted) setState(() => _parent = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final parent = _parent;
    final text = parent == null
        ? '…'
        : (parent.deletedAt != null
              ? l10n.messageDeleted
              : parent.body.isEmpty
              ? l10n.messagePhotoPlaceholder
              : parent.body);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 14, color: theme.hintColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Composer ────────────────────────────────────────────────────────────────

class _Composer extends StatefulWidget {
  final Message? replyTo;
  final String? defaultPlaceUuid;
  final VoidCallback onCancelReply;
  final Future<void> Function(String body, List<Uint8List> photos) onSend;

  const _Composer({
    required this.replyTo,
    required this.defaultPlaceUuid,
    required this.onCancelReply,
    required this.onSend,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
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

// ── Message photo viewer ─────────────────────────────────────────────────────

class _MessagePhotoViewer extends StatelessWidget {
  final PlacePhoto photo;
  final bool isOwn;
  final VoidCallback? onDeleted;

  const _MessagePhotoViewer({
    required this.photo,
    required this.isOwn,
    this.onDeleted,
  });

  Future<void> _share(BuildContext context) async {
    final bytes = photo.photoData;
    if (bytes.isEmpty) return;
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/share_msg_${photo.uuid}.jpg');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'image/jpeg')]),
    );
  }

  Future<void> _delete(BuildContext context) async {
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
    if (confirmed != true || !context.mounted) return;
    await DatabaseService.instance.softDeletePlacePhoto(photo.uuid);
    if (context.mounted) Navigator.pop(context);
    onDeleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: l10n.sharePhoto,
            onPressed: () => _share(context),
          ),
          if (isOwn)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () => _delete(context),
            ),
        ],
      ),
      body: InteractiveViewer(
        child: Center(
          child: photo.photoData.isNotEmpty
              ? Image.memory(photo.photoData)
              : const Icon(Icons.broken_image, color: Colors.white, size: 64),
        ),
      ),
    );
  }
}
