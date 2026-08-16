enum EventBoundarySituation {
  organizedOccurrence,
  informalPeopleSearch,
  recurringBookableResource,
  datedTournamentAtVenue,
  continuousTrack,
  datedTour,
  recurringProviderTourSlots,
  festivalProgram,
  attendeeFestivalPlan,
  undatedAnnouncement,
  undatedInterestOrBlindSale,
}

enum EventBoundaryDecision {
  event,
  findPeople,
  bookableSession,
  routeReferencedByEvent,
  bookableSessionOrEventByProviderProduct,
  eventWithProgramItems,
  scenario,
  eventDraft,
  externalDiscoveryCandidate,
}

/// Table-driven transcription of the normative aggregate boundaries in §1.2.
class ResolveEventAggregateBoundaryUseCase {
  const ResolveEventAggregateBoundaryUseCase();

  EventBoundaryDecision call(EventBoundarySituation situation) {
    return switch (situation) {
      EventBoundarySituation.organizedOccurrence => EventBoundaryDecision.event,
      EventBoundarySituation.informalPeopleSearch =>
        EventBoundaryDecision.findPeople,
      EventBoundarySituation.recurringBookableResource =>
        EventBoundaryDecision.bookableSession,
      EventBoundarySituation.datedTournamentAtVenue =>
        EventBoundaryDecision.event,
      EventBoundarySituation.continuousTrack =>
        EventBoundaryDecision.routeReferencedByEvent,
      EventBoundarySituation.datedTour => EventBoundaryDecision.event,
      EventBoundarySituation.recurringProviderTourSlots =>
        EventBoundaryDecision.bookableSessionOrEventByProviderProduct,
      EventBoundarySituation.festivalProgram =>
        EventBoundaryDecision.eventWithProgramItems,
      EventBoundarySituation.attendeeFestivalPlan =>
        EventBoundaryDecision.scenario,
      EventBoundarySituation.undatedAnnouncement =>
        EventBoundaryDecision.eventDraft,
      EventBoundarySituation.undatedInterestOrBlindSale =>
        EventBoundaryDecision.externalDiscoveryCandidate,
    };
  }
}
