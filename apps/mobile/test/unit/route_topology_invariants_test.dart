import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/validate_route_draft_usecase.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  const validator = ValidateRouteDraftUseCase();

  List<String> blockingCodes(RouteDraftData route) => validator
      .evaluate(route, policy: routeValidationPolicy())
      .blockingIssues
      .map((issue) => issue.code)
      .toList(growable: false);

  group('ordered topology properties', () {
    test('accepts generated one-way chains of different lengths', () {
      for (var anchorCount = 2; anchorCount <= 20; anchorCount += 1) {
        final path = <RouteAnchorDraft>[
          for (var index = 0; index < anchorCount; index += 1)
            routeAnchor(
              '01ANCHOR${index.toString().padLeft(16, '0')}',
              56.90 + index * 0.001,
              24.10 + index * 0.001,
            ),
        ];

        final codes = blockingCodes(
          routeForPath(shape: RouteShape.oneWay, path: path),
        );

        expect(codes, isEmpty, reason: 'anchorCount=$anchorCount');
      }
    });

    test('accepts closed loops with two to twenty unique anchors', () {
      for (var anchorCount = 2; anchorCount <= 20; anchorCount += 1) {
        final unique = <RouteAnchorDraft>[
          for (var index = 0; index < anchorCount; index += 1)
            routeAnchor(
              '01ANCHOR${index.toString().padLeft(16, '0')}',
              56.90 + index * 0.001,
              24.10 + index * 0.001,
            ),
        ];
        final path = <RouteAnchorDraft>[...unique, unique.first];

        final codes = blockingCodes(
          routeForPath(shape: RouteShape.loop, path: path),
        );

        expect(codes, isEmpty, reason: 'anchorCount=$anchorCount');
      }
    });

    test('accepts out-and-back chains with an explicit turning anchor', () {
      for (var armLength = 1; armLength <= 10; armLength += 1) {
        final outbound = <RouteAnchorDraft>[
          for (var index = 0; index <= armLength; index += 1)
            routeAnchor(
              '01ANCHOR${index.toString().padLeft(16, '0')}',
              56.90 + index * 0.001,
              24.10 + index * 0.001,
            ),
        ];
        final path = <RouteAnchorDraft>[
          ...outbound,
          ...outbound.reversed.skip(1),
        ];

        final codes = blockingCodes(
          routeForPath(
            shape: RouteShape.outAndBack,
            path: path,
            turningAnchorId: outbound.last.id,
          ),
        );

        expect(codes, isEmpty, reason: 'armLength=$armLength');
      }
    });
  });

  group('topology failures', () {
    test('detects a broken chain independently of segment ordering', () {
      final anchors = <RouteAnchorDraft>[
        routeAnchor('01ANCHOR000000000000000001', 56.90, 24.10),
        routeAnchor('01ANCHOR000000000000000002', 56.91, 24.11),
        routeAnchor('01ANCHOR000000000000000003', 56.92, 24.12),
        routeAnchor('01ANCHOR000000000000000004', 56.93, 24.13),
      ];
      final segments = <RouteSegmentDraft>[
        routeSegment(
          id: '01SEGMENT00000000000000001',
          order: 0,
          from: anchors[0],
          to: anchors[1],
        ),
        routeSegment(
          id: '01SEGMENT00000000000000002',
          order: 1,
          from: anchors[2],
          to: anchors[3],
        ),
      ];

      expect(
        blockingCodes(
          routeFixture(
            anchors: anchors,
            segments: segments,
            waypoints: const <RouteWaypointDraft>[],
          ),
        ),
        contains('segment_chain_broken'),
      );
    });

    test('detects missing or non-traversed turning anchors', () {
      final start = routeAnchor('01ANCHOR000000000000000001', 56.90, 24.10);
      final finish = routeAnchor('01ANCHOR000000000000000002', 56.91, 24.11);
      final route = routeForPath(
        shape: RouteShape.outAndBack,
        path: <RouteAnchorDraft>[start, finish],
        turningAnchorId: finish.id,
      );

      final codes = blockingCodes(route);

      expect(codes, contains('out_and_back_must_return'));
      expect(codes, contains('turning_anchor_not_traversed'));
    });

    test('detects non-contiguous and duplicate segment orders', () {
      final first = routeAnchor('01ANCHOR000000000000000001', 56.90, 24.10);
      final second = routeAnchor('01ANCHOR000000000000000002', 56.91, 24.11);
      final third = routeAnchor('01ANCHOR000000000000000003', 56.92, 24.12);
      final route = routeFixture(
        anchors: <RouteAnchorDraft>[first, second, third],
        segments: <RouteSegmentDraft>[
          routeSegment(
            id: '01SEGMENT00000000000000001',
            order: 2,
            from: first,
            to: second,
          ),
          routeSegment(
            id: '01SEGMENT00000000000000002',
            order: 2,
            from: second,
            to: third,
          ),
        ],
        waypoints: const <RouteWaypointDraft>[],
      );

      final codes = blockingCodes(route);

      expect(codes, contains('segment_order_invalid'));
      expect(codes, contains('segment_order_not_contiguous'));
    });
  });
}
