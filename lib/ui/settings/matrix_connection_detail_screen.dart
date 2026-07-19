import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

import '../../models/matrix_connection.dart';
import '../../services/database_service.dart';
import '../../services/matrix_service.dart';
import '../../services/settings_service.dart';
import '../../utils/unified_widget.dart';

class MatrixConnectionDetailScreen extends StatefulWidget {
  final MatrixConnection? existing;

  const MatrixConnectionDetailScreen({super.key, required this.existing});

  @override
  State<MatrixConnectionDetailScreen> createState() =>
      _MatrixConnectionDetailScreenState();
}

class _MatrixConnectionDetailScreenState
    extends State<MatrixConnectionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _uuid;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _homeserverCtrl;
  late final TextEditingController _roomIdCtrl;
  late final TextEditingController _tokenCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _testMsgCtrl;

  bool _tokenVisible = false;
  bool _passwordVisible = false;

  bool? _membershipStatus;
  String? _membershipError;
  bool _isCheckingMembership = false;

  bool? _loginSuccess;
  String? _loginResultMsg;
  bool _isLoggingIn = false;

  bool? _testSuccess;
  String? _testResultMsg;
  bool _isSendingTest = false;

  // ── Room picker state ──────────────────────────────────────────────────────
  List<MatrixRoomInfo> _joinedRooms = [];
  bool _isLoadingRooms = false;
  String? _roomsLoadError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _uuid = e?.uuid ?? const Uuid().v4();
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _homeserverCtrl = TextEditingController(
      text: e?.homeserver ?? 'https://matrix.org',
    );
    _roomIdCtrl = TextEditingController(text: e?.roomId ?? '');
    _tokenCtrl = TextEditingController(
      text: e != null
          ? (SettingsService.instance.getMatrixAccessToken(e.uuid) ?? '')
          : '',
    );
    final creds = e != null
        ? SettingsService.instance.getMatrixCredentials(e.uuid)
        : null;
    _usernameCtrl = TextEditingController(text: creds?['username'] ?? '');
    _passwordCtrl = TextEditingController(text: creds?['password'] ?? '');
    _testMsgCtrl = TextEditingController(text: '');
    if (e != null) {
      _membershipStatus = SettingsService.instance.getMatrixRoomMembership(
        e.uuid,
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _homeserverCtrl.dispose();
    _roomIdCtrl.dispose();
    _tokenCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _testMsgCtrl.dispose();
    super.dispose();
  }

  MatrixConnection _buildConn() => MatrixConnection(
    uuid: _uuid,
    name: _nameCtrl.text.trim(),
    description: _descCtrl.text.trim(),
    homeserver: _homeserverCtrl.text.trim(),
    roomId: _roomIdCtrl.text.trim(),
  );

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final homeserver = _homeserverCtrl.text.trim();
    if (username.isEmpty || password.isEmpty || homeserver.isEmpty) {
      setState(() {
        _loginSuccess = false;
        _loginResultMsg = l10n.matrixLoginMissingFields;
      });
      return;
    }
    setState(() {
      _isLoggingIn = true;
      _loginResultMsg = null;
      _loginSuccess = null;
    });

    final result = await MatrixService.instance.login(
      _uuid,
      homeserver,
      username,
      password,
    );

    if (result.success && result.accessToken != null) {
      _tokenCtrl.text = result.accessToken!;
      await SettingsService.instance.setMatrixCredentials(
        _uuid,
        username,
        password,
      );
    }

    if (mounted) {
      setState(() {
        _isLoggingIn = false;
        _loginSuccess = result.success;
        _loginResultMsg = result.success
            ? l10n.matrixLoginSuccess
            : l10n.matrixLoginError(result.errorMessage ?? l10n.unknown);
      });
    }
  }

  Future<void> _checkMembership() async {
    setState(() {
      _isCheckingMembership = true;
      _membershipError = null;
    });

    final result = await MatrixService.instance.checkRoomMembership(
      _buildConn(),
      overrideToken: _tokenCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isCheckingMembership = false;
        _membershipStatus = result.isMember;
        _membershipError = result.errorMessage;
      });
    }
  }

  Future<void> _loadRooms() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoadingRooms = true;
      _roomsLoadError = null;
    });

    final (rooms, error) = await MatrixService.instance.loadJoinedRooms(
      _buildConn(),
      overrideToken: _tokenCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoadingRooms = false;
        _joinedRooms = rooms;
        _roomsLoadError = error != null
            ? l10n.matrixRoomsLoadError(error)
            : (rooms.isEmpty ? l10n.matrixNoRooms : null);
      });
    }
  }

  Future<void> _sendTest() async {
    final l10n = AppLocalizations.of(context)!;
    final msg = _testMsgCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() {
      _isSendingTest = true;
      _testResultMsg = null;
      _testSuccess = null;
    });

    final result = await MatrixService.instance.sendMessage(
      _buildConn(),
      msg,
      overrideToken: _tokenCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSendingTest = false;
        _testSuccess = result.success;
        _testResultMsg = result.success
            ? l10n.matrixTestSent
            : l10n.matrixTestError(result.errorMessage ?? l10n.unknown);
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final conn = _buildConn();

    if (widget.existing == null) {
      await DatabaseService.instance.insertMatrixConnection(conn);
    } else {
      await DatabaseService.instance.updateMatrixConnection(conn);
    }

    await SettingsService.instance.setMatrixAccessToken(
      _uuid,
      _tokenCtrl.text.trim(),
    );
    await SettingsService.instance.setMatrixRoomMembership(
      _uuid,
      _membershipStatus,
    );

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (username.isNotEmpty) {
      await SettingsService.instance.setMatrixCredentials(
        _uuid,
        username,
        password,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  // ── Build helpers ──────────────────────────────────────────────────────────

  Widget _resultText({required bool? success, required String? message}) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: success == true ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? l10n.newMatrixConnection
              : l10n.editMatrixConnection,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: UnifiedWidget(context).saveButton(onPressed: _save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Grundeinstellungen ──────────────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: '${l10n.name} *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: l10n.description,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            // ── Matrix-Verbindung ───────────────────────────────────────────
            const SizedBox(height: 8),
            // ── Authentifizierung ───────────────────────────────────────────
            UnifiedWidget(context).namedDivider(l10n.matrixSectionAuth),
            TextFormField(
              controller: _homeserverCtrl,
              decoration: InputDecoration(
                labelText: l10n.matrixHomeserverLabel,
                hintText: l10n.matrixHomeserverHint,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _usernameCtrl,
              decoration: InputDecoration(
                labelText: l10n.matrixUsernameLabel,
                hintText: l10n.matrixUsernameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: l10n.matrixPasswordLabel,
                hintText: l10n.matrixPasswordHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                ),
              ),
              obscureText: !_passwordVisible,
            ),
            Text(
              l10n.matrixCredentialNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _isLoggingIn
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login, size: 18),
                label: Text(l10n.matrixLoginButton),
                onPressed: _isLoggingIn ? null : _login,
              ),
            ),
            _resultText(success: _loginSuccess, message: _loginResultMsg),

            const SizedBox(height: 14),
            TextFormField(
              controller: _tokenCtrl,
              decoration: InputDecoration(
                labelText: l10n.matrixAccessTokenLabel,
                hintText: l10n.matrixAccessTokenHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _tokenVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _tokenVisible = !_tokenVisible),
                ),
              ),
              obscureText: !_tokenVisible,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),
            UnifiedWidget(context).namedDivider('Matrix Room'),
            // ── Raum-Picker ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _isLoadingRooms
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.list, size: 18),
                label: Text(l10n.matrixLoadRooms),
                onPressed: _isLoadingRooms ? null : _loadRooms,
              ),
            ),
            if (_roomsLoadError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _roomsLoadError!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _joinedRooms.isEmpty
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Colors.red,
                  ),
                ),
              ),
            if (_joinedRooms.isNotEmpty) ...[
              const SizedBox(height: 8),

              DropdownButtonFormField<MatrixRoomInfo>(
                isExpanded: true,
                itemHeight: null,
                decoration: InputDecoration(
                  labelText: l10n.matrixPickRoom,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.meeting_room_outlined),
                ),
                selectedItemBuilder: (context) => _joinedRooms
                    .map(
                      (r) =>
                          Text(r.displayName, overflow: TextOverflow.ellipsis),
                    )
                    .toList(),
                items: _joinedRooms
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              r.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (r.displaySubtitle != null)
                              Text(
                                r.displaySubtitle!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (r) {
                  if (r != null) {
                    setState(() => _roomIdCtrl.text = r.roomId);
                  }
                },
              ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _roomIdCtrl,
              decoration: InputDecoration(
                labelText: l10n.matrixRoomIdLabel,
                hintText: l10n.matrixRoomIdHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _isCheckingMembership
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user, size: 18),
                label: Text(l10n.matrixCheckMembership),
                onPressed: _isCheckingMembership ? null : _checkMembership,
              ),
            ),
            const SizedBox(height: 4),
            _MembershipStatusRow(
              status: _membershipStatus,
              error: _membershipError,
              l10n: l10n,
            ),
            // ── Verbindung testen ───────────────────────────────────────────
            UnifiedWidget(context).namedDivider(l10n.matrixSectionTest),
            TextFormField(
              controller: _testMsgCtrl,
              decoration: InputDecoration(
                labelText: l10n.matrixTestMessageHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _isSendingTest
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(l10n.matrixSendTestButton),
                onPressed: _isSendingTest ? null : _sendTest,
              ),
            ),
            _resultText(success: _testSuccess, message: _testResultMsg),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Membership-Status-Zeile ───────────────────────────────────────────────────

class _MembershipStatusRow extends StatelessWidget {
  final bool? status;
  final String? error;
  final AppLocalizations l10n;

  const _MembershipStatusRow({
    required this.status,
    required this.error,
    required this.l10n,
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
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      );
    }
    if (status == null) {
      return Text(
        l10n.matrixMemberUnknown,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          status! ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: status! ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 4),
        Text(
          status! ? l10n.matrixMemberYes : l10n.matrixMemberNo,
          style: TextStyle(
            fontSize: 12,
            color: status! ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }
}
