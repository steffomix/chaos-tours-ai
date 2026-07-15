// ── Edit sheet (metadata only) ────────────────────────────────────────────────

import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../models/trusted_source.dart';
import '../../../models/virtual_device.dart';
import '../../../services/database_service.dart';
import '../../../services/settings_service.dart';
import '../../../utils/unified_widget.dart';

class TrustedSourceEditSheet extends StatefulWidget {
  final TrustedSource source;
  const TrustedSourceEditSheet({super.key, required this.source});

  @override
  State<TrustedSourceEditSheet> createState() => TrustedSourceEditSheetState();
}

class TrustedSourceEditSheetState extends State<TrustedSourceEditSheet> {
  late final TextEditingController _noteCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  bool _trusted = false;
  bool _trustedChanged = false;
  bool _creatingDevice = false;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _trusted = s.trusted;
    _noteCtrl = TextEditingController(text: s.note);
    _urlCtrl = TextEditingController(text: s.url);
    _emailCtrl = TextEditingController(text: s.email);
    _addressCtrl = TextEditingController(text: s.address);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _urlCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final result = widget.source.copyWith(
      note: _noteCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      trusted: _trustedChanged ? _trusted : widget.source.trusted,
    );
    Navigator.pop(context, result);
  }

  Future<void> _createVirtualDevice() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _creatingDevice = true);
    try {
      final deviceId = widget.source.deviceId;
      final all = await DatabaseService.instance.loadAllVirtualDevices();
      if (!mounted) return;
      if (all.any((v) => v.deviceId == deviceId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.virtualDeviceAlreadyExistsForSource)),
        );
        return;
      }
      final activeUuid = SettingsService.instance.activeVirtualDeviceUuid;
      final template =
          all.where((v) => v.uuid == activeUuid).firstOrNull ?? all.firstOrNull;
      final name = _noteCtrl.text.trim().isNotEmpty
          ? _noteCtrl.text.trim()
          : deviceId;
      final VirtualDevice newDevice;
      if (template != null) {
        newDevice = template.copyWith(uuid: '', name: name, deviceId: deviceId);
      } else {
        newDevice = VirtualDevice(name: name, deviceId: deviceId);
      }
      await DatabaseService.instance.insertVirtualDevice(newDevice);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.virtualDeviceCreatedFromTemplate)),
      );
    } finally {
      if (mounted) setState(() => _creatingDevice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.editTrustedSource,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            ListTile(
              title: Text(
                l10n.trustedDevicesSection,
                style:
                    widget.source.deviceId == SettingsService.instance.deviceId
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
              ),
              subtitle: Text(
                widget.source.deviceId,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Switch(
                value: _trusted,
                onChanged: (_) async {
                  setState(() {
                    _trusted = !_trusted;
                    _trustedChanged = true;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: l10n.notes,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.email,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: l10n.address,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _creatingDevice ? null : _createVirtualDevice,
              icon: _creatingDevice
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.devices_other),
              label: Text(l10n.createVirtualDeviceForSource),
            ),
            const SizedBox(height: 12),
            UnifiedWidget(context).saveAndCancelButtonsRow(
              onSavePressed: _save,
              onCancelPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
