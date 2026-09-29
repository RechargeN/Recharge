import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/published_bookable_session_discovery_entity.dart';

void main() {
  PublishedBookableSessionOffer offer({
    String key = 'slot_1',
    DateTime? start,
    String timezoneId = 'Europe/Riga',
  }) {
    final DateTime startsAt = start ?? DateTime.utc(2026, 9, 14, 15);
    return PublishedBookableSessionOffer(
      slotKey: key,
      startAtUtc: startsAt,
      endAtUtc: startsAt.add(const Duration(hours: 1)),
      timezoneId: timezoneId,
    );
  }

  PublishedBookableSessionDiscoveryEntity entity({
    PublishedBookableSessionPriceType priceType =
        PublishedBookableSessionPriceType.fixed,
    int? amount = 4500,
    String currency = 'EUR',
    PublishedBookableSessionScheduleSnapshot? schedule,
    Uri? bookingUri,
    PublishedBookableSessionPublicLocation? location,
  }) {
    return PublishedBookableSessionDiscoveryEntity(
      sessionId: 'session_1',
      publisherId: 'page_1',
      publisherType: 'page',
      publisherName: 'Recharge Studio',
      title: 'Персональная тренировка',
      resourceName: 'Зал 2',
      category: 'sport_fitness',
      serviceCategoryLabel: 'Personal training',
      durationMinutes: 60,
      maxPartySize: 1,
      priceType: priceType,
      priceAmountMinor: amount,
      currencyCode: currency,
      timezoneId: 'Europe/Riga',
      schedule:
          schedule ??
          PublishedBookableSessionScheduleSnapshot(
            scheduleRevision: 1,
            generatedAtUtc: DateTime.utc(2026, 9, 7, 10),
            validUntilUtc: DateTime.utc(2026, 9, 7, 11),
            offers: <PublishedBookableSessionOffer>[offer()],
          ),
      publicLocation:
          location ??
          PublishedBookableSessionPointLocation(
            meetingMode: PublishedBookableSessionMeetingMode.inPerson,
            venueName: 'Recharge Studio',
            areaLabel: 'Центр Риги',
            publicAddress: 'Brīvības iela, Rīga',
            latitude: 56.953,
            longitude: 24.113,
            publicGeoPrecisionMeters: 50,
          ),
      externalBookingUri:
          bookingUri ?? Uri.parse('https://booking.example/session/1'),
      publishedAtUtc: DateTime.utc(2026, 9, 1),
    );
  }

  test('accepts a coherent fixed-price public projection', () {
    final PublishedBookableSessionDiscoveryEntity value = entity();
    expect(value.sessionId, 'session_1');
    expect(value.schedule.providerAvailabilityUnknown, isTrue);
  });

  test('free never carries a fabricated zero amount', () {
    expect(
      () => entity(
        priceType: PublishedBookableSessionPriceType.free,
        amount: 0,
        currency: '',
      ),
      throwsArgumentError,
    );
    expect(
      entity(
        priceType: PublishedBookableSessionPriceType.free,
        amount: null,
        currency: '',
      ).priceAmountMinor,
      isNull,
    );
  });

  test('fixed price requires positive minor units and ISO currency', () {
    expect(() => entity(amount: 0), throwsArgumentError);
    expect(() => entity(currency: 'eur'), throwsArgumentError);
  });

  test('schedule rejects duplicate, unordered and foreign-timezone offers', () {
    expect(
      () => PublishedBookableSessionScheduleSnapshot(
        scheduleRevision: 1,
        generatedAtUtc: DateTime.utc(2026, 9, 7, 10),
        validUntilUtc: DateTime.utc(2026, 9, 7, 11),
        offers: <PublishedBookableSessionOffer>[
          offer(key: 'same'),
          offer(key: 'same', start: DateTime.utc(2026, 9, 15)),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => PublishedBookableSessionScheduleSnapshot(
        scheduleRevision: 1,
        generatedAtUtc: DateTime.utc(2026, 9, 7, 10),
        validUntilUtc: DateTime.utc(2026, 9, 7, 11),
        offers: <PublishedBookableSessionOffer>[
          offer(key: 'later', start: DateTime.utc(2026, 9, 15)),
          offer(key: 'earlier', start: DateTime.utc(2026, 9, 14)),
        ],
      ),
      throwsArgumentError,
    );
    final PublishedBookableSessionScheduleSnapshot foreignTimezone =
        PublishedBookableSessionScheduleSnapshot(
          scheduleRevision: 1,
          generatedAtUtc: DateTime.utc(2026, 9, 7, 10),
          validUntilUtc: DateTime.utc(2026, 9, 7, 11),
          offers: <PublishedBookableSessionOffer>[
            offer(timezoneId: 'Europe/Tallinn'),
          ],
        );
    expect(() => entity(schedule: foreignTimezone), throwsArgumentError);
  });

  test('booking URI must be HTTPS and contain no credentials', () {
    expect(
      () => entity(bookingUri: Uri.parse('http://booking.example/session')),
      throwsArgumentError,
    );
    expect(
      () => entity(
        bookingUri: Uri.parse('https://user:secret@booking.example/session'),
      ),
      throwsArgumentError,
    );
  });

  test('online and hidden locations cannot expose point geometry', () {
    const PublishedBookableSessionPublicLocation online =
        PublishedBookableSessionOnlineLocation(providerLabel: 'Zoom');
    final PublishedBookableSessionPublicLocation hidden =
        PublishedBookableSessionHiddenLocation(
          meetingMode: PublishedBookableSessionMeetingMode.hybrid,
          safeAreaLabel: 'Рига',
        );
    expect(online, isNot(isA<PublishedBookableSessionPointLocation>()));
    expect(hidden, isNot(isA<PublishedBookableSessionPointLocation>()));
  });

  test('public collections are immutable', () {
    final List<String> gallery = <String>['one.jpg'];
    final PublishedBookableSessionDiscoveryEntity value =
        PublishedBookableSessionDiscoveryEntity(
          sessionId: 'session_1',
          publisherId: 'page_1',
          publisherType: 'page',
          publisherName: 'Studio',
          title: 'Session',
          resourceName: 'Room',
          category: 'wellness',
          serviceCategoryLabel: 'Wellness session',
          galleryImageUrls: gallery,
          durationMinutes: 60,
          maxPartySize: 1,
          priceType: PublishedBookableSessionPriceType.free,
          timezoneId: 'Europe/Riga',
          schedule: PublishedBookableSessionScheduleSnapshot(
            scheduleRevision: 1,
            generatedAtUtc: DateTime.utc(2026, 9, 7, 10),
            validUntilUtc: DateTime.utc(2026, 9, 7, 11),
            offers: const <PublishedBookableSessionOffer>[],
          ),
          publicLocation: const PublishedBookableSessionOnlineLocation(),
          externalBookingUri: Uri.parse('https://booking.example/session'),
          publishedAtUtc: DateTime.utc(2026, 9, 1),
        );
    gallery.add('two.jpg');
    expect(value.galleryImageUrls, <String>['one.jpg']);
    expect(
      () => value.galleryImageUrls.add('three.jpg'),
      throwsUnsupportedError,
    );
  });
}
