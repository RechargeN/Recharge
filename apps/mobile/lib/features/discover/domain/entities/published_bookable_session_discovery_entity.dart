import 'publisher_verification_display_state.dart';

enum PublishedBookableSessionPriceType { free, fixed }

enum PublishedBookableSessionMeetingMode { inPerson, online, hybrid }

final class PublishedBookableSessionOffer {
  PublishedBookableSessionOffer({
    required this.slotKey,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.timezoneId,
  }) {
    if (slotKey.trim().isEmpty) {
      throw ArgumentError.value(slotKey, 'slotKey', 'must not be empty');
    }
    if (!startAtUtc.isUtc || !endAtUtc.isUtc) {
      throw ArgumentError('Bookable Session offers must use UTC values.');
    }
    if (!endAtUtc.isAfter(startAtUtc)) {
      throw ArgumentError('endAtUtc must be after startAtUtc.');
    }
    if (timezoneId.trim().isEmpty) {
      throw ArgumentError.value(timezoneId, 'timezoneId', 'must not be empty');
    }
  }

  final String slotKey;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String timezoneId;
}

final class PublishedBookableSessionScheduleSnapshot {
  PublishedBookableSessionScheduleSnapshot({
    required this.scheduleRevision,
    required this.generatedAtUtc,
    required this.validUntilUtc,
    required List<PublishedBookableSessionOffer> offers,
  }) : offers = List<PublishedBookableSessionOffer>.unmodifiable(offers) {
    if (scheduleRevision < 1) {
      throw ArgumentError.value(
        scheduleRevision,
        'scheduleRevision',
        'must be positive for an active publication',
      );
    }
    if (!generatedAtUtc.isUtc || !validUntilUtc.isUtc) {
      throw ArgumentError('Session schedule snapshot must use UTC values.');
    }
    if (!validUntilUtc.isAfter(generatedAtUtc)) {
      throw ArgumentError('validUntilUtc must be after generatedAtUtc.');
    }
    if (offers.map((offer) => offer.slotKey).toSet().length != offers.length) {
      throw ArgumentError('Session offer slot keys must be unique.');
    }
    for (int index = 1; index < offers.length; index++) {
      if (offers[index].startAtUtc.isBefore(offers[index - 1].startAtUtc)) {
        throw ArgumentError('Session offers must be ordered by startAtUtc.');
      }
    }
  }

  final int scheduleRevision;
  final DateTime generatedAtUtc;
  final DateTime validUntilUtc;
  final List<PublishedBookableSessionOffer> offers;

  /// Recharge only knows that the Creator declared the schedule time. It
  /// never claims provider-confirmed availability in this runtime slice.
  bool get providerAvailabilityUnknown => true;
}

sealed class PublishedBookableSessionPublicLocation {
  const PublishedBookableSessionPublicLocation();

  PublishedBookableSessionMeetingMode get meetingMode;
}

final class PublishedBookableSessionPointLocation
    extends PublishedBookableSessionPublicLocation {
  PublishedBookableSessionPointLocation({
    required this.meetingMode,
    required this.venueName,
    required this.areaLabel,
    this.publicAddress = '',
    required this.latitude,
    required this.longitude,
    required this.publicGeoPrecisionMeters,
  }) {
    if (meetingMode == PublishedBookableSessionMeetingMode.online) {
      throw ArgumentError('A point location cannot use online mode.');
    }
    if (venueName.trim().isEmpty || areaLabel.trim().isEmpty) {
      throw ArgumentError('A public point needs venueName and areaLabel.');
    }
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'must be valid');
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(longitude, 'longitude', 'must be valid');
    }
    if (publicGeoPrecisionMeters < 1) {
      throw ArgumentError.value(
        publicGeoPrecisionMeters,
        'publicGeoPrecisionMeters',
        'must be positive',
      );
    }
  }

  @override
  final PublishedBookableSessionMeetingMode meetingMode;
  final String venueName;
  final String areaLabel;
  final String publicAddress;
  final double latitude;
  final double longitude;
  final int publicGeoPrecisionMeters;
}

final class PublishedBookableSessionOnlineLocation
    extends PublishedBookableSessionPublicLocation {
  const PublishedBookableSessionOnlineLocation({this.providerLabel = ''});

  @override
  PublishedBookableSessionMeetingMode get meetingMode =>
      PublishedBookableSessionMeetingMode.online;

  /// A public display label only, never a meeting URL or credential.
  final String providerLabel;
}

final class PublishedBookableSessionHiddenLocation
    extends PublishedBookableSessionPublicLocation {
  PublishedBookableSessionHiddenLocation({
    required this.meetingMode,
    this.safeAreaLabel = '',
  }) {
    if (meetingMode == PublishedBookableSessionMeetingMode.online) {
      throw ArgumentError('Online sessions use the online location variant.');
    }
  }

  @override
  final PublishedBookableSessionMeetingMode meetingMode;
  final String safeAreaLabel;
}

/// Discover-owned public read projection for one active Bookable Session
/// listing (`DTL-SES-01`). It deliberately cannot carry private schedule
/// exceptions, provider calendar state, exact hidden location or customer
/// data.
final class PublishedBookableSessionDiscoveryEntity {
  PublishedBookableSessionDiscoveryEntity({
    required this.sessionId,
    required this.publisherId,
    required this.publisherType,
    required this.publisherName,
    this.publisherHandle = '',
    this.publisherVerification = PublisherVerificationDisplayState.none,
    required this.title,
    required this.resourceName,
    this.shortDescription = '',
    this.fullDescription = '',
    required this.category,
    this.subcategory = '',
    required this.serviceCategoryLabel,
    this.coverImageUrl = '',
    List<String> galleryImageUrls = const <String>[],
    required this.durationMinutes,
    required this.maxPartySize,
    required this.priceType,
    this.priceAmountMinor,
    this.currencyCode = '',
    required this.timezoneId,
    required this.schedule,
    required this.publicLocation,
    required this.externalBookingUri,
    this.externalTermsUri,
    required this.publishedAtUtc,
  }) : galleryImageUrls = List<String>.unmodifiable(galleryImageUrls) {
    _validate();
  }

  final String sessionId;
  final String publisherId;
  final String publisherType;
  final String publisherName;
  final String publisherHandle;
  final PublisherVerificationDisplayState publisherVerification;

  final String title;
  final String resourceName;
  final String shortDescription;
  final String fullDescription;
  final String category;
  final String subcategory;
  final String serviceCategoryLabel;
  final String coverImageUrl;
  final List<String> galleryImageUrls;

  final int durationMinutes;
  final int maxPartySize;
  final PublishedBookableSessionPriceType priceType;
  final int? priceAmountMinor;
  final String currencyCode;

  final String timezoneId;
  final PublishedBookableSessionScheduleSnapshot schedule;
  final PublishedBookableSessionPublicLocation publicLocation;

  final Uri externalBookingUri;
  final Uri? externalTermsUri;
  final DateTime publishedAtUtc;

  void _validate() {
    for (final (String name, String value) in <(String, String)>[
      ('sessionId', sessionId),
      ('publisherId', publisherId),
      ('publisherName', publisherName),
      ('title', title),
      ('resourceName', resourceName),
      ('category', category),
      ('serviceCategoryLabel', serviceCategoryLabel),
      ('timezoneId', timezoneId),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be empty');
      }
    }
    if (publisherType != 'user' && publisherType != 'page') {
      throw ArgumentError.value(
        publisherType,
        'publisherType',
        'must be user or page',
      );
    }
    if (durationMinutes < 30 || durationMinutes > 180) {
      throw ArgumentError.value(
        durationMinutes,
        'durationMinutes',
        'must be between 30 and 180',
      );
    }
    if (maxPartySize < 1 || maxPartySize > 20) {
      throw ArgumentError.value(
        maxPartySize,
        'maxPartySize',
        'must be between 1 and 20',
      );
    }
    switch (priceType) {
      case PublishedBookableSessionPriceType.free:
        if (priceAmountMinor != null) {
          throw ArgumentError('A free Session cannot carry a price amount.');
        }
      case PublishedBookableSessionPriceType.fixed:
        if (priceAmountMinor == null || priceAmountMinor! <= 0) {
          throw ArgumentError('A fixed Session needs a positive amount.');
        }
        if (!RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode)) {
          throw ArgumentError.value(
            currencyCode,
            'currencyCode',
            'must be a three-letter uppercase ISO code',
          );
        }
    }
    if (schedule.offers.any((offer) => offer.timezoneId != timezoneId)) {
      throw ArgumentError('Every offer must use the listing timezone.');
    }
    _validateHttpsUri(externalBookingUri, 'externalBookingUri');
    if (externalTermsUri != null) {
      _validateHttpsUri(externalTermsUri!, 'externalTermsUri');
    }
    if (!publishedAtUtc.isUtc) {
      throw ArgumentError('publishedAtUtc must use UTC.');
    }
  }
}

void _validateHttpsUri(Uri value, String name) {
  if (value.scheme != 'https' ||
      !value.hasAuthority ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty) {
    throw ArgumentError.value(
      value,
      name,
      'must be an absolute HTTPS URI without embedded credentials',
    );
  }
}
