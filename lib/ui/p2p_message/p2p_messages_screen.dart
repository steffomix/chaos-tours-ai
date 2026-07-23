import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/message.dart';
import '../../models/saved_place.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../utils/data_observer.dart';
import 'p2p_message_card.dart';
import 'p2p_message_composer.dart';

/// Scope of the shared [MessagesScreen].
enum MessagesListMode {
  /// All messages across all places, newest first.
  all,

  /// Messages anchored to a single place.
  place,

  /// Messages of all places within a radius around a coordinate.
  region,
}

/// A single unified screen that renders the P2P message feed in one of three
/// scopes ([MessagesListMode]). Sharing one screen keeps the look consistent and
/// simplifies maintenance. Messages are paginated (chunk-loaded) because the
/// volume can be large.
class MessagesScreen extends StatefulWidget {
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();

  final MessagesListMode messagesListMode;

  /// Required when [messagesListMode] is [MessagesListMode.place].
  final SavedPlace? place;

  /// Required when [messagesListMode] is [MessagesListMode.region].
  final double? lat;
  final double? lng;
  final double? radiusKm;

  /// Optional title override.
  final String? title;

  const MessagesScreen({
    super.key,
    this.messagesListMode = MessagesListMode.all,
    this.place,
    this.lat,
    this.lng,
    this.radiusKm,
    this.title,
  });

  const MessagesScreen.place({
    super.key,
    required SavedPlace this.place,
    this.title,
  }) : messagesListMode = MessagesListMode.place,
       lat = null,
       lng = null,
       radiusKm = null;

  const MessagesScreen.region({
    super.key,
    required double this.lat,
    required double this.lng,
    required double this.radiusKm,
    this.title,
  }) : messagesListMode = MessagesListMode.region,
       place = null;
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const int _chunkSize = 30;

  final ScrollController _scrollCtrl = ScrollController();
  final List<Message> _messages = [];
  final Map<String, SavedPlace> _placeCache = {};

  final SavedPlaceObserver _savedPlaceObserver = SavedPlaceObserver();

  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;

  Message? _replyTo;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _savedPlaceObserver.addListener(_onSavedPlaceChanged);
    _loadNextChunk();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _savedPlaceObserver.removeListener(_onSavedPlaceChanged);
    super.dispose();
  }

  void _onSavedPlaceChanged() {
    if (widget.messagesListMode == MessagesListMode.place &&
        _savedPlaceObserver.data == null) {
      if (mounted) {
        Navigator.pushNamed(context, '/places').then((value) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
        return;
      }
    }
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
    switch (widget.messagesListMode) {
      case MessagesListMode.all:
        return db.loadMessagesPaged(limit: _chunkSize, offset: offset);
      case MessagesListMode.place:
        return db.loadMessagesForPlace(
          widget.place!.uuid,
          limit: _chunkSize,
          offset: offset,
        );
      case MessagesListMode.region:
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
    final hydratedChunk = await _hydrateAndClean(chunk);
    if (!mounted) return;
    setState(() {
      _messages.addAll(hydratedChunk);
      _offset += hydratedChunk.length;
      _hasMore = hydratedChunk.length == _chunkSize;
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

  /// Loads place of the messages in the chunk and removes messages with missing places.
  Future<List<Message>> _hydrateAndClean(List<Message> chunk) async {
    final db = DatabaseService.instance;
    List<Message> brokenMessages = [];
    for (final m in chunk) {
      if (!_placeCache.containsKey(m.placeUuid)) {
        final place = await db.getSavedPlace(m.placeUuid);

        if (place != null) {
          _placeCache[m.placeUuid] = place;
        } else {
          brokenMessages.add(m);
        }
      }
    }
    for (final m in brokenMessages) {
      chunk.remove(m);
    }
    return chunk;
  }

  String _titleFor(AppLocalizations l10n) {
    if (widget.title != null) return widget.title!;
    switch (widget.messagesListMode) {
      case MessagesListMode.all:
        return l10n.messagesTitle;
      case MessagesListMode.place:
        return _placeCache[widget.place!.uuid]?.name ?? l10n.messagesPlaceTitle;
      case MessagesListMode.region:
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
                      SavedPlace? pl = _placeCache[_messages[i].placeUuid];
                      if (pl == null) {
                        return const SizedBox.shrink(); // Place not found, skip rendering this message
                      }
                      return P2pMessageCard(
                        message: _messages[i],
                        place: pl,
                        messagesListMode: widget.messagesListMode,
                        onReply: () => setState(() => _replyTo = _messages[i]),
                        onDelete: () => _deleteMessage(_messages[i]),
                        onDeletePhoto: _reload,
                        onPlaceUpdated: _reload,
                        onPlaceDeleted: () => Navigator.of(context).pop(),
                      );
                    },
                  ),
                ),
        ),
        P2pMessageComposer(
          replyTo: _replyTo,
          defaultPlaceUuid: widget.place?.uuid,
          onCancelReply: () => setState(() => _replyTo = null),
          onSend: _sendMessage,
        ),
      ],
    );

    // When embedded as a tab (place filter used inside PlaceDetailScreen keeps
    // its own Scaffold), the 'all' filter tab has no AppBar of its own.
    if (widget.messagesListMode == MessagesListMode.all &&
        widget.title == null) {
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
    final placeUuid = _replyTo?.placeUuid ?? widget.place?.uuid;
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
      photoData: newPhotos.isNotEmpty ? newPhotos.first : null,
    );
    await db.insertMessage(message);

    if (!mounted) return;
    setState(() => _replyTo = null);
    await _reload();
  }
}
