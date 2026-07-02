import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

/// A simple explorer for the app's [SharedPreferences] with basic editing
/// capabilities. Mirrors the SQLite [DatabaseExplorerScreen] but for key/value
/// preferences. Intended for debug use only.
class SharedPrefsExplorerScreen extends StatefulWidget {
  const SharedPrefsExplorerScreen({super.key});

  @override
  State<SharedPrefsExplorerScreen> createState() =>
      _SharedPrefsExplorerScreenState();
}

class _SharedPrefsExplorerScreenState extends State<SharedPrefsExplorerScreen> {
  SharedPreferences? _prefs;
  List<String> _keys = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.reload();
    if (!mounted) return;
    setState(() {
      _keys = _prefs!.getKeys().toList()..sort();
      _isLoading = false;
    });
  }

  /// Returns a short human-readable type name for the value stored at [key].
  String _typeOf(dynamic value) {
    if (value is bool) return 'bool';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is String) return 'String';
    if (value is List<String>) return 'List<String>';
    return value?.runtimeType.toString() ?? 'null';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editEntry(String key) async {
    final l10n = AppLocalizations.of(context)!;
    final value = _prefs!.get(key);
    final type = _typeOf(value);

    // Booleans get a simple switch dialog.
    if (value is bool) {
      bool current = value;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: Text(l10n.sharedPrefsEditTitle(key)),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('<$type>'),
                Switch(
                  value: current,
                  onChanged: (v) => setStateDialog(() => current = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, current),
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      );
      if (result != null) {
        await _prefs!.setBool(key, result);
        _showSnackBar(l10n.sharedPrefsUpdated);
        await _load();
      }
      return;
    }

    // All other types are edited as text and parsed back to their type.
    final controller = TextEditingController(
      text: value is List<String> ? value.join('\n') : value?.toString() ?? '',
    );
    final isNumeric = value is int || value is double;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sharedPrefsEditTitle(key)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('<$type>', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: value is List<String> ? null : 1,
              keyboardType: isNumeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : value is List<String>
                  ? TextInputType.multiline
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: l10n.newValueLabel,
                helperText: value is List<String>
                    ? 'List<String>: one entry per line'
                    : null,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      if (value is int) {
        final parsed = int.tryParse(result.trim());
        if (parsed == null) throw FormatException(type);
        await _prefs!.setInt(key, parsed);
      } else if (value is double) {
        final parsed = double.tryParse(result.trim());
        if (parsed == null) throw FormatException(type);
        await _prefs!.setDouble(key, parsed);
      } else if (value is List<String>) {
        final list = result
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        await _prefs!.setStringList(key, list);
      } else {
        await _prefs!.setString(key, result);
      }
      _showSnackBar(l10n.sharedPrefsUpdated);
      await _load();
    } on FormatException {
      _showSnackBar(l10n.sharedPrefsInvalidValue(type));
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _deleteEntry(String key) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sharedPrefsDeleteTitle),
        content: Text(l10n.sharedPrefsDeleteConfirm(key)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _prefs!.remove(key);
      _showSnackBar(l10n.sharedPrefsDeleted);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sharedPrefsExplorerScreenHeader),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _keys.isEmpty
            ? Center(child: Text(l10n.sharedPrefsNoEntries))
            : ListView.separated(
                itemCount: _keys.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final key = _keys[index];
                  final value = _prefs!.get(key);
                  final type = _typeOf(value);
                  final display = value is List<String>
                      ? '[${value.join(', ')}]'
                      : value?.toString() ?? 'NULL';

                  return ListTile(
                    title: Text(
                      key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '<$type>',
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontSize: 12,
                          ),
                        ),
                        Text(display),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.teal),
                          onPressed: () => _editEntry(key),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteEntry(key),
                        ),
                      ],
                    ),
                    onTap: () => _editEntry(key),
                  );
                },
              ),
      ),
    );
  }
}
