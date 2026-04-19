import '../../domain/entities/create_draft_entity.dart';

class CreateDraftModel {
  const CreateDraftModel({
    required this.id,
    required this.objectType,
    required this.title,
    required this.eventType,
    required this.mainCategory,
    required this.subcategory,
    required this.tags,
    required this.shortDescription,
    required this.fullDescription,
    required this.startDateTimeUtcIso,
    required this.endDateTimeUtcIso,
    required this.durationMinutes,
    required this.timezone,
    required this.registrationDeadlineUtcIso,
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
    required this.coverImage,
    required this.gallery,
    required this.draftStatus,
    required this.moderationStatus,
    required this.publishStatus,
    required this.visibility,
    required this.reportCount,
    required this.createdAtUtcIso,
    required this.updatedAtUtcIso,
    required this.publishedAtUtcIso,
  });

  final String id;
  final String objectType;
  final String title;
  final String eventType;
  final String mainCategory;
  final String subcategory;
  final List<String> tags;
  final String shortDescription;
  final String fullDescription;
  final String? startDateTimeUtcIso;
  final String? endDateTimeUtcIso;
  final int? durationMinutes;
  final String timezone;
  final String? registrationDeadlineUtcIso;
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
  final String coverImage;
  final List<String> gallery;
  final String draftStatus;
  final String moderationStatus;
  final String publishStatus;
  final String visibility;
  final int reportCount;
  final String createdAtUtcIso;
  final String updatedAtUtcIso;
  final String? publishedAtUtcIso;

  factory CreateDraftModel.fromEntity(CreateDraftEntity entity) {
    return CreateDraftModel(
      id: entity.id,
      objectType: entity.objectType.name,
      title: entity.title,
      eventType: entity.eventType,
      mainCategory: entity.mainCategory,
      subcategory: entity.subcategory,
      tags: entity.tags,
      shortDescription: entity.shortDescription,
      fullDescription: entity.fullDescription,
      startDateTimeUtcIso: entity.startDateTimeUtc?.toIso8601String(),
      endDateTimeUtcIso: entity.endDateTimeUtc?.toIso8601String(),
      durationMinutes: entity.durationMinutes,
      timezone: entity.timezone,
      registrationDeadlineUtcIso:
          entity.registrationDeadlineUtc?.toIso8601String(),
      format: entity.format,
      country: entity.country,
      city: entity.city,
      venueName: entity.venueName,
      addressLine1: entity.addressLine1,
      latitude: entity.latitude,
      longitude: entity.longitude,
      meetingPoint: entity.meetingPoint,
      minParticipants: entity.minParticipants,
      maxParticipants: entity.maxParticipants,
      currentParticipants: entity.currentParticipants,
      ageMin: entity.ageMin,
      ageMax: entity.ageMax,
      familyFriendly: entity.familyFriendly,
      kidsAllowed: entity.kidsAllowed,
      petFriendly: entity.petFriendly,
      wheelchairAccessible: entity.wheelchairAccessible,
      isFree: entity.isFree,
      basePrice: entity.basePrice,
      currency: entity.currency,
      pricingModel: entity.pricingModel,
      registrationRequired: entity.registrationRequired,
      approvalRequired: entity.approvalRequired,
      bookingLink: entity.bookingLink,
      waitlistEnabled: entity.waitlistEnabled,
      organizerId: entity.organizerId,
      organizerName: entity.organizerName,
      organizerProfileLink: entity.organizerProfileLink,
      organizerPhone: entity.organizerPhone,
      organizerEmail: entity.organizerEmail,
      coverImage: entity.media.coverImage,
      gallery: entity.media.gallery,
      draftStatus: entity.draftStatus.name,
      moderationStatus: entity.moderationStatus.name,
      publishStatus: entity.publishStatus.name,
      visibility: entity.visibility.name,
      reportCount: entity.reportCount,
      createdAtUtcIso: entity.createdAtUtc.toIso8601String(),
      updatedAtUtcIso: entity.updatedAtUtc.toIso8601String(),
      publishedAtUtcIso: entity.publishedAtUtc?.toIso8601String(),
    );
  }

  CreateDraftEntity toEntity() {
    return CreateDraftEntity(
      id: id,
      objectType: _parseObjectType(objectType),
      title: title,
      eventType: eventType,
      mainCategory: mainCategory,
      subcategory: subcategory,
      tags: tags,
      shortDescription: shortDescription,
      fullDescription: fullDescription,
      startDateTimeUtc:
          startDateTimeUtcIso == null ? null : DateTime.parse(startDateTimeUtcIso!).toUtc(),
      endDateTimeUtc:
          endDateTimeUtcIso == null ? null : DateTime.parse(endDateTimeUtcIso!).toUtc(),
      durationMinutes: durationMinutes,
      timezone: timezone,
      registrationDeadlineUtc: registrationDeadlineUtcIso == null
          ? null
          : DateTime.parse(registrationDeadlineUtcIso!).toUtc(),
      format: format,
      country: country,
      city: city,
      venueName: venueName,
      addressLine1: addressLine1,
      latitude: latitude,
      longitude: longitude,
      meetingPoint: meetingPoint,
      minParticipants: minParticipants,
      maxParticipants: maxParticipants,
      currentParticipants: currentParticipants,
      ageMin: ageMin,
      ageMax: ageMax,
      familyFriendly: familyFriendly,
      kidsAllowed: kidsAllowed,
      petFriendly: petFriendly,
      wheelchairAccessible: wheelchairAccessible,
      isFree: isFree,
      basePrice: basePrice,
      currency: currency,
      pricingModel: pricingModel,
      registrationRequired: registrationRequired,
      approvalRequired: approvalRequired,
      bookingLink: bookingLink,
      waitlistEnabled: waitlistEnabled,
      organizerId: organizerId,
      organizerName: organizerName,
      organizerProfileLink: organizerProfileLink,
      organizerPhone: organizerPhone,
      organizerEmail: organizerEmail,
      media: MediaEntity(
        coverImage: coverImage,
        gallery: gallery,
      ),
      draftStatus: _parseDraftStatus(draftStatus),
      moderationStatus: _parseModerationStatus(moderationStatus),
      publishStatus: _parsePublishStatus(publishStatus),
      visibility: _parseVisibility(visibility),
      reportCount: reportCount,
      createdAtUtc: DateTime.parse(createdAtUtcIso).toUtc(),
      updatedAtUtc: DateTime.parse(updatedAtUtcIso).toUtc(),
      publishedAtUtc:
          publishedAtUtcIso == null ? null : DateTime.parse(publishedAtUtcIso!).toUtc(),
    );
  }

  factory CreateDraftModel.fromJson(Map<String, dynamic> json) {
    return CreateDraftModel(
      id: json['id'] as String,
      objectType: json['objectType'] as String,
      title: json['title'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      mainCategory: json['mainCategory'] as String? ?? '',
      subcategory: json['subcategory'] as String? ?? '',
      tags: ((json['tags'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      shortDescription: json['shortDescription'] as String? ?? '',
      fullDescription: json['fullDescription'] as String? ?? '',
      startDateTimeUtcIso: json['startDateTimeUtcIso'] as String?,
      endDateTimeUtcIso: json['endDateTimeUtcIso'] as String?,
      durationMinutes: json['durationMinutes'] as int?,
      timezone: json['timezone'] as String? ?? 'Europe/Moscow',
      registrationDeadlineUtcIso: json['registrationDeadlineUtcIso'] as String?,
      format: json['format'] as String? ?? 'offline',
      country: json['country'] as String? ?? '',
      city: json['city'] as String? ?? '',
      venueName: json['venueName'] as String? ?? '',
      addressLine1: json['addressLine1'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      meetingPoint: json['meetingPoint'] as String? ?? '',
      minParticipants: json['minParticipants'] as int?,
      maxParticipants: json['maxParticipants'] as int?,
      currentParticipants: json['currentParticipants'] as int? ?? 0,
      ageMin: json['ageMin'] as int?,
      ageMax: json['ageMax'] as int?,
      familyFriendly: json['familyFriendly'] as bool? ?? false,
      kidsAllowed: json['kidsAllowed'] as bool? ?? false,
      petFriendly: json['petFriendly'] as bool? ?? false,
      wheelchairAccessible: json['wheelchairAccessible'] as bool? ?? false,
      isFree: json['isFree'] as bool? ?? true,
      basePrice: (json['basePrice'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      pricingModel: json['pricingModel'] as String? ?? 'fixed',
      registrationRequired: json['registrationRequired'] as bool? ?? true,
      approvalRequired: json['approvalRequired'] as bool? ?? false,
      bookingLink: json['bookingLink'] as String? ?? '',
      waitlistEnabled: json['waitlistEnabled'] as bool? ?? false,
      organizerId: json['organizerId'] as String? ?? '',
      organizerName: json['organizerName'] as String? ?? '',
      organizerProfileLink: json['organizerProfileLink'] as String? ?? '',
      organizerPhone: json['organizerPhone'] as String? ?? '',
      organizerEmail: json['organizerEmail'] as String? ?? '',
      coverImage: json['coverImage'] as String? ?? '',
      gallery: ((json['gallery'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      draftStatus: json['draftStatus'] as String? ?? 'draft',
      moderationStatus: json['moderationStatus'] as String? ?? 'none',
      publishStatus: json['publishStatus'] as String? ?? 'draft',
      visibility: json['visibility'] as String? ?? 'public',
      reportCount: json['reportCount'] as int? ?? 0,
      createdAtUtcIso:
          json['createdAtUtcIso'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      updatedAtUtcIso:
          json['updatedAtUtcIso'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      publishedAtUtcIso: json['publishedAtUtcIso'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'objectType': objectType,
      'title': title,
      'eventType': eventType,
      'mainCategory': mainCategory,
      'subcategory': subcategory,
      'tags': tags,
      'shortDescription': shortDescription,
      'fullDescription': fullDescription,
      'startDateTimeUtcIso': startDateTimeUtcIso,
      'endDateTimeUtcIso': endDateTimeUtcIso,
      'durationMinutes': durationMinutes,
      'timezone': timezone,
      'registrationDeadlineUtcIso': registrationDeadlineUtcIso,
      'format': format,
      'country': country,
      'city': city,
      'venueName': venueName,
      'addressLine1': addressLine1,
      'latitude': latitude,
      'longitude': longitude,
      'meetingPoint': meetingPoint,
      'minParticipants': minParticipants,
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'ageMin': ageMin,
      'ageMax': ageMax,
      'familyFriendly': familyFriendly,
      'kidsAllowed': kidsAllowed,
      'petFriendly': petFriendly,
      'wheelchairAccessible': wheelchairAccessible,
      'isFree': isFree,
      'basePrice': basePrice,
      'currency': currency,
      'pricingModel': pricingModel,
      'registrationRequired': registrationRequired,
      'approvalRequired': approvalRequired,
      'bookingLink': bookingLink,
      'waitlistEnabled': waitlistEnabled,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'organizerProfileLink': organizerProfileLink,
      'organizerPhone': organizerPhone,
      'organizerEmail': organizerEmail,
      'coverImage': coverImage,
      'gallery': gallery,
      'draftStatus': draftStatus,
      'moderationStatus': moderationStatus,
      'publishStatus': publishStatus,
      'visibility': visibility,
      'reportCount': reportCount,
      'createdAtUtcIso': createdAtUtcIso,
      'updatedAtUtcIso': updatedAtUtcIso,
      'publishedAtUtcIso': publishedAtUtcIso,
    };
  }

  static CreateObjectType _parseObjectType(String value) {
    return CreateObjectType.values.firstWhere(
      (CreateObjectType item) => item.name == value,
      orElse: () => CreateObjectType.event,
    );
  }

  static DraftStatus _parseDraftStatus(String value) {
    return DraftStatus.values.firstWhere(
      (DraftStatus item) => item.name == value,
      orElse: () => DraftStatus.draft,
    );
  }

  static ModerationStatus _parseModerationStatus(String value) {
    return ModerationStatus.values.firstWhere(
      (ModerationStatus item) => item.name == value,
      orElse: () => ModerationStatus.none,
    );
  }

  static PublishStatus _parsePublishStatus(String value) {
    return PublishStatus.values.firstWhere(
      (PublishStatus item) => item.name == value,
      orElse: () => PublishStatus.draft,
    );
  }

  static VisibilityType _parseVisibility(String value) {
    return VisibilityType.values.firstWhere(
      (VisibilityType item) => item.name == value,
      orElse: () => VisibilityType.public,
    );
  }
}
