import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/matrix_connection.dart';
import '../../services/database_service.dart';
import '../../services/matrix_service.dart';
import '../../services/settings_service.dart';
import '../../utils/custom_icons.dart';
import '../../utils/unified_widget.dart';

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

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> _add() async {
    final result = await _showEditDialog(null);
    if (result != null) {
      await DatabaseService.instance.insertMatrixConnection(result.$1);
      await SettingsService.instance.setMatrixAccessToken(
        result.$1.uuid,
        result.$2,
      );
      await SettingsService.instance.setMatrixRoomMembership(
        result.$1.uuid,
        result.$3,
      );
      await _load();
    }
  }

  Future<void> _edit(MatrixConnection conn) async {
    final result = await _showEditDialog(conn);
    if (result != null) {
      final updated = result.$1.copyWith(uuid: conn.uuid);
      await DatabaseService.instance.updateMatrixConnection(updated);
      await SettingsService.instance.setMatrixAccessToken(
        updated.uuid,
        result.$2,
      );
      await SettingsService.instance.setMatrixRoomMembership(
        updated.uuid,
        result.$3,
      );
      await _load();
    }
  }

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
      await _load();
    }
  }

  // ── Edit Dialog ────────────────────────────────────────────────────────────

  /// Returns (MatrixConnection, accessToken, membershipStatus?) or null.
  Future<(MatrixConnection, String, bool?)?> _showEditDialog(
    MatrixConnection? existing,
  ) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final homeserverCtrl = TextEditingController(
      text: existing?.homeserver ?? '',
    );
    final roomIdCtrl = TextEditingController(text: existing?.roomId ?? '');
    final tokenCtrl = TextEditingController(
      text: existing != null
          ? (SettingsService.instance.getMatrixAccessToken(existing.uuid) ?? '')
          : '',
    );
    final formKey = GlobalKey<FormState>();
    bool tokenVisible = false;
    bool? membershipStatus = existing != null
        ? SettingsService.instance.getMatrixRoomMembership(existing.uuid)
        : null;
    bool checkingMembership = false;
    String? membershipError;

    return showDialog<(MatrixConnection, String, bool?)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final l10n = AppLocalizations.of(ctx)!;
          return AlertDialog(
            title: Text(
              existing == null
                  ? l10n.newMatrixConnection
                  : l10n.editMatrixConnection,
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(labelText: '${l10n.name} *'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descCtrl,
                      decoration: InputDecoration(labelText: l10n.description),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: homeserverCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.matrixHomeserverLabel,
                        hintText: l10n.matrixHomeserverHint,
                      ),
                      keyboardType: TextInputType.url,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: roomIdCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.matrixRoomIdLabel,
                        hintText: l10n.matrixRoomIdHint,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: tokenCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.matrixAccessTokenLabel,
                        hintText: l10n.matrixAccessTokenHint,
                        suffixIcon: IconButton(
                          icon: Icon(
                            tokenVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setDlgState(() => tokenVisible = !tokenVisible),
                        ),
                      ),
                      obscureText: !tokenVisible,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 12),

                    // ── Membership check ──────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: checkingMembership
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.verified_user, size: 18),
                            label: Text(l10n.matrixCheckMembership),
                            onPressed: checkingMembership
                                ? null
                                : () async {
                                    if (formKey.currentState?.validate() !=
                                        true) {
                                      return;
                                    }
                                    setDlgState(() {
                                      checkingMembership = true;
                                      membershipError = null;
                                    });

                                    // Build a temporary connection for the check.
                                    final tempConn = MatrixConnection(
                                      uuid: existing?.uuid ?? 'tmp',
                                      name: nameCtrl.text.trim(),
                                      homeserver: homeserverCtrl.text.trim(),
                                      roomId: roomIdCtrl.text.trim(),
                                    );
                                    // Temporarily write the token so the service
                                    // can read it, then restore / clear.
                                    final prevToken = SettingsService.instance
                                        .getMatrixAccessToken(tempConn.uuid);
                                    await SettingsService.instance
                                        .setMatrixAccessToken(
                                          tempConn.uuid,
                                          tokenCtrl.text.trim(),
                                        );

                                    final checkResult = await MatrixService
                                        .instance
                                        .checkRoomMembership(tempConn);

                                    if (tempConn.uuid == 'tmp') {
                                      await SettingsService.instance
                                          .setMatrixAccessToken(
                                            tempConn.uuid,
                                            prevToken,
                                          );
                                    }

                                    setDlgState(() {
                                      checkingMembership = false;
                                      membershipStatus = checkResult.isMember;
                                      membershipError =
                                          checkResult.errorMessage;
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _MembershipIndicator(
                      status: membershipStatus,
                      error: membershipError,
                      l10n: l10n,
                    ),
                  ],
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: UnifiedWidget(context).saveAndCancelButtonsList(
              onSavePressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(ctx, (
                  MatrixConnection(
                    uuid: existing?.uuid,
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    homeserver: homeserverCtrl.text.trim(),
                    roomId: roomIdCtrl.text.trim(),
                  ),
                  tokenCtrl.text.trim(),
                  membershipStatus,
                ));
              },
              onCancelPressed: () => Navigator.pop(ctx),
            ),
          );
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matrixConnectionsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
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
                  leading: MatrixIcon(size: 32.0),
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
                      _MembershipIndicator(
                        status: membership,
                        error: null,
                        l10n: l10n,
                        compact: true,
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _edit(c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(c),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ── Membership-Status-Widget ──────────────────────────────────────────────────

class _MembershipIndicator extends StatelessWidget {
  final bool? status;
  final String? error;
  final AppLocalizations l10n;
  final bool compact;

  const _MembershipIndicator({
    required this.status,
    required this.error,
    required this.l10n,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 14, color: Colors.red),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l10n.matrixMemberError(error!),
              style: TextStyle(fontSize: compact ? 11 : 12, color: Colors.red),
            ),
          ),
        ],
      );
    }
    if (status == null) {
      return Text(
        l10n.matrixMemberUnknown,
        style: TextStyle(fontSize: compact ? 11 : 12, color: Colors.grey),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          status! ? Icons.check_circle : Icons.cancel,
          size: compact ? 14 : 16,
          color: status! ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 4),
        Text(
          status! ? l10n.matrixMemberYes : l10n.matrixMemberNo,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            color: status! ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }
}
