import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/l10n_inventory.dart';

/// L4: hard-coded user-visible strings may only go down. The baseline is the
/// honest inventory of what L4 did not localize yet; a new or grown file fails
/// here. After localizing more, regenerate the baseline with
/// `dart run tool/l10n_inventory.dart --json > test/fixtures/l10n/unlocalized_baseline.json`.
void main() {
  test('no file gained hard-coded user-visible strings', () {
    final Map<String, dynamic> baseline =
        jsonDecode(
              File(
                'test/fixtures/l10n/unlocalized_baseline.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final Map<String, int> current = scanLib(Directory('lib'));
    final List<String> grown = <String>[
      for (final MapEntry<String, int> entry in current.entries)
        if (entry.value > ((baseline[entry.key] as int?) ?? 0))
          '${entry.key}: ${entry.value} > ${baseline[entry.key] ?? 0}',
    ];
    expect(grown, isEmpty);
  });

  test('positive control: new literals are counted; keys, ids, imports and '
      'localized calls are not', () {
    expect(countUnlocalized("Text('Book your seat now'),"), 1);
    expect(countUnlocalized("Text('Забронировать'),"), 1);
    expect(countUnlocalized("Text(context.l10n.bookingTitle),"), 0);
    expect(countUnlocalized("key: const Key('event-booking-create'),"), 0);
    expect(countUnlocalized("import 'package:flutter/material.dart';"), 0);
    expect(countUnlocalized("final String code = 'sold_out';"), 0);
    expect(countUnlocalized("context.go('/discover/details');"), 0);
  });
}
