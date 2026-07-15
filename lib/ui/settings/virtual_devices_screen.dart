import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/virtual_device.dart';
import '../../models/trusted_source.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import 'virtual_device_detail_screen.dart';

class VirtualDevicesScreen extends StatefulWidget {
  const VirtualDevicesScreen({super.key});

  @override
  State<VirtualDevicesScreen> createState() => _VirtualDevicesScreenState();
}

class _VirtualDevicesScreenState extends State<VirtualDevicesScreen> {
  List<VirtualDevice> _virtualDevices = [];
  String? _activeUuid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseService.instance.loadAllVirtualDevices();
    final activeUuid = SettingsService.instance.activeVirtualDeviceUuid;
    if (mounted) {
      setState(() {
        _virtualDevices = list;
        _activeUuid = activeUuid;
      });
    }
  }

  Future<void> _createNewVirtualDevice() async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(
      text: '${l10n.sectionVirtualDevices} ${_virtualDevices.length + 1}',
    );
    final deviceNameCtrl = TextEditingController();
    VirtualDevice template = _virtualDevices.isNotEmpty
        ? _virtualDevices.first
        : VirtualDevice(name: '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setInner) {
            final l10n2 = AppLocalizations.of(ctx2)!;
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n2.newVirtualDeviceLabel,
                    ),
                    autofocus: true,
                  ),
                  if (_virtualDevices.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n2.copySettingsFrom,
                      style: const TextStyle(fontSize: 13),
                    ),
                    DropdownButton<VirtualDevice>(
                      isExpanded: true,
                      value: template,
                      items: _virtualDevices
                          .map(
                            (a) =>
                                DropdownMenuItem(value: a, child: Text(a.name)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setInner(() => template = v);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: deviceNameCtrl,
                    maxLength: 20,
                    decoration: InputDecoration(
                      labelText: l10n2.deviceNameLabel,
                      hintText: l10n2.deviceNameHint,
                      helperText: l10n2.deviceNameLengthHint,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2, false),
                  child: Text(l10n2.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx2, true),
                  child: Text(l10n2.create),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;
    final name = nameCtrl.text.trim();
    final deviceNameInput = deviceNameCtrl.text.trim();
    if (name.isEmpty) return;
    if (deviceNameInput.length < 3 || deviceNameInput.length > 20) return;

    const uuid = Uuid();
    final deviceId = '$deviceNameInput@${uuid.v4()}';
    final newA = template.copyWith(
      name: name,
      uuid: '',
      deviceId: deviceId,
      syncExportProtected: false,
      syncImportProtected: false,
    );
    final db = DatabaseService.instance;
    final id = await db.insertVirtualDevice(newA);
    await db.refreshTrustedSources();
    await db.upsertTrustedSource(
      TrustedSource(deviceId: deviceId, trusted: true),
    );
    final created = await db.loadVirtualDevice(id);
    await _load();

    // Navigate directly to the detail screen of the new VirtualDevice.
    if (created != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VirtualDeviceDetailScreen(
            virtualDevice: created,
            activeVirtualDeviceUuid: _activeUuid,
          ),
        ),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.virtualDevicesScreenTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text(
              l10n.newVirtualDeviceCreate,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              await _createNewVirtualDevice();
            },
          ),
          const Divider(),
          if (_virtualDevices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(l10n.noVirtualDevices)),
            )
          else
            ..._virtualDevices.map((a) {
              final isActive = a.uuid == _activeUuid;
              return ListTile(
                leading: Icon(
                  isActive
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(
                  a.name,
                  style: isActive
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
                subtitle: Text(
                  a.deviceId,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (a.syncExportProtected || a.syncImportProtected)
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VirtualDeviceDetailScreen(
                        virtualDevice: a,
                        activeVirtualDeviceUuid: _activeUuid,
                      ),
                    ),
                  );
                  await _load();
                },
              );
            }),
        ],
      ),
    );
  }
}
