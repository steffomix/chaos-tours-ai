import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/message.dart';
import '../../models/saved_place.dart';
import '../../models/trusted_source.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../utils/unified_widget.dart';
import '../place/place_detail_screen.dart';
import '../settings/trusted_source_edit_sheet.dart';
import 'p2p_message_photo_viewer.dart';
import 'p2p_messages_screen.dart';
import 'p2p_reply_reference.dart';

class P2pMessageCard extends StatefulWidget {
  final Message message;
  final SavedPlace place;
  final MessagesListMode messagesListMode;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback? onDeletePhoto;

  const P2pMessageCard({
    super.key,
    required this.message,
    required this.place,
    required this.messagesListMode,
    required this.onReply,
    required this.onDelete,
    this.onDeletePhoto,
  });

  @override
  State<P2pMessageCard> createState() => _P2pMessageCardState();
}

class _P2pMessageCardState extends State<P2pMessageCard> {
  final ValueNotifier<bool?> _ownDeviceIdNotifier = ValueNotifier(null);
  final ValueNotifier<TrustedSource?> _trustedSourceNotifier = ValueNotifier(
    null,
  );
  final TrustedSourceObserver _trustedSourceObserver = TrustedSourceObserver();

  @override
  void initState() {
    super.initState();
    _trustedSourceObserver.addListener(_onTrustedSourceChanged);
  }

  @override
  void dispose() {
    _trustedSourceObserver.removeListener(_onTrustedSourceChanged);
    _ownDeviceIdNotifier.dispose();
    _trustedSourceNotifier.dispose();
    super.dispose();
  }

  void _onTrustedSourceChanged() {
    if (_trustedSourceObserver.trustedSource?.deviceId !=
        widget.message.deviceId) {
      return;
    }
    _trustedSourceNotifier.value = _trustedSourceObserver.trustedSource;
    _ownDeviceIdNotifier.value =
        widget.message.deviceId == SettingsService.instance.deviceId;
  }

  Future<void> _loadTrustedStatus() async {
    _trustedSourceNotifier.value = await DatabaseService.instance
        .loadTrustedSource(widget.message.deviceId);
    _ownDeviceIdNotifier.value =
        widget.message.deviceId == SettingsService.instance.deviceId;
  }

  String _authorLabel(AppLocalizations l10n) {
    final id = widget.message.deviceId;
    if (id.contains('@')) {
      return id.split('@').first;
    }
    return id.length > 16 ? '${id.substring(0, 16)}…' : id;
  }

  String get _time {
    final dt = DateTime.fromMillisecondsSinceEpoch(widget.message.createdAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _editTrustedSource() async {
    final deviceId = widget.message.deviceId;
    if (_trustedSourceNotifier.value == null) {
      await DatabaseService.instance.refreshTrustedSources();
    }
    final source = await DatabaseService.instance.loadTrustedSource(deviceId);
    if (source != null) {
      if (!mounted) return;
      final result = await showModalBottomSheet<TrustedSource>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => TrustedSourceEditSheet(source: source),
      );
      if (result != null) {
        await DatabaseService.instance.upsertTrustedSource(result);
        _trustedSourceObserver.trustedSource = result;
      }
      // Refresh trust status after sheet is closed.
      _loadTrustedStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadTrustedStatus();
    final l10n = AppLocalizations.of(context)!;
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
                OutlinedButton(
                  onPressed: _editTrustedSource,
                  child: Row(
                    children: [
                      ValueListenableBuilder<bool?>(
                        valueListenable: _ownDeviceIdNotifier,
                        builder: (context, ownDeviceId, _) {
                          if (ownDeviceId == true) {
                            return Icon(Icons.phone_android, size: 16);
                          } else {
                            return SizedBox(width: 16, height: 16);
                          }
                        },
                      ),
                      ValueListenableBuilder(
                        valueListenable: _trustedSourceNotifier,
                        builder: (context, trustedSource, _) {
                          return Icon(
                            trustedSource == null
                                ? Icons.help_outline
                                : trustedSource.trusted == true
                                ? Icons.security
                                : Icons.warning,
                            color: trustedSource?.trusted == true
                                ? Colors.green
                                : Colors.red,
                            size: 16,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 10,
                  child: OutlinedButton.icon(
                    icon: null,
                    onPressed: () {
                      if (widget.messagesListMode == MessagesListMode.all) {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                MessagesScreen.place(place: widget.place),
                          ),
                        );
                      }

                      // TODO copy from places_screen.dart Line 406 does not work from here
                      if (widget.messagesListMode == MessagesListMode.place) {
                        // Navigator.of(context).push(
                        //   MaterialPageRoute<void>(
                        //     builder: (_) => PlaceDetailScreen(
                        //       place: place,
                        //       onUpdated: _loadPlaces,
                        //       onDeleted: _loadPlaces,
                        //       onShowOnMap: () => _showOnMap(place),
                        //     ),
                        //   ),
                        // );

                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PlaceDetailScreen(
                              place: widget.place,
                              onUpdated: () {},
                              onDeleted: () {},
                              onShowOnMap: () {},
                            ),
                          ),
                        );
                      }
                    },
                    label: Text(
                      _authorLabel(l10n),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
            if (widget.messagesListMode == MessagesListMode.place)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(
                      widget.place.placeType.icon,
                      size: 13,
                      color: theme.hintColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.place.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.message.replyToUuid != null)
              P2pReplyReference(replyToUuid: widget.message.replyToUuid!),
            if (widget.message.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy, size: 16, color: theme.hintColor),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.message.body),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.messageCopied)),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    UnifiedWidget(
                      context,
                    ).markdownText(widget.message.body, expanded: true),
                  ],
                ),
              ),

            if (widget.message.photoData.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => P2pMessagePhotoViewer(
                        photoData: widget.message.photoData,
                        messageUuid: widget.message.uuid,
                        isOwn: _ownDeviceIdNotifier.value == true,
                        onDeleted: widget.onDeletePhoto,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      widget.message.photoData,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          UnifiedWidget(
                            context,
                          ).fotoError(widget.message.photoData),
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(l10n.delete),
                ),
                TextButton.icon(
                  onPressed: widget.onReply,
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
