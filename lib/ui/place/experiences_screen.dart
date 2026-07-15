import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/place_experience.dart';
import '../../services/database_service.dart';
import '../../utils/unified_widget.dart';

/// Full-screen list of survival experiences for a single place.
/// Items are loaded in chunks as the user scrolls (chunk loader).
class ExperiencesScreen extends StatefulWidget {
  final String placeUuid;
  final String placeName;

  const ExperiencesScreen({
    super.key,
    required this.placeUuid,
    required this.placeName,
  });

  @override
  State<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends State<ExperiencesScreen> {
  static const int _chunkSize = 20;

  final ScrollController _scrollCtrl = ScrollController();
  final List<PlaceExperience> _experiences = [];

  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadNextChunk();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 && _hasMore && !_loading) {
      _loadNextChunk();
    }
  }

  Future<void> _loadNextChunk() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final chunk = await DatabaseService.instance.loadExperiencesForPlacePaged(
      widget.placeUuid,
      limit: _chunkSize,
      offset: _offset,
    );
    if (!mounted) return;
    setState(() {
      _experiences.addAll(chunk);
      _offset += chunk.length;
      _hasMore = chunk.length == _chunkSize;
      _loading = false;
    });
  }

  Future<void> _reload() async {
    setState(() {
      _experiences.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadNextChunk();
  }

  Future<void> _addOrEditExperience([PlaceExperience? existing]) async {
    final textCtrl = TextEditingController(text: existing?.text ?? '');
    var rDangerFriendly = existing?.ratingDangerousFriendly ?? 0;
    var rFraudReliable = existing?.ratingFraudReliable ?? 0;
    var rDismissiveAccommodation = existing?.ratingDismissiveAccommodation ?? 0;
    var rFood = existing?.ratingFood ?? 0;
    var rEquipment = existing?.ratingEquipment ?? 0;
    var rTransport = existing?.ratingTransport ?? 0;
    var rMedicine = existing?.ratingMedicine ?? 0;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final ctxL10n = AppLocalizations.of(ctx)!;
          Widget ratingRow(
            String label,
            int value,
            void Function(int) onChanged,
          ) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: const TextStyle(fontSize: 12)),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        value.toString(),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: value > 0
                              ? Colors.green
                              : value < 0
                              ? Colors.red
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: value.toDouble(),
                  min: -9,
                  max: 9,
                  divisions: 18,
                  label: value.toString(),
                  onChanged: (v) => setDlg(() => onChanged(v.round())),
                ),
              ],
            );
          }

          return AlertDialog(
            title: Text(
              existing == null
                  ? ctxL10n.addOrEditExperienceTitle
                  : ctxL10n.editExperienceTitle,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textCtrl,
                    decoration: InputDecoration(
                      labelText: ctxL10n.reportOptional,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ctxL10n.ratingsLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ratingRow(
                    ctxL10n.ratingDangerFriendly,
                    rDangerFriendly,
                    (v) => rDangerFriendly = v,
                  ),
                  ratingRow(
                    ctxL10n.ratingFraudReliable,
                    rFraudReliable,
                    (v) => rFraudReliable = v,
                  ),
                  ratingRow(
                    ctxL10n.ratingDismissiveAccommodation,
                    rDismissiveAccommodation,
                    (v) => rDismissiveAccommodation = v,
                  ),
                  ratingRow(ctxL10n.ratingFood, rFood, (v) => rFood = v),
                  ratingRow(
                    ctxL10n.ratingEquipment,
                    rEquipment,
                    (v) => rEquipment = v,
                  ),
                  ratingRow(
                    ctxL10n.ratingTransport,
                    rTransport,
                    (v) => rTransport = v,
                  ),
                  ratingRow(
                    ctxL10n.ratingMedicine,
                    rMedicine,
                    (v) => rMedicine = v,
                  ),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: UnifiedWidget(ctx).saveAndDeleteButtonsList(
              onSavePressed: () => Navigator.pop(ctx, true),
              onDeletePressed: () => Navigator.pop(ctx, false),
            ),
          );
        },
      ),
    );

    if (saved == false && existing != null) {
      await _deleteExperience(existing);
      return;
    }
    if (saved != true) return;
    if (existing == null) {
      await DatabaseService.instance.insertPlaceExperience(
        PlaceExperience(
          savedPlaceUuid: widget.placeUuid,
          text: textCtrl.text.trim(),
          ratingDangerousFriendly: rDangerFriendly,
          ratingFraudReliable: rFraudReliable,
          ratingDismissiveAccommodation: rDismissiveAccommodation,
          ratingFood: rFood,
          ratingEquipment: rEquipment,
          ratingTransport: rTransport,
          ratingMedicine: rMedicine,
        ),
      );
    } else {
      await DatabaseService.instance.updatePlaceExperience(
        existing.copyWith(
          text: textCtrl.text.trim(),
          ratingDangerousFriendly: rDangerFriendly,
          ratingFraudReliable: rFraudReliable,
          ratingDismissiveAccommodation: rDismissiveAccommodation,
          ratingFood: rFood,
          ratingEquipment: rEquipment,
          ratingTransport: rTransport,
          ratingMedicine: rMedicine,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    await _reload();
  }

  Future<void> _deleteExperience(PlaceExperience exp) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.experienceDeleteTitle),
        content: Text(l10n.experienceDeleteContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseService.instance.softDeletePlaceExperience(exp.uuid);
    await _reload();
  }

  Widget _ratingChip(String label, int value) {
    final color = value > 0
        ? Colors.green
        : value < 0
        ? Colors.red
        : Colors.grey;
    return Chip(
      label: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, color: color),
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withAlpha(120)),
      backgroundColor: color.withAlpha(20),
    );
  }

  String _fmtMs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.survivalExperiences),
            Text(
              widget.placeName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addOrEditExperience,
        tooltip: l10n.addOrEditExperienceTitle,
        child: const Icon(Icons.add),
      ),
      body: _experiences.isEmpty && !_loading
          ? Center(child: Text(l10n.noExperiencesYet))
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                itemCount: _experiences.length + (_hasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i >= _experiences.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final exp = _experiences[i];
                  final avg = exp.averageRating;
                  return InkWell(
                    onTap: () => _addOrEditExperience(exp),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Ø ${avg.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: avg > 0
                                          ? Colors.green
                                          : avg < 0
                                          ? Colors.red
                                          : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  _fmtMs(exp.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                // IconButton(
                                //   icon: const Icon(Icons.edit, size: 18),
                                //   tooltip: l10n.edit,
                                //   visualDensity: VisualDensity.compact,
                                //   onPressed: () => _addOrEditExperience(exp),
                                // ),
                                // IconButton(
                                //   icon: const Icon(
                                //     Icons.delete_outline,
                                //     size: 18,
                                //     color: Colors.red,
                                //   ),
                                //   tooltip: l10n.delete,
                                //   visualDensity: VisualDensity.compact,
                                //   onPressed: () => _deleteExperience(exp),
                                // ),
                              ],
                            ),
                            if (exp.text.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                exp.text,
                                maxLines: 20,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _ratingChip(
                                  'Gef/Fr',
                                  exp.ratingDangerousFriendly,
                                ),
                                _ratingChip('Btr/Zuv', exp.ratingFraudReliable),
                                _ratingChip(
                                  'Abw/Unt',
                                  exp.ratingDismissiveAccommodation,
                                ),
                                _ratingChip('Verpfl', exp.ratingFood),
                                _ratingChip('Equip', exp.ratingEquipment),
                                _ratingChip('Trans', exp.ratingTransport),
                                _ratingChip('Med', exp.ratingMedicine),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              exp.deviceId,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  //////
                },
              ),
            ),
    );
  }
}
