import 'package:flutter/material.dart';

import '../../domain/entities/location_search_suggestion.dart';

/// Shared dropdown-style suggestion list used by both Place's identity step
/// and Collection's area-anchor step — one look for "type a name, pick the
/// real place" across Create.
class LocationSearchSuggestionList extends StatelessWidget {
  const LocationSearchSuggestionList({
    required this.suggestions,
    required this.onSelected,
    super.key,
  });

  final List<LocationSearchSuggestion> suggestions;
  final ValueChanged<LocationSearchSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final LocationSearchSuggestion suggestion in suggestions)
            ListTile(
              dense: true,
              leading: const Icon(Icons.place_outlined),
              title: Text(suggestion.primaryText),
              subtitle: suggestion.secondaryText == null
                  ? null
                  : Text(suggestion.secondaryText!),
              onTap: () => onSelected(suggestion),
            ),
        ],
      ),
    );
  }
}
