import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/route_canonical_codec.dart';
import 'package:recharge/features/create/data/models/scenario_draft_mapper.dart';

void main() {
  test(
    'Route canonical bytes and hash preserve the legacy journal algorithm',
    () {
      final vectors = <Object?>[
        null,
        true,
        'Rīga 🚲',
        0,
        -0.0,
        1.0,
        1.25,
        <String, Object?>{
          'z': <Object?>[1.0, null, 'line\ntext'],
          'a': <String, Object?>{'β': 2.0, 'a': -3.5},
        },
        <String, Object?>{
          'title': 'Route',
          'latE7': 569496000,
          'lonE7': 241052000,
          'segments': <Object?>[
            <String, Object?>{'sourceKind': 'freehand', 'elevation': null},
          ],
        },
      ];
      for (final value in vectors) {
        final old = ScenarioDraftMapper.canonicalJson(value);
        final current = RouteCanonicalCodec.canonicalJson(value);
        expect(utf8.encode(current), utf8.encode(old));
        expect(
          sha256.convert(utf8.encode(current)).toString(),
          sha256.convert(utf8.encode(old)).toString(),
        );
      }
      expect(
        RouteCanonicalCodec.canonicalJson({
          'z': 1.0,
          'a': [2.0, -0.0],
        }),
        '{"a":[2,0],"z":1}',
      );
    },
  );
}
