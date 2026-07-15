import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/sync_source.dart';
import '../../utils/unified_widget.dart';

/// Opens a dialog that lets the user configure per-table sync options
/// (insert / update / delete) for a [SyncSourceOptions] value.
///
/// Returns the updated [SyncSourceOptions] when the user taps "Save", or
/// `null` when the dialog is cancelled.
Future<SyncSourceOptions?> showSyncOptionsDialog(
  BuildContext context,
  SyncSourceOptions initial,
) async {
  final l10n = AppLocalizations.of(context)!;
  var opts = initial;

  final labels = <String, String>{
    'place_groups': l10n.placeGroups,
    'saved_places': l10n.tabPlaces,
    'persons': l10n.persons,
    'activities': l10n.activities,
    'stays': l10n.visitsTitle,
    'stay_persons': l10n.stayPersons,
    'stay_activities': l10n.stayActivities,
    'virtual_devices': l10n.sectionVirtualDevices,
    'sync_sources': l10n.syncSources,
    'place_experiences': l10n.placeExperiences,
    'sync_source_experiences': l10n.sourceExperiences,
    'place_photos': l10n.photos,
    'p2p_messages': l10n.messagesPlaceTitle,
  };

  return showDialog<SyncSourceOptions>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(l10n.syncOptionsTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.syncOptionsWarning,
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 130),
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.insert,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.edit,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.delete,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: SyncSourceOptions.allTables.map((table) {
                        final tableOpts = opts.forTable(table);
                        return Row(
                          children: [
                            SizedBox(
                              width: 130,
                              child: Text(
                                labels[table] ?? table,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Checkbox(
                                value: tableOpts.insert,
                                onChanged: (v) => setDlgState(() {
                                  opts = opts.copyWithTable(
                                    table,
                                    tableOpts.copyWith(insert: v ?? false),
                                  );
                                }),
                              ),
                            ),
                            Expanded(
                              child: Checkbox(
                                value: tableOpts.update,
                                onChanged: (v) => setDlgState(() {
                                  opts = opts.copyWithTable(
                                    table,
                                    tableOpts.copyWith(update: v ?? false),
                                  );
                                }),
                              ),
                            ),
                            Expanded(
                              child: Checkbox(
                                value: tableOpts.delete,
                                onChanged: (v) => setDlgState(() {
                                  opts = opts.copyWithTable(
                                    table,
                                    tableOpts.copyWith(delete: v ?? false),
                                  );
                                }),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: UnifiedWidget(context).saveAndCancelButtonsList(
            onSavePressed: () => Navigator.pop(ctx, opts),
            onCancelPressed: () => Navigator.pop(ctx),
          ),
        ),
      );
    },
  );
}
