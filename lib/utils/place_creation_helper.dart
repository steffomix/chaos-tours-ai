import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart';

import '../models/saved_place.dart';
import '../services/database_service.dart';
import '../services/nominatim_service.dart';
import '../services/settings_service.dart';
import '../ui/p2p_message/p2p_messages_screen.dart';
import 'maidenhead.dart';
import 'unified_widget.dart';

/// Handles a long-press on any map. Offers the user a choice between creating a
/// new place (from tap, GPS coordinates, or Maidenhead locator) and viewing the
/// P2P messages of the surrounding region.
Future<void> handleMapLongPress(
  BuildContext context,
  TapPosition tapPosition,
  LatLng latlng, {
  required Future<void> Function() onCreated,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_location_alt),
              title: Text(l10n.createPlace),
              onTap: () => Navigator.pop(ctx, 'create'),
            ),
            ListTile(
              leading: const Icon(Icons.gps_fixed),
              title: Text(l10n.createPlaceFromGps),
              onTap: () => Navigator.pop(ctx, 'gps'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: Text(l10n.createPlaceFromMaidenhead),
              onTap: () => Navigator.pop(ctx, 'maidenhead'),
            ),
            if (SettingsService.instance.messengerEnabled)
              ListTile(
                leading: const Icon(Icons.forum),
                title: Text(l10n.showRegionMessages),
                onTap: () => Navigator.pop(ctx, 'region'),
              ),
          ],
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'create':
      return createPlaceFromLongPress(
        context,
        tapPosition,
        latlng,
        onCreated: onCreated,
      );
    case 'gps':
      return createPlaceFromGps(context, onCreated: onCreated);
    case 'maidenhead':
      return createPlaceFromMaidenhead(context, onCreated: onCreated);
    case 'region':
      final radius = await _askRegionRadiusKm(context);
      if (radius == null || !context.mounted) return;
      SettingsService.instance.regionMessageRadiusKm = radius;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MessagesScreen.region(
            lat: latlng.latitude,
            lng: latlng.longitude,
            radiusKm: radius,
          ),
        ),
      );
  }
}

/// Prompts for a search radius in kilometres, prefilled from settings.
Future<double?> _askRegionRadiusKm(BuildContext context) async {
  final ctrl = TextEditingController(
    text: SettingsService.instance.regionMessageRadiusKm.toString().replaceAll(
      RegExp(r'\.0$'),
      '',
    ),
  );
  return showDialog<double>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return AlertDialog(
        title: Text(l10n.regionRadiusTitle),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.radiusInKm,
            suffixText: 'km',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: Text(l10n.showAction),
          ),
        ],
      );
    },
  );
}

/// Shows a dialog to create a new [SavedPlace] at [latlng] via long-press.
/// Calls [onCreated] after the place has been inserted into the database.
Future<void> createPlaceFromLongPress(
  BuildContext context,
  TapPosition _,
  LatLng latlng, {
  required Future<void> Function() onCreated,
}) async {
  // Optionally pre-fill the name with the reverse-geocoded address so the user
  // can edit it before saving.
  String prefillName = '';
  if (SettingsService.instance.addressOnManualCreate) {
    final address = await NominatimService.instance.reverseGeocode(
      latlng.latitude,
      latlng.longitude,
    );
    if (address != null) prefillName = address;
  }
  if (!context.mounted) return;
  final nameController = TextEditingController(text: prefillName);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final ctxL10n = AppLocalizations.of(ctx)!;
      return AlertDialog(
        title: Text(ctxL10n.newPlaceTitle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: ctxL10n.name),
          autofocus: true,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: UnifiedWidget(context).saveAndCancelButtonsList(
          onSavePressed: () => Navigator.pop(ctx, true),
          onCancelPressed: () => Navigator.pop(ctx, false),
        ),
      );
    },
  );
  if (confirmed != true) return;
  final name = nameController.text.trim();
  if (name.isEmpty) return;

  final newPlace = SavedPlace(
    name: name,
    lat: latlng.latitude,
    lng: latlng.longitude,
    groupUuid: SettingsService.instance.defaultPlaceGroupUuid,
  );
  await DatabaseService.instance.insertPlace(newPlace);
  await onCreated();
}

// ── GPS coordinate creation ───────────────────────────────────────────────

/// Shows a bottom sheet for entering GPS coordinates manually and creating a
/// new [SavedPlace] at the given position.
Future<void> createPlaceFromGps(
  BuildContext context, {
  required Future<void> Function() onCreated,
}) async {
  final result = await showModalBottomSheet<({LatLng coords, String name})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => const _GpsInputSheet(),
  );
  if (result == null || !context.mounted) return;
  final newPlace = SavedPlace(
    name: result.name,
    lat: result.coords.latitude,
    lng: result.coords.longitude,
    groupUuid: SettingsService.instance.defaultPlaceGroupUuid,
  );
  await DatabaseService.instance.insertPlace(newPlace);
  await onCreated();
}

class _GpsInputSheet extends StatefulWidget {
  const _GpsInputSheet();

  @override
  State<_GpsInputSheet> createState() => _GpsInputSheetState();
}

class _GpsInputSheetState extends State<_GpsInputSheet> {
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  LatLng? _parsed;

  void _parseCoords() {
    final lat = double.tryParse(_latCtrl.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(_lonCtrl.text.trim().replaceAll(',', '.'));
    setState(() {
      if (lat != null &&
          lon != null &&
          lat >= -90.0 &&
          lat <= 90.0 &&
          lon >= -180.0 &&
          lon <= 180.0) {
        _parsed = LatLng(lat, lon);
      } else {
        _parsed = null;
      }
    });
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canCreate = _parsed != null && _nameCtrl.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.createPlaceFromGps,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _latCtrl,
            decoration: InputDecoration(
              labelText: l10n.latitude,
              hintText: '−90 … 90',
              suffixText: '°',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
            ],
            onChanged: (_) => _parseCoords(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lonCtrl,
            decoration: InputDecoration(
              labelText: l10n.longitude,
              hintText: '−180 … 180',
              suffixText: '°',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
            ],
            onChanged: (_) => _parseCoords(),
          ),
          const SizedBox(height: 8),
          if (_parsed != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${_parsed!.latitude.toStringAsFixed(6)}, '
                '${_parsed!.longitude.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: l10n.name,
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canCreate
                ? () => Navigator.pop(context, (
                    coords: _parsed!,
                    name: _nameCtrl.text.trim(),
                  ))
                : null,
            child: Text(l10n.createPlace),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Maidenhead locator creation ───────────────────────────────────────────

/// Opens a full-screen form for entering a Maidenhead locator and creating a
/// new [SavedPlace] with a deterministic UUID v5 derived from that locator.
Future<void> createPlaceFromMaidenhead(
  BuildContext context, {
  required Future<void> Function() onCreated,
}) async {
  final result =
      await Navigator.push<({LatLng coords, String name, String uuid})>(
        context,
        MaterialPageRoute<({LatLng coords, String name, String uuid})>(
          builder: (_) => const _MaidenheadCreationScreen(),
        ),
      );
  if (result == null || !context.mounted) return;
  final newPlace = SavedPlace(
    uuid: result.uuid,
    name: result.name,
    lat: result.coords.latitude,
    lng: result.coords.longitude,
    groupUuid: SettingsService.instance.defaultPlaceGroupUuid,
  );
  await DatabaseService.instance.insertPlace(newPlace);
  await onCreated();
}

class _MaidenheadCreationScreen extends StatefulWidget {
  const _MaidenheadCreationScreen();

  @override
  State<_MaidenheadCreationScreen> createState() =>
      _MaidenheadCreationScreenState();
}

class _MaidenheadCreationScreenState extends State<_MaidenheadCreationScreen> {
  /// One controller per Maidenhead section (6 sections × 2 chars each).
  final List<TextEditingController> _ctrls = List.generate(
    6,
    (_) => TextEditingController(),
  );

  /// 6 focus nodes for the section inputs + 1 for the name field.
  final List<FocusNode> _focusNodes = List.generate(7, (_) => FocusNode());

  final _nameCtrl = TextEditingController();

  late final List<List<TextInputFormatter>> _formatters;

  String _locator = '';
  LatLng? _coords;

  @override
  void initState() {
    super.initState();
    _formatters = [
      [_UpperCaseFilterFormatter(RegExp(r'[A-R]'))], // section 0: field A-R
      [FilteringTextInputFormatter.digitsOnly], // section 1: square 0-9
      [_UpperCaseFilterFormatter(RegExp(r'[A-X]'))], // section 2: subsquare A-X
      [FilteringTextInputFormatter.digitsOnly], // section 3: ext. square 0-9
      [
        _UpperCaseFilterFormatter(RegExp(r'[A-X]')),
      ], // section 4: ext. subsquare A-X
      [FilteringTextInputFormatter.digitsOnly], // section 5: precision 0-9
    ];
    for (final c in _ctrls) {
      c.addListener(_updatePreview);
    }
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.removeListener(_updatePreview);
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _nameCtrl.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final sb = StringBuffer();
    for (final c in _ctrls) {
      final t = c.text.toUpperCase();
      if (t.length == 2) {
        sb.write(t);
      } else {
        break; // locator must be sequential – stop at first incomplete section
      }
    }
    final locator = sb.toString();
    setState(() {
      _locator = locator;
      if (locator.length >= 6) {
        final decoded = Maidenhead.decodeCenter(locator);
        _coords = LatLng(decoded.lat, decoded.lng);
      } else {
        _coords = null;
      }
    });
  }

  bool get _canCreate =>
      _locator.length >= 6 && _nameCtrl.text.trim().isNotEmpty;

  void _onCreate() {
    final coords = _coords!;
    final uuid = Maidenhead.deterministicPlaceUuid(
      coords.latitude,
      coords.longitude,
    );
    Navigator.pop(context, (
      coords: coords,
      name: _nameCtrl.text.trim(),
      uuid: uuid,
    ));
  }

  Widget _sectionBox(int index, String rangeLabel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 42,
          child: TextField(
            controller: _ctrls[index],
            focusNode: _focusNodes[index],
            maxLength: 2,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            ),
            inputFormatters: _formatters[index],
            onChanged: (v) {
              if (v.length == 2) {
                if (index < 5) {
                  _focusNodes[index + 1].requestFocus();
                } else {
                  _focusNodes[6].requestFocus();
                }
              }
            },
          ),
        ),
        const SizedBox(height: 3),
        Text(rangeLabel, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _separatorWidget() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        '_',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.maidenheadLocatorTitle)),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Section input row ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _sectionBox(0, 'A–R'),
                const SizedBox(width: 3),
                _sectionBox(1, '0–9'),
                const SizedBox(width: 3),
                _sectionBox(2, 'A–X'),
                const SizedBox(width: 6),
                _separatorWidget(),
                const SizedBox(width: 6),
                _sectionBox(3, '0–9'),
                const SizedBox(width: 3),
                _sectionBox(4, 'A–X'),
                const SizedBox(width: 6),
                _separatorWidget(),
                const SizedBox(width: 6),
                _sectionBox(5, '0–9'),
              ],
            ),
            const SizedBox(height: 16),

            // ── Live preview ──────────────────────────────────────────────
            if (_locator.length >= 6)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Maidenhead.format(_locator),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (_coords != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_coords!.latitude.toStringAsFixed(6)}, '
                        '${_coords!.longitude.toStringAsFixed(6)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // ── Info boxes ────────────────────────────────────────────────
            _InfoTile(
              icon: Icons.grid_on,
              color: theme.colorScheme.primaryContainer,
              text: l10n.maidenheadInfoBase,
            ),
            const SizedBox(height: 8),
            _InfoTile(
              icon: Icons.fingerprint,
              color: theme.colorScheme.secondaryContainer,
              text: l10n.maidenheadInfoDeterministic,
            ),
            const SizedBox(height: 8),
            _InfoTile(
              icon: Icons.my_location,
              color: theme.colorScheme.tertiaryContainer,
              text: l10n.maidenheadInfoPrecision,
            ),
            const SizedBox(height: 20),

            // ── Name input ────────────────────────────────────────────────
            TextField(
              controller: _nameCtrl,
              focusNode: _focusNodes[6],
              decoration: InputDecoration(
                labelText: l10n.name,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // ── Create button ─────────────────────────────────────────────
            FilledButton(
              onPressed: _canCreate ? _onCreate : null,
              child: Text(l10n.createPlace),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Filters text input to only the characters matched by [_allowed] and
/// converts them to upper case.
class _UpperCaseFilterFormatter extends TextInputFormatter {
  _UpperCaseFilterFormatter(this._allowed);

  final RegExp _allowed;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text
        .toUpperCase()
        .split('')
        .where(_allowed.hasMatch)
        .join();
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}
