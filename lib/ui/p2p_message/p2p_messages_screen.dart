import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/message.dart';
import '../../models/saved_place.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import 'p2p_message_card.dart';
import 'p2p_message_composer.dart';

/// Scope of the shared [MessagesScreen].
enum MessagesFilter {
  /// All messages across all places, newest first.
  all,

  /// Messages anchored to a single place.
  place,

  /// Messages of all places within a radius around a coordinate.
  region,
}

class TrustedMessage {
  final Message message;
  bool trusted = false;

  TrustedMessage(this.message);

  Future<void> loadTrustedStatus() async {
    final db = DatabaseService.instance;
    final source = await db.loadTrustedSource(message.deviceId);
    trusted = source?.trusted ?? false;
  }
}

/// A single unified screen that renders the P2P message feed in one of three
/// scopes ([MessagesFilter]). Sharing one screen keeps the look consistent and
/// simplifies maintenance. Messages are paginated (chunk-loaded) because the
/// volume can be large.
class MessagesScreen extends StatefulWidget {
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();

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
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const int _chunkSize = 30;

  final ScrollController _scrollCtrl = ScrollController();
  final List<Message> _messages = [];
  final Map<String, SavedPlace> _placeCache = {};

  ValueNotifier<int> trustedStateRefreshNotifier = ValueNotifier(0);

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
                      return P2pMessageCard(
                        message: _messages[i],
                        place: _placeCache[_messages[i].placeUuid],
                        showPlace: widget.filter != MessagesFilter.place,
                        onReply: () => setState(() => _replyTo = _messages[i]),
                        onDelete: () => _deleteMessage(_messages[i]),
                        onDeletePhoto: _reload,
                        refreshTrustedStatus: () async {
                          await DatabaseService.instance
                              .refreshTrustedSources();
                          trustedStateRefreshNotifier.value++;
                        },
                        trustedStateRefreshNotifier:
                            trustedStateRefreshNotifier,
                      );
                    },
                  ),
                ),
        ),
        P2pMessageComposer(
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
      photoData: newPhotos.isNotEmpty ? newPhotos.first : null,
    );
    await db.insertMessage(message);

    if (!mounted) return;
    setState(() => _replyTo = null);
    await _reload();
  }
}
