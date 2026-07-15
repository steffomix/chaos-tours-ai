import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../services/database_service.dart';

class P2pMessagePhotoViewer extends StatelessWidget {
  final Uint8List photoData;
  final String messageUuid;
  final bool isOwn;
  final VoidCallback? onDeleted;

  const P2pMessagePhotoViewer({
    super.key,
    required this.photoData,
    required this.messageUuid,
    required this.isOwn,
    this.onDeleted,
  });

  Future<void> _share(BuildContext context) async {
    if (photoData.isEmpty) return;
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/share_msg_$messageUuid.jpg');
    await file.writeAsBytes(photoData);
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
    await DatabaseService.instance.removeMessagePhoto(messageUuid);
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
          child: photoData.isNotEmpty
              ? Image.memory(photoData)
              : const Icon(Icons.broken_image, color: Colors.white, size: 64),
        ),
      ),
    );
  }
}
