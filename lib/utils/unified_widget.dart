import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

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
}
