import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../theme/soul_theme.dart';

/// Every country, its states and their cities, and the sheet that picks
/// from them. Nouvel's first onboarding, rebuilt: after the map has a
/// country, a card comes up from the bottom with the states, then the
/// cities, each with a search, and a city can be typed when the list does
/// not have it.
class LocationState {
  const LocationState({required this.name, required this.cities});
  final String name;
  final List<String> cities;
}

class LocationCountry {
  const LocationCountry({required this.name, required this.iso3, required this.states});
  final String name;
  final String iso3;
  final List<LocationState> states;
}

/// Two megabytes of names. Parsed once, off the main thread, and held.
class LocationDataset {
  static Future<List<LocationCountry>>? _loading;

  static Future<List<LocationCountry>> load() {
    return _loading ??= rootBundle.loadString('assets/locations.json').then(
      (text) => compute(_parse, text),
    );
  }

  /// Natural Earth's code for Kosovo differs from the dataset's, so a tap
  /// on the map finds the country rather than nothing.
  static const _iso3Remap = {'KOS': 'XKX'};

  static LocationCountry? find(List<LocationCountry> countries, String iso3) {
    final code = _iso3Remap[iso3] ?? iso3;
    for (final c in countries) {
      if (c.iso3 == code) return c;
    }
    return null;
  }
}

List<LocationCountry> _parse(String text) {
  final list = jsonDecode(text) as List;
  return [
    for (final c in list)
      LocationCountry(
        name: c['name'] as String,
        iso3: c['iso3'] as String,
        states: [
          for (final s in c['states'] as List)
            LocationState(
              name: s['name'] as String,
              cities: [for (final city in s['cities'] as List) city as String],
            ),
        ],
      ),
  ];
}

/// The card from the bottom: a chevron, a small uppercase title, a search,
/// the rows, and for a city the option to type one.
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({
    super.key,
    required this.title,
    required this.rows,
    required this.onBack,
    required this.onSelect,
    this.allowsFreeText = false,
    this.freeTextHint = 'Type your city',
  });

  final String title;
  final List<String> rows;
  final VoidCallback onBack;
  final ValueChanged<String> onSelect;

  /// Whether a name that is not in the list can be typed instead.
  final bool allowsFreeText;
  final String freeTextHint;

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _query = TextEditingController();
  final _free = TextEditingController();
  final _freeFocus = FocusNode();
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    _free.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _free.dispose();
    _freeFocus.dispose();
    super.dispose();
  }

  List<String> get _visible {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.rows;
    return [for (final r in widget.rows) if (r.toLowerCase().contains(q)) r];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: SoulColors.bg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: SoulColors.shade, blurRadius: 24, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onBack,
                child: const SizedBox(
                  width: 36,
                  height: 44,
                  child: Icon(Icons.chevron_left, size: 22, color: SoulColors.text2),
                ),
              ),
              Text(
                widget.title.toUpperCase(),
                style: const TextStyle(
                  fontFamily: SoulType.sans,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                  color: SoulColors.text2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _query,
            style: const TextStyle(fontFamily: SoulType.serif, fontSize: 16, color: SoulColors.text),
            cursorColor: SoulColors.clay,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: SoulColors.s1,
              hintText: 'Search',
              hintStyle: const TextStyle(fontFamily: SoulType.serif, fontSize: 16, color: SoulColors.text3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: rows.length + (widget.allowsFreeText ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == rows.length) return _freeTextRow();
                return _row(rows[i]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelect(label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: SoulColors.border)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontFamily: SoulType.serif, fontSize: 17, color: SoulColors.text),
        ),
      ),
    );
  }

  Widget _freeTextRow() {
    if (!_typing) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _typing = true);
          _freeFocus.requestFocus();
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Type it yourself',
            style: TextStyle(
              fontFamily: SoulType.sans,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: SoulColors.clay,
            ),
          ),
        ),
      );
    }
    final text = _free.text.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _free,
              focusNode: _freeFocus,
              style: const TextStyle(fontFamily: SoulType.serif, fontSize: 17, color: SoulColors.text),
              cursorColor: SoulColors.clay,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (text.isNotEmpty) widget.onSelect(text);
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.freeTextHint,
                hintStyle: const TextStyle(fontFamily: SoulType.serif, fontSize: 17, color: SoulColors.text3),
                border: InputBorder.none,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: text.isEmpty ? null : () => widget.onSelect(text),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Done',
                style: TextStyle(
                  fontFamily: SoulType.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: text.isEmpty ? SoulColors.text3 : SoulColors.clay,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
