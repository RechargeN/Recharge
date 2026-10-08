import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/event_create_coordinator.dart';
import 'package:recharge/features/create/application/event_admission_section.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/materialize_event_schedule_usecase.dart';
import 'package:recharge/features/create/domain/usecases/validate_event_access_configuration_usecase.dart';
import 'package:recharge/features/create/domain/usecases/validate_event_draft_usecase.dart';

import '../fixtures/create/user_event_draft.dart';

void main() {
  test('Create refreshes readiness and keeps local v1 restrictions', () {
    bool enabled = false;
    final validator = ValidateEventDraftUseCase(
      accessReadiness: () =>
          EventAccessReadiness(internalRegistration: enabled),
    );
    final coordinator = EventCreateCoordinator(
      materializeSchedule: MaterializeEventScheduleUseCase(
        EventTimezoneRepositoryImpl(),
      ),
      validateDraft: validator,
    );
    final draft = withInternalRegistration(
      userEventDraft(pageId: 'page-1', coverPath: 'cover.png'),
    );
    final blocked = coordinator.admissionState(draft, enabled: true);
    expect(
      blocked.issues.map((issue) => issue.code),
      contains('internal_registration_not_ready'),
    );
    expect(
      blocked.disclosures.any(
        (disclosure) =>
            disclosure.code ==
            EventAccessDisclosureCode.internalLifecycleUnavailable,
      ),
      isTrue,
    );

    enabled = true;
    final closesAtStart = withInternalRegistration(
      draft,
      closesBeforeMinutes: 0,
    );
    expect(
      validator(
        closesAtStart,
        includeAccessConfiguration: true,
      ).map((issue) => issue.code),
      isNot(contains('relative_access_window_invalid')),
    );
    final ready = coordinator.admissionState(draft, enabled: true);
    expect(
      ready.issues.map((issue) => issue.code),
      isNot(contains('internal_registration_not_ready')),
    );
    expect(
      ready.disclosures.any(
        (disclosure) =>
            disclosure.code ==
            EventAccessDisclosureCode.internalLifecycleUnavailable,
      ),
      isFalse,
    );
    expect(
      ready.disclosures.any(
        (disclosure) => disclosure.message.contains('local testBackend stand'),
      ),
      isTrue,
    );

    final online = draft.copyWith(
      eventData: draft.eventData!.copyWith(format: EventFormat.online),
    );
    expect(
      validator(online, includeAccessConfiguration: true)
          .where(
            (issue) => issue.code == 'internal_registration_v1_unsupported',
          )
          .map((issue) => issue.fieldId),
      contains('format'),
    );
    enabled = false;
    expect(
      coordinator
          .admissionState(draft, enabled: true)
          .issues
          .map((issue) => issue.code),
      contains('internal_registration_not_ready'),
    );
  });
}
