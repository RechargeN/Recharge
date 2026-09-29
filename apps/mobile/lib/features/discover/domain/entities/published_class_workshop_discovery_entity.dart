import 'publisher_verification_display_state.dart';

enum ClassWorkshopKind {
  classLesson,
  workshop,
  masterclass,
  course,
  experience,
}

enum ClassWorkshopContextKind { singleClass, fixedSeries }

enum ClassWorkshopDelivery { offline, onlineLive, hybrid }

enum ClassWorkshopDurationScope { perClass, wholeSeries }

enum ClassWorkshopPriceScope { perPersonPerClass, perPersonFullSeries }

enum ClassWorkshopInformationReason {
  closed,
  onSite,
  notProvided,
  unsupportedInternal,
}

sealed class ClassWorkshopPrice {
  const ClassWorkshopPrice();
}

final class ClassWorkshopPriceNotProvided extends ClassWorkshopPrice {
  const ClassWorkshopPriceNotProvided();
}

final class ClassWorkshopPriceFree extends ClassWorkshopPrice {
  const ClassWorkshopPriceFree();
}

final class ClassWorkshopPriceFixed extends ClassWorkshopPrice {
  ClassWorkshopPriceFixed({
    required this.amountMinor,
    required this.currencyCode,
    required this.minorUnitDigits,
    required this.scope,
  }) {
    if (amountMinor <= 0 || !RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode) ||
        minorUnitDigits < 0 || minorUnitDigits > 4) {
      throw ArgumentError(
        'Fixed price requires positive minor units and ISO currency.',
      );
    }
  }
  final int amountMinor;
  final String currencyCode;
  /// Source-provided currency metadata; do not assume every currency has cents.
  final int minorUnitDigits;
  final ClassWorkshopPriceScope scope;
}

sealed class ClassWorkshopEnrollment {
  const ClassWorkshopEnrollment();
}

final class ClassWorkshopExternalEnrollment extends ClassWorkshopEnrollment {
  ClassWorkshopExternalEnrollment(this.uri) {
    if (uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError(
        'Enrollment requires absolute HTTPS without user-info.',
      );
    }
  }
  final Uri uri;
}

final class ClassWorkshopInformationOnly extends ClassWorkshopEnrollment {
  const ClassWorkshopInformationOnly(this.reason);
  final ClassWorkshopInformationReason reason;
}

sealed class ClassWorkshopInstructor {
  const ClassWorkshopInstructor();
}

final class ClassWorkshopInstructorSameAsPublisher
    extends ClassWorkshopInstructor {
  const ClassWorkshopInstructorSameAsPublisher();
}

/// A public reference, never ownership or an editing capability grant.
final class ClassWorkshopInstructorProfileRef {
  ClassWorkshopInstructorProfileRef({required this.id, required this.type}) {
    _id(id);
    if (type != 'user' && type != 'page') {
      throw ArgumentError('Invalid profile type.');
    }
  }
  final String id;
  final String type;
}

final class ClassWorkshopGuestInstructor extends ClassWorkshopInstructor {
  ClassWorkshopGuestInstructor({
    required this.name,
    this.handle = '',
    this.bio = '',
    this.profileRef,
  }) {
    _required(name, 'instructor name');
  }
  final String name;
  final String handle;
  final String bio;
  final ClassWorkshopInstructorProfileRef? profileRef;
}

final class ClassWorkshopOccurrence {
  ClassWorkshopOccurrence({
    required this.occurrenceId,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.timezoneId,
    this.title = '',
  }) {
    _id(occurrenceId);
    _required(timezoneId, 'timezoneId');
    if (!startAtUtc.isUtc || !endAtUtc.isUtc || !endAtUtc.isAfter(startAtUtc)) {
      throw ArgumentError('Occurrence needs ordered UTC timestamps.');
    }
  }
  final String occurrenceId;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String timezoneId;
  final String title;
}

sealed class ClassWorkshopSchedule {
  const ClassWorkshopSchedule();
}

final class ClassWorkshopDatesNotAnnounced extends ClassWorkshopSchedule {
  const ClassWorkshopDatesNotAnnounced();
}

final class ClassWorkshopAnnouncedSchedule extends ClassWorkshopSchedule {
  ClassWorkshopAnnouncedSchedule(List<ClassWorkshopOccurrence> occurrences)
    : occurrences = List.unmodifiable(occurrences) {
    if (occurrences.isEmpty) {
      throw ArgumentError('Announced schedule must not be empty.');
    }
    final ids = <String>{};
    ClassWorkshopOccurrence? previous;
    for (final occurrence in occurrences) {
      if (!ids.add(occurrence.occurrenceId) ||
          (previous != null &&
              (occurrence.startAtUtc.isBefore(previous.endAtUtc) ||
                  occurrence.timezoneId != previous.timezoneId))) {
        throw ArgumentError(
          'Schedule must be unique, ordered, non-overlapping and use one timezone.',
        );
      }
      previous = occurrence;
    }
  }
  final List<ClassWorkshopOccurrence> occurrences;
}

sealed class ClassWorkshopPublicLocation {
  const ClassWorkshopPublicLocation();
  ClassWorkshopDelivery get delivery;
}

final class ClassWorkshopPointLocation extends ClassWorkshopPublicLocation {
  ClassWorkshopPointLocation({
    required this.delivery,
    required this.venueName,
    required this.areaLabel,
    this.publicAddress = '',
    required this.latitude,
    required this.longitude,
    required this.precisionMeters,
  }) {
    _required(venueName, 'venueName');
    _required(areaLabel, 'areaLabel');
    if (delivery == ClassWorkshopDelivery.onlineLive ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        precisionMeters <= 0) {
      throw ArgumentError('Invalid public point.');
    }
  }
  @override
  final ClassWorkshopDelivery delivery;
  final String venueName;
  final String areaLabel;
  final String publicAddress;
  final double latitude;
  final double longitude;
  final int precisionMeters;
}

final class ClassWorkshopOnlineLocation extends ClassWorkshopPublicLocation {
  const ClassWorkshopOnlineLocation({this.providerLabel = ''});
  final String providerLabel;
  @override
  ClassWorkshopDelivery get delivery => ClassWorkshopDelivery.onlineLive;
}

final class ClassWorkshopHiddenLocation extends ClassWorkshopPublicLocation {
  ClassWorkshopHiddenLocation({
    required this.delivery,
    required this.safeAreaLabel,
  }) {
    _required(safeAreaLabel, 'safeAreaLabel');
    if (delivery == ClassWorkshopDelivery.onlineLive) {
      throw ArgumentError('Use online location.');
    }
  }
  @override
  final ClassWorkshopDelivery delivery;
  final String safeAreaLabel;
}

/// DTL-CLS-01 public read model. All facts belong to one displayContextId;
/// no drafts, inventory, attendees, credentials, or provider booking state.
final class PublishedClassWorkshopDiscoveryEntity {
  PublishedClassWorkshopDiscoveryEntity({
    required this.offeringId,
    required this.revision,
    required this.publishedAtUtc,
    required this.publisherId,
    required this.publisherType,
    required this.publisherName,
    this.publisherHandle = '',
    this.publisherVerification = PublisherVerificationDisplayState.none,
    required this.instructor,
    required this.title,
    required this.kind,
    required this.category,
    this.subcategory = '',
    required this.disciplineLabel,
    this.levelLabel = '',
    List<String> languageLabels = const [],
    this.shortDescription = '',
    this.fullDescription = '',
    List<String> learningOutcomes = const [],
    List<String> includedMaterials = const [],
    List<String> requirements = const [],
    this.coverImageUrl = '',
    List<String> galleryImageUrls = const [],
    required this.displayContextId,
    required this.contextKind,
    required this.schedule,
    this.declaredGroupLimit,
    this.durationMinutes,
    this.durationScope,
    required this.price,
    required this.publicLocation,
    required this.enrollment,
  }) : languageLabels = _strings(languageLabels),
       learningOutcomes = _strings(learningOutcomes),
       includedMaterials = _strings(includedMaterials),
       requirements = _strings(requirements),
       galleryImageUrls = _strings(galleryImageUrls) {
    for (final value in [offeringId, publisherId, displayContextId]) {
      _id(value);
    }
    for (final value in [publisherName, title, category, disciplineLabel]) {
      _required(value, 'public field');
    }
    if (revision <= 0 ||
        !publishedAtUtc.isUtc ||
        (publisherType != 'user' && publisherType != 'page')) {
      throw ArgumentError('Invalid publication identity.');
    }
    if ((declaredGroupLimit != null && declaredGroupLimit! <= 0) ||
        (durationMinutes != null && durationMinutes! <= 0) ||
        (durationMinutes == null) != (durationScope == null)) {
      throw ArgumentError(
        'Declared facts must be positive and duration needs its scope.',
      );
    }
    if (schedule case ClassWorkshopAnnouncedSchedule(:final occurrences)) {
      if ((contextKind == ClassWorkshopContextKind.singleClass &&
              occurrences.length != 1) ||
          (contextKind == ClassWorkshopContextKind.fixedSeries &&
              occurrences.length < 2)) {
        throw ArgumentError('Schedule does not match its display context.');
      }
    }
    final declaredPrice = price;
    if (contextKind == ClassWorkshopContextKind.singleClass &&
        (durationScope == ClassWorkshopDurationScope.wholeSeries ||
            (declaredPrice is ClassWorkshopPriceFixed &&
                declaredPrice.scope ==
                    ClassWorkshopPriceScope.perPersonFullSeries))) {
      throw ArgumentError('A single class cannot expose full-series facts.');
    }
  }
  final String offeringId;
  final int revision;
  final DateTime publishedAtUtc;
  final String publisherId;
  final String publisherType;
  final String publisherName;
  final String publisherHandle;
  final PublisherVerificationDisplayState publisherVerification;
  final ClassWorkshopInstructor instructor;
  final String title;
  final ClassWorkshopKind kind;
  final String category;
  final String subcategory;
  final String disciplineLabel;
  final String levelLabel;
  final List<String> languageLabels;
  final String shortDescription;
  final String fullDescription;
  final List<String> learningOutcomes;
  final List<String> includedMaterials;
  final List<String> requirements;
  final String coverImageUrl;
  final List<String> galleryImageUrls;
  final String displayContextId;
  final ClassWorkshopContextKind contextKind;
  final ClassWorkshopSchedule schedule;
  final int? declaredGroupLimit;
  final int? durationMinutes;
  final ClassWorkshopDurationScope? durationScope;
  final ClassWorkshopPrice price;
  final ClassWorkshopPublicLocation publicLocation;
  final ClassWorkshopEnrollment enrollment;
}

void _required(String value, String name) {
  if (value.trim().isEmpty) throw ArgumentError('$name must not be empty.');
}

void _id(String value) {
  _required(value, 'id');
  if (value.trim() != value || value.startsWith('loc_')) {
    throw ArgumentError('A public id must be permanent.');
  }
}

List<String> _strings(List<String> values) =>
    List.unmodifiable(values.map((s) => s.trim()).where((s) => s.isNotEmpty));
