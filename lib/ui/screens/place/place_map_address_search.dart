import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/nominatim_service.dart';

class PlaceMapAddressSearch extends StatefulWidget {
  const PlaceMapAddressSearch({
    super.key,
    required this.countryCtrl,
    required this.cityCtrl,
    required this.streetCtrl,
    required this.onResultSelected,
  });

  final TextEditingController countryCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController streetCtrl;
  final ValueChanged<NominatimResult> onResultSelected;

  @override
  State<PlaceMapAddressSearch> createState() => _PlaceMapAddressSearchState();
}

class _PlaceMapAddressSearchState extends State<PlaceMapAddressSearch> {
  List<NominatimResult> _results = [];
  bool _searching = false;
  String? _error;

  Future<void> _search() async {
    final country = widget.countryCtrl.text.trim();
    final city = widget.cityCtrl.text.trim();
    final street = widget.streetCtrl.text.trim();

    if (country.isEmpty && city.isEmpty && street.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _results = [];
    });

    final results = await NominatimService.instance.searchAddress(
      country: country,
      city: city,
      street: street,
    );

    if (mounted) {
      setState(() {
        _searching = false;
        _results = results;
        if (results.isEmpty) {
          _error = AppLocalizations.of(context)!.noResultsFound;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.search),
                const SizedBox(width: 8),
                Text(
                  l10n.addressSearch,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                TextField(
                  controller: widget.countryCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.country,
                    hintText: l10n.countryHint,
                    prefixIcon: const Icon(Icons.flag_outlined),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.cityCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.cityPlace,
                    hintText: l10n.cityHint,
                    prefixIcon: const Icon(Icons.location_city),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.streetCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.streetOptional,
                    hintText: l10n.streetHint,
                    prefixIcon: const Icon(Icons.signpost_outlined),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(l10n.search),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = _results[i];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(
                      r.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    dense: true,
                    onTap: () => widget.onResultSelected(r),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
