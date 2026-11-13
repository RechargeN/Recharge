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
    void need(
      bool ok,
      String code,
      String field, [
      Map<String, int> params = const <String, int>{},
    ]) {
      if (!ok) {
        issues.add(
          ClassWorkshopValidationIssue(
            code: code,
            field: field,
            params: params,
          ),
        );
      }
    }

    final ClassWorkshopOfferingKind? kind = data.offeringKind;
    need(kind != null, 'offering_kind', 'basics');
    need(draft.title.trim().isNotEmpty, 'title', 'basics');
    need(
      draft.shortDescription.trim().isNotEmpty,
      'short_description',
      'basics',
    );
    need(draft.fullDescription.trim().isNotEmpty, 'full_description', 'basics');
    need(
      draft.media.coverImage.trim().isNotEmpty && rightsConfirmed,
      'media',
      'basics',
    );
    need(data.outcomes.isNotEmpty, 'outcomes', 'learning');
    need(data.modules.isNotEmpty, 'modules', 'learning');
    need(data.prerequisitesListed != null, 'prerequisites', 'learning');
    if (kind?.requiresTakeHomeResult ?? false) {
      need(
        data.takeHomeResult.trim().isNotEmpty,
        'take_home_result',
        'learning',
      );
    }
    final ClassWorkshopInstructor instructor = data.instructor;
    if (!instructor.sameAsPublisher) {
      need(
        instructor.displayName.trim().isNotEmpty &&
            instructor.shortBio.trim().isNotEmpty,
        'instructor',
        'learning',
      );
    }
    if (kind == ClassWorkshopOfferingKind.masterclass) {
      need(instructor.shortBio.trim().isNotEmpty, 'instructor_bio', 'learning');
    }
    final int count = data.occurrences.length;
    need(
      data.contextKind == ClassWorkshopContextKind.singleClass
          ? count == 1
          : count >= 2,
      'occurrences',
      'schedule',
      <String, int>{
        'single': data.contextKind == ClassWorkshopContextKind.singleClass
            ? 1
            : 0,
      },
    );
    need(data.timezoneConfirmed, 'timezone', 'schedule');
    need(draft.scheduleSlots.isEmpty, 'legacy_schedule', 'schedule');
    if (data.deliveryFormat.hasPlace) {
      need(pinConfirmed, 'location', 'schedule');
      if (data.locationMode == ClassWorkshopLocationMode.areaOnly) {
        need(
          data.safeAreaLabel.trim().isNotEmpty,
          'safe_area_label',
          'schedule',
        );
      }
    }
    if (data.deliveryFormat == ClassWorkshopDeliveryFormat.onlineLive) {
      need(
        data.onlineProviderLabel.trim().isNotEmpty,
        'online_provider_label',
        'schedule',
      );
    }
    if (data.price.mode == ClassWorkshopPriceMode.fixed) {
      need(
        (data.price.amountMinor ?? 0) > 0 && data.price.scope != null,
        'price',
        'participation',
      );
    }
    if (data.enrollment.mode == ClassWorkshopEnrollmentMode.external) {
      need(
        data.enrollment.externalUrl.trim().isNotEmpty,
        'enrollment',
        'participation',
      );
    }
    return List<ClassWorkshopValidationIssue>.unmodifiable(issues);
  }
}
