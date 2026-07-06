import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/aktivitaet.dart';
import '../../models/trusted_source.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import 'aktivitaet_detail_screen.dart';

class AktivitaetenScreen extends StatefulWidget {
  const AktivitaetenScreen({super.key});

  @override
  State<AktivitaetenScreen> createState() => _AktivitaetenScreenState();
}

class _AktivitaetenScreenState extends State<AktivitaetenScreen> {
  List<Aktivitaet> _aktivitaeten = [];
  String? _activeUuid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseService.instance.loadAllAktivitaeten();
    final activeUuid = SettingsService.instance.activeAktivitaetUuid;
    if (mounted) {
      setState(() {
        _aktivitaeten = list;
        _activeUuid = activeUuid;
      });
    }
  }

  Future<void> _createNewAktivitaet() async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(
      text: '${l10n.sectionActivity} ${_aktivitaeten.length + 1}',
    );
    final deviceNameCtrl = TextEditingController();
    Aktivitaet template = _aktivitaeten.isNotEmpty
        ? _aktivitaeten.first
        : Aktivitaet(name: '');

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
                      labelText: l10n2.newActivityLabel,
                    ),
                    autofocus: true,
                  ),
                  if (_aktivitaeten.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n2.copySettingsFrom,
                      style: const TextStyle(fontSize: 13),
                    ),
                    DropdownButton<Aktivitaet>(
                      isExpanded: true,
                      value: template,
                      items: _aktivitaeten
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
    final id = await db.insertAktivitaet(newA);
    await db.refreshTrustedSources();
    await db.upsertTrustedSource(
      TrustedSource(deviceId: deviceId, trusted: true),
    );
    final created = await db.loadAktivitaet(id);
    await _load();

    // Navigate directly to the detail screen of the new aktivitaet.
    if (created != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AktivitaetDetailScreen(
            aktivitaet: created,
            activeAktivitaetUuid: _activeUuid,
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
      appBar: AppBar(title: Text(l10n.aktivitaetenScreenTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text(
              l10n.newActivityCreate,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              await _createNewAktivitaet();
            },
          ),
          const Divider(),
          if (_aktivitaeten.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(l10n.noActivity)),
            )
          else
            ..._aktivitaeten.map((a) {
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
                      builder: (_) => AktivitaetDetailScreen(
                        aktivitaet: a,
                        activeAktivitaetUuid: _activeUuid,
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
