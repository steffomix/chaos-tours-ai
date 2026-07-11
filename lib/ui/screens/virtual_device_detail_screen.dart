import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/virtual_device.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';

/// Detail screen for a single [VirtualDevice].
///
/// Allows the user to:
///  1. Switch to this VirtualDevice (make it the active one).
///  2. Rename the VirtualDevice.
///  3. Configure private-space sync protection (import / export).
///  4. Purge all database entries associated with this device ID.
///  5. Delete the VirtualDevice (optionally with a database purge).
class VirtualDeviceDetailScreen extends StatefulWidget {
  final VirtualDevice virtualDevice;
  final String? activeVirtualDeviceUuid;

  const VirtualDeviceDetailScreen({
    super.key,
    required this.virtualDevice,
    required this.activeVirtualDeviceUuid,
  });

  @override
  State<VirtualDeviceDetailScreen> createState() =>
      _VirtualDeviceDetailScreenState();
}

class _VirtualDeviceDetailScreenState extends State<VirtualDeviceDetailScreen> {
  late VirtualDevice _virtualDevice;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _virtualDevice = widget.virtualDevice;
    _isActive = _virtualDevice.uuid == widget.activeVirtualDeviceUuid;
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<void> _save(VirtualDevice updated) async {
    await DatabaseService.instance.updateVirtualDevice(updated);
    if (mounted) setState(() => _virtualDevice = updated);
  }

  // ── 1. Switch ─────────────────────────────────────────────────────────────

  Future<void> _switchToThis() async {
    SettingsService.instance.applyVirtualDevice(_virtualDevice);
    if (mounted) {
      setState(() => _isActive = true);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.virtualDeviceDetailTitle(_virtualDevice.name)),
        ),
      );
    }
  }

  // ── 2. Rename ─────────────────────────────────────────────────────────────

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: _virtualDevice.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameVirtualDevice),
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
    if (newName.isEmpty || newName == _virtualDevice.name) return;
    await _save(_virtualDevice.copyWith(name: newName));
    ctrl.dispose();
  }

  // ── 3. Private space toggles ──────────────────────────────────────────────

  Future<void> _toggleExportProtected(bool value) async {
    await _save(_virtualDevice.copyWith(syncExportProtected: value));
    if (_virtualDevice.uuid ==
        SettingsService.instance.activeVirtualDeviceUuid) {
      SettingsService.instance.applyVirtualDevice(
        _virtualDevice.copyWith(syncExportProtected: value),
      );
    }
  }

  Future<void> _toggleImportProtected(bool value) async {
    await _save(_virtualDevice.copyWith(syncImportProtected: value));
    if (_virtualDevice.uuid ==
        SettingsService.instance.activeVirtualDeviceUuid) {
      SettingsService.instance.applyVirtualDevice(
        _virtualDevice.copyWith(syncImportProtected: value),
      );
    }
  }

  // ── 4. Purge data ─────────────────────────────────────────────────────────

  Future<void> _purgeData() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.purgeDataConfirmTitle),
        content: Text(l10n.purgeDataConfirmContent(_virtualDevice.name)),
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
      _virtualDevice.deviceId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.purgeDataSuccess(count))));
  }

  // ── 5. Delete ─────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final allVirtualDevices = await DatabaseService.instance
        .loadAllVirtualDevices();
    if (allVirtualDevices.length <= 1 && mounted) {
      // Don't allow deleting the last VirtualDevice.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteLastVirtualDeviceNotAllowed)),
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
              title: Text(l10n.deleteVirtualDeviceTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.deleteVirtualDeviceContent(_virtualDevice.name)),
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

    // If this is the active VirtualDevice, switch to another before deleting.
    if (_isActive) {
      final next = allVirtualDevices.firstWhere(
        (x) => x.uuid != _virtualDevice.uuid,
      );
      SettingsService.instance.applyVirtualDevice(next);
    }

    if (withCleanup) {
      await DatabaseService.instance.purgeByDeviceId(_virtualDevice.deviceId);
    }
    await DatabaseService.instance.deleteVirtualDevice(_virtualDevice.uuid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.virtualDeviceDeleted(_virtualDevice.name))),
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
        title: Text(l10n.virtualDeviceDetailTitle(_virtualDevice.name)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.renameVirtualDevice,
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
                    l10n.virtualDeviceCurrentlyActive,
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
              _virtualDevice.deviceId,
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () {
              Clipboard.setData(ClipboardData(text: _virtualDevice.deviceId));
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
            title: Text(l10n.switchToVirtualDevice),
            subtitle: Text(l10n.switchToVirtualDeviceSubtitle),
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
              color: _virtualDevice.syncExportProtected
                  ? colorScheme.tertiary
                  : null,
            ),
            title: Text(l10n.protectFromExportLabel),
            subtitle: Text(l10n.protectFromExportSubtitle),
            value: _virtualDevice.syncExportProtected,
            onChanged: _toggleExportProtected,
          ),
          SwitchListTile(
            secondary: Icon(
              Icons.shield_outlined,
              color: _virtualDevice.syncImportProtected
                  ? colorScheme.tertiary
                  : null,
            ),
            title: Text(l10n.protectFromImportLabel),
            subtitle: Text(l10n.protectFromImportSubtitle),
            value: _virtualDevice.syncImportProtected,
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
              l10n.deleteVirtualDeviceLabel(_virtualDevice.name),
              style: const TextStyle(color: Colors.red),
            ),
            subtitle: Text(l10n.deleteVirtualDevice),
            onTap: _delete,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
