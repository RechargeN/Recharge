import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/l10n_inventory.dart';

/// L4: hard-coded user-visible strings may only go down. The baseline is the
/// honest inventory of what L4 did not localize yet, interface files only
/// (the listed non-interface files are mock data, parser vocabulary or data
/// formats); a new or grown file fails here. After localizing more,
/// regenerate the baseline with
/// `dart run tool/l10n_inventory.dart --json > test/fixtures/l10n/unlocalized_baseline.json`.
void main() {
  test('no interface file gained hard-coded user-visible strings', () {
    final Map<String, dynamic> baseline =
        jsonDecode(
              File(
                'test/fixtures/l10n/unlocalized_baseline.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final Map<String, int> current = scanInterface(Directory('lib'));
    final List<String> grown = <String>[
      for (final MapEntry<String, int> entry in current.entries)
        if (entry.value > ((baseline[entry.key] as int?) ?? 0))
          '${entry.key}: ${entry.value} > ${baseline[entry.key] ?? 0}',
    ];
    expect(grown, isEmpty);
  });

  test('the baseline holds interface files only', () {
    final Map<String, dynamic> baseline =
        jsonDecode(
              File(
                'test/fixtures/l10n/unlocalized_baseline.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(baseline.keys.where(isNonInterface), isEmpty);
  });

  test('every non-interface entry exists, has a reason and is not '
      'presentation code', () {
    expect(nonInterfaceFiles, isNotEmpty);
    for (final MapEntry<String, String> entry in nonInterfaceFiles.entries) {
      final String path = entry.key;
      final bool exists = path.endsWith('/')
          ? Directory(path).existsSync()
          : File(path).existsSync();
      expect(exists, isTrue, reason: '$path is listed but missing');
      expect(entry.value.trim(), isNotEmpty, reason: '$path has no reason');
      expect(
        path.split('/'),
        isNot(contains('presentation')),
        reason: '$path: presentation code is always interface',
      );
    }
  });

  test('positive control: listed files are excluded, others are not', () {
    expect(
      isNonInterface(
        'lib/features/discover/application/smart_search_parser.dart',
      ),
      isTrue,
    );
    expect(isNonInterface('lib/app/testing/seeded_event_fixture.dart'), isTrue);
    expect(
      isNonInterface(
        'lib/features/discover/presentation/pages/search_page.dart',
      ),
      isFalse,
    );
    expect(
      interfaceOnly(<String, int>{
        'lib/features/discover/application/smart_search_parser.dart': 48,
        'lib/features/discover/presentation/pages/search_page.dart': 75,
      }),
      <String, int>{
        'lib/features/discover/presentation/pages/search_page.dart': 75,
      },
    );
    expect(
      layerOf('lib/features/create/presentation/widgets/x.dart'),
      'presentation',
    );
    expect(layerOf('lib/features/create/data/gtfs/x.dart'), 'data');
    expect(layerOf('lib/core/config/x.dart'), 'other');
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
