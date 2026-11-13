import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/session_draft_data.dart';
import 'package:recharge/features/create/domain/entities/session_price_disclosure.dart';
import 'package:recharge/features/create/domain/entities/session_schedule.dart';
import 'package:recharge/features/create/domain/entities/session_validation_issue.dart';
import 'package:recharge/features/create/domain/usecases/validate_session_draft_usecase.dart';

void main() {
  const ValidateSessionDraftUseCase validate = ValidateSessionDraftUseCase();

  const SessionExternalValidationContext validContext =
      SessionExternalValidationContext(
    categoryAllowedForSession: true,
    hasCover: true,
    publisherEligible: true,
  );

  SessionDraftData validDraft() => SessionDraftData(
    resourceName: 'Sauna 1',
    timezoneId: 'Europe/Riga',
    timezoneConfirmed: true,
    maxPartySize: 4,
    schedule: SessionSchedule(
      scheduleRevision: 1,
      slotDurationMinutes: 60,
      projectionWindowDays: 30,
      weeklyRules: const [
        SessionWeeklyRule(
          id: 'r1',
          isoWeekday: 1,
          startMinuteLocal: 540,
          endMinuteLocalExclusive: 600,
        ),
      ],
    ),
    price: SessionPriceDisclosure.free,
    externalBookingUrl: 'https://example.com/book',
  );

  bool hasCode(List<SessionValidationIssue> issues, String code) =>
      issues.any((issue) => issue.code == code);

  test('a fully valid draft has no blocking issues', () {
    final issues = validate(validDraft(), context: validContext);
    expect(issues.where((i) => i.isBlocking), isEmpty);
  });

  test('empty weekly schedule blocks publish', () {
    final draft = validDraft().copyWith(
      schedule: const SessionSchedule(
        scheduleRevision: 1,
        slotDurationMinutes: 60,
        projectionWindowDays: 30,
      ),
    );
    final issues = validate(draft, context: validContext);
    expect(hasCode(issues, SessionBlockingCode.scheduleEmpty), isTrue);
  });

  test('overlapping ranges on the same weekday block publish (§10.1 rule 4)', () {
    final draft = validDraft().copyWith(
      schedule: validDraft().schedule.copyWith(
        weeklyRules: const [
          SessionWeeklyRule(
            id: 'r1',
            isoWeekday: 1,
            startMinuteLocal: 540,
            endMinuteLocalExclusive: 660,
          ),
          SessionWeeklyRule(
            id: 'r2',
            isoWeekday: 1,
            startMinuteLocal: 600,
            endMinuteLocalExclusive: 720,
          ),
        ],
      ),
    );
    final issues = validate(draft, context: validContext);
    expect(hasCode(issues, SessionBlockingCode.rangeOverlap), isTrue);
  });

  test('duration out of range blocks publish', () {
    final draft = validDraft().copyWith(
      schedule: validDraft().schedule.copyWith(slotDurationMinutes: 10),
    );
    final issues = validate(draft, context: validContext);
    expect(hasCode(issues, SessionBlockingCode.durationOutOfRange), isTrue);
  });

  test('party size out of range blocks publish', () {
    final draft = validDraft().copyWith(maxPartySize: 21);
    final issues = validate(draft, context: validContext);
    expect(hasCode(issues, SessionBlockingCode.partySizeOutOfRange), isTrue);
  });

  test('fixed price without a positive amount blocks publish', () {
    final draft = validDraft().copyWith(
      price: const SessionPriceDisclosure(mode: SessionPricingMode.fixed),
    );
    final issues = validate(draft, context: validContext);
    expect(hasCode(issues, SessionBlockingCode.priceInvalid), isTrue);
  });

  test('non-HTTPS booking URL blocks publish', () {
    final draft = validDraft().copyWith(
      externalBookingUrl: 'http://insecure.example.com',
    );
    final issues = validate(draft, context: validContext);
    expect(hasCode(issues, SessionBlockingCode.bookingUrlInvalid), isTrue);
  });

  test('category not allowed for Session blocks publish', () {
    final issues = validate(
      validDraft(),
      context: const SessionExternalValidationContext(
        categoryAllowedForSession: false,
        hasCover: true,
        publisherEligible: true,
      ),
    );
    expect(hasCode(issues, SessionBlockingCode.categoryNotAllowed), isTrue);
  });

  test(
    'missing category criteria is a warning only, never blocking (SES-D14)',
    () {
      final issues = validate(
        validDraft(),
        context: const SessionExternalValidationContext(
          categoryAllowedForSession: true,
          hasCover: true,
          publisherEligible: true,
          categoryCriteriaProvided: false,
        ),
      );
      final issue = issues.singleWhere(
        (i) => i.code == SessionWarningCode.categoryCriteriaIncomplete,
      );
      expect(issue.isBlocking, isFalse);
      expect(issues.where((i) => i.isBlocking), isEmpty);
    },
  );

  test('missing cover blocks publish', () {
    final issues = validate(
      validDraft(),
      context: const SessionExternalValidationContext(
        categoryAllowedForSession: true,
        hasCover: false,
        publisherEligible: true,
      ),
    );
    expect(hasCode(issues, SessionBlockingCode.mediaIncomplete), isTrue);
  });

  test('ineligible publisher blocks publish', () {
    final issues = validate(
      validDraft(),
      context: const SessionExternalValidationContext(
        categoryAllowedForSession: true,
        hasCover: true,
        publisherEligible: false,
      ),
    );
    expect(hasCode(issues, SessionBlockingCode.publisherIneligible), isTrue);
  });
}
