import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/aktivitaet.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';

/// Detail screen for a single [Aktivitaet].
///
/// Allows the user to:
///  1. Switch to this Aktivitaet (make it the active one).
///  2. Rename the Aktivitaet.
///  3. Configure private-space sync protection (import / export).
///  4. Purge all database entries associated with this device ID.
///  5. Delete the Aktivitaet (optionally with a database purge).
class AktivitaetDetailScreen extends StatefulWidget {
  final Aktivitaet aktivitaet;
  final String? activeAktivitaetUuid;

  const AktivitaetDetailScreen({
    super.key,
    required this.aktivitaet,
    required this.activeAktivitaetUuid,
  });

  @override
  State<AktivitaetDetailScreen> createState() => _AktivitaetDetailScreenState();
}

class _AktivitaetDetailScreenState extends State<AktivitaetDetailScreen> {
  late Aktivitaet _aktivitaet;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _aktivitaet = widget.aktivitaet;
    _isActive = _aktivitaet.uuid == widget.activeAktivitaetUuid;
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<void> _save(Aktivitaet updated) async {
    await DatabaseService.instance.updateAktivitaet(updated);
    if (mounted) setState(() => _aktivitaet = updated);
  }

  // ── 1. Switch ─────────────────────────────────────────────────────────────

  Future<void> _switchToThis() async {
    SettingsService.instance.applyAktivitaet(_aktivitaet);
    if (mounted) {
      setState(() => _isActive = true);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aktivitaetDetailTitle(_aktivitaet.name))),
      );
    }
  }

  // ── 2. Rename ─────────────────────────────────────────────────────────────

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: _aktivitaet.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameActivity),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: l10n.name),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    final newName = ctrl.text.trim();
    if (confirmed != true || !mounted) return;
    if (newName.isEmpty || newName == _aktivitaet.name) return;
    await _save(_aktivitaet.copyWith(name: newName));
    ctrl.dispose();
  }

  // ── 3. Private space toggles ──────────────────────────────────────────────

  Future<void> _toggleExportProtected(bool value) async {
    await _save(_aktivitaet.copyWith(syncExportProtected: value));
  }

  Future<void> _toggleImportProtected(bool value) async {
    await _save(_aktivitaet.copyWith(syncImportProtected: value));
  }

  // ── 4. Purge data ─────────────────────────────────────────────────────────

  Future<void> _purgeData() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.purgeDataConfirmTitle),
        content: Text(l10n.purgeDataConfirmContent(_aktivitaet.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.purgeDataLabel,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final count = await DatabaseService.instance.purgeByDeviceId(
      _aktivitaet.deviceId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.purgeDataSuccess(count))));
  }

  // ── 5. Delete ─────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final allAktivitaeten = await DatabaseService.instance
        .loadAllAktivitaeten();
    if (allAktivitaeten.length <= 1 && mounted) {
      // Don't allow deleting the last aktivitaet.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die letzte Aktivität kann nicht gelöscht werden.'),
        ),
      );
      return;
    }

    bool withCleanup = false;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setInner) {
            return AlertDialog(
              title: Text(l10n.deleteActivityTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.deleteActivityContent(_aktivitaet.name)),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.deleteWithCleanupCheckbox),
                    subtitle: Text(
                      l10n.deleteWithCleanupCheckboxSubtitle,
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: withCleanup,
                    onChanged: (v) => setInner(() => withCleanup = v ?? false),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2, false),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx2, true),
                  child: Text(
                    l10n.delete,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    // If this is the active aktivitaet, switch to another before deleting.
    if (_isActive) {
      final next = allAktivitaeten.firstWhere(
        (x) => x.uuid != _aktivitaet.uuid,
      );
      SettingsService.instance.applyAktivitaet(next);
    }

    if (withCleanup) {
      await DatabaseService.instance.purgeByDeviceId(_aktivitaet.deviceId);
    }
    await DatabaseService.instance.deleteAktivitaet(_aktivitaet.uuid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.activityDeleted(_aktivitaet.name))),
      );
      Navigator.pop(context);
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aktivitaetDetailTitle(_aktivitaet.name)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.renameActivity,
            onPressed: _rename,
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Info ─────────────────────────────────────────────────────────
          if (_isActive)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    size: 16,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.activityCurrentlyActive,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(l10n.deviceId),
            subtitle: Text(
              _aktivitaet.deviceId,
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () {
              Clipboard.setData(ClipboardData(text: _aktivitaet.deviceId));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.deviceIdCopied)));
            },
          ),
          const Divider(),

          // ── 1. Switch ────────────────────────────────────────────────────
          ListTile(
            leading: Icon(
              Icons.swap_horiz,
              color: _isActive ? Colors.grey : colorScheme.primary,
            ),
            title: Text(l10n.switchToActivity),
            subtitle: Text(l10n.switchToActivitySubtitle),
            enabled: !_isActive,
            onTap: _isActive ? null : _switchToThis,
          ),
          const Divider(),

          // ── 2. Privater Bereich ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.privateSpaceSection,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            secondary: Icon(
              Icons.cloud_off,
              color: _aktivitaet.syncExportProtected
                  ? colorScheme.tertiary
                  : null,
            ),
            title: Text(l10n.protectFromExportLabel),
            subtitle: Text(l10n.protectFromExportSubtitle),
            value: _aktivitaet.syncExportProtected,
            onChanged: _toggleExportProtected,
          ),
          SwitchListTile(
            secondary: Icon(
              Icons.shield_outlined,
              color: _aktivitaet.syncImportProtected
                  ? colorScheme.tertiary
                  : null,
            ),
            title: Text(l10n.protectFromImportLabel),
            subtitle: Text(l10n.protectFromImportSubtitle),
            value: _aktivitaet.syncImportProtected,
            onChanged: _toggleImportProtected,
          ),
          const Divider(),

          // ── 3. Datenbank säubern ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Datenbank',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(l10n.purgeDataLabel),
            subtitle: Text(l10n.purgeDataSubtitle),
            onTap: _purgeData,
          ),
          const Divider(),

          // ── 4. Löschen ────────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(
              l10n.deleteActivityLabel(_aktivitaet.name),
              style: const TextStyle(color: Colors.red),
            ),
            subtitle: Text(l10n.deleteActivity),
            onTap: _delete,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
