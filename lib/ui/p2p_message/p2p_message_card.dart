import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/message.dart';
import '../../models/saved_place.dart';
import '../../models/trusted_source.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../utils/unified_widget.dart';
import '../settings/trusted_source_edit_sheet.dart';
import 'p2p_message_photo_viewer.dart';
import 'p2p_reply_reference.dart';

class P2pMessageCard extends StatefulWidget {
  final Message message;
  final SavedPlace? place;
  final bool showPlace;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback? onDeletePhoto;
  final VoidCallback refreshTrustedStatus;
  final ValueNotifier<int> trustedStateRefreshNotifier;

  const P2pMessageCard({
    super.key,
    required this.message,
    required this.place,
    required this.showPlace,
    required this.onReply,
    required this.onDelete,
    required this.refreshTrustedStatus,
    required this.trustedStateRefreshNotifier,
    this.onDeletePhoto,
  });

  @override
  State<P2pMessageCard> createState() => _P2pMessageCardState();
}

class _P2pMessageCardState extends State<P2pMessageCard> {
  bool? _trusted;
  bool _ownDeviceId = false;

  @override
  void initState() {
    super.initState();
    _ownDeviceId = SettingsService.instance.deviceId == widget.message.deviceId;
    _loadTrustedStatus();
    widget.trustedStateRefreshNotifier.addListener(_onRefreshTrustedStatus);
  }

  @override
  void dispose() {
    widget.trustedStateRefreshNotifier.removeListener(_onRefreshTrustedStatus);
    super.dispose();
  }

  Future<void> _onRefreshTrustedStatus() async {
    await _loadTrustedStatus();

    setState(() {});
  }

  Future<void> _loadTrustedStatus() async {
    final source = await DatabaseService.instance.loadTrustedSource(
      widget.message.deviceId,
    );
    if (mounted) {
      setState(() => _trusted = source?.trusted);
    }
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
    final db = DatabaseService.instance;
    if (_trusted == null) {
      widget.refreshTrustedStatus();
      return;
    }
    final deviceId = widget.message.deviceId;
    final source = await db.loadTrustedSource(deviceId);
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
        widget.trustedStateRefreshNotifier.value++;
      }
      // Refresh trust status after sheet is closed.
      _loadTrustedStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                if (_ownDeviceId)
                  Icon(Icons.phone_android, color: Colors.green)
                else
                  SizedBox(width: 24),
                const SizedBox(width: 4),
                Expanded(
                  flex: 10,
                  child: OutlinedButton.icon(
                    icon: _trusted == null
                        ? Icon(Icons.question_mark, color: theme.hintColor)
                        : Icon(
                            _trusted! ? Icons.security : Icons.warning,
                            color: _trusted! ? Colors.green : Colors.red,
                          ),
                    onPressed: _editTrustedSource,
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
            if (widget.showPlace && widget.place != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(
                      widget.place!.placeType.icon,
                      size: 13,
                      color: theme.hintColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.place!.name,
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
                        isOwn: _ownDeviceId,
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
