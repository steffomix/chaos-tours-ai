import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/message.dart';
import '../../../services/database_service.dart';

/// Loads and renders a compact quote of the referenced (parent) message.
class P2pReplyReference extends StatefulWidget {
  final String replyToUuid;
  const P2pReplyReference({super.key, required this.replyToUuid});

  @override
  State<P2pReplyReference> createState() => _P2pReplyReferenceState();
}

class _P2pReplyReferenceState extends State<P2pReplyReference> {
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
