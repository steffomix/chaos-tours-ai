import 'package:flutter/material.dart';

import '../../models/person.dart';
import '../../services/database_service.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({super.key});

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> {
  List<Person> _persons = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final persons = await DatabaseService.instance.loadAllPersons();
    if (mounted) setState(() => _persons = persons);
  }

  Future<void> _add() async {
    final result = await _showEditDialog(null);
    if (result != null) {
      await DatabaseService.instance.insertPerson(result);
      await _load();
    }
  }

  Future<void> _edit(Person person) async {
    final result = await _showEditDialog(person);
    if (result != null) {
      await DatabaseService.instance.updatePerson(result);
      await _load();
    }
  }

  Future<void> _delete(Person person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Person löschen?'),
        content: Text('„${person.name}" wirklich entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.instance.deletePerson(person.uuid);
      await _load();
    }
  }

  Future<Person?> _showEditDialog(Person? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final roleCtrl = TextEditingController(text: existing?.role ?? '');

    return showDialog<Person>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Neue Person' : 'Person bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(
                labelText: 'Rolle / Beschreibung (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                ctx,
                Person(
                  uuid: existing?.uuid,
                  name: name,
                  role: roleCtrl.text.trim(),
                ),
              );
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personen')),
      body: _persons.isEmpty
          ? const Center(child: Text('Noch keine Personen vorhanden.'))
          : ListView.builder(
              itemCount: _persons.length,
              itemBuilder: (ctx, i) {
                final p = _persons[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(p.name),
                  subtitle: p.role.isNotEmpty ? Text(p.role) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _edit(p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(p),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: 'Person hinzufügen',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
