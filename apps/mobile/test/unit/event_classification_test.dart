import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/event_classification.dart';
import 'package:recharge/features/create/domain/usecases/resolve_event_aggregate_boundary_usecase.dart';
import 'package:recharge/features/create/domain/usecases/validate_event_classification_usecase.dart';

void main() {
  group('Event classification canon', () {
    test('contains all 34 archetypes with unique canonical wire names', () {
      expect(EventArchetype.values, hasLength(34));
      expect(
        EventArchetype.values
            .map((EventArchetype value) => value.wireName)
            .toSet(),
        hasLength(34),
      );
      expect(
        EventArchetype.fromWireName('open_stage'),
        EventArchetype.openStage,
      );
      expect(EventArchetype.fromWireName('unknown_future_value'), isNull);
    });

    test('contains all 17 participation modes with canonical wire names', () {
      expect(ParticipationMode.values, hasLength(17));
      expect(
        ParticipationMode.values
            .map((ParticipationMode value) => value.wireName)
            .toSet(),
        hasLength(17),
      );
      expect(
        ParticipationMode.fromWireName('meet_people'),
        ParticipationMode.meetPeople,
      );
      expect(ParticipationMode.fromWireName('unknown_future_value'), isNull);
    });

    test('participation value enforces uniqueness and the limit', () {
      expect(
        () => EventParticipation(
          primary: ParticipationMode.attend,
          additional: const <ParticipationMode>{ParticipationMode.attend},
        ),
        throwsArgumentError,
      );
      expect(
        () => EventParticipation(
          primary: ParticipationMode.attend,
          additional: const <ParticipationMode>{
            ParticipationMode.watch,
            ParticipationMode.learn,
            ParticipationMode.create,
            ParticipationMode.support,
          },
        ),
        throwsArgumentError,
      );
    });

    test('validator requires archetype, primary mode and other reason', () {
      const ValidateEventClassificationUseCase validate =
          ValidateEventClassificationUseCase();
      expect(
        validate(null).map((issue) => issue.code),
        containsAll(<String>[
          'event_archetype_required',
          'primary_participation_required',
        ]),
      );
      final issues = validate(
        EventClassificationDraft(
          archetype: EventArchetype.other,
          primaryParticipationMode: ParticipationMode.attend,
        ),
      );
      expect(
        issues.map((issue) => issue.code),
        contains('event_archetype_other_reason_required'),
      );
      final reviewIssues = validate(
        EventClassificationDraft(
          archetype: EventArchetype.other,
          primaryParticipationMode: ParticipationMode.attend,
          otherReason: 'A bounded organized mechanic',
        ),
      );
      expect(
        reviewIssues.single.code,
        'event_archetype_other_moderation_review',
      );
      expect(reviewIssues.single.isBlocking, isFalse);
    });
  });

  test('all normative aggregate boundary fixtures resolve canonically', () {
    const ResolveEventAggregateBoundaryUseCase resolve =
        ResolveEventAggregateBoundaryUseCase();
    const Map<EventBoundarySituation, EventBoundaryDecision> fixtures =
        <EventBoundarySituation, EventBoundaryDecision>{
          EventBoundarySituation.organizedOccurrence:
              EventBoundaryDecision.event,
          EventBoundarySituation.informalPeopleSearch:
              EventBoundaryDecision.findPeople,
          EventBoundarySituation.recurringBookableResource:
              EventBoundaryDecision.bookableSession,
          EventBoundarySituation.datedTournamentAtVenue:
              EventBoundaryDecision.event,
          EventBoundarySituation.continuousTrack:
              EventBoundaryDecision.routeReferencedByEvent,
          EventBoundarySituation.datedTour: EventBoundaryDecision.event,
          EventBoundarySituation.recurringProviderTourSlots:
              EventBoundaryDecision.bookableSessionOrEventByProviderProduct,
          EventBoundarySituation.festivalProgram:
              EventBoundaryDecision.eventWithProgramItems,
          EventBoundarySituation.attendeeFestivalPlan:
              EventBoundaryDecision.scenario,
          EventBoundarySituation.undatedAnnouncement:
              EventBoundaryDecision.eventDraft,
          EventBoundarySituation.undatedInterestOrBlindSale:
              EventBoundaryDecision.externalDiscoveryCandidate,
        };
    for (final MapEntry<EventBoundarySituation, EventBoundaryDecision> fixture
        in fixtures.entries) {
      expect(resolve(fixture.key), fixture.value, reason: fixture.key.name);
    }
  });
}
