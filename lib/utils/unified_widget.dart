import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UnifiedWidget {
  final BuildContext context;
  UnifiedWidget(this.context);

  Row namedDivider(String name) => Row(
    children: [
      Expanded(child: Divider(color: Colors.grey[400])),
      const SizedBox(width: 8),
      Text(
        name,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: Colors.grey[400])),
    ],
  );

  FilledButton saveButton({required VoidCallback onPressed}) => FilledButton(
    onPressed: onPressed,
    child: Text(AppLocalizations.of(context)!.save),
  );

  TextButton deleteButton({required VoidCallback onPressed}) => TextButton(
    onPressed: onPressed,
    child: Text(AppLocalizations.of(context)!.delete),
  );

  TextButton cancelButton({required VoidCallback onPressed}) => TextButton(
    onPressed: onPressed,
    child: Text(AppLocalizations.of(context)!.cancel),
  );

  Row saveAndDeleteButtonsRow({
    required VoidCallback onSavePressed,
    required VoidCallback onDeletePressed,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      deleteButton(onPressed: onDeletePressed),
      saveButton(onPressed: onSavePressed),
    ],
  );

  Row saveAndCancelButtonsRow({
    required VoidCallback onSavePressed,
    required VoidCallback onCancelPressed,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      cancelButton(onPressed: onCancelPressed),
      saveButton(onPressed: onSavePressed),
    ],
  );

  List<Widget> saveAndCancelButtonsList({
    required VoidCallback onSavePressed,
    required VoidCallback onCancelPressed,
  }) => [
    cancelButton(onPressed: onCancelPressed),
    saveButton(onPressed: onSavePressed),
  ];

  List<Widget> saveAndDeleteButtonsList({
    required VoidCallback onSavePressed,
    required VoidCallback onDeletePressed,
  }) => [
    deleteButton(onPressed: onDeletePressed),
    saveButton(onPressed: onSavePressed),
  ];

  Widget markdownText(String text, {bool expanded = false}) {
    final mdWidget = MarkdownBody(
      data: text,
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href));
        }
      },
      imageBuilder: (uri, title, alt) {
        return Image.network(
          uri.toString(),
          errorBuilder: (ctx, err, stack) =>
              const Icon(Icons.broken_image, color: Colors.red),
        );
      },
    );
    return expanded ? Expanded(child: mdWidget) : mdWidget;
  }
}
