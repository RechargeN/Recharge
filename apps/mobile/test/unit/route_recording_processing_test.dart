import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_edit_command.dart';
import 'package:recharge/features/create/domain/entities/route_recording_data.dart';
import 'package:recharge/features/create/domain/usecases/apply_route_edit_command_usecase.dart';
import 'package:recharge/features/create/domain/usecases/process_route_recording_usecase.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  const processor = ProcessRouteRecordingUseCase(
    config: RouteRecordingProcessingConfig(
      maximumHorizontalAccuracyMeters: 30,
      maximumSpeedMetersPerSecond: 15,
      minimumMovementMeters: 1,
    ),
  );

  test('preview filters unsafe samples and preserves pause as a gap', () {
    final journal = _journal(
      legs: <RouteRecordingLeg>[
        _leg('leg-1', <RouteRecordingSample>[
          _sample(0, 56.9700, 24.1300),
          _sample(5000, 56.9701, 24.1301, accuracy: 80),
          _sample(10000, 56.9702, 24.1302),
        ]),
        _leg('leg-2', <RouteRecordingSample>[
          _sample(20000, 56.9703, 24.1303),
          _sample(30000, 56.9704, 24.1304),
        ]),
      ],
    );

    final preview = processor.preview(journal);

    expect(preview.tracks, hasLength(2));
    expect(preview.gaps.single.reason, RouteRecordingGapReason.pause);
    expect(preview.quality.rawSampleCount, 5);
    expect(preview.quality.acceptedSampleCount, 4);
    expect(preview.quality.rejectedAccuracyCount, 1);
    expect(preview.quality.rawDistanceMeters, greaterThan(0));
    expect(preview.quality.safeMetrics.keys, isNot(contains('coordinates')));
  });

  test('implausible movement is excluded without a silent connection', () {
    final preview = processor.preview(
      _journal(
        legs: <RouteRecordingLeg>[
          _leg('leg-1', <RouteRecordingSample>[
            _sample(0, 56.9700, 24.1300),
            _sample(10000, 56.9701, 24.1301),
            _sample(11000, 57.5000, 25.0000),
            _sample(20000, 56.9702, 24.1302),
            _sample(30000, 56.9703, 24.1303),
          ]),
        ],
      ),
    );

    expect(preview.tracks, hasLength(2));
    expect(
      preview.gaps.single.reason,
      RouteRecordingGapReason.implausibleMovement,
    );
    expect(preview.quality.rejectedMovementCount, 1);
    expect(
      preview.tracks.expand((track) => track),
      isNot(contains(const GeoPoint(latitude: 57.5, longitude: 25))),
    );
  });

  test(
    'every gap needs an explicit decision and direct join is reviewable',
    () {
      final preview = processor.preview(
        _journal(
          legs: <RouteRecordingLeg>[
            _leg('leg-1', <RouteRecordingSample>[
              _sample(0, 56.9700, 24.1300),
              _sample(10000, 56.9701, 24.1301),
            ]),
            _leg('leg-2', <RouteRecordingSample>[
              _sample(20000, 56.9702, 24.1302),
              _sample(30000, 56.9703, 24.1303),
            ]),
          ],
        ),
      );

      expect(
        () => processor.finalize(
          preview,
          gapResolutions: const <String, RouteRecordingGapResolution>{},
          nowUtc: DateTime.utc(2026, 7, 25),
        ),
        _throwsCode('gps_gap_decision_required'),
      );
      final result = processor.finalize(
        preview,
        gapResolutions: <String, RouteRecordingGapResolution>{
          preview.gaps.single.id: RouteRecordingGapResolution.connectDirect,
        },
        nowUtc: DateTime.utc(2026, 7, 25),
      );

      expect(result.tracks, hasLength(1));
      expect(result.tracks.single, hasLength(4));
      expect(
        result.sourceIssues.map((issue) => issue.code),
        contains('gps_direct_gap_confirmed'),
      );
      expect(result.rawStats.recordedDurationSeconds, 20);
    },
  );

  test('route-between remains typed until application routing resolves it', () {
    final preview = processor.preview(
      _journal(
        legs: <RouteRecordingLeg>[
          _leg('leg-1', <RouteRecordingSample>[
            _sample(0, 56.9700, 24.1300),
            _sample(10000, 56.9701, 24.1301),
          ]),
          _leg('leg-2', <RouteRecordingSample>[
            _sample(20000, 56.9702, 24.1302),
            _sample(30000, 56.9703, 24.1303),
          ]),
        ],
      ),
    );

    expect(
      () => processor.finalize(
        preview,
        gapResolutions: <String, RouteRecordingGapResolution>{
          preview.gaps.single.id: RouteRecordingGapResolution.routeBetween,
        },
        nowUtc: DateTime.utc(2026, 7, 25),
      ),
      _throwsCode('gps_gap_routing_required'),
    );
  });

  test('privacy trim is explicit and removes private endpoints in preview', () {
    final preview = processor.preview(
      _journal(
        legs: <RouteRecordingLeg>[
          _leg('leg-1', <RouteRecordingSample>[
            _sample(0, 56.9700, 24.1300),
            _sample(10000, 56.9701, 24.1300),
            _sample(20000, 56.9702, 24.1300),
            _sample(30000, 56.9703, 24.1300),
            _sample(40000, 56.9704, 24.1300),
          ]),
        ],
      ),
      trimStartMeters: 10,
      trimEndMeters: 10,
    );

    expect(preview.quality.trimmedStartCount, 1);
    expect(preview.quality.trimmedEndCount, 1);
    expect(preview.tracks.single, hasLength(3));
    expect(preview.tracks.single.first.latitude, closeTo(56.9701, 0.000001));
    expect(preview.tracks.single.last.latitude, closeTo(56.9703, 0.000001));
  });

  test('invalid journal and excessive privacy trim fail closed', () {
    final invalid = _journal(
      legs: <RouteRecordingLeg>[
        _leg('leg-1', <RouteRecordingSample>[
          _sample(1000, 56.9700, 24.1300),
          _sample(1000, 56.9701, 24.1301),
        ]),
      ],
    );
    expect(
      () => processor.preview(invalid),
      _throwsCode('gps_journal_invalid'),
    );
    expect(
      () => processor.preview(
        _journal(
          legs: <RouteRecordingLeg>[
            _leg('leg-1', <RouteRecordingSample>[
              _sample(0, 56.9700, 24.1300),
              _sample(10000, 56.9701, 24.1301),
            ]),
          ],
        ),
        trimStartMeters: 2001,
      ),
      _throwsCode('gps_privacy_trim_invalid'),
    );
  });

  test('active journal and mocked samples never enter a preview silently', () {
    final active = RouteRecordingJournal(
      sessionId: 'active-session',
      draftId: 'draft-1',
      startedAtUtc: DateTime.utc(2026, 7, 25, 10),
      updatedAtUtc: DateTime.utc(2026, 7, 25, 11),
      status: RouteRecordingJournalStatus.recording,
      legs: <RouteRecordingLeg>[
        _leg('leg-1', <RouteRecordingSample>[
          _sample(0, 56.9700, 24.1300),
          _sample(10000, 56.9701, 24.1301),
        ]),
      ],
    );
    expect(
      () => processor.preview(active),
      _throwsCode('gps_recording_not_completed'),
    );

    final preview = processor.preview(
      _journal(
        legs: <RouteRecordingLeg>[
          _leg('leg-1', <RouteRecordingSample>[
            _sample(0, 56.9700, 24.1300),
            _sample(5000, 56.9701, 24.1301, mocked: true),
            _sample(10000, 56.9702, 24.1302),
          ]),
        ],
      ),
    );
    expect(preview.quality.rejectedMockedCount, 1);
    expect(preview.tracks.single, hasLength(2));
  });

  test('GPS apply is atomic, typed and keeps raw private samples out', () {
    final preview = processor.preview(
      _journal(
        legs: <RouteRecordingLeg>[
          _leg('leg-1', <RouteRecordingSample>[
            _sample(0, 56.9700, 24.1300),
            _sample(10000, 56.9701, 24.1301),
            _sample(20000, 56.9702, 24.1302),
          ]),
        ],
      ),
    );
    final result = processor.finalize(
      preview,
      gapResolutions: const <String, RouteRecordingGapResolution>{},
      nowUtc: DateTime.utc(2026, 7, 25),
    );
    final draft = routeFixture();
    final apply = ApplyRouteEditCommandUseCase(
      idGenerator: _SequenceIdGenerator(),
    );

    final rejected = apply(
      draft,
      ApplyRouteGpsRecording(result: result),
      nowUtc: DateTime.utc(2026, 7, 25),
      maximumAnchors: 10,
      maximumSegments: 10,
      maximumWaypoints: 10,
      maximumGeometryPoints: 100,
    );
    expect(rejected.accepted, isFalse);
    expect(
      rejected.failureCode,
      RouteEditFailureCode.geometryReplacementConfirmationRequired,
    );
    expect(identical(rejected.draft, draft), isTrue);

    final accepted = apply(
      draft,
      ApplyRouteGpsRecording(result: result, confirmGeometryReplacement: true),
      nowUtc: DateTime.utc(2026, 7, 25),
      maximumAnchors: 10,
      maximumSegments: 10,
      maximumWaypoints: 10,
      maximumGeometryPoints: 100,
    );
    expect(accepted.accepted, isTrue);
    expect(accepted.draft.creationMethod, RouteCreationMethod.recordedGps);
    expect(
      accepted.draft.segments.single.source,
      RouteSegmentSource.recordedGps,
    );
    expect(
      accepted.draft.segments.single.rawStats?.recordedDurationSeconds,
      20,
    );
    expect(
      accepted.draft.segments.single.geometry.points,
      everyElement(isA<GeoPoint>()),
    );
  });
}

RouteRecordingJournal _journal({required List<RouteRecordingLeg> legs}) =>
    RouteRecordingJournal(
      sessionId: 'recording-session',
      draftId: 'draft-1',
      startedAtUtc: DateTime.utc(2026, 7, 25, 10),
      updatedAtUtc: DateTime.utc(2026, 7, 25, 11),
      status: RouteRecordingJournalStatus.completed,
      legs: legs,
    );

RouteRecordingLeg _leg(String id, List<RouteRecordingSample> samples) =>
    RouteRecordingLeg(id: id, samples: samples);

RouteRecordingSample _sample(
  int elapsedMilliseconds,
  double latitude,
  double longitude, {
  double accuracy = 5,
  bool mocked = false,
}) => RouteRecordingSample(
  position: GeoPoint(latitude: latitude, longitude: longitude),
  horizontalAccuracyMeters: accuracy,
  elapsedMilliseconds: elapsedMilliseconds,
  capturedAtUtc: DateTime.utc(
    2026,
    7,
    25,
    10,
  ).add(Duration(milliseconds: elapsedMilliseconds)),
  source: RouteRecordingSampleSource.fused,
  isMocked: mocked,
);

Matcher _throwsCode(String code) => throwsA(
  isA<RouteRecordingException>().having((error) => error.code, 'code', code),
);

class _SequenceIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'gps-test-${_next++}';
}
