import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/matrix_connection.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import 'matrix_connection_detail_screen.dart';

class MatrixConnectionsScreen extends StatefulWidget {
  const MatrixConnectionsScreen({super.key});

  @override
  State<MatrixConnectionsScreen> createState() =>
      _MatrixConnectionsScreenState();
}

class _MatrixConnectionsScreenState extends State<MatrixConnectionsScreen> {
  List<MatrixConnection> _connections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseService.instance.loadAllMatrixConnections();
    if (mounted) setState(() => _connections = list);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _openDetail(MatrixConnection? existing) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: existing == null,
        builder: (_) => MatrixConnectionDetailScreen(existing: existing),
      ),
    );
    if (saved == true) await _load();
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _delete(MatrixConnection conn) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.connectionDeleteTitle),
        content: Text(l10n.connectionDeleteContent(conn.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.instance.softDeleteMatrixConnection(conn.uuid);
      await SettingsService.instance.removeMatrixAccessTokens([conn.uuid]);
      await SettingsService.instance.removeMatrixRoomMemberships([conn.uuid]);
      await SettingsService.instance.removeMatrixRefreshTokens([conn.uuid]);
      await SettingsService.instance.removeMatrixCredentials([conn.uuid]);
      await _load();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matrixConnectionsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDetail(null),
        child: const Icon(Icons.add),
      ),
      body: _connections.isEmpty
          ? Center(child: Text(l10n.noMatrixConnections))
          : ListView.builder(
              itemCount: _connections.length,
              itemBuilder: (ctx, i) {
                final c = _connections[i];
                final membership = SettingsService.instance
                    .getMatrixRoomMembership(c.uuid);
                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(c.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.description.isNotEmpty)
                        Text(
                          c.description,
                          style: const TextStyle(fontSize: 12),
                        ),
                      Text(
                        '${c.homeserver}  •  ${c.roomId}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (membership != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              membership ? Icons.check_circle : Icons.cancel,
                              size: 12,
                              color: membership ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              membership
                                  ? l10n.matrixMemberYes
                                  : l10n.matrixMemberNo,
                              style: TextStyle(
                                fontSize: 11,
                                color: membership
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  onTap: () => _openDetail(c),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _delete(c),
                  ),
                );
              },
            ),
    );
  }
}
