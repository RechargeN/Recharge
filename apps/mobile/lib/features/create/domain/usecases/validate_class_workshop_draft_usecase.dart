import '../entities/class_workshop_draft_data.dart';
import '../entities/class_workshop_validation_issue.dart';
import '../entities/create_draft_entity.dart';

/// Local readiness of a Class / Workshop draft (D3.6): presence of what CW-V1
/// requires, so the Creator sees gaps before submit. Bounds, taxonomy,
/// criteria, time and media rules are decided by the server validator only.
final class ValidateClassWorkshopDraftUseCase {
  const ValidateClassWorkshopDraftUseCase();

  List<ClassWorkshopValidationIssue> call(
    CreateDraftEntity draft, {
    required bool pinConfirmed,
    required bool rightsConfirmed,
  }) {
    final ClassWorkshopDraftData? data = draft.classWorkshopData;
    if (data == null) return const <ClassWorkshopValidationIssue>[];
    final List<ClassWorkshopValidationIssue> issues =
        <ClassWorkshopValidationIssue>[];
    void need(bool ok, String code, String field, String message) {
      if (!ok) {
        issues.add(
          ClassWorkshopValidationIssue(
            code: code,
            field: field,
            message: message,
          ),
        );
      }
    }

    final ClassWorkshopOfferingKind? kind = data.offeringKind;
    need(kind != null, 'offering_kind', 'basics', 'Choose the offering kind');
    need(draft.title.trim().isNotEmpty, 'title', 'basics', 'Add a title');
    need(
      draft.shortDescription.trim().isNotEmpty,
      'short_description',
      'basics',
      'Add a short description',
    );
    need(
      draft.fullDescription.trim().isNotEmpty,
      'full_description',
      'basics',
      'Add a full description',
    );
    need(
      draft.media.coverImage.trim().isNotEmpty && rightsConfirmed,
      'media',
      'basics',
      'Add a cover and confirm image rights',
    );
    need(data.outcomes.isNotEmpty, 'outcomes', 'learning', 'Add an outcome');
    need(
      data.modules.isNotEmpty,
      'modules',
      'learning',
      'Add a programme step',
    );
    need(
      data.prerequisitesListed != null,
      'prerequisites',
      'learning',
      'Choose prerequisites or "No prerequisites"',
    );
    if (kind?.requiresTakeHomeResult ?? false) {
      need(
        data.takeHomeResult.trim().isNotEmpty,
        'take_home_result',
        'learning',
        'Describe the result participants take home',
      );
    }
    final ClassWorkshopInstructor instructor = data.instructor;
    if (!instructor.sameAsPublisher) {
      need(
        instructor.displayName.trim().isNotEmpty &&
            instructor.shortBio.trim().isNotEmpty,
        'instructor',
        'learning',
        'Add the instructor name and bio',
      );
    }
    if (kind == ClassWorkshopOfferingKind.masterclass) {
      need(
        instructor.shortBio.trim().isNotEmpty,
        'instructor_bio',
        'learning',
        'A masterclass needs the instructor bio',
      );
    }
    final int count = data.occurrences.length;
    need(
      data.contextKind == ClassWorkshopContextKind.singleClass
          ? count == 1
          : count >= 2,
      'occurrences',
      'schedule',
      data.contextKind == ClassWorkshopContextKind.singleClass
          ? 'A single class has exactly one date'
          : 'A series has at least two dates',
    );
    need(
      data.timezoneConfirmed,
      'timezone',
      'schedule',
      'Confirm the timezone',
    );
    need(
      draft.scheduleSlots.isEmpty,
      'legacy_schedule',
      'schedule',
      'Clear the old schedule before publishing',
    );
    if (data.deliveryFormat.hasPlace) {
      need(pinConfirmed, 'location', 'schedule', 'Confirm the location');
      if (data.locationMode == ClassWorkshopLocationMode.areaOnly) {
        need(
          data.safeAreaLabel.trim().isNotEmpty,
          'safe_area_label',
          'schedule',
          'Add the public area label',
        );
      }
    }
    if (data.deliveryFormat == ClassWorkshopDeliveryFormat.onlineLive) {
      need(
        data.onlineProviderLabel.trim().isNotEmpty,
        'online_provider_label',
        'schedule',
        'Name the online provider',
      );
    }
    if (data.price.mode == ClassWorkshopPriceMode.fixed) {
      need(
        (data.price.amountMinor ?? 0) > 0 && data.price.scope != null,
        'price',
        'participation',
        'Add the amount and what it covers',
      );
    }
    if (data.enrollment.mode == ClassWorkshopEnrollmentMode.external) {
      need(
        data.enrollment.externalUrl.trim().isNotEmpty,
        'enrollment',
        'participation',
        'Add the external enrollment link',
      );
    }
    return List<ClassWorkshopValidationIssue>.unmodifiable(issues);
  }
}
