enum CreateObjectType { event, place }

enum DraftStatus { draft, pendingReview, published, archived, hidden, deleted }

enum ModerationStatus { none, pending, approved, rejected }

enum PublishStatus { draft, pendingReview, published, archived, hidden, deleted }

enum VisibilityType { public, private, unlisted }

class MediaEntity {
  const MediaEntity({
    required this.coverImage,
    required this.gallery,
  });

  final String coverImage;
  final List<String> gallery;

  MediaEntity copyWith({
    String? coverImage,
    List<String>? gallery,
  }) {
    return MediaEntity(
      coverImage: coverImage ?? this.coverImage,
      gallery: gallery ?? this.gallery,
    );
  }
}

class CreateDraftEntity {
  const CreateDraftEntity({
    required this.id,
    required this.objectType,
    required this.title,
    required this.eventType,
    required this.mainCategory,
    required this.subcategory,
    required this.tags,
    required this.shortDescription,
    required this.fullDescription,
    required this.startDateTimeUtc,
    required this.endDateTimeUtc,
    required this.durationMinutes,
    required this.timezone,
    required this.registrationDeadlineUtc,
    required this.format,
    required this.country,
    required this.city,
    required this.venueName,
    required this.addressLine1,
    required this.latitude,
    required this.longitude,
    required this.meetingPoint,
    required this.minParticipants,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.ageMin,
    required this.ageMax,
    required this.familyFriendly,
    required this.kidsAllowed,
    required this.petFriendly,
    required this.wheelchairAccessible,
    required this.isFree,
    required this.basePrice,
    required this.currency,
    required this.pricingModel,
    required this.registrationRequired,
    required this.approvalRequired,
    required this.bookingLink,
    required this.waitlistEnabled,
    required this.organizerId,
    required this.organizerName,
    required this.organizerProfileLink,
    required this.organizerPhone,
    required this.organizerEmail,
    required this.media,
    required this.draftStatus,
    required this.moderationStatus,
    required this.publishStatus,
    required this.visibility,
    required this.reportCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.publishedAtUtc,
  });

  final String id;
  final CreateObjectType objectType;

  final String title;
  final String eventType;
  final String mainCategory;
  final String subcategory;
  final List<String> tags;
  final String shortDescription;
  final String fullDescription;

  final DateTime? startDateTimeUtc;
  final DateTime? endDateTimeUtc;
  final int? durationMinutes;
  final String timezone;
  final DateTime? registrationDeadlineUtc;

  final String format;
  final String country;
  final String city;
  final String venueName;
  final String addressLine1;
  final double? latitude;
  final double? longitude;
  final String meetingPoint;

  final int? minParticipants;
  final int? maxParticipants;
  final int currentParticipants;
  final int? ageMin;
  final int? ageMax;
  final bool familyFriendly;
  final bool kidsAllowed;
  final bool petFriendly;
  final bool wheelchairAccessible;

  final bool isFree;
  final double? basePrice;
  final String currency;
  final String pricingModel;

  final bool registrationRequired;
  final bool approvalRequired;
  final String bookingLink;
  final bool waitlistEnabled;

  final String organizerId;
  final String organizerName;
  final String organizerProfileLink;
  final String organizerPhone;
  final String organizerEmail;

  final MediaEntity media;

  final DraftStatus draftStatus;
  final ModerationStatus moderationStatus;
  final PublishStatus publishStatus;
  final VisibilityType visibility;
  final int reportCount;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? publishedAtUtc;

  factory CreateDraftEntity.defaults({
    required String organizerId,
    required String organizerEmail,
    required String organizerName,
  }) {
    final DateTime now = DateTime.now().toUtc();
    return CreateDraftEntity(
      id: 'draft_${now.microsecondsSinceEpoch}',
      objectType: CreateObjectType.event,
      title: '',
      eventType: 'standard',
      mainCategory: '',
      subcategory: '',
      tags: const <String>[],
      shortDescription: '',
      fullDescription: '',
      startDateTimeUtc: null,
      endDateTimeUtc: null,
      durationMinutes: null,
      timezone: 'Europe/Moscow',
      registrationDeadlineUtc: null,
      format: 'offline',
      country: 'Latvia',
      city: '',
      venueName: '',
      addressLine1: '',
      latitude: null,
      longitude: null,
      meetingPoint: '',
      minParticipants: null,
      maxParticipants: null,
      currentParticipants: 0,
      ageMin: null,
      ageMax: null,
      familyFriendly: true,
      kidsAllowed: true,
      petFriendly: false,
      wheelchairAccessible: false,
      isFree: true,
      basePrice: null,
      currency: 'EUR',
      pricingModel: 'fixed',
      registrationRequired: true,
      approvalRequired: false,
      bookingLink: '',
      waitlistEnabled: false,
      organizerId: organizerId,
      organizerName: organizerName,
      organizerProfileLink: '',
      organizerPhone: '',
      organizerEmail: organizerEmail,
      media: const MediaEntity(
        coverImage: '',
        gallery: <String>[],
      ),
      draftStatus: DraftStatus.draft,
      moderationStatus: ModerationStatus.none,
      publishStatus: PublishStatus.draft,
      visibility: VisibilityType.public,
      reportCount: 0,
      createdAtUtc: now,
      updatedAtUtc: now,
      publishedAtUtc: null,
    );
  }

  CreateDraftEntity copyWith({
    CreateObjectType? objectType,
    String? title,
    String? eventType,
    String? mainCategory,
    String? subcategory,
    List<String>? tags,
    String? shortDescription,
    String? fullDescription,
    DateTime? startDateTimeUtc,
    bool clearStartDateTimeUtc = false,
    DateTime? endDateTimeUtc,
    bool clearEndDateTimeUtc = false,
    int? durationMinutes,
    bool clearDurationMinutes = false,
    String? timezone,
    DateTime? registrationDeadlineUtc,
    bool clearRegistrationDeadlineUtc = false,
    String? format,
    String? country,
    String? city,
    String? venueName,
    String? addressLine1,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    String? meetingPoint,
    int? minParticipants,
    bool clearMinParticipants = false,
    int? maxParticipants,
    bool clearMaxParticipants = false,
    int? currentParticipants,
    int? ageMin,
    bool clearAgeMin = false,
    int? ageMax,
    bool clearAgeMax = false,
    bool? familyFriendly,
    bool? kidsAllowed,
    bool? petFriendly,
    bool? wheelchairAccessible,
    bool? isFree,
    double? basePrice,
    bool clearBasePrice = false,
    String? currency,
    String? pricingModel,
    bool? registrationRequired,
    bool? approvalRequired,
    String? bookingLink,
    bool? waitlistEnabled,
    String? organizerName,
    String? organizerProfileLink,
    String? organizerPhone,
    String? organizerEmail,
    MediaEntity? media,
    DraftStatus? draftStatus,
    ModerationStatus? moderationStatus,
    PublishStatus? publishStatus,
    VisibilityType? visibility,
    int? reportCount,
    DateTime? updatedAtUtc,
    DateTime? publishedAtUtc,
    bool clearPublishedAtUtc = false,
  }) {
    return CreateDraftEntity(
      id: id,
      objectType: objectType ?? this.objectType,
      title: title ?? this.title,
      eventType: eventType ?? this.eventType,
      mainCategory: mainCategory ?? this.mainCategory,
      subcategory: subcategory ?? this.subcategory,
      tags: tags ?? this.tags,
      shortDescription: shortDescription ?? this.shortDescription,
      fullDescription: fullDescription ?? this.fullDescription,
      startDateTimeUtc: clearStartDateTimeUtc
          ? null
          : (startDateTimeUtc ?? this.startDateTimeUtc),
      endDateTimeUtc:
          clearEndDateTimeUtc ? null : (endDateTimeUtc ?? this.endDateTimeUtc),
      durationMinutes: clearDurationMinutes
          ? null
          : (durationMinutes ?? this.durationMinutes),
      timezone: timezone ?? this.timezone,
      registrationDeadlineUtc: clearRegistrationDeadlineUtc
          ? null
          : (registrationDeadlineUtc ?? this.registrationDeadlineUtc),
      format: format ?? this.format,
      country: country ?? this.country,
      city: city ?? this.city,
      venueName: venueName ?? this.venueName,
      addressLine1: addressLine1 ?? this.addressLine1,
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      meetingPoint: meetingPoint ?? this.meetingPoint,
      minParticipants:
          clearMinParticipants ? null : (minParticipants ?? this.minParticipants),
      maxParticipants:
          clearMaxParticipants ? null : (maxParticipants ?? this.maxParticipants),
      currentParticipants: currentParticipants ?? this.currentParticipants,
      ageMin: clearAgeMin ? null : (ageMin ?? this.ageMin),
      ageMax: clearAgeMax ? null : (ageMax ?? this.ageMax),
      familyFriendly: familyFriendly ?? this.familyFriendly,
      kidsAllowed: kidsAllowed ?? this.kidsAllowed,
      petFriendly: petFriendly ?? this.petFriendly,
      wheelchairAccessible: wheelchairAccessible ?? this.wheelchairAccessible,
      isFree: isFree ?? this.isFree,
      basePrice: clearBasePrice ? null : (basePrice ?? this.basePrice),
      currency: currency ?? this.currency,
      pricingModel: pricingModel ?? this.pricingModel,
      registrationRequired: registrationRequired ?? this.registrationRequired,
      approvalRequired: approvalRequired ?? this.approvalRequired,
      bookingLink: bookingLink ?? this.bookingLink,
      waitlistEnabled: waitlistEnabled ?? this.waitlistEnabled,
      organizerId: organizerId,
      organizerName: organizerName ?? this.organizerName,
      organizerProfileLink: organizerProfileLink ?? this.organizerProfileLink,
      organizerPhone: organizerPhone ?? this.organizerPhone,
      organizerEmail: organizerEmail ?? this.organizerEmail,
      media: media ?? this.media,
      draftStatus: draftStatus ?? this.draftStatus,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      publishStatus: publishStatus ?? this.publishStatus,
      visibility: visibility ?? this.visibility,
      reportCount: reportCount ?? this.reportCount,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      publishedAtUtc:
          clearPublishedAtUtc ? null : (publishedAtUtc ?? this.publishedAtUtc),
    );
  }
}
