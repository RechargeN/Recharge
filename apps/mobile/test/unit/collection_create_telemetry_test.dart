import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/collection_create_telemetry.dart';
import 'package:recharge/features/create/domain/entities/collection_publication_data.dart';

void main() {
  late _RecordingAnalyticsService analytics;
  late CollectionCreateTelemetry telemetry;

  setUp(() {
    analytics = _RecordingAnalyticsService();
    telemetry = CollectionCreateTelemetry(analytics);
  });

  test('every event uses the single collection_create_action name', () {
    telemetry.trackPublish(direct: true, outcome: CollectionPublishOutcome.created);
    telemetry.trackRemovalOnly();
    telemetry.trackArchive();
    telemetry.trackModerationDecision(accept: true);
    telemetry.trackFailure(
      action: CollectionCreateTelemetryAction.publish,
      failureCode: 'revisionConflict',
    );

    expect(analytics.events, hasLength(5));
    expect(
      analytics.events.map((e) => e.name).toSet(),
      <String>{'collection_create_action'},
    );
  });

  test(
    'params allowlist never carries free text — only typed enum names and '
    'booleans',
    () {
      telemetry.trackPublish(
        direct: true,
        outcome: CollectionPublishOutcome.pendingReview,
      );
      telemetry.trackModerationDecision(accept: false);
      telemetry.trackFailure(
        action: CollectionCreateTelemetryAction.removalOnly,
        failureCode: 'notFound',
      );

      for (final _TrackedEvent event in analytics.events) {
        expect(event.params.keys, everyElement(anyOf('action', 'result', 'direct', 'accept')));
        for (final Object? value in event.params.values) {
          expect(value, anyOf(isA<String>(), isA<bool>()));
          if (value is String) {
            // Every string value must be a known enum member name, never a
            // raw id, title, note, price, coordinate or error message.
            expect(
              CollectionCreateTelemetryAction.values.map((a) => a.name).contains(value) ||
                  CollectionCreateTelemetryResult.values.map((r) => r.name).contains(value),
              isTrue,
              reason: '"$value" is not an allowlisted enum name',
            );
          }
        }
      }
    },
  );

  test('trackPublish(direct:false) records the direct flag as false', () {
    telemetry.trackPublish(
      direct: false,
      outcome: CollectionPublishOutcome.pendingReview,
    );
    expect(analytics.events.single.params['direct'], isFalse);
    expect(
      analytics.events.single.params['result'],
      CollectionCreateTelemetryResult.pendingReview.name,
    );
  });

  test('trackPublish with an already-active outcome records success', () {
    telemetry.trackPublish(
      direct: true,
      outcome: CollectionPublishOutcome.replayedIdempotentSuccess,
    );
    expect(
      analytics.events.single.params['result'],
      CollectionCreateTelemetryResult.success.name,
    );
  });

  test('an unknown failure code falls back to persistenceUnavailable', () {
    telemetry.trackFailure(
      action: CollectionCreateTelemetryAction.archive,
      failureCode: 'somethingNeverSeenBefore',
    );
    expect(
      analytics.events.single.params['result'],
      CollectionCreateTelemetryResult.persistenceUnavailable.name,
    );
  });

  test('CollectionCreateTelemetry.disabled() never throws and tracks nothing', () {
    const CollectionCreateTelemetry disabled = CollectionCreateTelemetry.disabled();
    expect(
      () => disabled.trackPublish(
        direct: true,
        outcome: CollectionPublishOutcome.created,
      ),
      returnsNormally,
    );
  });
}

class _TrackedEvent {
  const _TrackedEvent(this.name, this.params);

  final String name;
  final Map<String, Object?> params;
}

class _RecordingAnalyticsService implements AnalyticsService {
  final List<_TrackedEvent> events = <_TrackedEvent>[];

  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {
    events.add(_TrackedEvent(eventName, params));
  }
}
