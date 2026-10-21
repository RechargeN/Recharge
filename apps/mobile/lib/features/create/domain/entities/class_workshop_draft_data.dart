/// Type-specific payload for `CreateObjectType.classWorkshop` inside the common
/// Create draft envelope (CLASS_WORKSHOP_EXPERIENCE_CREATE_SPEC.md v1.2 §34,
/// CW-V1). Title, descriptions, category, criteria, location and media live on
/// the shared `CreateDraftEntity` fields, as for `sessionData`; this class
/// holds only what is specific to a declared class or fixed series.
///
/// CW-V1 has no Cohort aggregate, recurrence, inventory, Booking or Payments:
/// the group limit is a declaration and enrollment is an external link or an
/// information-only state.
library;

enum ClassWorkshopOfferingKind {
  classLesson('class'),
  workshop('workshop'),
  masterclass('masterclass'),
  course('course'),
  experience('experience');

  const ClassWorkshopOfferingKind(this.wireName);
  final String wireName;

  /// §9.2: a practical or observable result is required for these kinds.
  bool get requiresTakeHomeResult =>
      this == workshop || this == masterclass || this == experience;

  static ClassWorkshopOfferingKind? fromWire(Object? value) {
    for (final ClassWorkshopOfferingKind kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

enum ClassWorkshopContextKind {
  singleClass('single_class'),
  fixedSeries('fixed_series');

  const ClassWorkshopContextKind(this.wireName);
  final String wireName;

  static ClassWorkshopContextKind? fromWire(Object? value) {
    for (final ClassWorkshopContextKind kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

enum ClassWorkshopDeliveryFormat {
  offline('offline'),
  onlineLive('online_live'),
  hybrid('hybrid');

  const ClassWorkshopDeliveryFormat(this.wireName);
  final String wireName;

  bool get hasPlace => this != onlineLive;

  static ClassWorkshopDeliveryFormat? fromWire(Object? value) {
    for (final ClassWorkshopDeliveryFormat format in values) {
      if (format.wireName == value) return format;
    }
    return null;
  }
}

enum ClassWorkshopLocationMode {
  point('point'),
  areaOnly('area_only');

  const ClassWorkshopLocationMode(this.wireName);
  final String wireName;

  static ClassWorkshopLocationMode? fromWire(Object? value) {
    for (final ClassWorkshopLocationMode mode in values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}

/// `earlier`/`later` resolves a wall time that exists twice (DST overlap).
enum ClassWorkshopFold {
  earlier('earlier'),
  later('later');

  const ClassWorkshopFold(this.wireName);
  final String wireName;

  static ClassWorkshopFold? fromWire(Object? value) {
    for (final ClassWorkshopFold fold in values) {
      if (fold.wireName == value) return fold;
    }
    return null;
  }
}

enum ClassWorkshopPriceMode {
  notProvided('not_provided'),
  free('free'),
  fixed('fixed');

  const ClassWorkshopPriceMode(this.wireName);
  final String wireName;

  static ClassWorkshopPriceMode? fromWire(Object? value) {
    for (final ClassWorkshopPriceMode mode in values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}

enum ClassWorkshopPriceScope {
  perPersonPerClass('per_person_per_class'),
  perPersonFullSeries('per_person_full_series');

  const ClassWorkshopPriceScope(this.wireName);
  final String wireName;

  static ClassWorkshopPriceScope? fromWire(Object? value) {
    for (final ClassWorkshopPriceScope scope in values) {
      if (scope.wireName == value) return scope;
    }
    return null;
  }
}

enum ClassWorkshopEnrollmentMode {
  external('external'),
  informationOnly('information_only');

  const ClassWorkshopEnrollmentMode(this.wireName);
  final String wireName;

  static ClassWorkshopEnrollmentMode? fromWire(Object? value) {
    for (final ClassWorkshopEnrollmentMode mode in values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}

/// CW-V1 creatable information states; `unsupported_internal` is read-only.
enum ClassWorkshopInformationReason {
  closed('closed'),
  onSite('on_site'),
  notProvided('not_provided');

  const ClassWorkshopInformationReason(this.wireName);
  final String wireName;

  static ClassWorkshopInformationReason? fromWire(Object? value) {
    for (final ClassWorkshopInformationReason reason in values) {
      if (reason.wireName == value) return reason;
    }
    return null;
  }
}

/// One declared class: a local date and wall-clock minutes in the draft's
/// timezone. UTC is derived through the timezone repository, never typed.
final class ClassWorkshopOccurrence {
  const ClassWorkshopOccurrence({
    required this.id,
    required this.localDate,
    required this.startMinuteLocal,
    required this.endMinuteLocal,
    this.fold,
    this.title,
  });

  /// `loc_*` while local; the wire id is a stable UUIDv5 of the publication.
  final String id;

  /// `YYYY-MM-DD`.
  final String localDate;
  final int startMinuteLocal;
  final int endMinuteLocal;
  final ClassWorkshopFold? fold;
  final String? title;

  ClassWorkshopOccurrence copyWith({
    String? id,
    String? localDate,
    int? startMinuteLocal,
    int? endMinuteLocal,
    ClassWorkshopFold? fold,
    bool clearFold = false,
    String? title,
    bool clearTitle = false,
  }) => ClassWorkshopOccurrence(
    id: id ?? this.id,
    localDate: localDate ?? this.localDate,
    startMinuteLocal: startMinuteLocal ?? this.startMinuteLocal,
    endMinuteLocal: endMinuteLocal ?? this.endMinuteLocal,
    fold: clearFold ? null : (fold ?? this.fold),
    title: clearTitle ? null : (title ?? this.title),
  );
}

final class ClassWorkshopInstructor {
  const ClassWorkshopInstructor({
    this.sameAsPublisher = true,
    this.displayName = '',
    this.shortBio = '',
  });

  final bool sameAsPublisher;
  final String displayName;
  final String shortBio;

  ClassWorkshopInstructor copyWith({
    bool? sameAsPublisher,
    String? displayName,
    String? shortBio,
  }) => ClassWorkshopInstructor(
    sameAsPublisher: sameAsPublisher ?? this.sameAsPublisher,
    displayName: displayName ?? this.displayName,
    shortBio: shortBio ?? this.shortBio,
  );
}

final class ClassWorkshopModule {
  const ClassWorkshopModule({required this.id, required this.title});

  final String id;
  final String title;
}

final class ClassWorkshopPrice {
  const ClassWorkshopPrice({
    this.mode = ClassWorkshopPriceMode.notProvided,
    this.amountMinor,
    this.currencyCode,
    this.scope,
  });

  /// Unknown is never shown as free (DTL-CLS-01 §3.5).
  static const ClassWorkshopPrice notProvided = ClassWorkshopPrice();

  final ClassWorkshopPriceMode mode;
  final int? amountMinor;
  final String? currencyCode;
  final ClassWorkshopPriceScope? scope;
}

final class ClassWorkshopEnrollment {
  const ClassWorkshopEnrollment({
    this.mode = ClassWorkshopEnrollmentMode.informationOnly,
    this.externalUrl = '',
    this.informationReason = ClassWorkshopInformationReason.notProvided,
  });

  final ClassWorkshopEnrollmentMode mode;
  final String externalUrl;
  final ClassWorkshopInformationReason informationReason;
}

final class ClassWorkshopDraftData {
  const ClassWorkshopDraftData({
    this.schemaVersion = currentSchemaVersion,
    this.offeringKind,
    this.contextKind = ClassWorkshopContextKind.singleClass,
    this.deliveryFormat = ClassWorkshopDeliveryFormat.offline,
    this.locationMode = ClassWorkshopLocationMode.point,
    this.safeAreaLabel = '',
    this.onlineProviderLabel = '',
    required this.timezoneId,
    this.timezoneConfirmed = false,
    this.dstPolicyVersion = 1,
    this.occurrences = const <ClassWorkshopOccurrence>[],
    this.instructor = const ClassWorkshopInstructor(),
    this.outcomes = const <String>[],
    this.modules = const <ClassWorkshopModule>[],
    this.prerequisitesListed,
    this.prerequisites = const <String>[],
    this.takeHomeResult = '',
    this.includedMaterials = const <String>[],
    this.requirements = const <String>[],
    this.declaredGroupLimit,
    this.price = ClassWorkshopPrice.notProvided,
    this.enrollment = const ClassWorkshopEnrollment(),
    this.unknownFields = const <String, Object?>{},
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;

  /// Not chosen until the Creator picks one (§34.4 default "не выбран").
  final ClassWorkshopOfferingKind? offeringKind;
  final ClassWorkshopContextKind contextKind;
  final ClassWorkshopDeliveryFormat deliveryFormat;
  final ClassWorkshopLocationMode locationMode;
  final String safeAreaLabel;
  final String onlineProviderLabel;
  final String timezoneId;
  final bool timezoneConfirmed;
  final int dstPolicyVersion;
  final List<ClassWorkshopOccurrence> occurrences;
  final ClassWorkshopInstructor instructor;
  final List<String> outcomes;
  final List<ClassWorkshopModule> modules;

  /// Explicit choice: null until "No prerequisites" or a list is chosen.
  final bool? prerequisitesListed;
  final List<String> prerequisites;
  final String takeHomeResult;
  final List<String> includedMaterials;
  final List<String> requirements;

  /// A declared group size, never inventory or remaining places.
  final int? declaredGroupLimit;
  final ClassWorkshopPrice price;
  final ClassWorkshopEnrollment enrollment;

  /// Fields this app version does not understand, kept verbatim.
  final Map<String, Object?> unknownFields;

  ClassWorkshopDraftData copyWith({
    int? schemaVersion,
    ClassWorkshopOfferingKind? offeringKind,
    ClassWorkshopContextKind? contextKind,
    ClassWorkshopDeliveryFormat? deliveryFormat,
    ClassWorkshopLocationMode? locationMode,
    String? safeAreaLabel,
    String? onlineProviderLabel,
    String? timezoneId,
    bool? timezoneConfirmed,
    List<ClassWorkshopOccurrence>? occurrences,
    ClassWorkshopInstructor? instructor,
    List<String>? outcomes,
    List<ClassWorkshopModule>? modules,
    bool? prerequisitesListed,
    List<String>? prerequisites,
    String? takeHomeResult,
    List<String>? includedMaterials,
    List<String>? requirements,
    int? declaredGroupLimit,
    bool clearDeclaredGroupLimit = false,
    ClassWorkshopPrice? price,
    ClassWorkshopEnrollment? enrollment,
    Map<String, Object?>? unknownFields,
  }) => ClassWorkshopDraftData(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    offeringKind: offeringKind ?? this.offeringKind,
    contextKind: contextKind ?? this.contextKind,
    deliveryFormat: deliveryFormat ?? this.deliveryFormat,
    locationMode: locationMode ?? this.locationMode,
    safeAreaLabel: safeAreaLabel ?? this.safeAreaLabel,
    onlineProviderLabel: onlineProviderLabel ?? this.onlineProviderLabel,
    timezoneId: timezoneId ?? this.timezoneId,
    timezoneConfirmed: timezoneConfirmed ?? this.timezoneConfirmed,
    dstPolicyVersion: dstPolicyVersion,
    occurrences: occurrences ?? this.occurrences,
    instructor: instructor ?? this.instructor,
    outcomes: outcomes ?? this.outcomes,
    modules: modules ?? this.modules,
    prerequisitesListed: prerequisitesListed ?? this.prerequisitesListed,
    prerequisites: prerequisites ?? this.prerequisites,
    takeHomeResult: takeHomeResult ?? this.takeHomeResult,
    includedMaterials: includedMaterials ?? this.includedMaterials,
    requirements: requirements ?? this.requirements,
    declaredGroupLimit: clearDeclaredGroupLimit
        ? null
        : (declaredGroupLimit ?? this.declaredGroupLimit),
    price: price ?? this.price,
    enrollment: enrollment ?? this.enrollment,
    unknownFields: unknownFields ?? this.unknownFields,
  );

  static ClassWorkshopDraftData defaults({required String timezoneId}) =>
      ClassWorkshopDraftData(timezoneId: timezoneId);
}
